from google.appengine.ext import db

class Account(db.Model):
    user = db.UserProperty()

    invited_by = db.SelfReferenceProperty()

    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now=True)

class App(db.Model):
    name = db.StringProperty(required=True)
    body = db.TextProperty()

    created_by = db.ReferenceProperty(Account)
    editors    = db.ListProperty(db.Key)

    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now=True)

class ImageGroup(db.Model):
    name = db.StringProperty()
    owner = db.ReferenceProperty(Account)
    priority = db.IntegerProperty()

    effect = db.StringProperty()

class Image(db.Model):
    account   = db.ReferenceProperty(Account)
    file_name = db.StringProperty()
    width     = db.IntegerProperty()
    height    = db.IntegerProperty()

    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now=True)

    group = db.ReferenceProperty(ImageGroup)

class ImageData(db.Model):
    data = db.BlobProperty()
