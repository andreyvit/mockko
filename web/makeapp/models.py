from google.appengine.ext import db

class Account(db.Model):
    user = db.UserProperty()

    invited_by = db.SelfReferenceProperty()

    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now=True)

    profile_created = db.BooleanProperty(required=True, default=False)
    newsletter = db.BooleanProperty()
    full_name = db.StringProperty()

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

class ImageData(db.Model):
    data = db.BlobProperty()

class Image(db.Model):
    account   = db.ReferenceProperty(Account)
    file_name = db.StringProperty()
    width     = db.IntegerProperty()
    height    = db.IntegerProperty()
    mime_type = db.StringProperty()

    created_at = db.DateTimeProperty(auto_now_add=True)
    updated_at = db.DateTimeProperty(auto_now=True)

    group = db.ReferenceProperty(ImageGroup)

    data = db.ReferenceProperty(ImageData)
    digest = db.StringProperty()
