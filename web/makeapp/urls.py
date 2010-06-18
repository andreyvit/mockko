from tipfy import Rule

def get_rules():
    return [
        Rule('/', endpoint='home', handler='makeapp.handlers:HomeHandler'),
        Rule('/user-info.json', endpoint='api/get-user-data', handler='makeapp.handlers:GetUserDataHandler'),
        Rule('/apps/', endpoint='api/get-app-list', methods=['GET'], handler='makeapp.handlers:GetAppListHandler'),
        Rule('/apps/', endpoint='api/save-new-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
        Rule('/apps/<int:app_id>/', endpoint='api/save-app', methods=['POST'], handler='makeapp.handlers:SaveAppHandler'),
        Rule('/apps/<int:app_id>/', endpoint='api/delete-app', methods=['DELETE'], handler='makeapp.handlers:DeleteAppHandler'),
        Rule('/R<int:app_id>/', endpoint='api/run-app', methods=['GET'], handler='makeapp.handlers:RunAppHandler'),
        Rule('/images/', endpoint='api/get-image-list', methods=['GET'], handler='makeapp.handlers:GetImageListHandler'),
        Rule('/images/', endpoint='api/save-image', methods=['POST'], handler='makeapp.handlers:SaveImageHandler'),
        Rule('/images/<image_name>', endpoint='api/serve-image', methods=['GET'], handler='makeapp.handlers:ServeImageHandler'),
        Rule('/images/<image_name>/<effect>', endpoint='api/serve-processed-image', methods=['GET'], handler='makeapp.handlers:ServeProcessedImageHandler'),
        Rule('/images/<image_name>', endpoint='api/delete-image', methods=['DELETE'], handler='makeapp.handlers:DeleteImageHandler'),
    ]
