#
# Server Stub
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

(window.Mockko ||= {}).fakeServer = {
    supportsImageEffects: no

    adjustUI: (userData) ->
        #

    getUserInfo: (callback) ->
        callback { 'status': 'offline' }

    startDesigner: (userData, switchToDashboard, startDesignerWithSampleApp) ->
        startDesignerWithSampleApp JSON.parse(Mockko.sampleApplications[0]['body'])

    saveApplicationChanges: (app, appId, callback) ->
        #

    loadApplications: (callback) ->
        callback [
            # { 'id': 42, 'body': JSON.stringify(MakeApp.appTemplates.basic) }
            # { 'id': 43, 'body': JSON.stringify(MakeApp.appTemplates.basic) }
        ]

    uploadImage: (groupName, fileName, file, callback) ->
        #

    loadImages: (callback) ->
        #

    deleteImage: (groupName, imageId, callback) ->
        #

    loadImageGroup: (imageGroupId, callback) ->
        #
}
