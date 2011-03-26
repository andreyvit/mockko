from tipfy import Rule

def get_rules():
    return [
        Rule('/', endpoint='home', methods=['GET'], handler='makeapp.handlers:HomeHandler'),
        Rule('/user/', endpoint='api/get-user-data', methods=['GET'], handler='makeapp.handlers:GetUserDataHandler'),
        Rule('/user/', endpoint='api/set-user-data', methods=['POST'], handler='makeapp.handlers:SetUserDataHandler'),

        Rule('/apps/', endpoint='api/get-app-list', methods=['GET'], handler='makeapp.handlers:GetAppListHandler'),
        Rule('/R<int:app_id>/', endpoint='api/run-app', methods=['GET'], handler='makeapp.handlers:RunAppHandler'),

        Rule('/apps/', endpoint='api/save-new-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
        Rule('/apps/<int:app_id>/', endpoint='api/save-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
        Rule('/apps/<int:app_id>/', endpoint='api/delete-app', methods=['DELETE'], handler='makeapp.handlers:DeleteAppHandler'),

        Rule('/images/', endpoint='api/get-image-list', methods=['GET'], handler='makeapp.handlers:GetImageListHandler'),
        Rule('/images/<group_id>', endpoint='api/image-group', methods=['GET'], handler='makeapp.handlers:GetImageGroupHandler'),
        Rule('/images/<group_id>', endpoint='api/save-image', methods=['POST'], handler='makeapp.handlers:SaveImageHandler'),
        Rule('/images/<group_id>/<image_name>', endpoint='api/serve-image', methods=['GET'], handler='makeapp.handlers:ServeImageHandler'),
        Rule('/images/<group_id>/<image_name>', endpoint='api/delete-image', methods=['DELETE'], handler='makeapp.handlers:DeleteImageHandler'),

        Rule('/status/', endpoint='admin/status', methods=['GET'], handler='makeapp.handlers:StatusHandler'),
        Rule('/users-csv-export/', endpoint='admin/users-export', methods=['GET'], handler='makeapp.handlers:UserExportHandler'),

        Rule('/stats/apps.xml', endpoint='stats/apps', methods=['GET', 'POST'], handler='makeapp.handlers:UserStatsHandler'),
    ]
