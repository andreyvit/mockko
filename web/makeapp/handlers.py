
import png
from StringIO import StringIO
import os
import logging
import mimetypes
import re
import hashlib
import time

from tipfy import RequestHandler, url_for, redirect, redirect_to, render_json_response, request, BadRequest, NotFound, Response
from tipfy.ext.jinja2 import render_response
# from tipfy.ext.user import user_required, get_current_user

from django.utils import simplejson as json

from google.appengine.api import users
from google.appengine.api import images, mail
from google.appengine.api import memcache
from google.appengine.ext import db
from google.appengine.ext.deferred import defer
from google.appengine.ext.webapp.util import login_required

from makeapp.models import Account, App, ImageGroup, Image, ImageData

def notify_admins_about_new_user_signup(user):
    mail.send_mail_to_admins(sender="Mockko <andreyvit@gmail.com>",
                  subject="[Mockko] new user signed up: %s" % user.email(),
                  body="""Dear Creators,

Another human being is about to discover just how awesome our
iPhone mock-up tool is.

Say hello to %s!

-- Your Mockko.
    """ % user.email())

def simple_decorator(decorator):
    def new_decorator(f):
        g = decorator(f)
        g.__name__ = f.__name__
        g.__doc__ = f.__doc__
        g.__dict__.update(f.__dict__)
        return g
    new_decorator.__name__ = decorator.__name__
    new_decorator.__doc__ = decorator.__doc__
    new_decorator.__dict__.update(decorator.__dict__)
    return new_decorator

def create_account(user):
    """
    This function creates account for new user
    """
    account = Account(user=user, newsletter=True)
    account.put()
    ig = ImageGroup(name='Custom Images', owner=account, priority=0)
    ig.save()
    notify_admins_about_new_user_signup(user)
    return account

