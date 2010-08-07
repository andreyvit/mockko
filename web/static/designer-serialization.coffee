#
# JSON Serialization & Deserialization
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

DEFAULT_TEXT_STYLES: {
    fontSize: 17
    textColor: '#fff'
    fontBold: no
    fontItalic: no
}

externalizeAction: (action) ->
    return null unless action?
    switch action.action
        when Mockko.actions.switchScreen
            {
                'action': Mockko.actions.switchScreen.extname
                'screenName': action.screenName
            }
        else throw "unknown action: ${action.action}"

internalizeAction: (action) ->
    return null unless action?
    switch action['action']
        when Mockko.actions.switchScreen.extname
            {
                action: Mockko.actions.switchScreen
                screenName: action['screenName']
            }
        else throw "error loading app: invalid action ${action['action']}"

internalizeLocation: (location, parent) ->
    location ||= {}
    {
        x: (location['x'] || 0) + (parent?.abspos?.x || 0)
        y: (location['y'] || 0) + (parent?.abspos?.y || 0)
    }

externalizeLocation: (abspos, parent) ->
    {
        'x': abspos.x - (parent?.abspos?.x || 0)
        'y': abspos.y - (parent?.abspos?.y || 0)
    }

externalizeSize: (size) ->
    {
        'w': size.w
        'h': size.h
    }

internalizeSize: (size) ->
    {
        w: if size then size['w'] || size['width']  else null
        h: if size then size['h'] || size['height'] else null
    }

internalizeStyle: (style) ->
    {
        fontSize: style['fontSize']
        textColor: style['textColor']
        fontBold: style['fontBold']
        fontItalic: style['fontItalic']
        textShadowStyleName: style['textShadowStyleName']
        background: style['background']
        imageEffect: style['imageEffect']
        borderRadius: style['borderRadius']
    }

externalizeStyle: (style) ->
    {
        'fontSize': style.fontSize
        'textColor': style.textColor
        'fontBold': style.fontBold
        'fontItalic': style.fontItalic
        'textShadowStyleName': style.textShadowStyleName
        'background': style.background
        'imageEffect': style.imageEffect
        'borderRadius': style.borderRadius
    }

externalizeImage: (image) ->
    {
        'group': image.group
        'name': image.name
    }

internalizeImage: (image) ->
    {
        group: image['group']
        name: image['name']
    }

externalizeComponent: (c) ->
    rc: {
        'type': c.type.name || c.type
        'location': externalizeLocation c.abspos, c.parent
        # 'effsize': externalizeSize c.effsize
        'size': externalizeSize c.size
        'styleName': c.styleName
        'style': externalizeStyle c.style
        'text': c.text
        'action': externalizeAction c.action
        'children': (externalizeComponent(child) for child in c.children || [])
    }
    rc['state']: c.state if c.state?
    rc['image']: externalizeImage(c.image) if c.image?
    rc

externalizePaletteComponent: (c) ->
    rc: {
        'type': c.type
        'location': externalizeLocation(c.location || { x: 0, y: 0 }, null)
        'size': externalizeSize(c.size || { w: null, h: null })
        'styleName': c.styleName
        'style': externalizeStyle(c.style || {})
        'text': c.text
        'action': externalizeAction c.action
        'children': (externalizePaletteComponent(child) for child in c.children || [])
    }
    rc['state']: c.state if c.state?
    rc['image']: externalizeImage(c.image) if c.image?
    rc

internalizeComponent: (c, parent) ->
    rc: {
        type: Mockko.componentTypes[c['type']]
        abspos: internalizeLocation c['location'], parent
        size: internalizeSize c['size']
        styleName: c['styleName']
        action: internalizeAction c['action']
        inDocument: yes
        parent: parent
    }
    rc.children: (internalizeComponent(child, rc) for child in c['children'] || [])
    if not rc.type
        console.log "Missing type for component:"
        console.log c
        throw "Missing type: ${c['type']}"
    rc.state: c['state']
    rc.image: internalizeImage(c['image']) if c['image']?
    if rc.image?.constructor is String
        if rc.image.substr(0, 'images/'.length) == 'images/'
            encodedId: rc.image.substr('images/'.length)
            rc.image: { id: decodeURIComponent encodedId }
        else
            throw "Invalid image reference: ${rc.image}"
    rc.style: $.extend({}, (if rc.type.textStyleEditable then DEFAULT_TEXT_STYLES else {}), rc.type.style || {}, internalizeStyle(c['style'] || {}))
    rc.text: c['text'] || rc.type.defaultText if rc.type.supportsText
    rc

externalizeScreen: (screen) ->
    {
        'rootComponent': externalizeComponent(screen.rootComponent)
        'name': screen.name
        'html': screen.html || ''
    }

internalizeScreen: (screen) ->
    rootComponent: internalizeComponent(screen['rootComponent'], null)
    screen: {
        rootComponent: rootComponent
        html: screen['html'] || ''
        name: screen['name'] || null
        allowedArea: {
            x: 0
            y: 0
            w: 320
            h: 480
        }
    }
    return screen

externalizeApplication: (app) ->
    {
        'name': app.name
        'screens': (externalizeScreen(s) for s in app.screens)
    }

internalizeApplication: (app) ->
    screens: (internalizeScreen(s) for s in app['screens'])
    _(screens).each (screen, index) ->
        screen.name ||= "Screen ${index+1}"
    {
        name: app['name']
        screens: screens
    }

(window.Mockko ||= {}).serialization: {
    externalizeAction, internalizeAction
    internalizeLocation, externalizeLocation
    externalizeSize, internalizeSize
    internalizeStyle, externalizeStyle
    externalizeImage, internalizeImage
    externalizeComponent, externalizePaletteComponent, internalizeComponent
    externalizeScreen, internalizeScreen
    externalizeApplication, internalizeApplication
}
