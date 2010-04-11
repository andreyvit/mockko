
from random import choice

from google.appengine.ext import db
# from tipfy.ext.user.model import User as TipfyUser


class Account(db.Model):
    user = db.UserProperty()
    invited_by = db.SelfReferenceProperty()
    
    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now_add=True)
    
class App(db.Model):
    name = db.StringProperty(required=True)
    created_by = db.ReferenceProperty(Account)
    editors = db.ListProperty(db.Key)

ADJs = ['Best-Selling', 'Great', 'Glorious', 'Stunning', 'Gorgeous']

def create_app_name():
    return 'My %s App' % choice(ADJs)
