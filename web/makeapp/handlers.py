
import png
from StringIO import StringIO
import os
import logging

from tipfy import RequestHandler, url_for, redirect, redirect_to, render_json_response, request, BadRequest, NotFound, Response
from tipfy.ext.jinja2 import render_response
# from tipfy.ext.user import user_required, get_current_user

from django.utils import simplejson as json

from google.appengine.api import users
from google.appengine.api import images
from google.appengine.ext import db
from google.appengine.ext.deferred import defer
from google.appengine.ext.webapp.util import login_required

from makeapp.models import Account, App, Image, ImageData

class HomeHandler(RequestHandler):
  
    def get(self, **kwargs):
        return redirect_to('designer')
        
class GetUserDataHandler(RequestHandler):
    
    def get(self, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({
                'status': 'anonymous',
                'login_url': users.create_login_url('/'),
            })
        else:
            return render_json_response({
                'status': 'authenticated',
                'logout_url': users.create_logout_url(url_for('home')),
            })

class GetAppListHandler(RequestHandler):

    def get(self, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                apps = []
            else:
                apps = App.all().filter('editors', account.key()).order('-updated_at').fetch(100)

            apps_json = [ { 'id': app.key().id(), 'body': app.body } for app in apps]
            return render_json_response({ 'apps': apps_json })

class SaveAppHandler(RequestHandler):
    
    def post(self, **kwargs):
        app_id = (kwargs['app_id'] if 'app_id' in kwargs else 'new')
        body_json = request.data
        body = json.loads(body_json)
        
        if 'name' not in body:
            return BadRequest("Invalid JSON data")
        
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                account = Account(user=user)
                account.put()
            if app_id == 'new':
                app = App(name=body['name'], created_by=account.key(), editors=[account.key()])
            else:
                app = App.get_by_id(int(app_id))
                if app is None:
                    return render_json_response({ 'error': 'app-not-found' })
                if account.key() not in app.editors:
                    return render_json_response({ 'error': 'access-denied' })
            app.name = body['name']
            app.body = db.Text(body_json)
            app.put()
            return render_json_response({ 'id': app.key().id()    })

class DeleteAppHandler(RequestHandler):
    
    def delete(self, **kwargs):
        app_id = kwargs['app_id']
        
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                account = Account(user=user)
                account.put()
            app = App.get_by_id(int(app_id))
            if app is None:
                return render_json_response({ 'error': 'app-not-found' })
            if account.key() not in app.editors:
                return render_json_response({ 'error': 'access-denied' })
            app.delete()
            return render_json_response({ 'status': 'ok' })

class GetImageListHandler(RequestHandler):

    def get(self, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                images = []
            else:
                images = account.image_set.order('updated_at').fetch(1000)
                
            return render_json_response({
                'images': [ { 'id': img.key().id_or_name(), 'fileName': img.file_name, 'width': img.width, 'height': img.height } for img in images ]
            })

class ServeImageHandler(RequestHandler):

    def get(self, image_name):
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                raise NotFound()
                
            img = Image.get_by_key_name(image_name)
            if img is None or img.account.key() != account.key():
                raise NotFound()
                
            img_data = ImageData.get_by_key_name(image_name)
            if img_data is None:
                raise NotFound()
            
            return Response(response=img_data.data, mimetype='image/png')

class ServeProcessedImageHandler(RequestHandler):

    def get(self, image_name, effect):
        if effect in ('iphone-tabbar-active', 'iphone-tabbar-inactive'):
            if image_name.startswith('stock--'):
                path = os.path.join(os.path.dirname(__file__), '..', 'server-images', image_name.replace('--', '/'))
                kw = dict(file=open(path, 'rb'))
            else:
                user = users.get_current_user()
                if user is None:
                    return render_json_response({ 'error': 'signed-out' })
                account = Account.all().filter('user', user).get()
                if account is None:
                    raise NotFound()

                img = Image.get_by_key_name(image_name)
                if img is None or img.account.key() != account.key():
                    raise NotFound()
    
                img_data = ImageData.get_by_key_name(image_name)
                if img_data is None:
                    raise NotFound()
        
                kw = dict(byte=img_data.data)

            square_file = os.path.join(os.path.dirname(__file__), '..', 'server-images', effect + '.png')
            sw, sh, spix, smeta = png.Reader(file=open(square_file, 'rb')).asRGBA8()
            uw, uh, upix, umeta = png.Reader(**kw).asRGBA8()
    
            spix = list(spix)
            upix = list(upix)
    
            # raise StandardError, repr(spix)
    
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
            return Response(response=f.getvalue(), mimetype='image/png')

class DeleteImageHandler(RequestHandler):

    def delete(self, image_name):
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                raise NotFound()
                
            img = Image.get_by_key_name(image_name)
            if img is None or img.account.key() != account.key():
                raise NotFound()
                
            img_data = ImageData.get_by_key_name(image_name)
            if img_data is None:
                raise NotFound()
                
            img.delete()
            img_data.delete()
            
            return render_json_response({ 'status': 'ok' })

class SaveImageHandler(RequestHandler):
    
    def post(self, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({ 'error': 'signed-out' })
        else:
            account = Account.all().filter('user', user).get()
            if account is None:
                account = Account(user=user)
                account.put()

            file_name = request.headers['X-File-Name']
            data = request.data

            img = images.Image(data)

            image_key = "img-%s-%s" % (account.key().id_or_name(), file_name)
            image = Image(key_name=image_key, account=account, file_name=file_name, width=img.width, height=img.height)
            image.put()
            
            image_data = ImageData(key_name=image_key, data=data)
            image_data.put()
            
            return render_json_response({ 'id': image.key().id()    })

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
