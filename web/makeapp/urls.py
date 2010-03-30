from tipfy import Rule
from werkzeug.routing import Subdomain, Submount

def get_rules():
    return [
        Rule('/', endpoint='home', handler='makeapp.handlers:HomeHandler'),
        Rule('/designer/', endpoint='designer', handler='makeapp.handlers:DesignerHandler'),
    ]