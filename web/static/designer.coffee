jQuery ($) ->

    CONF_SNAPPING_DISTANCE = 5
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100
    STACKED_COMP_TRANSITION_DURATION = 200

    MAX_IMAGE_UPLOAD_SIZE: 1024*1024
    MAX_IMAGE_UPLOAD_SIZE_DESCR: '1 Mb'

    DUPLICATE_COMPONENT_OFFSET_X: 5
    DUPLICATE_COMPONENT_OFFSET_Y: 5
    DUPLICATE_COMPONENT_MIN_EDGE_INSET_X: 5
    DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y: 5

    ##########################################################################################################
    ## constants

    applicationList: null
    serverMode: null
    applicationId: null
    application: null
    activeScreen: null
    mode: null
    allowedArea: null
    componentBeingDoubleClickEdited: null
    allStacks: null

    # our very own idea of infinity
    INF: 100000

    Types: MakeApp.componentTypes

    DEFAULT_TEXT_STYLES: {
        fontSize: 17
        textColor: '#fff'
        fontBold: no
        fontItalic: no
    }

    DEFAULT_ROOT_COMPONENT: {
        type: "background"
        size: { w: 320, h: 480 }
        abspos: { x: 0, y: 0 }
        id: "root"
    }

    SAMPLE_APPS: ( { 'body': body, 'sample': yes } for body in MakeApp.sampleApplications )


    ##########################################################################################################
    ##  Server Communication

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

    SERVER_MODES = {
        'anonymous': {
            supportsImageEffects: yes

            adjustUI: (userData) ->
                $('.login-button').attr 'href', userData['login_url']

            startDesigner: (userData) ->
                createNewApplication()
                $('#welcome-screen').show()

            saveApplicationChanges: (app, appId, callback) ->
                #

            uploadImageFile: (groupName, fileName, file, callback) ->
                #

            loadCustomImages: (callback) ->
                #

            deleteCustomImage: (groupName, imageId, callback) ->
                #

            getImageGroupInfo: (imageGroupId, callback) ->
                #
        }

        'authenticated': {
            supportsImageEffects: yes

            adjustUI: (userData) ->
                $('.logout-button').attr 'href', userData['logout_url']

            startDesigner: (userData) ->
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

            uploadImageFile: (groupName, fileName, file, callback) ->
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
                        return if processPossibleErrorResponse(failedActivity, r)
                        callback()
                    error: (xhr, status, e) ->
                        handleHttpError failedActivity, status, e
                }

            loadCustomImages: (callback) ->
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

            deleteCustomImage: (groupName, imageId, callback) ->
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

            getImageGroupInfo: (imageGroupId, callback) ->
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
                        handleHttpError failedActivity, status, e
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

        'local': {
            supportsImageEffects: no

            adjustUI: (userData) ->
                #

            startDesigner: (userData) ->
                loadApplication internalizeApplication(JSON.parse(SAMPLE_APPS[0]['body'])), null
                switchToDesign()

            saveApplicationChanges: (app, appId, callback) ->
                #

            loadApplications: (callback) ->
                callback [
                    # { 'id': 42, 'body': JSON.stringify(MakeApp.appTemplates.basic) }
                    # { 'id': 43, 'body': JSON.stringify(MakeApp.appTemplates.basic) }
                ]

            uploadImageFile: (groupName, fileName, file, callback) ->
                #

            loadCustomImages: (callback) ->
                #

            deleteCustomImage: (groupName, imageId, callback) ->
                #

            getImageGroupInfo: (imageGroupId, callback) ->
                #
        }
    }


    ##########################################################################################################
    ##  various stuff

    BACKGROUND_STYLES: {}
    (->
        for bg in MakeApp.backgroundStyles
            BACKGROUND_STYLES[bg.name]: bg
    )()

    encodeNameForId: (name) ->
        encodeURIComponent(name).replace('%', '_')

    ACTIONS: {
        switchScreen: {
            extname: 'switch-screen'
            describe: (act) ->
                "${act.screenName}"
            create: (screen) ->
                {
                    action: this
                    screenName: screen.name
                }
            encodeActionAsURL: (act) ->
                "screen:${encodeNameForId(act.screenName)}"
        }
    }


    ##########################################################################################################
    ##  DOM templates

    domTemplates = {}
    $('.template').each ->
        domTemplates[this.id] = this
        $(this).removeClass('template').remove()
    domTemplate: (id) ->
        domTemplates[id].cloneNode(true)

    ##########################################################################################################
    ##  utilities

    aOrAn: (s) ->
        if s[0] in {'a': yes, 'e': yes, 'i': yes, 'o': yes, 'u': yes} then "an ${s}" else "a ${s}"

    ##########################################################################################################
    ##  external representation

    externalizeAction: (action) ->
        return null unless action?
        switch action.action
            when ACTIONS.switchScreen
                {
                    'action': ACTIONS.switchScreen.extname
                    'screenName': action.screenName
                }
            else throw "unknown action: ${action.action}"

    internalizeAction: (action) ->
        return null unless action?
        switch action['action']
            when ACTIONS.switchScreen.extname
                {
                    action: ACTIONS.switchScreen
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
            type: Types[c['type']]
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
        rootComponent: internalizeComponent(screen['rootComponent'] || DEFAULT_ROOT_COMPONENT, null)
        screen: {
            rootComponent: rootComponent
            html: screen['html'] || ''
            name: screen['name'] || null
            nextId: 1
        }
        traverse rootComponent, (c) -> assignNameIfStillUnnamed c, screen
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


    ##########################################################################################################
    ##  undo

    undoStack: []
    lastChange: null

    friendlyComponentName: (c) ->
        if c.type is Types.text
            "“${c.text}”"
        else
            label: (c.type.genericLabel || c.type.label).toLowerCase()
            if c.text then "the “${c.text}” ${label}" else aOrAn label

    beginUndoTransaction: (changeName) ->
        if lastChange isnt null
            console.log "Make-App Internal Warning: implicitly closing an unclosed undo change: ${lastChange.name}"
        lastChange: { memento: createApplicationMemento(), name: changeName }

    runTransaction: (changeName, change) ->
        beginUndoTransaction changeName
        change()
        componentsChanged()

    setCurrentChangeName: (changeName) -> lastChange.name: changeName

    endUndoTransaction: ->
        return if lastChange is null
        snapshotForSimulation activeScreen
        if lastChange.memento != createApplicationMemento()
            console.log "Change: ${lastChange.name}"
            undoStack.push lastChange
            undoStackChanged()
            saveApplicationChanges()
        lastChange = null

    undoStackChanged: ->
        if undoStack.length != 0
            $('#undo-hint span').html "Undo ${undoStack[undoStack.length-1].name}"
        $('#undo-button').alterClass('disabled', undoStack.length == 0)

    undoLastChange: ->
        return if undoStack.length == 0
        screenIndex: _(application.screens).indexOf activeScreen
        change: undoStack.pop()
        console.log "Undoing: ${change.name}"
        revertToMemento change.memento
        undoStackChanged()
        saveApplicationChanges()
        if screenIndex >= 0 && screenIndex < application.screens.length
            switchToScreen application.screens[screenIndex]

    createApplicationMemento: -> JSON.stringify(externalizeApplication(application))

    revertToMemento: (memento) -> loadApplication internalizeApplication(JSON.parse(memento)), applicationId

    $('#undo-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        undoLastChange()

    undoStackChanged()

    ##########################################################################################################
    ##  global events

    componentsChanged: ->
        endUndoTransaction()

        if $('#share-popover').is(':visible')
            updateSharePopover()

        reassignZIndexes()

        allStacks: discoverStacks()

        updateInspector()
        updateScreenPreview(activeScreen)

    ##########################################################################################################
    ##  geometry

    isRectInsideRect: (i, o) -> i.x >= o.x and i.x+i.w <= o.x+o.w and i.y >= o.y and i.y+i.h <= o.y+o.h

    doesRectIntersectRect: (a, b) ->
        (b.x <= a.x+a.w) and (b.x+b.w >= a.x) and (b.y <= a.y+a.h) and (b.y+b.h >= a.y)

    rectIntersection: (a, b) ->
        x: Math.max(a.x, b.x)
        y: Math.max(a.y, b.y)
        x2: Math.min(a.x+a.w, b.x+b.w)
        y2: Math.min(a.y+a.h, b.y+b.h)
        if x2 < x then t = x2; x2 = x; x = t
        if y2 < y then t = y2; y2 = y; y = t
        { x: x, y: y, w: x2-x, h: y2-y }

    areaOfIntersection: (a, b) ->
        if doesRectIntersectRect(a, b)
            r: rectIntersection(a, b)
            r.w * r.h
        else
            0

    proximityOfRectToRect: (a, b) ->
        if doesRectIntersectRect(a, b)
            r: rectIntersection(a, b)
            -(r.w * r.h)
        else
            a2: { x: a.x+a.w, y: a.y+a.h }
            b2: { x: b.x+b.w, y: b.y+b.h }
            dx: Math.min(Math.abs(a.x - b.x), Math.abs(a2.x - b.x), Math.abs(a.x - b2.x), Math.abs(a2.x - b2.x))
            dy: Math.min(Math.abs(a.y - b.y), Math.abs(a2.y - b.y), Math.abs(a.y - b2.y), Math.abs(a2.y - b2.y))
            dy*dy

    ptDiff: (a, b) -> { x: a.x - b.x, y: a.y - b.y }
    ptSum:  (a, b) -> { x: a.x + b.x, y: a.y + b.y }
    ptMul:  (p, r) -> { x: p.x * r,   y: p.y * r   }
    distancePtToPtMod: (a, b) -> Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y))
    distancePtToPtSqr: (a, b) -> Math.sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))

    ZeroPt:        { x: 0, y: 0 }
    ptToString:    (pt) -> "(${pt.x},${pt.y})"
    distancePtPt1: (a, b) -> Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y))
    distancePtPt2: (a, b) -> Math.sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))
    addPtPt:       (a, b) -> { x: a.x + b.x, y: a.y + b.y }
    subPtPt:       (a, b) -> { x: a.x - b.x, y: a.y - b.y }
    mulPtSize:     (p, s) -> { x: p.x * s.w, y: p.y * s.h }
    ptFromLT:      (lt) -> { x: lt.left, y: lt.top }
    unitVecOfPtPt: (a, b) ->
        len: distancePtPt2(a, b)
        if len is 0 then ZeroPt else { x: (b.x-a.x)/len, y: (b.y-a.y)/len }
    mulVecLen:     (v, len) -> { x: v.x * len, y: v.y * len }
    ptInRect:      (pt, r) -> (r.x <= pt.x < r.x+r.w and r.y <= pt.y <= r.y+r.h)

    ZeroSize:     { w: 0, h: 0 }
    sizeToString: (size) -> "${size.w}x${size.h}"
    domSize:      (node) -> { w: node.offsetWidth, h: node.offsetHeight }
    centerOfSize: (s) -> { x: s.w / 2, y: s.h / 2 }

    rectToString:      (r) -> "(${r.x},${r.y} ${r.w}x${r.h})"
    rectFromPtAndSize: (p, s) -> { x:p.x, y:p.y, w:s.w, h:s.h }
    dupRect:           (r)    -> { x:r.x, y:r.y, w:r.w, h:r.h }
    addRectPt:         (r, p) -> { x:r.x+p.x, y:r.y+p.y, w:r.w, h:r.h }
    subRectPt:         (r, p) -> { x:r.x-p.x, y:r.y-p.y, w:r.w, h:r.h }
    topLeftOf:         (r) -> { x: r.x, y: r.y }
    bottomRightOf:     (r) -> { x: r.x+r.w, y: r.y+r.h }
    rectOfNode:        (node) -> rectFromPtAndSize ptFromLT($(node).offset()), { w: $(node).width(), h: $(node).height() }
    canonRect:         (r) -> {
        x: r.x, y: r.y,
        w: (if r.w? then r.w else r.x2-r.x+1),
        h: (if r.h? then r.h else r.y2-r.y+1)
    }
    insetRect: (r, i) -> { x: r.x+i.l, y: r.y+i.t, w: r.w-i.l-i.r, h: r.h-i.t-i.b }

    centerOfRect: (r) -> { x: r.x + r.w / 2, y: r.y + r.h / 2 }
    centerSizeInRect:  (s, r) -> rectFromPtAndSize { x: r.x + (r.w-s.w) / 2, y: r.y + (r.h-s.h)/2 }, s


    ##########################################################################################################
    ##  Component Utilities

    sizeOf: (c) -> { w: c.effsize.w, h: c.effsize.h }
    rectOf: (c) -> { x: c.abspos.x, y: c.abspos.y, w: c.effsize.w, h: c.effsize.h }

    findChildByType: (parent, type) ->
        _(parent.children).detect (child) -> child.type is type

    commitMoves: (moves, exclusions, delay) ->
        if moves.length > 0
            liveMover: newLiveMover exclusions
            liveMover.moveComponents moves
            liveMover.commit(delay)

    ##########################################################################################################
    ##  component management

    assignNameIfStillUnnamed: (c, screen) -> c.id ||= "c${screen.nextId++}"

    storeAndBindComponentNode: (c, cn) ->
        c.node = cn
        $(cn).dblclick ->
            return if componentBeingDoubleClickEdited is c
            handleComponentDoubleClick c; false

    skipTraversingChildren: {}
    # traverse(comp-or-array-of-comps, [parent], func)
    traverse: (comp, parent, func) ->
        return if not comp?
        if not func
            func = parent; parent = null
        if _.isArray comp
            for child in comp
                traverse child, parent, func
        else
            r: func(comp, parent)
            if r isnt skipTraversingChildren
                for child in comp.children || []
                    traverse child, comp, func
        null

    cloneTemplateComponent: (compTemplate) ->
        c: internalizeComponent compTemplate, null
        traverse c, (comp) -> comp.inDocument: no
        return c

    deleteComponentWithoutTransaction: (rootc, animated) ->
        return if rootc.type.unmovable

        effect: computeDeletionEffect rootc
        stacking: handleStacking rootc, null, allStacks

        liveMover: newLiveMover [rootc]
        liveMover.moveComponents stacking.moves.concat(effect.moves)
        liveMover.commit(animated && STACKED_COMP_TRANSITION_DURATION)

        _(rootc.parent.children).removeValue rootc
        if animated
            $(rootc.node).hide 'drop', { direction: 'down' }, 'normal', -> $(rootc.node).remove()
        else
            $(rootc.node).remove()
        deselectComponent() if isComponentOrDescendant selectedComponent, rootc
        componentUnhovered() if isComponentOrDescendant hoveredComponent, rootc

    deleteComponent: (rootc) ->
        beginUndoTransaction "deletion of ${friendlyComponentName rootc}"
        deleteComponentWithoutTransaction rootc, true
        componentsChanged()

    moveComponentBy: (comp, offset) ->
        beginUndoTransaction "keyboard moving of ${friendlyComponentName comp}"
        traverse comp, (c) -> c.abspos: ptSum(c.abspos, offset)
        traverse comp, componentPositionChangedPernamently
        componentsChanged()

    duplicateComponent: (comp) ->
        return if comp.type.unmovable || comp.type.singleInstance
        beginUndoTransaction "duplicate ${friendlyComponentName comp}"

        newComp: internalizeComponent(externalizeComponent(comp), comp.parent)
        # make sure all ids are reassigned
        traverse newComp, (c) -> c.id: null

        effect: computeDuplicationEffect newComp, comp
        if effect is null
            alert "Cannot duplicate the component because another copy does not fit into the designer"
            return

        newRect: effect.rect
        if newRect.w != comp.effsize.w or newRect.h != comp.effsize.h
            newComp.size: { w: newRect.w, h: newRect.h }

        commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION
        moveComponent newComp, newRect

        comp.parent.children.push newComp
        $(comp.parent.node).append renderInteractiveComponentHeirarchy newComp
        traverse newComp, (c) -> updateEffectiveSize c

        componentsChanged()

    # findParent: (c) -> c.parent
    #     # a parent is a covering component of minimal area
    #     r: rectOf c
    #     _(pc for pc in components when pc != c && isRectInsideRect(r, rectOf(pc))).min (pc) -> r: rectOf(pc); r.w*r.h

    findBestTargetContainerForRect: (r, excluded) ->
        trav: (comp) ->
            return null if _.include excluded, comp

            bestHere: null
            for child in comp.children
                if res: trav(child)
                    if bestHere == null or res.area > bestHere.area
                        bestHere = res

            if bestHere is null
                rc: rectOf comp
                if isRectInsideRect r, rc
                    if (area: areaOfIntersection r, rc) > 0
                        bestHere: { comp: comp, area: area }
            else
                bestHere

        trav(activeScreen.rootComponent)?.comp || activeScreen.rootComponent

    ##########################################################################################################
    ##  DOM rendering

    createNodeForComponent: (c) ->
        ct: c.type
        movability: if ct.unmovable then "unmovable" else "movable"
        tagName: c.type.tagName || "div"
        $(ct.html || "<${tagName} />").addClass("component c-${c.type.name} c-${c.type.name}-${c.styleName || 'nostyle'}").addClass(if ct.container then 'container' else 'leaf').setdata('moa-comp', c).addClass(movability)[0]

    _renderComponentHierarchy: (c, storeFunc) ->
        n: storeFunc c, createNodeForComponent(c)

        for child in c.children || []
            childNode: _renderComponentHierarchy(child, storeFunc)
            $(n).append(childNode)

        return n

    renderStaticComponentHierarchy: (c) ->
        _renderComponentHierarchy c, (ch, n) ->
            renderComponentVisualProperties ch, n
            renderComponentPosition ch, n if ch != c
            n

    renderInteractiveComponentHeirarchy: (c) ->
        _renderComponentHierarchy c, (ch, n) ->
            storeAndBindComponentNode ch, n
            renderComponentProperties ch
            n

    findComponentAt: (pt) ->
        if hoveredComponent
            rect: insetRect rectOf(hoveredComponent), { l: -7, r: -7, t: -20, b: -7 }
            if ptInRect(pt, rect)
                result: hoveredComponent
                traverse hoveredComponent, (child) ->
                    rect: rectOf(child)
                    unless ptInRect(pt, rect)
                        return skipTraversingChildren
                    result: child
                return result

        result: null
        traverse activeScreen.rootComponent, (child) ->
            rect: rectOf(child)
            unless ptInRect(pt, rect)
                return skipTraversingChildren
            result: child
        result

    findComponentByEvent: (e) ->
        origin: ptFromLT $('#design-area').offset()
        findComponentAt subPtPt({ x: e.pageX, y: e.pageY }, origin)

    renderComponentPosition: (c, cn) ->
        ct: c.type
        relpos: switch
            when c.dragpos
                {
                    'x': c.dragpos.x - ((c.dragParent?.dragpos || c.dragParent?.abspos)?.x || 0)
                    'y': c.dragpos.y - ((c.dragParent?.dragpos || c.dragParent?.abspos)?.y || 0)
                }
            else
                {
                    'x': c.abspos.x - ((c.parent?.dragpos && false || c.parent?.abspos)?.x || 0)
                    'y': c.abspos.y - ((c.parent?.dragpos && false || c.parent?.abspos)?.y || 0)
                }

        $(cn || c.node).css({
            left:   "${relpos.x}px"
            top:    "${relpos.y}px"
        })

    reassignZIndexes: ->
        traverse activeScreen.rootComponent, (comp) ->
            ordered: _(comp.children).sortBy (c) -> r: rectOf c; -r.w * r.h
            _.each ordered, (c, i) -> $(c.node).css('z-index', i)

    textNodeOfComponent: (c, cn) ->
        cn ||= c.node
        return null unless c.type.supportsText
        if c.type.textSelector then $(c.type.textSelector, cn)[0] else cn

    imageNodeOfComponent: (c, cn) ->
        cn ||= c.node
        return null unless c.type.supportsImage
        if c.type.imageSelector then $(c.type.imageSelector, cn)[0] else cn

    imageSizeForImage: (image, effect) ->
        return image.size unless serverMode.supportsImageEffects
        switch effect
            when 'iphone-tabbar-active'   then { w: 35, h: 35 }
            when 'iphone-tabbar-inactive' then { w: 35, h: 32 }
            else image.size

    _imageEffectName: (image, effect) ->
        splitext: /^(.*)\.([^.]+)$/
        split: splitext.exec image
        if split?
            "${split[1]}.${effect}.${split[2]}"
        else
            throw "Unable to split ${image} into filename and extensions"

    #
    # UI may request URLs for many images belonging to the same image group.
    #
    # To avoid issuing sheer amount of requests to server, first call will mark
    # image group as "pending", so subsequent calls will add callback to the
    # list of "waiting for image group $foo". All callbacks will be executed
    # when AJAX handler is executed.
    #

    groups: {}
    pending: {}

    _returnImageUrl: (image, effect, cb) ->
        digest: groups[image.group][image.name]
        if effect and serverMode.supportsImageEffects
            cb "images/${encodeURIComponent image.group}/${encodeURIComponent (_imageEffectName image.name, effect)}?${digest}"
        else
            cb "images/${encodeURIComponent image.group}/${encodeURIComponent image.name}?${digest}"

    _updateGroup: (groupName, group) ->
        info: {}
        for imginfo in group
            info[imginfo['fileName']]: imginfo['digest']
        groups[groupName]: info

    getImageUrl: (image, effect, callback) ->
        if not(image.group of groups)
            if image.group of pending
                pending[image.group].push([image, effect, callback])
            else
                pending[image.group]: [[image, effect, callback]]
                serverMode.getImageGroupInfo image.group, (info) ->
                    _updateGroup image.group, info['images']
                    for [image, effect, callback] in pending[image.group]
                        _returnImageUrl image, effect, callback
                    delete pending[image.group]
        else
            _returnImageUrl image, effect, callback

    renderImageDefault: (comp, node, imageUrl) ->
        $(imageNodeOfComponent comp, node).css { backgroundImage: "url(${imageUrl})"}

    encodeActionAsURL: (comp) ->
        if comp.action?
            comp.action.action.encodeActionAsURL(comp.action)
        else
            ""

    renderComponentStyle: (c, cn) ->
        cn ||= c.node

        dynamicStyle: if c.type.dynamicStyle then c.type.dynamicStyle(c) else {}
        style: $.extend({}, dynamicStyle, c.stylePreview || c.style)
        css: {}
        css.fontSize: style.fontSize if style.fontSize?
        css.color: style.textColor if style.textColor?
        css.fontWeight: (if style.fontBold then 'bold' else 'normal') if style.fontBold?
        css.fontStyle: (if style.fontItalic then 'italic' else 'normal') if style.fontItalic?

        if style.textShadowStyleName?
            for k, v of MakeApp.textShadowStyles[style.textShadowStyleName].css
                css[k] = v

        $(textNodeOfComponent c, cn).css css

        if style.background?
            if not (BACKGROUND_STYLES[style.background])
                console.log "!! Unknown backgrond style ${style.background} for ${c.type.name}"
            bgn: cn || c.node
            if bgsel: c.type.backgroundSelector
                bgn: $(bgn).find(bgsel)[0]
            bgn.className: _((bgn.className || '').trim().split(/\s+/)).reject((n) -> n.match(/^bg-/)).
                concat(["bg-${style.background}"]).join(" ")

        if c.state?
            $(cn).removeClass('state-on state-off').addClass("state-${c.state && 'on' || 'off'}")
        if c.text? and not c.dirtyText
            $(textNodeOfComponent c, cn).html(c.text)
        if c.image?
            getImageUrl c.image, (style.imageEffect || null), (imageUrl) ->
                (c.type.renderImage || renderImageDefault)(c, cn, imageUrl)
        actionURL: encodeActionAsURL(c)
        $(cn).attr('action', actionURL)
        $(cn).alterClass('has-action', actionURL != '')

        if c is activeScreen?.rootComponent
            renderScreenRootComponentId activeScreen

    renderComponentVisualProperties: (c, cn) ->
        renderComponentStyle c, cn
        if cn?
            renderComponentSize c, cn
        else
            updateEffectiveSize c

    renderComponentProperties: (c, cn) -> renderComponentPosition(c, cn); renderComponentVisualProperties(c, cn)

    componentPositionChangedWhileDragging: (c) ->
        renderComponentPosition c
        renderComponentSize c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()

    componentPositionChangedPernamently: (c) ->
        renderComponentPosition c
        updateEffectiveSize c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()

    componentStyleChanged: (c) ->
        renderComponentStyle c

    componentActionChanged: (c) ->
        renderComponentStyle c
        if c is componentToActUpon()
            updateActionInspector()
        if c is hoveredComponent
            updateHoverPanelPosition()

    ##########################################################################################################
    ##  Alignment Detection

    ALIGNMENT_DETECTION_CENTER_FUZZINESS_PX: 2
    ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX: 17
    ALIGNMENT_DETECTION_SIBLING_FUZZINESS_PX: 12
    Alignments: {
        left: {
            bestDefiniteGuess: -> this
            cssValue: 'left'
            adjustedPosition: (originalRect, newSize) -> null
        }
        center: {
            bestDefiniteGuess: -> this
            cssValue: 'center'
            adjustedPosition: (originalRect, newSize) ->
                c: centerOfRect originalRect
                { x: c.x - newSize.w/2, y: originalRect.y }
        }
        right: {
            bestDefiniteGuess: -> this
            cssValue: 'right'
            adjustedPosition: (originalRect, newSize) ->
                { x: originalRect.x+originalRect.w - newSize.w, y: originalRect.y }
        }
        tight: {
            bestDefiniteGuess: -> Alignments.left
        }
        unknown: {
            bestDefiniteGuess: -> Alignments.left
        }
    }
    (->
        for name, al of Alignments
            al.name: name
    )()
    Edges: {
        top: {
            siblingRect: (r, distance) -> { x: r.x, w: r.w, h: distance, y: r.y - distance }
        }
        bottom: {
            siblingRect: (r, distance) -> { x: r.x, w: r.w, h: distance, y: r.y + r.h }
        }
        left: {
            siblingRect: (r, distance) -> { y: r.y, h: r.h, w: distance, x: r.x - distance }
        }
        right: {
            siblingRect: (r, distance) -> { y: r.y, h: r.h, w: distance, x: r.x + r.w }
        }
    }

    findComponentByRect: (r, exclusionSet) ->
        match: null
        traverse activeScreen.rootComponent, (comp) ->
            unless inSet comp, exclusionSet
                if doesRectIntersectRect r, rectOf comp
                    # don't return yet to find the innermost match
                    match: r
        match

    findComponentByTypeIntersectingRect: (type, rect, exclusionSet) ->
        match: null
        traverse activeScreen.rootComponent, (comp) ->
            if inSet comp, exclusionSet
                return skipTraversingChildren
            if not (doesRectIntersectRect rect, rectOf comp)
                return skipTraversingChildren
            if comp.type is type
                match: comp
        match

    compWithChildrenAndParents: (comp) ->
        items: []
        traverse comp, (child) -> items.push child
        while comp: comp.parent
            items.push comp
        items

    possibleAlignmentOf: (comp) ->
        return Alignments.unknown unless comp.parent

        pr: rectOf comp.parent
        cr: rectOf comp

        return Alignments.left  if pr.x <= cr.x <= pr.x + ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX
        return Alignments.right if pr.x+pr.w - ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX <= cr.x+cr.w <= pr.x+pr.w

        nonSiblings: setOf compWithChildrenAndParents comp
        findConstrainingSibling: (edge) -> findComponentByRect(edge.siblingRect(cr, ALIGNMENT_DETECTION_SIBLING_FUZZINESS_PX), nonSiblings)

        leftSibling:  findConstrainingSibling Edges.left
        rightSibling: findConstrainingSibling Edges.right
        return Alignments.tight if leftSibling and rightSibling
        return Alignments.right if rightSibling
        return Alignments.left  if leftSibling

        if Math.abs(centerOfRect(pr).x - centerOfRect(cr).x) <= ALIGNMENT_DETECTION_CENTER_FUZZINESS_PX
            return Alignments.center

        return Alignments.unknown


    ##########################################################################################################
    ##  Component Positioning

    moveComponent: (comp, newPos) ->
        delta: ptDiff(newPos, comp.abspos)
        traverse comp, (child) -> child.abspos: ptSum(child.abspos, delta)

    findComponentOccupyingRect: (r, exclusionSet) ->
        match: null
        traverse activeScreen.rootComponent, (comp) ->
            if not exclusionSet? or not inSet comp, exclusionSet
                candidate: not isContainer
                if !candidate and (comp isnt activeScreen.rootComponent)
                    rect: rectOf comp
                    if rect.x == r.x && rect.y == r.y && rect.w == r.w && rect.h == r.h
                        candidate: yes
                if candidate
                    if doesRectIntersectRect r, rectOf comp
                        # don't return yet to find the innermost match
                        match: comp
        match

    isComponentOrDescendant: (candidate, possibleAncestor) ->
        match: no
        traverse possibleAncestor, (child) ->
            match: yes if child is candidate
        match


    ##########################################################################################################
    ##  sizing

    recomputeEffectiveSizeInDimension: (userSize, policy, fullSize) ->
        userSize || policy.fixedSize?.portrait || policy.fixedSize || switch policy.autoSize
            when 'fill'    then fullSize
            when 'browser' then null

    sizeToPx: (v) ->
        if v then "${v}px" else 'auto'

    renderComponentSize: (c, cn) ->
        ct: c.type
        size: c.dragsize || c.size
        effsize: {
            w: recomputeEffectiveSizeInDimension size.w, ct.widthPolicy, 320
            h: recomputeEffectiveSizeInDimension size.h, ct.heightPolicy, 480
        }
        $(cn || c.node).css({ width: sizeToPx(effsize.w), height: sizeToPx(effsize.h) })
        return effsize

    updateEffectiveSize: (c) ->
        if c.dragsize
            renderComponentSize c
            return
        c.effsize: renderComponentSize c
        # get browser-computed size if needed
        if c.effsize.w is null then c.effsize.w = c.node.offsetWidth
        if c.effsize.h is null then c.effsize.h = c.node.offsetHeight


    ##########################################################################################################
    ##  stacking

    TABLE_TYPES = setOf ['plain-row', 'plain-header', 'roundrect-row', 'roundrect-header']

    isContainer: (c) -> c.type.container

    areVerticallyAdjacent: (c1, c2) ->
        r1: rectOf c1
        r2: rectOf c2
        r1.y + r1.h == r2.y

    midy: (r) -> r.y + r.h / 2

    rectWith: (pos, size) -> { x: pos.x, y: pos.y, w: size.w, h: size.h }

    discoverStacks: ->
        returning [], (stacks) ->
            traverse activeScreen.rootComponent, (c) ->
                c.stack = null; c.previousStackSibling = null; c.nextStackSibling = null

            traverse activeScreen.rootComponent, (c) ->
                if isContainer c
                    discoverStacksInComponent c, stacks

            $('.component').removeClass('in-stack first-in-stack last-in-stack odd-in-stack even-in-stack first-in-group last-in-group odd-in-group even-in-group')
            for stack in stacks
                prev: null
                index: 1
                indexInGroup: 1
                prevGroupName: null
                $(stack.items[0].node).addClass('first-in-stack')
                for cur in stack.items
                    groupName: cur.type.group || 'default'
                    if groupName != prevGroupName
                        $(cur.node).addClass('first-in-group')
                        $(prev.node).addClass('last-in-group') if prev
                        indexInGroup: 1
                    prevGroupName: groupName

                    $(cur.node).addClass("in-stack ${if index % 2 is 0 then 'even' else 'odd'}-in-stack")
                    $(cur.node).addClass("${if indexInGroup % 2 is 0 then 'even' else 'odd'}-in-group")
                    index += 1
                    indexInGroup += 1

                    cur.stack = stack
                    if prev
                        prev.nextStackSibling = cur
                        cur.previousStackSibling = prev
                    prev = cur
                $(prev.node).addClass('last-in-group') if prev
                $(prev.node).addClass('last-in-stack') if prev

    discoverStacksInComponent: (container, stacks) ->
        peers: _(container.children).select (c) -> c.type.name in TABLE_TYPES
        peers: _(peers).sortBy (c) -> c.abspos.y

        contentSoFar: []
        lastStackItem: null
        stackMinX: INF
        stackMaxX: -INF

        canBeStacked: (c) ->
            minX: c.abspos.x
            maxX: c.abspos.x + c.effsize.w
            return no if maxX < stackMinX or minX > stackMaxX
            return no unless lastStackItem.abspos.y + lastStackItem.effsize.h == c.abspos.y
            yes

        flush: ->
            rect: { x: stackMinX, w: stackMaxX - stackMinX, y: contentSoFar[0].abspos.y }
            rect.h = lastStackItem.abspos.y + lastStackItem.effsize.h - rect.y
            stacks.push { type: 'vertical', items: contentSoFar, rect: rect }

            contentSoFar: []
            lastStackItem: null
            stackMinX: INF
            stackMaxX: -INF

        for peer in peers
            flush() if lastStackItem isnt null and not canBeStacked(peer)
            contentSoFar.push peer
            lastStackItem = peer
            stackMinX: Math.min(stackMinX, peer.abspos.x)
            stackMaxX: Math.max(stackMaxX, peer.abspos.x + peer.effsize.w)
        flush() if lastStackItem isnt null

    # stackSlice(from, inclFrom?, [to, inclTo?])
    stackSlice: (from, inclFrom, to, inclTo) ->
        res: []
        res.push from if inclFrom
        item: from.nextStackSibling
        while item? and item isnt to
            res.push item
            item: item.nextStackSibling
        res.push to if inclTo
        return res

    findStackByProximity: (rect, stacks) ->
        _(stacks).find (s) -> proximityOfRectToRect(rect, s.rect) < 20 * 20

    handleStacking: (comp, rect, stacks, action) ->
        return { moves: [] } unless comp.type.name in TABLE_TYPES

        sourceStack: if action == 'duplicate' then null else comp.stack
        targetStack: if rect? then findStackByProximity(rect, stacks) else null

        handleVerticalStacking comp, rect, sourceStack, targetStack

    pickHorizontalPositionBetween: (rect, items) ->
        throw "cannot work with empty list of items" if items.length is 0
        [prevItem, prevItemRect]: [null, null]
        index: 0
        positions: for item in items.concat(null)
            itemRect: if item then rectOf(item) else null
            coord: switch
                when itemRect && prevItemRect then (prevItemRect.x+prevItemRect.w + itemRect.x) / 2
                when itemRect then itemRect.x
                when prevItemRect then prevItemRect.x+prevItemRect.w
                else throw "impossible case"
            [after, before] : [prevItem, item]
            [prevItem, prevItemRect] : [item, itemRect]
            { coord, after, before, index:index++ }

        center: rect.x + rect.w / 2
        _(positions).min (pos) -> Math.abs(center - pos.coord)

    pickHorizontalRectAmong: (rect, items) ->
        throw "cannot work with empty list of items" if items.length is 0
        index: 0
        positions: for item in items
            { rect:(if item.abspos then rectOf(item) else item), item, index:index++ }

        center: rect.x + rect.w / 2
        _(positions).min (pos) -> Math.abs(pos.rect.x+pos.rect.w/2 - center)

    handleVerticalStacking: (comp, rect, sourceStack, targetStack) ->
        if sourceStack && sourceStack.items.length == 1
            if targetStack is sourceStack
                targetStack: null
            sourceStack: null

        return { moves: [] } unless sourceStack? or targetStack?

        if sourceStack == targetStack
          target: _(targetStack.items).min (c) -> proximityOfRectToRect rectOf(c), rect
          if target is comp
            return { targetRect: rectOf(comp), moves: [] }
          else if rect.y > comp.abspos.y
            # moving down
            return {
              targetRect: rectWith target.abspos, comp.effsize
              moves: [
                { comps: stackSlice(comp, no, target, yes), offset: { x: 0, y: -comp.effsize.h } }
              ]
            }
          else
            # moving up
            return {
                targetRect: rectWith target.abspos, comp.effsize
                moves: [
                    { comps: stackSlice(target, yes, comp, no), offset: { x: 0, y: comp.effsize.h } }
                ]
            }
        else
            res: { moves: [] }
            if targetStack?
                firstItem: _(targetStack.items).first()
                lastItem: _(targetStack.items).last()
                # fake components serving as placeholders
                bofItem: {
                    abspos: { x: firstItem.abspos.x, y: firstItem.abspos.y - comp.effsize.h }
                    effsize: { w: comp.effsize.w, h: comp.effsize.h }
                }
                eofItem: {
                    abspos: { x: lastItem.abspos.x, y: lastItem.abspos.y + lastItem.effsize.h }
                    effsize: { w: comp.effsize.w, h: comp.effsize.h }
                }
                target: _(targetStack.items.concat([bofItem, eofItem])).min (c) -> proximityOfRectToRect rectOf(c), rect
                res.targetRect = rectWith target.abspos, comp.effsize
                if target isnt eofItem and target isnt bofItem
                    res.moves.push { comps: stackSlice(target, yes), offset: { x: 0, y: comp.effsize.h } }
            if sourceStack?
                res.moves.push { comps: stackSlice(comp, no), offset: { x: 0, y: -comp.effsize.h } }
            return res

    ##########################################################################################################
    ##  hover panel

    hoveredComponent: null

    RESIZING_HANDLES = ['tl', 'tc', 'tr', 'cl', 'cr', 'bl', 'bc', 'br']

    adjustHorizontalSizingMode: (comp, hmode) ->
        if comp.type.widthPolicy.userSize then hmode else 'c'
    adjustVerticalSizingMode: (comp, vmode) ->
        if comp.type.heightPolicy.userSize then vmode else 'c'

    updateHoverPanelPosition: ->
        return if hoveredComponent is null
        refOffset: $('#design-area').offset()
        compOffset: $(hoveredComponent.node).offset()
        r: {
            x: compOffset.left - refOffset.left
            y: compOffset.top - refOffset.top
            w: $(hoveredComponent.node).outerWidth()
            h: $(hoveredComponent.node).outerHeight()
        }
        $('#hover-panel').css({ left: r.x, top: r.y })
        [r.x, r.y]: [-6, -6]
        xpos: { 'l': r.x, 'c': r.x + r.w/2, 'r': r.x + r.w - 1 }
        ypos: { 't': r.y, 'c': r.y + r.h/2, 'b': r.y + r.h - 1 }
        xenable: { 'l': yes, 'c': (hoveredComponent.effsize.w >= 23), 'r': yes }
        yenable: { 't': yes, 'c': (hoveredComponent.effsize.h >= 23), 'b': yes }
        # hoveredComponent.effsize.w < 63 or hoveredComponent.effsize.h <= 25
        controlsOutside: yes
        _($('#hover-panel .resizing-handle')).each (handle, index) ->
            [vmode, hmode]: [RESIZING_HANDLES[index][0], RESIZING_HANDLES[index][1]]
            pos: { x: xpos[hmode], y: ypos[vmode] }
            [vmode, hmode]: [adjustVerticalSizingMode(hoveredComponent, vmode), adjustHorizontalSizingMode(hoveredComponent, hmode)]
            disabled: (vmode is 'c' and hmode is 'c')
            visible: xenable[RESIZING_HANDLES[index][1]] and yenable[RESIZING_HANDLES[index][0]] and (controlsOutside or index isnt 0)
            $(handle).css({ left: pos.x, top: pos.y }).alterClass('disabled', disabled).alterClass('hidden', not visible)
        $('#hover-panel .duplicate-handle').alterClass('disabled', hoveredComponent.type.singleInstance)
        $('#hover-panel').alterClass('controls-outside', controlsOutside)
        $('.unlink-handle').alterClass('disabled', not hoveredComponent.action?)
        if hoveredComponent.action?
            renderActionOverlay(hoveredComponent)
        else
            hideLinkOverlay()

    componentHovered: (c) ->
        # the component is being deleted right now
        return unless c.node?
        return if hoveredComponent is c
        if c.type.unmovable
            componentUnhovered()
            return

        ct: c.type
        if ct.container
            $('#hover-panel').addClass('container').removeClass('leaf')
        else
            $('#hover-panel').removeClass('container').addClass('leaf')
        $('#hover-panel').fadeIn(100) if hoveredComponent is null
        hoveredComponent = c
        updateHoverPanelPosition()
        updateInspector()

    componentUnhovered: ->
        return if hoveredComponent is null
        hoveredComponent = null
        $('#hover-panel').hide()
        hideLinkOverlay()
        updateInspector()

    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click ->
        if hoveredComponent isnt null
            $('#hover-panel').hide()
            deleteComponent hoveredComponent
            hoveredComponent = null

    $('#hover-panel .duplicate-handle').click ->
        if hoveredComponent isnt null
            duplicateComponent hoveredComponent

    _($('.hover-panel .resizing-handle')).each (handle, index) ->
        $(handle).mousedown (e) ->
            return if hoveredComponent is null
            [vmode, hmode]: [RESIZING_HANDLES[index][0], RESIZING_HANDLES[index][1]]
            [vmode, hmode]: [adjustVerticalSizingMode(hoveredComponent, vmode), adjustHorizontalSizingMode(hoveredComponent, hmode)]
            disabled: (vmode is 'c' and hmode is 'c')
            return if disabled
            activateResizingMode hoveredComponent, { x: e.pageX, y: e.pageY }, { vmode: vmode, hmode: hmode }
            false

    renderLinkOverlay: (sourceComp, destR) ->
        compR:  rectOfNode sourceComp.node
        compPt: centerOfRect compR
        destPt: { x: destR.x+destR.w, y: destR.y+destR.h/2 }
        designAreaR: rectOfNode $('#design-pane')
        clipR:  canonRect { x: Math.min(designAreaR.x, destR.x+destR.w), y: designAreaR.y, x2: designAreaR.x+designAreaR.w-1, y2: designAreaR.y+designAreaR.h-1 }

        $('#link-overlay').css({ 'opacity': 0.2 })
        canvas: $('#link-overlay').attr({ 'width': clipR.w, 'height': clipR.h }).css({ 'left': clipR.x, 'top': clipR.y, 'width': clipR.w, 'height': clipR.h }).show()[0]

        startPt: subPtPt compPt, clipR
        endPt:   subPtPt destPt, clipR
        clipX: 2
        if endPt.x < clipX
            endPt.y: startPt.y + (endPt.y-startPt.y) * ((clipX-startPt.x) / (endPt.x-startPt.x))
            endPt.x: clipX

        ctx: canvas.getContext '2d'
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        ctx.beginPath()
        ctx.moveTo(startPt.x, startPt.y)
        ctx.lineTo(endPt.x, endPt.y)
        arrowPt: mulVecLen(unitVecOfPtPt(endPt, startPt), 10)
        ctx.save()
        ctx.translate(endPt.x, endPt.y)
        ctx.save()
        ctx.rotate(Math.PI/180*20)
        ctx.moveTo(0, 0)
        ctx.lineTo(arrowPt.x, arrowPt.y)
        ctx.restore()
        ctx.rotate(-Math.PI/180*20)
        ctx.moveTo(0, 0)
        ctx.lineTo(arrowPt.x, arrowPt.y)
        ctx.restore()
        ctx.strokeStyle: "rgba(0, 0, 127, 0.8)"
        ctx.lineWidth: 2
        ctx.stroke()

    hideLinkOverlay: ->
        $('#link-overlay').fadeOut(100)

    animateLinkOverlaySet: ->
        # TODO: cancel this animation if hovering another comp
        $('#link-overlay').animate({ 'opacity': 1 }, 500)

    animateLinkRemoved: (callback) ->
        $('#link-overlay').fadeOut(500, callback)

    renderActionOverlay: (comp) ->
        if comp.action && comp.action.action is ACTIONS.switchScreen
            screenName: comp.action.screenName
            screen: _(application.screens).detect (s) -> s.name is screenName
            if screen
                renderLinkOverlay comp, rectOfNode(screen.node)
                return
        hideLinkOverlay()

    $('.link-handle').bind {
        'mousedown': (e) ->
            if hoveredComponent isnt null
                startLinkDragging hoveredComponent, e
    }
    $('.unlink-handle').click (e) ->
        if hoveredComponent isnt null
            runTransaction "remove link", ->
                hoveredComponent.action: null
                animateLinkRemoved ->
                    componentActionChanged hoveredComponent

    startLinkDragging: (sourceComp, initialE) ->
        lastCandidate: null

        onmousemove: (e) ->
            r: { x: e.pageX, y: e.pageY, w: 0, h: 0 }
            lastCandidate: _({ screen, dist: distancePtPt2(r, centerOfRect(rectOfNode(screen.node))) } for screen in application.screens).min (o) -> o.dist
            if lastCandidate.dist > 100
                lastCandidate: null
            if lastCandidate
                renderLinkOverlay sourceComp, rectOfNode(lastCandidate.screen.node)
            else
                renderLinkOverlay sourceComp, r
            e.preventDefault()
            e.stopPropagation()

        onmouseup: (e) ->
            onmousemove(e)
            if lastCandidate
                sourceComp.action: ACTIONS.switchScreen.create(lastCandidate.screen)
                componentActionChanged sourceComp
                animateLinkOverlaySet()
                activateInspector 'action'
            else
                # TODO: render old link if any
                renderActionOverlay sourceComp
            deactivateMode()

        activateMode {
            isScreenLinkingMode: yes
            activated: ->
                document.addEventListener 'mousemove', onmousemove, true
                document.addEventListener 'mouseup',   onmouseup,   true
                $('#screens-list').addClass('prominent')
            deactivated: ->
                document.removeEventListener 'mousemove', onmousemove, true
                document.removeEventListener 'mouseup',   onmouseup,   true
                $('#screens-list').removeClass('prominent')
        }
        onmousemove(initialE)

    ##########################################################################################################
    ##  selection

    selectedComponent: null

    selectComponent: (comp) ->
        return if comp is selectedComponent
        deselectComponent()
        selectedComponent: comp
        $(selectedComponent.node).addClass 'selected'
        updateInspector()

    deselectComponent: ->
        return if selectedComponent is null
        $(selectedComponent.node).removeClass 'selected'
        selectedComponent: null
        updateInspector()

    componentToActUpon: -> selectedComponent || hoveredComponent


    ##########################################################################################################
    ##  double-click editing

    handleComponentDoubleClick: (c) ->
        switch c.type.name
            when 'tab-bar-item'
                beginUndoTransaction "activation of ${friendlyComponentName c}"
                _(c.parent.children).each (child) ->
                    newState: if c is child then on else off
                    if child.state isnt newState
                        child.state: newState
                        renderComponentStyle child
                componentsChanged()
            when 'switch'
                c.state: c.type.state unless c.state?
                newStateDesc: if c.state then 'off' else 'on'
                beginUndoTransaction "undo turning ${friendlyComponentName c} ${newStateDesc}"
                c.state: !c.state
                renderComponentStyle c
                componentsChanged()
        startComponentTextInPlaceEditing c

    startComponentTextInPlaceEditing: (c) ->
        return unless c.type.supportsText

        if c.type.wantsSmartAlignment
            alignment: possibleAlignmentOf(c).bestDefiniteGuess()
            originalRect: rectOf c

        realign: ->
            if c.type.wantsSmartAlignment
                updateEffectiveSize c
                if newPos: alignment.adjustedPosition(originalRect, c.effsize)
                    c.abspos: newPos
                    renderComponentPosition c
                    updateHoverPanelPosition()

        $(textNodeOfComponent c).startInPlaceEditing {
            before: ->
                c.dirtyText: yes;
                $(c.node).addClass 'editing';
                activateMode {
                    isInsideTextField: yes
                    debugname: "In-Place Text Edit"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                }
                componentBeingDoubleClickEdited: c
            after:  ->
                c.dirtyText: no
                $(c.node).removeClass 'editing'
                deactivateMode()
                if componentBeingDoubleClickEdited is c
                    componentBeingDoubleClickEdited: null
            accept: (newText) ->
                if newText is ''
                    newText: "Text"
                runTransaction "text change in ${friendlyComponentName c}", ->
                    c.text: newText
                    c.dirtyText: no
                    renderComponentVisualProperties c
                    realign()
            changed: ->
                realign()
        }


    ##########################################################################################################
    ##  context menu

    $('#delete-component-menu-item').bind {
        update:   (e, comp) -> e.enabled: !comp.type.unmovable
        selected: (e, comp) -> deleteComponent comp
    }
    $('#duplicate-component-menu-item').bind {
        update:   (e, comp) -> e.enabled: !comp.type.unmovable
        selected: (e, comp) -> duplicateComponent comp
    }
    showComponentContextMenu: (comp, pt) -> $('#component-context-menu').showAsContextMenuAt pt, comp

    $('#delete-custom-image-menu-item').bind {
        selected: (e, image) -> deleteCustomImage image
    }


    ##########################################################################################################
    ##  Mode Engine

    [activateMode, deactivateMode, cancelMode, dispatchToMode, activeMode]: newModeEngine {
        modeDidChange: (mode) ->
            if mode
                console.log "Mode: ${mode?.debugname}"
            else
                console.log "Mode: None"
    }
    ModeMethods: {
        mouseup:      (m) -> m.mouseup
        contextmenu:  (m) -> m.contextmenu
        mousedown:    (m) -> m.mousedown
        mousemove:    (m) -> m.mousemove
        screenclick:  (m) -> m.screenclick
        escdown:      (m) -> m.escdown
    }


    ##########################################################################################################
    ##  Snapping

    class Snapping
        constructor: (magnet, anchor) ->
            @magnet: magnet
            @anchor: anchor
            @affects: magnet.affects
            @distance: Math.abs(@magnet.coord - @anchor.coord)
        isValid: ->
            @distance <= CONF_SNAPPING_DISTANCE

    Snappings: {}

    class Snappings.left extends Snapping
        apply: (rect) -> rect.x: @anchor.coord
    class Snappings.leftonly extends Snappings.left
    class Snappings.right extends Snapping
        apply: (rect) -> rect.x: @anchor.coord - rect.w
    class Snappings.rightonly extends Snappings.right
    class Snappings.xcenter extends Snapping
        apply: (rect) -> rect.x: @anchor.coord - rect.w/2

    class Snappings.top extends Snapping
        apply: (rect) -> rect.y: @anchor.coord
    class Snappings.bottom extends Snapping
        apply: (rect) -> rect.y: @anchor.coord - rect.h
    class Snappings.ycenter extends Snapping
        apply: (rect) -> rect.y: @anchor.coord - rect.h/2

    Snappings.left.snapsTo:    (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.leftonly
    Snappings.right.snapsTo:   (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.rightonly
    Snappings.xcenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.xcenter
    _([Snappings.left, Snappings.right, Snappings.xcenter]).each (s) -> s.affects: 'x'

    Snappings.top.snapsTo:     (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
    Snappings.bottom.snapsTo:  (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
    Snappings.ycenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.ycenter
    _([Snappings.top, Snappings.bottom, Snappings.ycenter]).each (s) -> s.affects: 'y'

    Anchors: {}
    class Anchors.line
        constructor: (comp, snappingClass, coord) ->
            @comp:    comp
            @coord:   coord
            @snappingClass: snappingClass
            @affects: @snappingClass.affects
        snapTo: (anchor) ->
            if @snappingClass.snapsTo anchor
                new @snappingClass(this, anchor)
            else
                null

    computeOuterAnchors: (comp, r) ->
        _.compact [
            new Anchors.line(comp, Snappings.left,    r.x)            if r.x > allowedArea.x
            new Anchors.line(comp, Snappings.right,   r.x + r.w)      if r.x+r.w < allowedArea.x+allowedArea.w
            new Anchors.line(comp, Snappings.xcenter, r.x + r.w / 2)
            new Anchors.line(comp, Snappings.top,     r.y)            if r.y > allowedArea.y
            new Anchors.line(comp, Snappings.bottom,  r.y + r.h)      if r.y+r.h < allowedArea.y+allowedArea.h
            new Anchors.line(comp, Snappings.ycenter, r.y + r.h / 2)
        ]

    computeInnerAnchors: (comp, forComp) ->
        anchors: _.flatten(computeOuterAnchors(child, rectOf(child)) for child in comp.children)
        rect: rectOf(comp)
        anchors: anchors.concat computeOuterAnchors(comp, rect)
        if comp.type.name is 'plain-row'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 8)
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 43)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8-8-10)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 43)
        if comp.type.name is 'roundrect-row'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 20)
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 55)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20-8-10)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 55)
        if comp.type.name is 'navBar'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 5)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 5)
        anchors

    computeMagnets: (comp, rect) -> computeOuterAnchors(comp, rect)

    computeSnappings: (anchors, magnets) ->
        snappings: []
        for magnet in magnets
            for anchor in anchors
                if snapping: magnet.snapTo anchor
                    snappings.push snapping
        snappings

    chooseSnappings: (snappings) ->
        bestx: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'x'), (s) -> s.distance)
        besty: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'y'), (s) -> s.distance)
        _.compact [bestx, besty]


    ##########################################################################################################
    ##  General Dragging

    newLiveMover: (excluded) ->
        excludedSet: setOf excluded
        traverse activeScreen.rootComponent, (c) ->
            if inSet c, excludedSet
                return skipTraversingChildren
            $(c.node).addClass 'stackable'

        {
            moveComponents: (moves) ->
                for m in moves
                    if m.comp
                        m.comps: [m.comp]
                    for c in m.comps
                        if inSet c, excludedSet
                            throw "Component ${c.id} cannot be moved because it has been excluded!"
                componentSet: setOf _.flatten(m.comps for m in moves)

                traverse activeScreen.rootComponent, (c) ->
                    if inSet c, excludedSet
                        return skipTraversingChildren
                    if inSet c, componentSet
                        return skipTraversingChildren
                    if c.dragpos
                        c.dragpos: null
                        c.dragsize: null
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c

                for m in moves
                    for c in m.comps
                        $(c.node).addClass 'stacked'
                        offset: m.offset || subPtPt(m.abspos, c.abspos)
                        traverse c, (child) ->
                            child.dragpos: { x: child.abspos.x + offset.x; y: child.abspos.y + offset.y }
                            child.dragsize: m.size || null
                            child.dragParent: child.parent
                            componentPositionChangedWhileDragging child

            rollback: ->
                traverse activeScreen.rootComponent, (c) ->
                    if inSet c, excludedSet
                        return skipTraversingChildren
                    $(c.node).removeClass 'stackable'
                traverse activeScreen.rootComponent, (c) ->
                    if inSet c, excludedSet
                        return skipTraversingChildren
                    if c.dragpos
                        c.dragpos: null
                        c.dragsize: null
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c

            commit: (delay) ->
                traverse activeScreen.rootComponent, (c) ->
                    if c.dragpos
                        c.abspos = c.dragpos
                        if c.dragsize
                            c.size: c.dragsize
                        c.dragpos: null
                        c.dragsize: null
                        c.dragParent: null
                        componentPositionChangedPernamently c

                cleanup: -> $('.component').removeClass 'stackable'
                if delay? then setTimeout(cleanup, delay) else cleanup()
        }

    positionTabBarItems: (count, tabBarRect) ->
        [hinset, hgap, vinset]: [5, 2, 3]
        itemSize: { w: (tabBarRect.w - 2*hinset - hgap*(count-1)) / count
                    h: Types['tab-bar-item'].heightPolicy.fixedSize }
        pt: { x: tabBarRect.x + hinset, y: tabBarRect.y + vinset }
        switch count
            when 0 then []
            when 1 then [rectFromPtAndSize(pt, itemSize)]
            else
                index: 0
                while index++ < count
                    r: rectFromPtAndSize(pt, itemSize)
                    pt.x += itemSize.w + hgap
                    r

    positionToolbarItems: (children, outerRect) ->
        return [] if children.length is 0

        totalW: _(children).reduce 0, (memo, child) -> memo + child.effsize.w
        hgap = (outerRect.w - totalW) / (children.length + 1)

        x: outerRect.x + hgap
        for child in children
            r: rectFromPtAndSize { x: x, y: outerRect.y + (outerRect.h-child.effsize.h)/2 }, child.effsize
            x += child.effsize.w + hgap
            r

    newItemsForHorizontalStack: (items, comp, rect) ->
        if _(items).include(comp)
            filteredItems: _(_(items).without(comp)).sortBy (child) -> child.abspos.x
            if rect
                sortedItems: _(items).sortBy (child) -> child.abspos.x
                index: pickHorizontalRectAmong(rect, sortedItems).index
                filteredItems.slice(0, index).concat([comp]).concat(filteredItems.slice(index))
            else
                filteredItems
        else if items.length is 0
            [comp]
        else
            sortedItems: _(items).sortBy (child) -> child.abspos.x
            index: pickHorizontalPositionBetween(rect, sortedItems).index
            sortedItems.slice(0, index).concat([comp]).concat(sortedItems.slice(index))

    newItemsForHorizontalStackDuplication: (items, oldComp, newComp) ->
        items: _(items).sortBy (child) -> child.abspos.x
        index: _(items).indexOf oldComp
        if index < 0
            items.concat([newComp])
        else
            items.slice(0, index).concat([newComp]).concat(items.slice(index))

    computeDropEffectFromNewRects: (items, newRects, comp) ->
        throw "lengths do not match" unless items.length == newRects.length
        effect: { moves: [], rect: null }
        for [item, rect] in _.zip(items, newRects)
            if comp? and item is comp
                effect.rect: rect
            else
                effect.moves.push { comp: item, abspos: { x:rect.x, y:rect.y }, size: { w:rect.w, h:rect.h } }
        effect

    startDragging: (comp, options, initialMoveOptions) ->
        origin: $('#design-area').offset()

        if comp.inDocument
            originalR: rectOf comp

        computeHotSpot: (pt) ->
            r: rectOf comp
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        liveMover: newLiveMover [comp]
        wasAnchored: no
        anchoredTransitionChangeTimeout: new Timeout STACKED_COMP_TRANSITION_DURATION

        $(comp.node).addClass 'dragging'

        updateRectangleAndClipToArea: (pt) ->
            r: sizeOf comp
            r.x: pt.x - origin.left - r.w * hotspot.x
            r.y: pt.y - origin.top  - r.h * hotspot.y
            unsnappedRect: dupRect r

            insideArea: {
                x: (allowedArea.x <= r.x <= allowedArea.x+allowedArea.w-r.w)
                y: allowedArea.y <= r.y <= allowedArea.y+allowedArea.h-r.h
            }
            snapToArea: {
                left:   (allowedArea.x - CONF_DESIGNAREA_PUSHBACK_DISTANCE <= r.x < allowedArea.x)
                top:    (allowedArea.y - CONF_DESIGNAREA_PUSHBACK_DISTANCE <= r.y < allowedArea.y)
                right:  (allowedArea.x+allowedArea.w-r.w < r.x <= allowedArea.x+allowedArea.w-r.w + CONF_DESIGNAREA_PUSHBACK_DISTANCE)
                bottom: (allowedArea.y+allowedArea.h-r.h < r.y <= allowedArea.y+allowedArea.h-r.h + CONF_DESIGNAREA_PUSHBACK_DISTANCE)
            }
            if (insideArea.x or snapToArea.left or snapToArea.right) and (insideArea.y or snapToArea.top or snapToArea.bottom)
                if snapToArea.left then r.x = allowedArea.x
                if snapToArea.top  then r.y = allowedArea.y
                if snapToArea.right then r.x = allowedArea.x+allowedArea.w - r.w
                if snapToArea.bottom then r.y = allowedArea.y+allowedArea.h - r.h
                insideArea.x = insideArea.y = yes

            [r, unsnappedRect, insideArea.x && insideArea.y]

        moveTo: (pt, moveOptions) ->
            [rect, unsnappedRect, ok] = updateRectangleAndClipToArea(pt)

            if ok
                if effect: computeDropEffect comp, rect, moveOptions
                    { target, isAnchored, rect, moves }: effect
                else
                    ok: no
                    moves: []
            else
                { moves }: computeDeletionEffect comp

            unless ok
                rect: unsnappedRect

            $(comp.node)[if ok then 'removeClass' else 'addClass']('cannot-drop')
            liveMover.moveComponents moves

            comp.dragpos = { x: rect.x, y: rect.y }
            comp.dragsize: { w: rect.w, h: rect.h }
            comp.dragParent: null

            if wasAnchored and not isAnchored
                anchoredTransitionChangeTimeout.set -> $(comp.node).removeClass 'anchored'
            else if isAnchored and not wasAnchored
                anchoredTransitionChangeTimeout.clear()
                $(comp.node).addClass 'anchored'
            wasAnchored = isAnchored

            componentPositionChangedWhileDragging comp

            if ok then { target: target } else null

        dropAt: (pt, moveOptions) ->
            $(comp.node).removeClass 'dragging'

            if res: moveTo pt, moveOptions
                effects: []
                if comp.type is Types['image'] and res.target.type.supportsImageReplacement
                    effects.push newSetImageEffect(res.target, comp)
                else
                    effects.push newDropOnTargetEffect(comp, res.target, originalSize, originalEffSize)
                for e in effects
                    e.apply()
                liveMover.commit()
                true
            else
                comp.dragpos: null
                comp.dragsize: null
                comp.dragParent: null
                liveMover.commit()
                false

        cancel: ->
            $(comp.node).removeClass 'dragging cannot-drop'
            liveMover.rollback()

        if comp.node.parentNode
            comp.node.parentNode.removeChild(comp.node)
        activeScreen.rootComponent.node.appendChild(comp.node)
        # we might have just added a new component
        traverse comp, (child) -> updateEffectiveSize child
        originalSize: comp.size
        originalEffSize: comp.effsize

        moveTo(options.startPt, initialMoveOptions)

        { moveTo, dropAt, cancel }


    ##########################################################################################################
    ##  Layouts & Effects Computation

    class Layout
        constructor: (target) ->
            @target: target

    class PinnedLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            pin: comp.type.pin
            rect: pin.computeRect allowedArea, comp, (otherPin) =>
                for child in @target.children
                    if child.type.pin is otherPin
                        return rectOf(child)
                null
            moves: []
            for dependantPin in pin.dependantPins
                for child in @target.children
                    if child.type.pin is dependantPin
                        newRect: child.type.pin.computeRect allowedArea, child, (otherPin) =>
                            return rect if otherPin is pin
                            for otherChild in @target.children
                                if otherChild.type.pin is otherPin
                                    return rectOf(otherChild)
                            null
                        moves.push { comp: child, abspos: newRect }
            { isAnchored: yes, rect, moves }

        computeDuplicationEffect: (oldComp, newComp) ->
            if oldComp is newComp
                # this is a paste op
                return { rect: rectOf(newComp), moves: [] }
            null

        computeDeletionEffect: (comp) ->
            pin: comp.type.pin
            moves: []
            for dependantPin in pin.dependantPins
                for child in @target.children
                    if child.type.pin is dependantPin
                        newRect: child.type.pin.computeRect allowedArea, child, (otherPin) =>
                            return null if otherPin is pin
                            for otherChild in @target.children
                                if otherChild.type.pin is otherPin
                                    return rectOf(otherChild)
                            null
                        moves.push { comp: child, abspos: newRect }
            { moves }

    class TabBarItemLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, rect
            itemRects: positionTabBarItems newChildren.length, rectOf(@target)
            { rect, moves }: computeDropEffectFromNewRects newChildren, itemRects, comp
            { isAnchored: yes, rect, moves }

        computeDuplicationEffect: (oldComp, newComp) ->
            newChildren: newItemsForHorizontalStackDuplication @target.children, oldComp, newComp
            itemRects: positionTabBarItems newChildren.length, rectOf(@target)
            computeDropEffectFromNewRects newChildren, itemRects, newComp

        computeDeletionEffect: (comp) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, null
            itemRects: positionTabBarItems newChildren.length, rectOf(@target)
            { moves }: computeDropEffectFromNewRects newChildren, itemRects, comp

    class ToolbarContentLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, rect
            itemRects: positionToolbarItems newChildren, rectOf(@target)
            { rect, moves }: computeDropEffectFromNewRects newChildren, itemRects, comp
            { isAnchored: yes, rect, moves }

        computeDuplicationEffect: (oldComp, newComp) ->
            newChildren: newItemsForHorizontalStackDuplication @target.children, oldComp, newComp
            itemRects: positionToolbarItems newChildren, rectOf(@target)
            computeDropEffectFromNewRects newChildren, itemRects, newComp

        computeDeletionEffect: (comp) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, null
            itemRects: positionToolbarItems newChildren, rectOf(@target)
            { moves }: computeDropEffectFromNewRects newChildren, itemRects, comp

    class RegularLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            stacking: handleStacking comp, rect, allStacks
            if stacking.targetRect?
                { isAnchored: yes, rect: stacking.targetRect, moves: stacking.moves }
            else
                anchors: _(computeInnerAnchors(@target, comp)).reject (a) -> comp == a.comp
                magnets: computeMagnets(comp, rect)
                snappings: computeSnappings(anchors, magnets)

                unless moveOptions.disableSnapping
                    snappings: chooseSnappings snappings
                    # console.log "(${rect.x}, ${rect.y}, w ${rect.w}, h ${rect.h}), target ${target?.id}, best snapping horz: ${best.horz?.dist} at ${best.horz?.coord}, vert: ${best.vert?.dist} at ${best.vert?.coord}"
                    for snapping in snappings
                        snapping.apply rect

                { isAnchored: no, rect, moves: [] }

        computeDuplicationEffect: (oldComp, newComp) ->
            rect: rectOf(oldComp)
            rect.y += rect.h
            stacking: handleStacking oldComp, rect, allStacks, 'duplicate'

            if stacking.targetRect
                return { rect: stacking.targetRect, moves: stacking.moves }
            else
                usableBounds: rectOf activeScreen.rootComponent

                rect: rectOf(oldComp)
                while rect.x+rect.w <= usableBounds.x+usableBounds.w - DUPLICATE_COMPONENT_MIN_EDGE_INSET_X
                    found: findComponentOccupyingRect rect
                    return { rect, moves: [] } unless found
                    rect.x += found.effsize.w + DUPLICATE_COMPONENT_OFFSET_X

                rect: rectOf(oldComp)
                while rect.y+rect.h <= usableBounds.y+usableBounds.h - DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y
                    found: findComponentOccupyingRect rect
                    return { rect, moves: [] } unless found
                    rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y

                # when everything else fails, just pick a position not occupied by exact duplicate
                rect: rectOf(oldComp)
                while rect.y+rect.h <= usableBounds.y+usableBounds.h
                    found: no
                    traverse activeScreen.rootComponent, (c) -> found: c if c.abspos.x == rect.x && c.abspos.y == rect.y
                    # handle (0,0) case
                    found: null if found is activeScreen.rootComponent
                    return { rect, moves: [] } unless found
                    rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y
                return null

        computeDeletionEffect: (comp) ->
            { moves: [] }

    class TableRowLayout extends RegularLayout

        computeDropTarget: (target, comp, rect, moveOptions) ->


    # either target or rect is specified
    computeLayout: (comp, target, rect) ->
        return null unless target? or rect?
        if pin: comp.type.pin
            new PinnedLayout(activeScreen.rootComponent)
        else if comp.type.name in TABLE_TYPES
            new TableRowLayout(activeScreen.rootComponent)
        else if comp.type.name is 'tab-bar-item'
            if target: findChildByType(activeScreen.rootComponent, Types['tabBar'])
                new TabBarItemLayout(target)
            else
                null
        else if (target and target.type.name is 'toolbar') or (rect and (target: findComponentByTypeIntersectingRect(Types['toolbar'], rect, setOf [comp])))
            new ToolbarContentLayout(target)
        else if target or (rect and (target: findBestTargetContainerForRect rect, [comp]))
            new RegularLayout(target)
        else
            null

    computeDropEffect: (comp, rect, moveOptions) ->
        if comp.type.name is 'image' and (target: findComponentByTypeIntersectingRect(Types['tab-bar-item'], rect, setOf [comp]))
            return { target, moves: [], isAnchored: yes, rect: centerSizeInRect(comp.effsize, rectOf target) }

        if layout: computeLayout comp, null, rect
            if comp.type.singleInstance
                for child in layout.target.children
                    if child.type is comp.type
                        return null

            eff: layout.computeDropEffect comp, rect, moveOptions
            eff.target: layout.target
            return eff
        else
            return null

    computeDuplicationEffect: (newComp, oldComp) ->
        oldComp ||= newComp
        if layout: computeLayout(oldComp, oldComp.parent)
            layout.computeDuplicationEffect oldComp, newComp
        else
            null

    computeDeletionEffect: (comp) ->
        return { moves: [] } unless comp.parent

        if layout: computeLayout comp, comp.parent
            layout.computeDeletionEffect comp
        else
            { moves: [] }


    ##########################################################################################################
    ##  Dragging Specifics


    newDropOnTargetEffect: (c, target, originalSize, originalEffSize) ->
        {
            apply: ->
                if c.parent != target
                    _(c.parent.children).removeValue c  if c.parent
                    c.parent = target
                    c.parent.children.push c

                if c.node.parentNode
                    c.node.parentNode.removeChild(c.node)
                c.parent.node.appendChild(c.node)

                if c.dragsize
                    c.size: {
                        w: if c.dragsize.w is originalEffSize.w then originalSize.w else c.dragsize.w
                        h: if c.dragsize.h is originalEffSize.h then originalSize.h else c.dragsize.h
                    }
                shift: ptDiff c.dragpos, c.abspos
                traverse c, (cc) -> cc.abspos: ptSum cc.abspos, shift
                c.dragpos: null
                c.dragsize: null
                c.dragParent: null

                traverse c, (child) -> child.inDocument: yes
                traverse c, (child) -> assignNameIfStillUnnamed child, activeScreen

                componentPositionChangedPernamently c
        }

    newSetImageEffect: (target, c) ->
        {
            apply: ->
                target.image: c.image
                $(c.node).remove()
                renderComponentVisualProperties target
                componentsChanged()
        }

    computeMoveOptions: (e) ->
        {
            disableSnapping: !!e.ctrlKey
        }

    activateExistingComponentDragging: (c, startPt) ->
        dragger: null

        window.status = "Dragging a component."

        activateMode {
            debugname: "Existing Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->

                pt: { x: e.pageX, y: e.pageY }
                if dragger is null
                    return if Math.abs(pt.x - startPt.x) <= 1 and Math.abs(pt.y - startPt.y) <= 1
                    beginUndoTransaction "movement of ${friendlyComponentName c}"
                    dragger: startDragging c, { startPt: startPt }, computeMoveOptions(e)
                    $('#hover-panel').hide()
                dragger.moveTo pt, computeMoveOptions(e)
                true

            mouseup: (e) ->
                if dragger isnt null
                    if dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                        componentsChanged()
                        $('#hover-panel').show()
                    else
                        deleteComponent c
                deactivateMode()

                true

            cancel: ->
                if dragger isnt null
                    dragger.cancel()
                c.dragsize: null
                c.dragpos: null
                c.dragParent: null
                componentPositionChangedWhileDragging c
        }

    activateNewComponentDragging: (startPt, c, e) ->
        beginUndoTransaction "creation of ${friendlyComponentName c}"
        cn: renderInteractiveComponentHeirarchy c

        dragger: startDragging c, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }, computeMoveOptions(e)

        window.status = "Dragging a new component."

        activateMode {
            debugname: "New Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                true

            mouseup: (e) ->
                ok: dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                if ok
                    componentsChanged()
                else
                    $(c.node).fadeOut 250, ->
                        $(c.node).remove()
                deactivateMode()
                true

            cancel: ->
                $(c.node).fadeOut 250, ->
                    $(c.node).remove()
        }

    startResizing: (comp, startPt, options) ->
        originalSize: comp.size
        baseSize: comp.effsize
        console.log "base size:"
        console.log baseSize
        originalPos: comp.abspos
        {
            moveTo: (pt) ->
                delta: ptDiff(pt, startPt)
                newPos: {}
                newSize: {}
                console.log options
                minimumSize: comp.type.minimumSize || { w: 4, h: 4 }

                maxSizeDecrease: { x: baseSize.w - minimumSize.w; y : baseSize.h - minimumSize.h }

                maxSizeIncrease: { x: INF; y: INF }
                maxSizeIncrease.x: switch options.hmode
                    when 'l' then originalPos.x - allowedArea.x
                    else          allowedArea.x+allowedArea.w - (originalPos.x+baseSize.w)
                maxSizeIncrease.y: switch options.vmode
                    when 't' then originalPos.y - allowedArea.y
                    else          allowedArea.y+allowedArea.h - (originalPos.y+baseSize.h)

                switch options.hmode
                    when 'l' then delta.x: Math.max(-maxSizeIncrease.x, Math.min( maxSizeDecrease.x, delta.x))
                    else          delta.x: Math.min( maxSizeIncrease.x, Math.max(-maxSizeDecrease.x, delta.x))
                switch options.vmode
                    when 't' then delta.y: Math.max(-maxSizeIncrease.y, Math.min( maxSizeDecrease.y, delta.y))
                    else          delta.y: Math.min( maxSizeIncrease.y, Math.max(-maxSizeDecrease.y, delta.y))

                [newSize.w, newPos.x]: switch
                    when delta.w is 0 or options.hmode is 'c' then [originalSize.w, originalPos.x]
                    when options.hmode is 'r' then [baseSize.w + delta.x, originalPos.x]
                    when options.hmode is 'l' then [baseSize.w - delta.x, originalPos.x + delta.x]
                    else throw "Internal Error: unknown resize hmode ${options.hmode}"
                [newSize.h, newPos.y]: switch
                    when delta.h is 0 or options.vmode is 'c' then [originalSize.h, originalPos.y]
                    when options.vmode is 'b' then [baseSize.h + delta.y, originalPos.y]
                    when options.vmode is 't' then [baseSize.h - delta.y, originalPos.y + delta.y]
                    else throw "Internal Error: unknown resize vmode ${options.vmode}"
                comp.size: newSize
                comp.dragpos: newPos
                comp.dragParent: comp.parent
                console.log "resizing to ${comp.size.w} x ${comp.size.h}"
                updateEffectiveSize comp
                renderComponentPosition comp
                updateHoverPanelPosition()

            dropAt: (pt) ->
                @moveTo pt
                runTransaction "resizing of ${friendlyComponentName comp}", ->
                    comp.abspos: comp.dragpos
                    comp.dragpos: null
                    comp.dragParent: null
        }

    activateResizingMode: (comp, startPt, options) ->
        console.log "activating resizing mode for ${friendlyComponentName comp}"
        resizer: startResizing comp, startPt, options
        activateMode {
            debugname: "Resizing"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                resizer.moveTo { x:e.pageX, y:e.pageY }
                true
            mouseup: (e) ->
                resizer.dropAt { x:e.pageX, y:e.pageY }
                deactivateMode()
                true
        }


    ##########################################################################################################
    ##  Mouse Event Handling

    defaultMouseDown: (e, comp) ->
        if comp
            selectComponent comp
            if not comp.type.unmovable
                activateExistingComponentDragging comp, { x: e.pageX, y: e.pageY }
        else
            deselectComponent()
        true

    defaultMouseMove: (e, comp) ->
        if comp
            componentHovered comp
        else if $(e.target).closest('.hover-panel').length
            #
        else
            componentUnhovered()
        true

    defaultContextMenu: (e, comp) ->
        if comp then showComponentContextMenu comp, { x: e.pageX, y: e.pageY }; true
        else         false

    defaultMouseUp: (e, comp) -> false

    $('#design-pane, #link-overlay').bind {
        mousedown: (e) ->
            if e.button is 0
                comp: findComponentByEvent(e)
                e.preventDefault(); e.stopPropagation()
                dispatchToMode(ModeMethods.mousedown, e, comp) || defaultMouseDown(e, comp)
            undefined

        mousemove: (e) ->
            comp: findComponentByEvent(e)
            e.preventDefault(); e.stopPropagation()
            dispatchToMode(ModeMethods.mousemove, e, comp) || defaultMouseMove(e, comp)
            undefined

        mouseup: (e) ->
            comp: findComponentByEvent(e)
            if e.which is 3
                return if e.shiftKey
                e.stopPropagation()
            else
                handled: dispatchToMode(ModeMethods.mouseup, e, comp) || defaultMouseUp(e, comp)
                e.preventDefault() if handled
            undefined

        'contextmenu': (e) ->
            return if e.shiftKey
            comp: findComponentByEvent(e)
            console.log ["contextmenu", e]
            setTimeout (-> dispatchToMode(ModeMethods.contextmenu, e, comp) || defaultContextMenu(e, comp)), 1
            false
    }

    $('body').mouseup (e) ->
        # console.log "mouseup on document"
        cancelMode() if activeMode()?.cancelOnMouseUp

    $(document).mouseout (e) ->
        if e.target is document.documentElement
            # console.log "mouseout on window"
            cancelMode() if activeMode()?.cancelOnMouseUp

    ##########################################################################################################
    ##  palette

    paletteWanted: on

    customImages: {}

    bindPaletteItem: (item, compTemplate) ->
        $(item).mousedown (e) ->
            if e.which is 1
                e.preventDefault()
                c: cloneTemplateComponent compTemplate
                activateNewComponentDragging { x: e.pageX, y: e.pageY }, c, e

    renderPaletteGroupContent: (ctg, group, func) ->
        $('<div />').addClass('header').html(ctg.name).appendTo(group)
        ctg.itemsNode: items: $('<div />').addClass('items').appendTo(group)
        func ||= ((ct, n) ->)
        for compTemplate in ctg.items
            c: cloneTemplateComponent(externalizePaletteComponent(compTemplate))
            n: renderStaticComponentHierarchy c
            $(n).attr('title', compTemplate.label || c.type.label)
            $(n).addClass('item').appendTo(items)
            bindPaletteItem n, externalizePaletteComponent(compTemplate)
            func compTemplate, n

    renderPaletteGroup: (ctg, permanent) ->
        group: $('<div />').addClass('group').appendTo($('#palette-container'))
        renderPaletteGroupContent ctg, group
        if not permanent
            group.addClass('transient-group')
        group

    fillPalette: ->
        for ctg in MakeApp.paletteDefinition
            renderPaletteGroup ctg, true

    constrainImageSize: (imageSize, maxSize) ->
      if imageSize.w <= maxSize.w and imageSize.h <= maxSize.h
        imageSize
      else
        # need to scale up this number of times
        ratio: { x: maxSize.w / imageSize.w ; y: maxSize.h / imageSize.h }
        if ratio.x > ratio.y
          { h: maxSize.h; w: imageSize.w * ratio.y }
        else
          { w: maxSize.w; h: imageSize.h * ratio.x }

    updateCustomImagesPalette: ->
        $('.transient-group').remove()
        for group_id, group of customImages
            group.items: []
            for image in group.images
                i: {
                    type: 'image'
                    label: "${image.fileName} ${image.width}x${image.height}"
                    image: { name: image.fileName, group: group_id }
                    # TODO landscape
                    size: constrainImageSize { w: image.width, h: image.height }, { w: 320, h: 480 }
                    imageEl: image
                }
                if group.effect
                    i.style = { imageEffect: group.effect }
                    i.size = imageSizeForImage i, group.effect
                group.items.push(i)
            renderPaletteGroup group, false
            renderPaletteGroupContent group, group.element, (item, node) ->
                item.imageEl.node: node
                $(node).bindContextMenu '#custom-image-context-menu', item.imageEl

    addCustomImagePlaceholder: ->
        # FIXME: draw this placeholder in proper place
        #$(customImagesPaletteCategory.itemsNode).append $("<div />", { className: 'customImagePlaceholder' })
        $('#palette').scrollToBottom()

    # updatePaletteVisibility: (reason) ->
    #     showing: $('.palette').is(':visible')
    #     desired: paletteWanted # && !mode.hidesPalette
    #     if showing and not desired
    #         $('.palette').hidePopOver()
    #     else if desired and not showing
    #         anim: if reason is 'mode' then 'fadein' else 'popin'
    #         $('.palette').showPopOverPointingTo $('#add-button'), anim

    # resizePalette: ->
    #     maxPopOverSize: $(window).height() - 44 - 20
    #     $('.palette').css 'height', Math.min(maxPopOverSize, 600)
    #     if $('.palette').is(':visible')
    #         $('.palette').repositionPopOver $('#add-button')

    initPalette: ->
        fillPalette()
        updateCustomImagesPalette()
        # resizePalette()


    ##########################################################################################################
    ##  Screen List

    renderScreenComponents: (screen, node) ->
        cn: renderStaticComponentHierarchy screen.rootComponent
        renderComponentPosition screen.rootComponent, cn
        $(node).append(cn)

    renderScreen: (screen) ->
        sn: screen.node: domTemplate 'app-screen-template'
        $(sn).setdata('makeapp.screen', screen)
        rerenderScreenContent screen
        sn

    renderScreenRootComponentId: (screen) ->
        $(screen.rootComponent.node).attr('id', 'screen-' + encodeNameForId(screen.name))

    renderScreenName: (screen) ->
        $('.caption', screen.node).html screen.name
        renderScreenRootComponentId screen

    rerenderScreenContent: (screen) ->
        $(screen.node).find('.component').remove()
        renderScreenName screen
        renderScreenComponents screen, $('.content .rendered', screen.node)

    bindScreen: (screen) ->
        $(screen.node).bindContextMenu '#screen-context-menu', screen
        $('.content', screen.node).click (e) ->
            if e.which is 1
                if not dispatchToMode ModeMethods.screenclick, screen
                    switchToScreen screen
                false
        $('.caption', screen.node).click -> startRenamingScreen screen

    updateScreenList: ->
        $('#screens-list > .app-screen').remove()
        _(application.screens).each (screen, index) ->
            appendRenderedScreenFor screen

    updateActionsDueToScreenRenames: (renames) ->
        for screen in application.screens
            traverse screen.rootComponent, (comp) ->
                if comp.action && comp.action.action is ACTIONS.switchScreen
                        if newName: renames[comp.action.screenName]
                            comp.action.screenName: newName
                            componentActionChanged comp

    keepingScreenNamesNormalized: (func) ->
        _(application.screens).each (screen, index) -> screen.originalName: screen.name; screen.nameIsBasedOnIndex: (screen.name is "Screen ${index+1}")
        func()
        # important to execute all renames at once to handle numbered screens ("Screen 1") being swapped
        renames: {}
        _(application.screens).each (screen, index) ->
            screen.name: "Screen ${index+1}" if screen.nameIsBasedOnIndex or not screen.name?
            if screen.name isnt screen.originalName
                renames[screen.originalName]: screen.name
            delete screen.nameIsBasedOnIndex if screen.nameIsBasedOnIndex?
            delete screen.originalName if screen.originalName?
        updateActionsDueToScreenRenames renames

    addScreenWithoutTransaction: ->
        screen: internalizeScreen {
            rootComponent: DEFAULT_ROOT_COMPONENT
        }
        keepingScreenNamesNormalized ->
            application.screens.push screen
        appendRenderedScreenFor screen
        switchToScreen screen

    addScreen: ->
        beginUndoTransaction "creation of a new screen"
        addScreenWithoutTransaction()
        endUndoTransaction()

    startRenamingScreen: (screen) ->
        return if activeMode()?.screenBeingRenamed is screen
        $('.caption', screen.node).startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "Screen Name Editing"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    screenBeingRenamed: screen
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                runTransaction "screen rename", ->
                    oldText: screen.name
                    screen.name: newText
                    renames: {}
                    renames[oldText]: newText
                    updateActionsDueToScreenRenames renames
                    renderScreenName screen
        }
        return false

    deleteScreen: (screen) ->
        pos: application.screens.indexOf(screen)
        return if pos < 0

        beginUndoTransaction "deletion of a screen"
        keepingScreenNamesNormalized ->
            application.screens.splice(pos, 1)
        $(screen.node).fadeOut 250, ->
            $(screen.node).remove()
        if application.screens.length is 0
            addScreenWithoutTransaction()
        else
            switchToScreen(application.screens[pos] || application.screens[pos-1])
        endUndoTransaction()

    duplicateScreen: (oldScreen) ->
        pos: application.screens.indexOf(oldScreen)
        return if pos < 0

        screen: internalizeScreen externalizeScreen oldScreen
        screen.name: null

        beginUndoTransaction "duplication of a screen"
        keepingScreenNamesNormalized ->
            application.screens.splice pos+1, 0, screen
        appendRenderedScreenFor screen, oldScreen.node
        endUndoTransaction()
        updateScreenList()
        switchToScreen screen

    appendRenderedScreenFor: (screen, after) ->
        renderScreen screen
        if after
            $(after).after(screen.node)
        else
            $('#screens-list').append(screen.node)
        bindScreen screen

    updateScreenPreview: (screen) ->
        rerenderScreenContent screen

    setActiveScreen: (screen) ->
        $('#screens-list > .app-screen').removeClass('active')
        $(screen.node).addClass('active')

    $('#add-screen-button').click -> addScreen(); false

    $('#rename-screen-menu-item').bind {
        selected: (e, screen) -> startRenamingScreen screen
    }
    $('#duplicate-screen-menu-item').bind {
        selected: (e, screen) -> duplicateScreen screen
    }
    $('#delete-screen-menu-item').bind {
        selected: (e, screen) -> deleteScreen screen
    }

    $('#screens-list').sortable {
        items: '.app-screen'
        axis: 'y'
        distance: 5
        opacity: 0.8
        update: (e, ui) ->
            runTransaction "reordering screens", ->
                keepingScreenNamesNormalized ->
                    screens: _($("#screens-list .app-screen")).map (sn) -> $(sn).getdata('makeapp.screen')
                    application.screens: screens
                updateScreenList()
    }


    ##########################################################################################################
    ##  Active Screen / Application

    switchToScreen: (screen) ->
        setActiveScreen screen

        $('#design-area .component').remove()

        activeScreen = screen
        activeScreen.nextId ||= 1

        $('#design-area').append renderInteractiveComponentHeirarchy activeScreen.rootComponent
        updateSizes: ->
            traverse activeScreen.rootComponent, (c) -> updateEffectiveSize c
        setTimeout updateSizes, 10


        devicePanel: $('#device-panel')[0]
        allowedArea: {
            x: 0
            y: 0
            w: 320
            h: 480
        }

        componentsChanged()
        deselectComponent()
        componentUnhovered()


    loadApplication: (app, appId) ->
        app.name = createNewApplicationName() unless app.name
        application = app
        applicationId = appId
        renderApplicationName()
        updateScreenList()
        switchToScreen application.screens[0]

    saveApplicationChanges: (callback) ->
        serverMode.saveApplicationChanges externalizeApplication(application), applicationId, (newId) ->
            applicationId: newId
            if callback then callback()

    renderApplicationName: ->
        $('#app-name-content').html(application.name)

    $('#app-name-content').click ->
        return if activeMode()?.isAppRenamingMode
        $('#app-name-content').startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "App Name Editing"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    isAppRenamingMode: yes
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                runTransaction "application rename", ->
                    application.name: newText
        }
        false

    ##########################################################################################################
    ##  Share (stub implementation)

    updateSharePopover: ->
        s: JSON.stringify(externalizeApplication(application))
        $('#share-popover textarea').val(s)

    toggleSharePopover: ->
        if $('#share-popover').is(':visible')
            $('#share-popover').hidePopOver()
        else
            $('#share-popover').showPopOverPointingTo $('#run-button')
            updateSharePopover()

    checkApplicationLoading: ->
        v: $('#share-popover textarea').val()
        s: JSON.stringify(externalizeApplication(application))

        good: yes
        if v != s && v != ''
            try
                app: JSON.parse(v)
            catch e
                good: no
            loadApplication internalizeApplication(app), applicationId if app
        $('#share-popover textarea').css('background-color', if good then 'white' else '#ffeeee')
        undefined

    for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
        $('#share-popover textarea').bind event, checkApplicationLoading

    ##########################################################################################################
    ## inspector

    $('.tab').click ->
        $('.tab').removeClass 'active'
        $(this).addClass 'active'
        $('.pane').removeClass 'active'
        $('#' + this.id.replace('-tab', '-pane')).addClass 'active'
        false

    activateInspector: (name) ->
        $("#insp-${name}-tab").trigger 'click'

    activateInspector 'backgrounds'

    fillInspector: ->
        fillBackgroundsInspector()

    updateInspector: ->
        updateBackgroundsInspector()
        updatePositionInspector()
        updateTextInspector()
        updateActionInspector()

    bindBackground: (swatch, bg) ->
        bindStyleChangeButton swatch, (c, style) ->
            style.background: bg.name
            "setting background of comp to ${bg.label}"

    fillBackgroundsInspector: ->
        $pal: $('#backgrounds-palette')
        for bg in MakeApp.backgroundStyles
            node: domTemplate('background-swatch-template')
            $(node).attr({'id': "bg-${bg.name}", 'title': bg.label}).addClass("bg-${bg.name}").appendTo($pal)
            bindBackground node, bg

    updateBackgroundsInspector: ->
        enabled: no
        $('#insp-backgrounds-pane li').removeClass 'active'
        if c: componentToActUpon()
            enabled: c.type.supportsBackground
            if enabled
                if active: c.style.background || ''
                    $("#bg-${active}").addClass 'active'
        $('#insp-backgrounds-pane li').alterClass 'disabled', !enabled

    updatePositionInspector: ->
        if c: componentToActUpon()
            abspos: c.dragpos || c.abspos
            relpos: { x: abspos.x - c.parent.abspos.x, y: abspos.y - c.parent.abspos.y } if c.parent?
            $('#insp-rel-pos').html(if c.parent? then "(${relpos.x}, ${relpos.y})" else "&mdash;")
            $('#insp-abs-pos').html "(${abspos.x}, ${abspos.y})"
            $('#insp-size').html "${c.effsize.w}x${c.effsize.h}"
        else
            $('#insp-rel-pos').html "&mdash;"
            $('#insp-abs-pos').html "&mdash;"
            $('#insp-size').html "&mdash;"

    formatHexColor: (color) ->
        if (m: color.match(/^\s*([a-hA-H0-9]{6})\s*$/)) or (m: color.match(/^\s*#([a-hA-H0-9]{6})\s*/))
            return m[1].toLowerCase()
        if (m: color.match(/^\s*([a-hA-H0-9]{3})\s*$/)) or (m: color.match(/^\s*#([a-hA-H0-9]{3})\s*/))
            return (m[1][0] + m[1][0] + m[1][1] + m[1][1] + m[1][2] + m[1][2]).toLowerCase()
        return null

    updateTextInspector: ->
        pixelSize: null
        textStyleEditable: no
        bold: no
        italic: no
        textColor: null
        if c: componentToActUpon()
            tn: textNodeOfComponent c
            if tn
                cs: getComputedStyle(tn, null)
                pixelSize: parseInt cs.fontSize
                bold: cs.fontWeight is 'bold'
                italic: cs.fontStyle is 'italic'
                textColor: if c.style.textColor then formatHexColor c.style.textColor else null
            textStyleEditable: c.type.textStyleEditable
        $('#pixel-size-label').html(if pixelSize then "${pixelSize} px" else "")
        $('#insp-text-pane li')[if textStyleEditable then 'removeClass' else 'addClass']('disabled')
        $('#text-bold')[if bold then 'addClass' else 'removeClass']('active')
        $('#text-italic')[if italic then 'addClass' else 'removeClass']('active')
        if textColor is null
            $('#text-color-input').attr('disabled', 'disabled')
        else
            $('#text-color-input').removeAttr('disabled')
        $('#text-color-input').val(textColor || '') unless activeMode()?.isTextColorEditingMode
        $('#pick-color-button').alterClass('disabled', textColor is null or !textStyleEditable)
        $('#pick-color-swatch').css 'background-color', (if textColor then '#'+textColor else 'transparent')
        setColorToPicker(textColor) if textColor
        if textColor is null and $('#color-picker').is(':visible')
            $('#color-picker').hide()

    $('#pick-color-button').click ->
        if $('#color-picker').is(':visible')
            $('#color-picker').hide()
        else if $('#pick-color-button').is(':not(.disabled)')
            offsets: {
                button: $('#pick-color-button').offset()
                pickerParent: $('#color-picker').parent().offset()
            }
            pickerSize: {
                width: $('#color-picker').outerWidth()
                height: $('#color-picker').outerHeight()
            }
            $('#color-picker').css {
                left: offsets.button.left - pickerSize.width/2  - offsets.pickerParent.left
                top:  offsets.button.top  - pickerSize.height - 10 - offsets.pickerParent.top
            }
            $('#color-picker').show()

    ignorePickerUpdates: no

    setColorToPicker: (color) ->
        ignorePickerUpdates: yes
        $.jPicker.List[0].color.active.val('hex', color)
        ignorePickerUpdates: no

    commitTextColor: (fromPicker) ->
        if (fromPicker or activeMode()?.isTextColorEditingMode) and (c: componentToActUpon())
            originalColor: $('#text-color-input').val()
            color: formatHexColor originalColor
            $('#text-color-input').alterClass('invalid', color is null)

            if color and color isnt c.style.textColor
                runTransaction "color change", ->
                    c.style.textColor: '#' + color
                renderComponentStyle c

            if fromPicker and color and color isnt originalColor
                $('#text-color-input').val(color)

            setColorToPicker(color) unless fromPicker

    initColorPicker: ->

        $('#text-color-input').livechange -> commitTextColor(false); true

        commit: (color, context) ->
            return if ignorePickerUpdates
            $('#text-color-input').val color.val('hex')
            commitTextColor(true)

        $('#color-picker').jPicker {
            images: {
                clientPath: 'static/theme/images/jpicker/'
            }
        }, commit, commit
    initColorPicker()

    $('#text-color-input').focus ->
        activateMode {
            isTextColorEditingMode: yes
            isInsideTextField: yes
            deactivated:  ->
                # $('#color-picker').hide(200)
                commitTextColor(true)
                updateTextInspector()
            cancel: -> $('#text-color-input').blur()
            mousemove: -> false
            mouseup: -> false
        }
    $('#text-color-input').blur ->
        if activeMode()?.isTextColorEditingMode
            deactivateMode()

    updateActionInspector: ->
        # enabled: no
        # current: ""
        # actionSet: no
        # actionCleared: no
        # if activeMode()?.isActionPickingMode
        #     enabled: yes
        #     current: "&larr; click on a screen in the left pane (ESC to cancel)"
        #     actionSet: yes
        # else if c: componentToActUpon()
        #     if enabled: not c.type.forbidsAction
        #         if act: c.action
        #             current: act.action.describe(act, application)
        #             actionSet: yes
        #         else
        #             current: ""
        #             actionCleared: yes
        # $('#chosen-action-label').html(current)
        # $('#set-action-button, #no-action-button')[if enabled then 'removeClass' else 'addClass']('disabled')
        # $('#set-action-button')[if actionSet then 'addClass' else 'removeClass']('active')
        # $('#no-action-button')[if actionCleared then 'addClass' else 'removeClass']('active')

    activateActionPickingMode: (c) ->
        activateMode {
            screenclick: (screen) ->
                runTransaction "action change", ->
                    c.action: ACTIONS.switchScreen.create(screen)
                    componentActionChanged c
                    deactivateMode()
                    updateActionInspector()
            activated:   -> updateActionInspector()
            deactivated: -> updateActionInspector()
            escdown:     -> deactivateMode(); true
            mousemove:   -> true
            isActionPickingMode: yes
        }

    $('#no-action-button').click (e) ->
        cancelMode()
        if c: componentToActUpon()
            if enabled: not c.type.forbidsAction
                runTransaction "clearing action of ${friendlyComponentName c}", ->
                    c.action: null
                    componentActionChanged c
                    updateActionInspector()

    $('#set-action-button').click (e) ->
        if activeMode()?.isActionPickingMode
            deactivateMode()
        else if c: componentToActUpon()
            if enabled: not c.type.forbidsAction
                activateActionPickingMode c

    bindStyleChangeButton: (button, func) ->
        savedComponent: null
        cancelStyle: ->
            if savedComponent
                savedComponent.stylePreview: null
                componentStyleChanged savedComponent
                savedComponent: null

        $(button).bind {
            mouseover: ->
                cancelStyle()
                return if $(button).is('.disabled')
                if c: savedComponent: componentToActUpon()
                    c.stylePreview: cloneObj(c.style)
                    func(c, c.stylePreview)
                    componentStyleChanged c

            mouseout: cancelStyle

            click: ->
                cancelStyle()
                return if $(button).is('.disabled')
                if c: componentToActUpon()
                    c.stylePreview: null
                    beginUndoTransaction "changing style of ${friendlyComponentName c}"
                    s: func(c, c.style)
                    if s && s.constructor == String
                        setCurrentChangeName s.replace(/\bcomp\b/, friendlyComponentName(c))
                    componentStyleChanged c
                    componentsChanged()
        }

    bindStyleChangeButton $('#make-size-smaller'), (c, style) ->
        if tn: textNodeOfComponent c
            currentSize: c.style.fontSize || parseInt getComputedStyle(tn, null).fontSize
            style.fontSize: currentSize - 1
            "decreasing font size of comp to ${style.fontSize} px"
    bindStyleChangeButton $('#make-size-bigger'), (c, style) ->
        if tn: textNodeOfComponent c
            currentSize: c.style.fontSize || parseInt getComputedStyle(tn, null).fontSize
            style.fontSize: currentSize + 1
            "increasing font size of comp to ${style.fontSize} px"

    bindStyleChangeButton $('#text-bold'), (c, style) ->
        if tn: textNodeOfComponent c
            currentState: if c.style.fontBold? then c.style.fontBold else getComputedStyle(tn, null).fontWeight is 'bold'
            style.fontBold: not currentState
            if style.fontBold then "making comp bold" else "making comp non-bold"

    bindStyleChangeButton $('#text-italic'), (c, style) ->
        if tn: textNodeOfComponent c
            currentState: if c.style.fontItalic? then c.style.fontItalic else getComputedStyle(tn, null).fontStyle is 'italic'
            style.fontItalic: not currentState
            if style.fontItalic then "making comp italic" else "making comp non-italic"

    updateShadowStyle: (shadowStyleName, c, style) ->
        style.textShadowStyleName: shadowStyleName
        "changing text shadow of comp to ${MakeApp.textShadowStyles[shadowStyleName].label}"

    bindStyleChangeButton $('#shadow-none'), (c, style) -> updateShadowStyle 'none', c, style
    bindStyleChangeButton $('#shadow-dark-above'), (c, style) -> updateShadowStyle 'dark-above', c, style
    bindStyleChangeButton $('#shadow-light-below'), (c, style) -> updateShadowStyle 'light-below', c, style

    fillInspector()
    updateInspector()


    ##########################################################################################################
    ##  Image Upload

    uploadImageFile: (file) ->
        console.log "Uploading ${file.fileName} of size ${file.fileSize}"
        serverMode.uploadImageFile file.fileName, file, ->
            updateCustomImages()

    updateCustomImages: ->
        serverMode.loadCustomImages (groups) ->
            for group in groups
                _updateGroup group['name'], group['images']
                gg: {
                    name: group['name'] + (if group['writeable'] then ' (drop your image files here)' else '')
                    effect: group['effect']
                    writeable: group['writeable']
                }
                gg.images: ({
                    width: img['width']
                    height: img['height']
                    fileName: img['fileName']
                } for img in group['images'])
                customImages[group['id']]: gg
            updateCustomImagesPalette()

    $('body').each ->
        this.ondragenter: (e) ->
            console.log "dragenter"
            e.preventDefault()
            e.dataTransfer.dropEffect: 'copy'
            false
        this.ondragover: (e) ->
            console.log "dragover"
            e.preventDefault()
            e.dataTransfer.dropEffect: 'copy'
            false
        this.ondrop: (e) ->
            return unless e.dataTransfer?.files?.length
            console.log "drop"
            e.preventDefault()
            errors: []
            filesToUpload: []
            for file in e.dataTransfer.files
                if not file.fileName.match(/\.jpg$|\.png$|\.gif$/)
                    ext: file.fileName.match(/\.[^.\/\\]+$/)[1]
                    errors.push { fileName: file.fileName, reason: "${ext || 'this'} format is not supported"}
                else if file.fileSize > MAX_IMAGE_UPLOAD_SIZE
                    errors.push { fileName: file.fileName, reason: "file too big, maximum size is ${MAX_IMAGE_UPLOAD_SIZE_DESCR}"}
                else
                    filesToUpload.push file
            if errors.length > 0
                message: switch errors.length
                    when 1 then "Cannot upload ${errors[0].fileName}: ${errors[0].reason}.\n"
                    else "Cannot upload the following files:\n" + ("\t* ${e.fileName} (${e.reason})\n" for e in errors)
                if filesToUpload.length > 0
                    message += "\nThe following files WILL be uploaded: " + _(filesToUpload).map((f) -> f.fileName).join(", ")
                alert message
            for file in filesToUpload
                addCustomImagePlaceholder()
                uploadImageFile file
            $('#palette').scrollToBottom()

    deleteCustomImage: (image) ->
        serverMode.deleteCustomImage image.id, ->
            $(image.node).fadeOut 250, ->
                $(image.node).remove()


    ##########################################################################################################
    ##  keyboard shortcuts

    KB_MOVE_DIRS: {
        up: {
            offset: { x: 0, y: -1 }
        }
        down: {
            offset: { x: 0, y:  1 }
        }
        left: {
            offset: { x: -1, y: 0 }
        }
        right: {
            offset: { x:  1, y: 0 }
        }
    }

    moveComponentByKeyboard: (comp, e, movement) ->
        if e.ctrlKey
            # TODO: duplicate
        else
            # TODO: detect if part of stack
            amount: if e.shiftKey then 10 else 1
            moveComponentBy comp, ptMul(movement.offset, amount)

    hookKeyboardShortcuts: ->
        $('body').keydown (e) ->
            return if activeMode()?.isInsideTextField
            act: componentToActUpon()
            switch e.which
                when $.KEY_ESC then dispatchToMode(ModeMethods.escdown, e) || deselectComponent(); false
                when $.KEY_DELETE, $.KEY_BACKSPACE then deleteComponent(act) if act
                when $.KEY_ARROWUP    then moveComponentByKeyboard act, e, KB_MOVE_DIRS.up    if act
                when $.KEY_ARROWDOWN  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.down  if act
                when $.KEY_ARROWLEFT  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.left  if act
                when $.KEY_ARROWRIGHT then moveComponentByKeyboard act, e, KB_MOVE_DIRS.right if act
                when 'D'.charCodeAt(0) then duplicateComponent(act) if act and (e.ctrlKey or e.metaKey)
                when 'Z'.charCodeAt(0) then undoLastChange() if (e.ctrlKey or e.metaKey)

    ##########################################################################################################
    ##  Simulation (Run)

    snapshotForSimulation: (screen) ->
        if not screen.rootComponent.node?
            throw "This hack only works for the current screen"
        screen.html: screen.rootComponent.node.outerHTML

    runCurrentApplication: ->
        $('#run-screen').show()
        url: window.location.href.replace(/\/(?:dev|designer).*$/, '/').replace(/#.*$/, '') + "R" + applicationId
        console.log url
        $('#run-address-label a').attr('href', url).html(url)
        $('#run-iframe').attr 'src', url

    $('#run-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        if e.shiftKey
            toggleSharePopover()
            return
        if applicationId?
            runCurrentApplication()
        else
            saveApplicationChanges ->
                runCurrentApplication()

    $('#run-stop-button').click ->
        $('#run-screen').hide()

    ##########################################################################################################
    ##  Dashboard: Application List

    startDashboardApplicationNameEditing: (app) ->
        return if activeMode()?.appBeingRenamed is app
        $('.caption', app.node).startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "App Name Editing (Dashboard)"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    appBeingRenamed: app
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                app.content.name: newText
                serverMode.saveApplicationChanges externalizeApplication(app.content), app.id, (newId) ->
                    refreshApplicationList()
        }

    duplicateApplication: (app) ->
        content: externalizeApplication(app.content)
        content.name: "${content.name} Copy"
        serverMode.saveApplicationChanges content, null, (newId) ->
            refreshApplicationList (newApps) ->
                freshApp: _(newApps).detect (a) -> a.id is newId
                startDashboardApplicationNameEditing freshApp

    $('#rename-application-menu-item').bind {
        selected: (e, app) -> startDashboardApplicationNameEditing app
    }
    $('#duplicate-application-menu-item').bind {
        selected: (e, app) -> duplicateApplication app
    }
    $('#delete-application-menu-item').bind {
        selected: (e, app) ->
            return unless confirm("Are you sure you want to delete ${app.content.name}?")
            deleteApplication app
    }


    ##########################################################################################################
    ##  Copy/Paste

    pasteJSON: (json) ->
        targetCont: activeScreen.rootComponent
        data: JSON.parse(json)
        if data.type then data: [data]
        newComps: (internalizeComponent(c, targetCont) for c in data)
        newComps: _((if c.type is Types.background then c.children else c) for c in newComps).flatten()
        pasteComponents targetCont, newComps

    pasteComponents: (targetCont, newComps) ->
        return if newComps.length is 0
        for newComp in newComps
            # make sure all ids are reassigned
            traverse newComp, (child) -> child.id: null
        friendlyName: if newComps.length > 1 then "${newComps.length} objects" else friendlyComponentName(newComps[0])
        runTransaction "pasting ${friendlyName}", ->
            for newComp in newComps
                newComp.parent: targetCont
                targetCont.children.push newComp
                $(targetCont.node).append renderInteractiveComponentHeirarchy newComp

                effect: computeDuplicationEffect newComp
                if effect is null
                    alert "Cannot paste the components because they do not fit into the designer"
                    return
                commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION
                newRect: effect.rect

                moveComponent newComp, newRect
                if newRect.w != newComp.effsize.w or newRect.h != newComp.effsize.h
                    newComp.size: { w: newRect.w, h: newRect.h }
                traverse newComp, (child) -> renderComponentPosition child; updateEffectiveSize child
                traverse newComp, (child) -> assignNameIfStillUnnamed child, activeScreen

    cutComponents: (comps) ->
        comps: _((if c.type is Types.background then c.children else c) for c in comps).flatten()
        friendlyName: if comps.length > 1 then "${comps.length} objects" else friendlyComponentName(comps[0])
        runTransaction "cutting of ${friendlyName}", ->
            for comp in comps
                deleteComponentWithoutTransaction comp, false

    $(document).copiableAsText {
        gettext: -> JSON.stringify(externalizeComponent(comp)) if comp: componentToActUpon()
        aftercut: -> cutComponents [comp] if comp: componentToActUpon()
        paste: (text) -> pasteJSON text
        shouldProcessCopy: -> componentToActUpon() isnt null and !activeMode()?.isInsideTextField
        shouldProcessPaste: -> !activeMode()?.isInsideTextField
    }


    ##########################################################################################################

    initComponentTypes: ->
        for typeName, ct of Types
            ct.name: typeName
            ct.style ||= {}
            if not ct.supportsBackground?
                ct.supportsBackground: 'background' in ct.style
            if not ct.textStyleEditable?
                ct.textStyleEditable: ct.defaultText?
            ct.supportsText: ct.defaultText?

    createNewApplicationName: ->
        adjs = ['Best-Selling', 'Great', 'Incredible', 'Stunning', 'Gorgeous', 'Wonderful',
            'Amazing', 'Awesome', 'Fantastic', 'Beautiful', 'Unbelievable', 'Remarkable']
        names: ("${adj} App" for adj in adjs)
        usedNames: setOf(_.compact(app.content.name for app in (applicationList || [])))
        names: _(names).reject (n) -> n in usedNames
        if names.length == 0
            "Yet Another App"
        else
            names[Math.floor(Math.random() * names.length)]

    createNewApplication: ->
        loadApplication internalizeApplication(MakeApp.appTemplates.basic), null
        switchToDesign()

    bindApplication: (app, an) ->
        app.node: an
        $(an).bindContextMenu '#application-context-menu', app
        $('.content', an).click ->
            loadApplication app.content, app.id
            switchToDesign()
        $('.caption', an).click ->
            startDashboardApplicationNameEditing app
            false

    deleteApplication: (app) ->
        serverMode.deleteApplication app.id, ->
            $(app.node).fadeOut 250, ->
                $(app.node).remove()
                updateApplicationListWidth()

    updateApplicationListWidth: ->
        # 250 is the width of #sample-apps-separator
        $('#apps-list-container').css 'width', (160+60) * $('#apps-list-container .app').length + 250

    renderApplication: (appData, destination, show_name) ->
        appId: appData['id']
        app: JSON.parse(appData['body'])
        app: internalizeApplication(app)
        an: domTemplate('app-template')
        $('.caption', $(an)).html(if show_name then app.name + ' (' + appData['nickname'] + ')' else app.name)
        renderScreenComponents(app.screens[0], $('.content .rendered', an))
        $(an).appendTo(destination)
        app: { id: appId, content: app }
        bindApplication app, an
        app

    refreshApplicationList: (callback) ->
        serverMode.loadApplications (apps) ->
            $('#apps-list .app').remove()
            applicationList: for appData in apps['apps'] when not appData['sample']
                renderApplication appData, '#apps-list-container',
                    apps['current_user'] != appData['created_by']
            $('#sample-apps-separator').detach().appendTo('#apps-list-container')
            for appData in apps['apps'].concat(SAMPLE_APPS) when appData['sample']
                renderApplication appData, '#apps-list-container', false
            updateApplicationListWidth()
            callback(applicationList) if callback

    switchToDesign: ->
        $(".screen").hide()
        $('#design-screen').show()
        # if any
        deactivateMode()
        adjustDeviceImagePosition()
        updateCustomImages()

    switchToDashboard: ->
        $(".screen").hide()
        $('#dashboard-screen').show()
        console.log "switchToDashboard"
        refreshApplicationList()

    $('#new-app-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        createNewApplication()

    $('#dashboard-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        switchToDashboard()

    loadDesigner: (userData) ->
        $("body").removeClass("anonymous-user authenticated-user").addClass("${userData['status']}-user")
        console.log serverMode
        serverMode.adjustUI userData
        serverMode.startDesigner userData
        console.log "done"

    $('#welcome-continue-link').click ->
        $('#welcome-screen').fadeOut()
        false

    adjustDeviceImagePosition: ->
        deviceOffset: $('#device-panel').offset()
        contentOffset: $('#design-area').offset()
        deviceSize: { w: $('#device-panel').outerWidth(), h: $('#device-panel').outerHeight() }
        paneSize: { w: $('#design-pane').outerWidth(), h: $('#design-pane').outerHeight() }
        contentSize: { w: $('#design-area').outerWidth(), h: $('#design-area').outerHeight() }
        deviceInsets: { x: contentOffset.left - deviceOffset.left, y: contentOffset.top - deviceOffset.top }

        devicePos: {
            x: (paneSize.w - deviceSize.w) / 2
        }
        if deviceSize.h >= paneSize.h
            contentY: (paneSize.h - contentSize.h) / 2
            devicePos.y: contentY - deviceInsets.y
        else
            devicePos.y: (paneSize.h - deviceSize.h) / 2

        $('#device-panel').css({ left: devicePos.x, top: devicePos.y })

    unless $.browser.webkit
        $('#welcome-screen .buttons').hide()
        $('#welcome-screen .unsupported').show()
        $('#welcome-screen').show()
        return

    $(window).resize ->
        # resizePalette()
        adjustDeviceImagePosition()

    if window.location.href.match /^file:/
        serverMode: SERVER_MODES['local']
    else
        serverMode: SERVER_MODES['authenticated']

    initComponentTypes()
    initPalette()
    hookKeyboardShortcuts()

    if window.location.href.match /^file:/
        loadDesigner { 'status': 'local' }
    else
        $.ajax {
            url: '/user-info.json'
            dataType: 'json'
            success: (userData) -> loadDesigner userData
            error: (xhr, status, e) ->
                alert "Failed to load the application: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }

    # Make-App Dump
    window.mad: -> activeScreen
