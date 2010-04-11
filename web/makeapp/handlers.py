
from tipfy import RequestHandler, url_for, redirect, redirect_to, render_json_response
from tipfy.ext.jinja2 import render_response
# from tipfy.ext.user import user_required, get_current_user

from django.utils import simplejson as json

from google.appengine.api import users
from google.appengine.ext import db
from google.appengine.ext.deferred import defer

from makeapp.models import Account, App

class HomeHandler(RequestHandler):
  
    def get(self, **kwargs):
        return redirect_to('designer')

class DesignerHandler(RequestHandler):

    def get(self, **kwargs):
        context = {}
        return render_response('designer.html', **context)
        
class GetUserDataHandler(RequestHandler):
    
    def get(self, **kwargs):
        user = users.get_current_user()
        if user is None:
            return render_json_response({
                'status': 'anonymous',
                'login_url': users.create_login_url(url_for('designer')),
            })
        else:
            return render_json_response({
                'status': 'authenticated',
                'logout_url': users.create_logout_url(url_for('home')),
            })

class CreateAppHandler(RequestHandler):
    
    def post(self, **kwargs):
        return render_json_response({ 'status': 'ok' })
