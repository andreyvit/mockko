# -*- coding: utf-8 -*-

import webapp2

import makeapp.handlers

from webapp2 import Route

routes = [
    Route('/',                               name='home',               methods=['GET'],         handler='makeapp.handlers.HomeHandler'), # for resolving routes to home
    Route('/user/',                          name='api/get-user-data',  methods=['GET'],         handler='makeapp.handlers.GetUserDataHandler'),
    Route('/user/',                          name='api/set-user-data',  methods=['POST'],        handler='makeapp.handlers.SetUserDataHandler'),

    Route('/apps/',                          name='api/get-app-list',   methods=['GET'],         handler='makeapp.handlers.GetAppListHandler'),
#    Route('/R<int:app_id>/',                 name='api/run-app',        methods=['GET'],         handler='makeapp.handlers.RunAppHandler'),
    Route('/R<app_id:\d+>',                  name='api/run-app',        methods=['GET'],         handler='makeapp.handlers.RunAppHandler'),

    Route('/apps/',                          name='api/save-new-app',   methods=['POST'],        handler='makeapp.handlers.SaveAppHandler'),
    Route('/apps/<app_id:\d+>/',             name='api/save-app',       methods=['POST'],        handler='makeapp.handlers.SaveAppHandler'),
    Route('/apps/<app_id:\d+>/',             name='api/delete-app',     methods=['DELETE'],      handler='makeapp.handlers.DeleteAppHandler'),

    Route('/images/',                        name='api/get-image-list', methods=['GET'],         handler='makeapp.handlers.GetImageListHandler'),
    Route('/images/<group_id>',              name='api/image-group',    methods=['GET'],         handler='makeapp.handlers.GetImageGroupHandler'),
    Route('/images/<group_id>',              name='api/save-image',     methods=['POST'],        handler='makeapp.handlers.SaveImageHandler'),
    Route('/images/<group_id>/<image_name>', name='api/serve-image',    methods=['GET'],         handler='makeapp.handlers.ServeImageHandler'),
    Route('/images/<group_id>/<image_name>', name='api/delete-image',   methods=['DELETE'],      handler='makeapp.handlers.DeleteImageHandler'),

    Route('/status/',                        name='admin/status',       methods=['GET'],         handler='makeapp.handlers.StatusHandler'),
    Route('/users-csv-export/',              name='admin/users-export', methods=['GET'],         handler='makeapp.handlers.UserExportHandler'),

    Route('/stats/apps.xml',                 name='stats/apps',         methods=['GET', 'POST'], handler='makeapp.handlers.UserStatsHandler'),
    ]

app = webapp2.WSGIApplication(routes, debug=False)