@simple_decorator
def auth(func):
    def _auth(self, *args, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({'error': 'signed-out'})
        account = Account.all().filter('user', user).get()
        if account is None:
            account = create_account(user)
        return func(self, user, account, *args, **kwargs)
    return _auth

class GetUserDataHandler(RequestHandler):

    @auth
    def get(self, user, account):
        return render_json_response({
            'logout_url': users.create_logout_url(url_for('home')),
            'profile-created': account.profile_created,
            'newsletter': account.newsletter,
            'full-name': account.full_name
        })

class SetUserDataHandler(RequestHandler):
    @auth
    def post(self, user, account):
        user_info = json.loads(request.data)
        account.profile_created = True
        account.newsletter = user_info['newsletter']
        account.full_name = user_info['full-name']
        account.put()

        return render_json_response({ 'status': 'ok' })

class GetAppListHandler(RequestHandler):

    @auth
    def get(self, user, account, **kwargs):
        users_info = {}

        app_query = App.all()
        if not users.is_current_user_admin():
            app_query = app_query.filter('editors', account.key())
        apps = app_query.fetch(100)

        accounts_by_key = {}
        for acc in Account.get(set([app._created_by for app in apps] + [account.key()])):
            accounts_by_key[acc.key()] = acc

            users_info[acc.user.user_id()] = {
                'apps': [],
                'full_name': acc.full_name or '',
                'email': acc.user.email(),
                'created_at': time.mktime(acc.created_at.timetuple()),
            }

        for app in apps:
            users_info[accounts_by_key[app._created_by].user.user_id()]['apps'].append(
                { 'id': app.key().id(), 'body': app.body, }
            )

        return render_json_response({ 'users': users_info, 'current_user': account.user.user_id() if account else None })

class SaveAppHandler(RequestHandler):

    @auth
    def post(self, user, account, **kwargs):
        app_id = (kwargs['app_id'] if 'app_id' in kwargs else 'new')
        body_json = request.data
        body = json.loads(body_json)

        if 'name' not in body:
            return BadRequest("Invalid JSON data")

        if app_id == 'new':
            app = App(name=body['name'], created_by=account.key(), editors=[account.key()])
        else:
            app = App.get_by_id(int(app_id))
            if app is None:
                return render_json_response({ 'error': 'app-not-found' })
            if account.key() not in app.editors:
                return render_json_response({ 'error': 'access-denied' })
        app.name = body['name']
        app.body = db.Text(body_json.decode('utf-8'))
        app.put()
        return render_json_response({ 'id': app.key().id()    })

class DeleteAppHandler(RequestHandler):

    @auth
    def delete(self, user, account, **kwargs):
        app_id = kwargs['app_id']

        app = App.get_by_id(int(app_id))
        if app is None:
            return render_json_response({ 'error': 'app-not-found' })
        if account.key() not in app.editors:
            return render_json_response({ 'error': 'access-denied' })
        app.delete()
        return render_json_response({ 'status': 'ok' })

def format_image(image):
    return {
        'id': image.key().id_or_name(),
        'fileName': image.file_name,
        'width': image.width,
        'height': image.height,
        'digest': image.digest
    }

def format_images(group):
    for image in group.image_set.order('created_at').fetch(1000):
        yield format_image(image)

def format_group_without_caching(group):
    return {'id': group.key().id_or_name(),
            'name': group.name,
            'effect': group.effect,
            'images': list(format_images(group))}

def format_group(group, read_write):
    # only cache unowned groups because we can't afford other groups being stale
    if group.owner is None:
        memcache_key = group.memcache_key()
        group_info = memcache.get(memcache_key)
        if group_info is None:
            group_info = format_group_without_caching(group)
            memcache.add(memcache_key, group_info, 60)
    else:
        group_info = format_group_without_caching(group)
    group_info['writeable'] = read_write
    return group_info

def get_image_group_or_404(group_id):
    try:
        group = ImageGroup.get_by_id(int(group_id))
    except ValueError:
        group = ImageGroup.get_by_key_name(group_id)
    if not group:
        raise NotFound()
    return group

class GetImageListHandler(RequestHandler):

    @auth
    def get(self, user, account, **kwargs):
        images = []
        for group in ImageGroup.all().filter('owner', None).order('priority').fetch(1000):
            images += [format_group(group, False)]
        for group in account.imagegroup_set.order('priority'):
            images += [format_group(group, True)]
        return render_json_response(images)

class GetImageGroupHandler(RequestHandler):
    @auth
    def get(self, user, account, group_id):
        group = get_image_group_or_404(group_id)
        return render_json_response(format_group(group, group.owner == account))

class SaveImageHandler(RequestHandler):
    @auth
    def post(self, user, account, group_id):
        group = get_image_group_or_404(group_id)

        # FIXME: admins!
        if group.owner.key() != account.key():
            return render_json_response({ 'error': 'access-denied'})

        file_name = request.headers['X-File-Name']
        data = request.data

        mime_type = mimetypes.guess_type(file_name)[0]
        if not mime_type.startswith('image/'):
            return render_json_response({'error': 'wrong-file-type'})

        img = images.Image(data)

        imgdata = ImageData(data=data)
        imgdata.put()

        image = Image(file_name=file_name,
                      width=img.width,
                      height=img.height,
                      mime_type=mime_type,
                      group=group,
                      data=imgdata,
                      digest=hashlib.sha1(data).hexdigest())
        image.put()

        memcache.delete(group.memcache_key())

        return render_json_response({ 'name': image.file_name })

#
# UGLY HACK: effect name is embedded to filename
#
KNOWN_EFFECTS = set(['iphone-tabbar-active', 'iphone-tabbar-inactive'])
FILENAME_RE = re.compile('^(.+\.)([^.]+)\.([^.]+)$')

def parse_image_name(name):
    '''
    This function parses image name and extracts effect name from it.
    It is supposed that effect names do not have '.' inside and image
    names contain single extension immediately preceded by effect name.
    '''
    r = FILENAME_RE.match(name)
    if r and r.group(2) in KNOWN_EFFECTS:
        return r.group(1) + r.group(3), r.group(2)
    else:
        return name, None
#
# END OF UGLY HACK
#

def overlay_png(underlay, overlay):
    '''
    Arguments: underlay and overlay png.Reader objects

    Return value: StringIO with processed image
    '''
    sw, sh, spix, smeta = underlay.asRGBA8()
    uw, uh, upix, umeta = overlay.asRGBA8()

    spix = list(spix)
    upix = list(upix)

    wins = (sw-uw) / 2
    hins = (sh-uh) / 2

    res = []

    sy = 0
    upix = iter(upix)
    for srow in iter(spix):
        srow = iter(srow)
        uy = sy - hins
        urow = (iter(upix.next()) if uy >= 0 and uy < uh else None)
        resrow = []
        res.append(resrow)
        sx = 0
        while sx < sw:
            s_r, s_g, s_b, s_a = srow.next(), srow.next(), srow.next(), srow.next()

            ux = sx - wins
            if urow is not None and ux >= 0 and ux < uw:
                u_r, u_g, u_b, u_a = urow.next(), urow.next(), urow.next(), urow.next()
            else:
                u_a = 0

            resrow.append(s_r)
            resrow.append(s_g)
            resrow.append(s_b)
            resrow.append(u_a)
            sx += 1

        sy += 1

    f = StringIO()
    png.Writer(sw, sh, bitdepth=8, alpha=True, planes=4).write(f, res)
    return f

class ServeImageHandler(RequestHandler):
    def get(self, group_id, image_name):
        filename, effect = parse_image_name(image_name)

        group = get_image_group_or_404(group_id)

        img = Image.all().filter('file_name', filename).filter('group', group).get()
        if not img or not img.data:
            raise NotFound()

        if not effect:
            response_data = img.data.data
            response_type = img.mime_type
        else:
            square_file = os.path.join(os.path.dirname(__file__), '..',
                                       'server-images', effect + '.png')

            f = overlay_png(png.Reader(file=open(square_file, 'rb')),
                            png.Reader(bytes=img.data.data))

            response_data = f.getvalue()
            response_type = 'image/png' # We know overlay_png returns PNG

        return Response(response=response_data,
                        mimetype=response_type,
                        headers={'Cache-Control' : 'private, max-age=31536000'})

class DeleteImageHandler(RequestHandler):
    @auth
    def delete(self, user, account, group_id, image_name):
        group = get_image_group_or_404(group_id)

        # FIXME: admins!
        if group.owner.key() != account.key():
            return render_json_response({'error': 'access-denied'})

        img = group.image_set.filter('file_name', image_name).get()
        if img is None:
            raise NotFound()

        if img.data:
            img.data.delete()
        img.delete()

        memcache.delete(group.memcache_key())

        return render_json_response({'status': 'ok'})

class RunAppHandler(RequestHandler):

    def get(self, app_id):

        # user = users.get_current_user()
        # if user is None:
        #     return render_json_response({ 'error': 'signed-out' })
        # else:
        #     account = Account.all().filter('user', user).get()
        #     if account is None:
        #         account = Account(user=user)
        #         account.put()
        app = App.get_by_id(int(app_id))
        if app is None:
            return render_json_response({ 'error': 'app-not-found' })
        # if account.key() not in app.editors:
        #     return render_json_response({ 'error': 'access-denied' })

        body_json = app.body
        content = json.loads(body_json)

        body = "\n".join([s['html'] for s in content['screens']])
        body = body.replace('"static', '"/static')
        body = body.replace('"images', '"/images')

        html="""
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
            <meta name="apple-mobile-web-app-capable" content="yes" />
            <meta name="apple-mobile-web-app-status-bar-style" content="default" />
            <link charset='utf-8' href='/static/iphone/iphone.css' media='screen' rel='stylesheet' title='no title' type='text/css' />
            <script charset='utf-8' src='/static/lib/jquery.js' type='text/javascript'></script>
            <style> .c-background { display: none; }</style>
            <script>
                jQuery(function($) {
                    $('.c-background:first').show();
                    $('.has-action').click(function() {
                        var action = $(this).attr('action');
                        var m;
                        if (m = action.match(/^screen:(.*)$/)) {
                            var screenId = "screen-" + m[1];
                            console.log("Jumping to #" + screenId);
                            $('.c-background').hide();
                            $('#' + screenId).show();
                        }
                    });
                });
            </script>
            <title>
              %(title)s
            </title>
          </head>
          <body class="run">
            %(content)s
          </body>
        </html>
""" % dict(title=content['name'], content=body)

        return Response(html, mimetype="text/html")

class StatusHandler(RequestHandler):

    def get(self):
        account_count = Account.all().count(1000)
        app_count = App.all().count(1000)

        html="""
        <pre>
        Mockko statistics:

        Users:          %(account_count)d
        Applications:   %(app_count)d
        """ % dict(account_count=account_count, app_count=app_count)

        return Response(html, mimetype="text/html")

class UserStatsHandler(RequestHandler):

    def get(self):
        account_count = Account.all().count(1000)
        app_count = App.all().count(1000)

        html="""<?xml version="1.0" encoding="UTF-8"?>
        <root>
        	<item>
        		<value>%(app_count)d</value>
        		<text>Apps</text>
        	</item>
        	<item>
        		<value>0</value>
        		<text></text>
        	</item>
        	<item>
        		<value>%(account_count)d</value>
        		<text>Accounts</text>
        	</item>
        </root>
        """ % dict(account_count=account_count, app_count=app_count)

        return Response(html, mimetype="text/xml")
    post = get

class UserExportHandler(RequestHandler):

    def get(self):
        accounts = Account.all().fetch(1000)
        lines = []
        lines.append("email,name")
        for account in accounts:
            lines.append("%s,%s" % (account.user.email(), account.full_name))
        return Response("\n".join(lines), mimetype="text/csv")
