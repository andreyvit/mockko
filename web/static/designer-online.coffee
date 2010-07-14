#
# Server Communication
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

handleHttpError: (failedActivity, status, e) ->
    if status and status isnt 'error'
        alert "${failedActivity} because there was an error communicating with the server: ${status} Please try again in a few minutes."
    else
        alert "${failedActivity} because there was an error communicating with the server. Please try again in a few minutes."

handleServerError: (failedActivity, err) ->
    switch err
        when 'signed-out'
            alert "${failedActivity} because you were logged out. Please sign in again."
        else
            alert "${failedActivity} because server reported an error: ${err}"

processPossibleErrorResponse: (failedActivity, response) ->
    if not response?
        alert "${failedActivity} because the server is not responding. Please try again in a few minutes."
        true
    else if response['error']
        handleServerError failedActivity, response['error']
        true
    else
        false


(window.Mockko ||= {}).server: {
    supportsImageEffects: yes

    adjustUI: (userData) ->
        $('.logout-button').attr 'href', userData['logout_url']

    getUserInfo: (callback) ->
        $.ajax {
            url: '/user/'
            dataType: 'json'
            success: (userData) ->
                userData['status']: 'online'
                callback userData
            error: (xhr, status, e) ->
                alert "Failed to load the application: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }

    setUserInfo: (userInfo) ->
        failedActivity: "Failed to save user profile"
        $.ajax {
            url: '/user/'
            type: 'POST'
            data: JSON.stringify(userInfo)
            contentType: 'application/json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }

    startDesigner: (userData, switchToDashboard, startDesignerWithSampleApp) ->
        switchToDashboard()

    saveApplicationChanges: (app, appId, callback) ->
        failedActivity: "Failed to save application changes"
        $.ajax {
            url: '/apps/' + (if appId then "${appId}/" else "")
            type: 'POST'
            data: JSON.stringify(app)
            contentType: 'application/json'
            dataType: 'json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
                callback(r['id'])
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }

    loadApplications: (callback) ->
        failedActivity: "Failed to get a list of applications"
        $.ajax {
            url: '/apps/'
            dataType: 'json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
                callback(r)
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }

    uploadImage: (groupName, fileName, file, callback) ->
        failedActivity: "Could not upload your image"
        $.ajax {
            type: 'POST'
            url: '/images/${encodeURIComponent groupName}'
            data: file
            processData: no
            beforeSend: (xhr) -> xhr.setRequestHeader("X-File-Name", fileName)
            contentType: 'application/octet-stream'
            dataType: 'json'
            success: (r) ->
                if processPossibleErrorResponse(failedActivity, r)
                    callback(true)
                else
                    callback(false)
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
                callback(true)
        }

    loadImages: (callback) ->
        failedActivity: "Could not load the list of your images"
        $.ajax {
            type: 'GET'
            url: '/images/'
            dataType: 'json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
                callback(r)
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }

    deleteImage: (groupName, imageId, callback) ->
        failedActivity: "Could not delete the image"
        $.ajax {
            type: 'DELETE'
            url: "/images/${encodeURIComponent groupName}/${encodeURIComponent imageId}"
            dataType: 'json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
                callback()
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }

    loadImageGroup: (imageGroupId, callback) ->
        console.log "Requesting /images/$imageGroupId"
        failedActivity: "Could not load image group info"
        $.ajax {
            type: 'GET'
            url: "/images/$imageGroupId"
            dataType: 'json'
            success: (r) ->
                console.log "Finished requesting /images/$imageGroupId"
                return if processPossibleErrorResponse(failedActivity, r)
                callback(r)
            error: (xhr, status, e) ->
                console.log "Unable to load image group ${imageGroupId}: ${status}"
                callback null
        }

    deleteApplication: (appId, callback) ->
        failedActivity: "Could not delete the application"
        $.ajax {
            type: 'DELETE'
            url: "/apps/${encodeURIComponent appId}/"
            dataType: 'json'
            success: (r) ->
                return if processPossibleErrorResponse(failedActivity, r)
                callback()
            error: (xhr, status, e) ->
                handleHttpError failedActivity, status, e
        }
}
