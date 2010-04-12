from tipfy import Rule
from werkzeug.routing import Subdomain, Submount

def get_rules():
    return [
        Rule('/', endpoint='home', handler='makeapp.handlers:HomeHandler'),
        Rule('/designer/', endpoint='designer', handler='makeapp.handlers:DesignerHandler'),
        Rule('/user-info.json', endpoint='api/get-user-data', handler='makeapp.handlers:GetUserDataHandler'),
        Rule('/apps/', endpoint='api/get-app-list', methods=['GET'], handler='makeapp.handlers:GetAppListHandler'),
        Rule('/apps/', endpoint='api/save-new-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
        Rule('/apps/<int:app_id>/', endpoint='api/save-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
    ]
