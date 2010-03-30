
from tipfy import RequestHandler, url_for, redirect, redirect_to
from tipfy.ext.jinja2 import render_response

from google.appengine.api import users
from google.appengine.ext import db
from google.appengine.ext.deferred import defer

from makeapp.models import *

class HomeHandler(RequestHandler):
  
    def get(self, **kwargs):
        return redirect_to('designer')

class DesignerHandler(RequestHandler):
  
    def get(self, **kwargs):
        context = {}
        return render_response('designer.html', **context)
