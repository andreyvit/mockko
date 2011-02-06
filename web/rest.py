# REST API for App Engine Datastore
#
# Please note that you also need to add rest_apikey.py with something
# like this:
#
#     REST_API_KEY = '1234567890123456'
#
# Add the following to app.yaml:
#
#    - url: /rest/.*
#      script: rest.py
#
# Query URLs:
#
#   /rest/Foo/                       # return all Foos
#   /rest/Foo/?bar=7                 # return all Foos where bar == 7
#   /rest/Foo/?bar_lt=7              # return all Foos where bar < 7
#   /rest/Foo/?bar_ge=7              # return all Foos where bar >= 7
#
#   /rest/Foo/?_key_ge=999           # return all Foos where __key__ >= 999
#   /rest/Foo/?_key_ge=xxx           # return all Foos where __key__ >= xxx
#
#   /rest/Foo/?_include=xx,yy        # return properties xx and yy of all Foos
#   /rest/Foo/?_exclude=zz,ww        # return all properties of all Foos except for properies zz and ww
#
# Response is a JSON array.
#
# Single property retrieval URL (e.g. for blobs):
#
#   /rest/Foo/boz?_key=777           # return property boz of Foo with __key__ == 777
#
# Response is the raw value of this property (passed to str, no JSON encoding).
#
# Save URLs:
#
#   /rest/Foo/put?a=1&b=2            # create a new Foo with properties a and b
#   /rest/Foo/put?_key=xxx&a=1&b=2   # create or update Foo with key 'xxx' and properties a and b
#
# Response is a JSON object with all saved properties, including the assigned key.
#
# All requests must be GETs.
#

from google.appengine.ext.webapp import RequestHandler, WSGIApplication
from google.appengine.ext.webapp.util import run_wsgi_app

from django.utils import simplejson
from google.appengine.ext import db
from google.appengine.api import users

import datetime
import time
import logging

try:
    from rest_apikey import REST_API_KEY
except:
    raise StandardError, "Please add rest_apikey.py file which defines REST_API_KEY = '1234567890123456'"

if REST_API_KEY == '1234567890123456':
    raise StandardError, "Please use your own REST_API_KEY"

def check_apikey(handler):
    def handler_with_apikey_check(self, apikey, *args, **kw):
        if apikey == REST_API_KEY:
            return handler(self, *args, **kw)
        else:
            self.error(403)
            self.response.out.write("Invalid API key.")
    return handler_with_apikey_check

def model_for(kind):
    return type(kind, (db.Expando,), {})

def make_serializable(v):
    if isinstance(v, datetime.datetime):
        return time.mktime(v.timetuple())
    elif isinstance(v, users.User):
        return v.email()
    elif isinstance(v, db.Key):
        return v.id_or_name()
    elif isinstance(v, (list, tuple)):
        return [make_serializable(i) for i in v]
    else:
        return v

def expando_to_properties(expando, include=None, exclude=[]):
    result = {}
    result['_key'] = expando.key().id_or_name()
    for key in expando.dynamic_properties():
        if (include == None or key in include) and key not in exclude:
            result[key] = make_serializable(getattr(expando, key))
    return result

def serializable_to_value(v):
    try:
        return int(v)
    except:
        if v.startswith('dt:'):
            return parse_datetime(v[3:])
        else:
            return v

def parse_datetime(v):
    try:
        return datetime.datetime.fromtimestamp(int(v))
    except ValueError:
        for format in ['%Y-%m', '%Y-%m-%d', '%Y-%m-%d %H:%M', '%Y-%m-%d %H:%M:%S']:
            try:
                return datetime.datetime.strptime(v, format)
            except ValueError:
                pass
        raise ValueError, "Invalid date/time format: %s" % v

def params_to_query(kind, params, options={}):
    query = model_for(kind).all()

    for k, v in params.iteritems():
        v = serializable_to_value(v)

        if k in ('_limit', '_include', '_exclude'):
            options[k] = v
            continue

        k = k.replace('_ge', ' >=').replace('_le', ' <=').replace('_gt', ' >').replace('_lt', ' <')
        if k == '_key' or k.startswith('_key '):
            k = k.replace('_key', '__key__')
            v = db.Key.from_path(kind, v)

        logging.info("%s %s" % (str(k), str(v)))
        query.filter(k, v)
    
    return query

class QueryHandler(RequestHandler):
    @check_apikey
    def get(self, kind):
        options = { '_limit': 100, '_include': '', '_exclude': '' }

        items = params_to_query(kind, self.request.params, options).fetch(options['_limit'])
        i = (None if options['_include'] == '' else options['_include'].split(','))
        e = ([]   if options['_exclude'] == '' else options['_exclude'].split(','))
        
        self.response.out.write(simplejson.dumps([expando_to_properties(item, i, e) for item in items]))
        self.response.mimetype = 'application/json'

class CountHandler(RequestHandler):
    @check_apikey
    def get(self, kind):
        options = { '_limit': 100 }
        count = params_to_query(kind, self.request.params, options).count(options['_limit'])
        self.response.out.write(count)

class GetHandler(RequestHandler):
    @check_apikey
    def get(self, kind, attr):
        model = model_for(kind)
        item = params_to_query(kind, self.request.params).get()

        if item == None:
            value = None
        else:
            value = getattr(item, attr)

        self.response.out.write(str(make_serializable(value)))
        self.response.mimetype = 'application/json'

class SaveHandler(RequestHandler):
    @check_apikey
    def get(self, kind):
        model = model_for(kind)
        instance = model()
        at_least_one = False
        for k, v in self.request.params.iteritems():
            try:
                v = int(v)
            except:
                if v.startswith('dt:'):
                    v = parse_datetime(v[3:])

            setattr(instance, k, v)
            at_least_one = True
            
        if not at_least_one:
            self.response.out.write("Expected: at least one query param")
            return
        instance.put()

        self.response.out.write(simplejson.dumps(expando_to_properties(instance)))

app = WSGIApplication([
    ('/rest/([\w\d-]+)/([\w\d_]+)/',             QueryHandler),
    ('/rest/([\w\d-]+)/([\w\d_]+)/count',        CountHandler),
    ('/rest/([\w\d-]+)/([\w\d_]+)/put',          SaveHandler),
    ('/rest/([\w\d-]+)/([\w\d_]+)/([\w\d_]+)',   GetHandler),
])

def main():
    run_wsgi_app(app)

if __name__ == '__main__':
    main()
