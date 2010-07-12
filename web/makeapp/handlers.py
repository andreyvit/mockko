
import png
from StringIO import StringIO
import os
import logging
import mimetypes
import re
import hashlib

from tipfy import RequestHandler, url_for, redirect, redirect_to, render_json_response, request, BadRequest, NotFound, Response
from tipfy.ext.jinja2 import render_response
# from tipfy.ext.user import user_required, get_current_user

from django.utils import simplejson as json

from google.appengine.api import users
from google.appengine.api import images, mail
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
    account = Account(user=user)
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
        apps = App.all()
        if not users.is_current_user_admin():
            apps = apps.filter('editors', account.key())
        apps = apps.order('-updated_at').fetch(100)

        apps_json = [ { 'id': app.key().id(),
                        'created_by': app.created_by.user.user_id(),
                        'nickname': app.created_by.user.nickname(),
                        'body': app.body } for app in apps]
        return render_json_response({ 'apps': apps_json, 'current_user': account.user.user_id() if account else None })

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

IMAGES_QUERY = \
    "SELECT * FROM Image WHERE group = :1 ORDER BY created_at"

def format_image(image):
    return {
        'id': image.key().id_or_name(),
        'fileName': image.file_name,
        'width': image.width,
        'height': image.height,
        'digest': image.digest
    }

def format_images(group):
    for image in db.GqlQuery(IMAGES_QUERY, group):
        yield format_image(image)

def format_group(group, read_write):
    return {'id': group.key().id_or_name(),
            'name': group.name,
            'writeable': read_write,
            'effect': group.effect,
            'images': list(format_images(group))}

def get_image_group_or_404(group_id):
    try:
        group = ImageGroup.get_by_id(int(group_id))
    except ValueError:
        group =ImageGroup.get_by_key_name(group_id)
    if not group:
        raise NotFound()
    return group

class GetImageListHandler(RequestHandler):

    COMMON_GROUPS_QUERY = \
        "SELECT * FROM ImageGroup WHERE owner = NULL ORDER BY priority"

    @auth
    def get(self, user, account, **kwargs):
        images = []
        for group in db.GqlQuery(self.COMMON_GROUPS_QUERY):
            images += [format_group(group, False)]
        for group in account.imagegroup_set.order('priority'):
            images += [format_group(group, True)]
        return render_json_response(images)

class GetImageGroupHandler(RequestHandler):
    @auth
    def get(self, user, account, group_name):
        group = get_image_group_or_404(group_name)
        return render_json_response(format_group(group, group.owner == account))

class SaveImageHandler(RequestHandler):
    @auth
    def post(self, user, account, group_name):
        group = get_image_group_or_404(group_name)

        # FIXME: admins!
        if group.owner.key() != account.key():
            return render_json_response({ 'error': 'access-denied'})

        file_name = request.headers['X-File-Name']
        data = request.data

        mime_type = mimetypes.guess_type(file_name)
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
    def get(self, group_name, image_name):
        filename, effect = parse_image_name(image_name)

        group = get_image_group_or_404(group_name)

        img = db.GqlQuery("SELECT * FROM Image WHERE file_name = :1 AND group = :2",
                          filename, group).get()
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
    def delete(self, user, account, group_name, image_name):
        group = get_image_group_or_404(group_name)

        # FIXME: admins!
        if group.owner.key() != account.key():
            return render_json_response({'error': 'access-denied'})

        img = Image.get_by_key_name(image_name)
        if img is None:
            raise NotFound()

        if img.data:
            img.data.delete()
        img.delete()

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
            <script charset='utf-8' src='/static/lib/jquery-1.4.2.js' type='text/javascript'></script>
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
