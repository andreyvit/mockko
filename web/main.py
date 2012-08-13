# -*- coding: utf-8 -*-

import webapp2

import handlers

from webapp2 import Route

routes = [
    Route('/',                               name='home',               methods=['GET'],         handler='handlers.HomeHandler'), # for resolving routes to home
    Route('/user/',                          name='api/user-data',      methods=['GET','POST'],  handler='handlers.UserDataHandler'),

    Route('/apps/',                          name='api/get-app-list',   methods=['GET'],         handler='handlers.GetAppListHandler'),
#    Route('/R<int:app_id>/',                 name='api/run-app',        methods=['GET'],         handler='handlers.RunAppHandler'),
    Route('/R<app_id:\d+>',                  name='api/run-app',        methods=['GET'],         handler='handlers.RunAppHandler'),

    Route('/apps/',                          name='api/save-new-app',   methods=['POST'],        handler='handlers.SaveAppHandler'),
    Route('/apps/<app_id:\d+>/',             name='api/save-app',       methods=['POST'],        handler='handlers.SaveAppHandler'),
    Route('/apps/<app_id:\d+>/',             name='api/delete-app',     methods=['DELETE'],      handler='handlers.DeleteAppHandler'),

    Route('/images/',                        name='api/get-image-list', methods=['GET'],         handler='handlers.GetImageListHandler'),
    Route('/images/<group_id>',              name='api/image-group',    methods=['GET'],         handler='handlers.GetImageGroupHandler'),
    Route('/images/<group_id>',              name='api/save-image',     methods=['POST'],        handler='handlers.SaveImageHandler'),
    Route('/images/<group_id>/<image_name>', name='api/serve-image',    methods=['GET'],         handler='handlers.ServeImageHandler'),
    Route('/images/<group_id>/<image_name>', name='api/delete-image',   methods=['DELETE'],      handler='handlers.DeleteImageHandler'),

    Route('/status/',                        name='admin/status',       methods=['GET'],         handler='handlers.StatusHandler'),
    Route('/users-csv-export/',              name='admin/users-export', methods=['GET'],         handler='handlers.UserExportHandler'),

    Route('/stats/apps.xml',                 name='stats/apps',         methods=['GET', 'POST'], handler='handlers.UserStatsHandler'),
    ]

app = webapp2.WSGIApplication(routes, debug=False)
