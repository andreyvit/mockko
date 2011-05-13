#
# Components Hyperlinks (& other actions in the future)
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

(window.Mockko ||= {}).actions =
    switchScreen:
        extname: 'switch-screen'
        describe: (act) ->
            "#{act.screenName}"
        create: (screen) ->
            action: this
            screenName: screen.name
        encodeActionAsURL: (act) ->
            "screen:#{encodeNameForId(act.screenName)}"
