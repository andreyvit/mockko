
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
                apps = App.all().filter('editors', account.key())

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
