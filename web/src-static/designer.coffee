
jQuery ($) ->

    CONF_SNAPPING_DISTANCE = 5
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100
    STACKED_COMP_TRANSITION_DURATION = 200

    ##########################################################################################################
    #  constants
    
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

    STOCK_DIR: 'static/stock/'
    
    DEFAULT_TEXT_STYLES: {
        fontSize: 17
        textColor: '#fff'
        fontBold: no
        fontItalic: no
    }
    
    DEFAULT_ROOT_COMPONENT: {
        type: "background"
        size: { width: 320, height: 480 }
        abspos: { x: 0, y: 0 }
        id: "root"
    }
    
    SERVER_MODES = {
        anonymous: {
            adjustUI: (userData) ->
                $('.login-button').attr 'href', userData.login_url
                
            startDesigner: (userData) ->
                createNewApplication()
                $('#welcome-screen').show()
                
            saveApplicationChanges: ->
                #
        }
        
        authenticated: {
            adjustUI: (userData) ->
                $('.logout-button').attr 'href', userData.logout_url
                
            startDesigner: (userData) ->
                switchToDashboard()
                
            saveApplicationChanges: ->
                $.ajax {
                    url: '/apps/' + (if applicationId then "${applicationId}/" else "")
                    type: 'POST'
                    data: JSON.stringify(externalizeApplication(application))
                    contentType: 'application/json'
                    dataType: 'json'
                    success: (r) ->
                        if r.error
                            switch r.error
                                when 'signed-out'
                                    alert "Cannot save your changes because you were logged out. Please sign in again."
                                else
                                    alert "Other error: ${r.error}"
                        else
                            applicationId = r.id
                    error: (xhr, status, e) ->
                        alert "Failed to save the application: ${status} - ${e}"
                        # TODO ERROR HANDLING!
                }
                
            loadApplications: (callback) ->
                $.ajax {
                    url: '/apps/'
                    dataType: 'json'
                    success: (r) ->
                        if r.error
                            switch r.error
                                when 'signed-out'
                                    alert "Cannot load your applications because you were logged out. Please sign in again."
                                else
                                    alert "Other error: ${r.error}"
                        else
                            callback(r.apps)
                    error: (xhr, status, e) ->
                        alert "Failed to save the application: ${status} - ${e}"
                        # TODO ERROR HANDLING!
                }
        }
        
        local: {
            adjustUI: (userData) ->
                #
                
            startDesigner: (userData) ->
                createNewApplication()
                
            saveApplicationChanges: ->
                #

            loadApplications: (callback) ->
                callback { apps: [ { id: 42, body: MakeApp.appTemplates.basic } ] }
        }
    }
    
    BACKGROUND_STYLES: {}
    (->
        for bg in MakeApp.backgroundStyles
            BACKGROUND_STYLES[bg.name]: bg
    )()


    ##########################################################################################################
    #  DOM templates
    
    domTemplates = {}
    $('.template').each ->
        domTemplates[this.id] = this
        $(this).removeClass('template').remove()
    domTemplate: (id) ->
        domTemplates[id].cloneNode(true)

    ##########################################################################################################
    #  utilities
    
    aOrAn: (s) ->
        if s[0] in {a: yes, e: yes, i: yes, o: yes, u: yes} then "an ${s}" else "a ${s}"

    ##########################################################################################################
    #  external representation

    internalizeLocation: (location, parent) ->
        {
            x: (location?.x || 0) + (parent?.abspos?.x || 0)
            y: (location?.y || 0) + (parent?.abspos?.y || 0)
        }

    externalizeLocation: (abspos, parent) ->
        {
            x: abspos.x - (parent?.abspos?.x || 0)
            y: abspos.y - (parent?.abspos?.y || 0)
        }
    
    internalizeSize: (size) ->
        {
            width: size?.width || null
            height: size?.height || null
        }
    
    externalizeComponent: (c) ->
        rc: {
            type: c.type.name
            location: externalizeLocation c.abspos, c.parent
            effsize: cloneObj c.effsize
            size: cloneObj c.size
            styleName: c.styleName
            style: cloneObj c.style
            text: c.text
            children: (externalizeComponent(child) for child in c.children || [])
        }
        rc.state: c.state if c.state?
        rc.image: c.image if c.image?
        rc
        
    internalizeComponent: (c, parent) ->
        rc: {
            type: Types[c.type]
            abspos: internalizeLocation c.location, parent
            size: internalizeSize c.size
            styleName: c.styleName
            inDocument: yes
            parent: parent
        }
        rc.children: (internalizeComponent(child, rc) for child in c.children || [])
        if not rc.type
            console.log "Missing type for component:"
            console.log c
            throw "Missing type: ${c.type}"
        rc.state: c.state if c.state?
        rc.image: c.image if c.image?
        rc.style: $.extend({}, (if rc.type.textStyleEditable then DEFAULT_TEXT_STYLES else {}), rc.type.style || {}, c.style || {})
        rc.text: c.text || rc.type.defaultText if rc.type.supportsText
        rc
        
    externalizeScreen: (screen) ->
        {
            rootComponent: externalizeComponent(screen.rootComponent)
        }
        
    internalizeScreen: (screen) ->
        rootComponent: internalizeComponent(screen.rootComponent || DEFAULT_ROOT_COMPONENT, null)
        screen: {
            rootComponent: rootComponent
            nextId: 1
        }
        traverse rootComponent, (c) -> assignNameIfStillUnnamed c, screen
        return screen
    
    externalizeApplication: (app) ->
        {
            name: app.name
            screens: (externalizeScreen(s) for s in app.screens)
        }
        
    internalizeApplication: (app) ->
        {
            name: app.name
            screens: (internalizeScreen(s) for s in app.screens)
        }
    

    ##########################################################################################################
    #  undo
    
    undoStack: []
    lastChange: null
    
    friendlyComponentName: (c) ->
        ct: c.type
        label: (ct.genericLabel || ct.label).toLowerCase()
        if c.text then "the “${c.text}” ${label}" else aOrAn label
    
    beginUndoTransaction: (changeName) ->
        if lastChange isnt null
            console.log "Make-App Internal Warning: implicitly closing an unclosed undo change: ${lastChange.name}"
        lastChange: { memento: createApplicationMemento(), name: changeName }
        
    setCurrentChangeName: (changeName) -> lastChange.name: changeName
        
    endUndoTransaction: ->
        return if lastChange is null
        if lastChange.memento != createApplicationMemento()
            console.log "Change: ${lastChange.name}"
            undoStack.push lastChange
            undoStackChanged()
            saveApplicationChanges()
        lastChange = null

    undoStackChanged: ->
        msg: if undoStack.length == 0 then "Nothing to undo" else "Undo ${undoStack[undoStack.length-1].name}"
        $('#undo-hint span').html msg
        
    undoLastChange: ->
        return if undoStack.length == 0
        change: undoStack.pop()
        console.log "Undoing: ${change.name}"
        revertToMemento change.memento
        undoStackChanged()
        saveApplicationChanges()
        
    createApplicationMemento: -> JSON.stringify(externalizeApplication(application))
    
    revertToMemento: (memento) -> loadApplication JSON.parse(memento), applicationId
    
    $('#undo-button').click -> undoLastChange(); false
    
    undoStackChanged()
    
    ##########################################################################################################
    #  global events
    
    componentsChanged: ->
        endUndoTransaction()
        
        if $('#share-popover').is(':visible')
            updateSharePopover()
            
        reassignZIndexes()
        
        allStacks: discoverStacks()
        
        updateInspector()
        updateScreenPreview(activeScreen)
    
    ##########################################################################################################
    #  geometry

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
    
    ##########################################################################################################
    #  component management
    
    assignNameIfStillUnnamed: (c, screen) -> c.id ||= "c${screen.nextId++}"
    
    storeAndBindComponentNode: (c, cn) ->
        c.node = cn
        $(cn).bind 'contextmenu', -> false
        $(cn).dblclick -> handleComponentDoubleClick c; false
    
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
    
    deleteComponent: (rootc) ->
        return if rootc.type.unmovable
        beginUndoTransaction "deletion of ${friendlyComponentName rootc}"

        stacking: handleStacking rootc, null, allStacks
        
        liveMover: newLiveMover [rootc]
        liveMover.moveComponents stacking.moves
        liveMover.commit(STACKED_COMP_TRANSITION_DURATION)

        _(rootc.parent.children).removeValue rootc
        $(rootc.node).hide 'drop', { direction: 'down' }, 'normal', -> $(rootc.node).remove()
        componentsChanged()

    moveComponent: (comp, offset) ->
        beginUndoTransaction "keyboard moving of ${friendlyComponentName comp}"
        traverse comp, (c) -> c.abspos: ptSum(c.abspos, offset)
        traverse comp, componentPositionChangedPernamently
        componentsChanged()

    duplicateComponent: (comp) ->
        return if comp.type.unmovable
        beginUndoTransaction "duplicate ${friendlyComponentName comp}"

        rect: rectOf comp
        rect.y += rect.h
        stacking: handleStacking comp, rect, allStacks, 'duplicate'
        
        newComp: internalizeComponent(externalizeComponent(comp), comp.parent)
        traverse newComp, (c) -> c.id: null  # make sure all ids are reassigned
        
        
        if stacking.targetRect
            # part of stack, so add directly below
            liveMover: newLiveMover [comp]
            liveMover.moveComponents stacking.moves
            liveMover.commit(STACKED_COMP_TRANSITION_DURATION)
            
            newComp.abspos: { x: stacking.targetRect.x, y: stacking.targetRect.y }
        else
            if comp.abspos.x + 2*comp.effsize.w + 5 + 5 <= 320
                newComp.abspos: {
                    x: comp.abspos.x + comp.effsize.w + 5
                    y: comp.abspos.y
                }
            else
                newComp.abspos: {
                    x: comp.abspos.x
                    y: comp.abspos.y + comp.effsize.h + 5
                }

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
    #  DOM rendering
    
    createNodeForComponent: (c) ->
        ct: c.type
        movability: if ct.unmovable then "unmovable" else "movable"
        $(ct.html || "<div />").addClass("component c-${c.type.name} c-${c.type.name}-${c.styleName || 'nostyle'}").addClass(if ct.container then 'container' else 'leaf').setdata('moa-comp', c).addClass(movability)[0]
        
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
    
    findComponentOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-comp')
        
    renderComponentPosition: (c, cn) ->
        ct: c.type
        relpos: if c.dragpos then externalizeLocation(c.dragpos, c.dragParent) else externalizeLocation(c.abspos, c.parent)
        
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

    renderComponentStyle: (c, cn) ->
        cn ||= c.node

        dynamicStyle: if c.type.dynamicStyle then c.type.dynamicStyle(c) else {}
        style: $.extend({}, dynamicStyle, c.stylePreview || c.style)
        console.log(style)
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
            if not BACKGROUND_STYLES[style.background]
                console.log "!! Unknown backgrond style ${style.background} for ${c.type.name}"
            bgn: cn || c.node
            if bgsel: c.type.backgroundSelector
                bgn: $(bgn).find(bgsel)[0]
            bgn.className: _((bgn.className || '').trim().split(/\s+/)).reject((n) -> n.match(/^bg-/)).
                concat(["bg-${style.background}"]).join(" ")

        if c.state?
            $(cn).removeClass('state-on state-off').addClass("state-${c.state && 'on' || 'off'}")
        if c.text?
            $(textNodeOfComponent c, cn).html(c.text)
        if c.image?
            imageUrl: c.image
            if style.imageEffect
                if imageUrl.substr(0, STOCK_DIR.length) == STOCK_DIR
                    imageUrl = "images/stock--" + imageUrl.substr(STOCK_DIR.length).replace(/\//g, '--') + "/${style.imageEffect}"
                else
                    imageUrl = "${imageUrl}/${style.imageEffect}"
            $(imageNodeOfComponent c, cn).css { backgroundImage: "url(${imageUrl})"}

    renderComponentVisualProperties: (c, cn) ->
        renderComponentStyle c, cn
        if cn?
            renderComponentSize c, cn
        else
            updateEffectiveSize c
    
    renderComponentProperties: (c, cn) -> renderComponentPosition(c, cn); renderComponentVisualProperties(c, cn)
    
    componentPositionChangedWhileDragging: (c) ->
        renderComponentPosition c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()
    
    componentPositionChangedPernamently: (c) ->
        renderComponentPosition c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()
            
    componentStyleChanged: (c) ->
        renderComponentStyle c


    ##########################################################################################################
    #  sizing
    
    recomputeEffectiveSizeInDimension: (userSize, policy, fullSize) ->
        userSize || policy.fixedSize?.portrait || policy.fixedSize || switch policy.autoSize
            when 'fill'    then fullSize
            when 'browser' then null
        
    sizeToPx: (v) ->
        if v then "${v}px" else 'auto'
        
    renderComponentSize: (c, cn) ->
        ct: c.type
        effsize: {
            w: recomputeEffectiveSizeInDimension c.size.width, ct.widthPolicy, 320
            h: recomputeEffectiveSizeInDimension c.size.height, ct.heightPolicy, 460
        }
        $(cn || c.node).css({ width: sizeToPx(effsize.w), height: sizeToPx(effsize.h) })
        return effsize
        
    updateEffectiveSize: (c) ->
        c.effsize: renderComponentSize c
        # get browser-computed size if needed
        if c.effsize.w is null then c.effsize.w = c.node.offsetWidth
        if c.effsize.h is null then c.effsize.h = c.node.offsetHeight


    ##########################################################################################################
    #  stacking
    
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
            
    handleStacking: (comp, rect, stacks, action) ->
        return { moves: [] } unless comp.type.name in TABLE_TYPES
        
        sourceStack: if action == 'duplicate' then null else comp.stack
        targetStack: if rect? then _(stacks).find (s) -> proximityOfRectToRect(rect, s.rect) < 20 * 20 else null

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
                {
                    targetRect: rectWith target.abspos, comp.effsize
                    moves: [
                        { comps: stackSlice(comp, no, target, yes), offset: { x: 0, y: -comp.effsize.h } }
                    ]
                } 
            else
                # moving up
                {
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
    #  hover panel
    
    hoveredComponent: null
    
    updateHoverPanelPosition: ->
        return if hoveredComponent is null
        refOffset: $('#design-area').offset()
        compOffset: $(hoveredComponent.node).offset()
        offset: { left: compOffset.left - refOffset.left, top: compOffset.top - refOffset.top }
        $('#hover-panel').css({ left: offset.left, top: offset.top })
    
    componentHovered: (c) ->
        return unless c.node?  # the component is being deleted right now
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
        

    ##########################################################################################################
    #  selection
    
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
    #  double-click editing
    
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
        startDoubleClickEditing c

    startDoubleClickEditing: (c) ->
        activatePointingMode()
        
        ct: c.type
        return unless ct.supportsText
        
        componentBeingDoubleClickEdited = c
        $(c.node).addClass 'editing'
        
        $editable: $(textNodeOfComponent c)
        
        $editable[0].contentEditable = true
        $editable[0].focus()
        
        originalText: c.text
        
        $editable.blur -> finishDoubleClickEditing() if c is componentBeingDoubleClickEdited
        $editable.keydown (e) ->
            switch e.keyCode
                when 13 then finishDoubleClickEditing(); false
                when 27 then finishDoubleClickEditing(originalText); false
        
        baseMode = mode
        mode: $.extend({}, baseMode, {
            mousedown: (e, c) ->
                return false if c is componentBeingDoubleClickEdited
                finishDoubleClickEditing()
                baseMode.mousedown e, c
        })
        
    finishDoubleClickEditing: (overrideText) ->
        return if componentBeingDoubleClickEdited is null
        
        c:  componentBeingDoubleClickEdited

        $editable: $(textNodeOfComponent c)

        beginUndoTransaction "text change in ${friendlyComponentName c}"
        
        $(c.node).removeClass 'editing'
        $editable[0].contentEditable = false
        
        $editable.unbind 'blur'
        $editable.unbind 'keydown'
        
        c.text = overrideText || $($editable).text()
        renderComponentVisualProperties c
        componentsChanged()
        
        $editable.blur()
        componentBeingDoubleClickEdited = null
        activatePointingMode()


    ##########################################################################################################
    #  context menu

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

    $('#delete-screen-menu-item').bind {
        selected: (e, screen) -> deleteScreen screen
    }
    $('#duplicate-screen-menu-item').bind {
        selected: (e, screen) -> duplicateScreen screen
    }

    $('#delete-application-menu-item').bind {
        selected: (e, applicationId) ->
            return unless confirm("Are you sure you want to delete this application?")
            deleteApplication applicationId
    }
    
    
    ##########################################################################################################
    #  dragging
    
    sizeOf: (c) -> { w: c.effsize.w, h: c.effsize.h }
    rectOf: (c) -> { x: c.abspos.x, y: c.abspos.y, w: c.effsize.w, h: c.effsize.h }
    
    computeSnappingPositionsOfComponent: (c) ->
        r: rectOf c
        _.compact [
            { orient: 'vert', type: 'edge', c: c, coord: r.x } if r.x > allowedArea.x
            { orient: 'vert', type: 'edge', c: c, coord: r.x + r.w } if r.x+r.w < allowedArea.x+allowedArea.w
            { orient: 'vert', type: 'center', c: c, coord: r.x + r.w / 2 }
            { orient: 'horz', type: 'edge', c: c, coord: r.y } if r.y > allowedArea.y
            { orient: 'horz', type: 'edge', c: c, coord: r.y + r.h } if r.y+r.h < allowedArea.y+allowedArea.h
            { orient: 'horz', type: 'center', c: c, coord: r.y + r.h / 2 }
        ]
        
    computeChildrenSnappingPositionsOfContainer: (c) -> computeSnappingPositionsOfComponent c
        
    computeAllSnappingPositions: (pc) ->
        comps: pc.children
        r: _.flatten(computeSnappingPositionsOfComponent c for c in comps)
        if pc is null then r else r.concat computeChildrenSnappingPositionsOfContainer pc
        
    computeSnappings: (ap, r) ->
        switch ap.type
            when 'edge'
                switch ap.orient
                    when 'vert'
                        [
                            {
                                atype: 'left'
                                dist: Math.abs(ap.coord - r.x)
                                coord: ap.coord
                                orient: ap.orient
                            }
                            {
                                atype: 'right'
                                dist: Math.abs(ap.coord - (r.x + r.w))
                                coord: ap.coord
                                orient: ap.orient
                            }
                        ]
                    when 'horz'
                        [
                            {
                                atype: 'top'
                                dist: Math.abs(ap.coord - r.y)
                                coord: ap.coord
                                orient: ap.orient
                            }
                            {
                                atype: 'bottom'
                                dist: Math.abs(ap.coord - (r.y + r.h))
                                coord: ap.coord
                                orient: ap.orient
                            }
                        ]
            when 'center'
                if ap.orient == 'vert'
                    [{
                        atype: 'xcenter'
                        dist: Math.abs(ap.coord - (r.x + r.w/2))
                        coord: ap.coord
                        orient: ap.orient
                    }]
                else
                    [{
                        atype: 'ycenter'
                        dist: Math.abs(ap.coord - (r.y + r.h/2))
                        coord: ap.coord
                        orient: ap.orient
                    }]
                
    applySnapping: (a, r) ->
        switch a.atype
            when 'left'   then r.x = a.coord
            when 'right'  then r.x = a.coord - r.w
            when 'top'    then r.y = a.coord
            when 'bottom' then r.y = a.coord - r.h
            when 'xcenter' then r.x = a.coord - r.w/2
            when 'ycenter' then r.y = a.coord - r.h/2
            else return false
        true
    
    activateMode: (m) ->
        mode: m
        # updatePaletteVisibility('mode')
    
    activatePointingMode: ->
        window.status = "Hover a component for options. Click to edit. Drag to move."
        activateMode {
            mousedown: (e, c) ->
                if c
                    selectComponent c
                    if not c.type.unmovable
                        activateExistingComponentDragging c, { x: e.pageX, y: e.pageY }
                else
                    deselectComponent()
                true

            mousemove: (e, c) ->
                if c
                    componentHovered c
                else if $(e.target).closest('.hover-panel').length
                    #
                else
                    componentUnhovered()
                    
            mouseup: (e, c) ->
                if e.button == 2
                    if c
                        showComponentContextMenu c, { x: e.pageX, y: e.pageY }
            
            hidesPalette: no
        }
        
    newLiveMover: (excluded) ->
        excludedSet: setOf excluded
        traverse activeScreen.rootComponent, (c) ->
            if inSet c, excludedSet
                return skipTraversingChildren
            $(c.node).addClass 'stackable'

        {
            moveComponents: (moves) ->
                componentSet: setOf _.flatten(m.comps for m in moves)
                for m in moves
                    for c in m.comps
                        if inSet c, excludedSet
                            throw "Component ${c.id} cannot be moved because it has been excluded!"
                traverse activeScreen.rootComponent, (c) ->
                    if inSet c, excludedSet
                        return skipTraversingChildren
                    if c.dragpos and not inSet c, componentSet
                        c.dragpos: null
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c
                
                for m in moves
                    for c in m.comps
                        $(c.node).addClass 'stacked'
                        c.dragpos: { x: c.abspos.x + m.offset.x; y: c.abspos.y + m.offset.y }
                        c.dragParent: c.parent
                        componentPositionChangedWhileDragging c
                    
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
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c
                    
            commit: (delay) ->
                traverse activeScreen.rootComponent, (c) ->
                    if c.dragpos
                        c.abspos = c.dragpos
                        c.dragpos: null
                        c.dragParent: null
                        componentPositionChangedPernamently c

                cleanup: -> $('.component').removeClass 'stackable'
                if delay? then setTimeout(cleanup, delay) else cleanup()
        }

    newDropOnTargetEffect: (c, target) ->
        {
            apply: ->
                if c.parent != target
                    _(c.parent.children).removeValue c  if c.parent
                    c.parent = target
                    c.parent.children.push c

                if c.node.parentNode
                    c.node.parentNode.removeChild(c.node)
                c.parent.node.appendChild(c.node)

                shift: ptDiff c.dragpos, c.abspos
                traverse c, (cc) -> cc.abspos: ptSum cc.abspos, shift
                c.dragpos: null
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
    
    startDragging: (c, options) ->
        origin: $('#design-area').offset()
        
        if c.inDocument
            originalR: rectOf c
        
        computeHotSpot: (pt) ->
            r: rectOf c
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        liveMover: newLiveMover [c]
        wasAnchored: no
        anchoredTransitionChangeTimeout: new Timeout STACKED_COMP_TRANSITION_DURATION
        
        $(c.node).addClass 'dragging'
        
        updateRectangleAndClipToArea: (pt) ->
            r: sizeOf c
            r.x: pt.x - origin.left - r.w * hotspot.x
            r.y: pt.y - origin.top  - r.h * hotspot.y

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
            
            [r, insideArea.x && insideArea.y]
        
        moveTo: (pt) ->
            [r, ok] = updateRectangleAndClipToArea(pt)
            $(c.node)[if ok then 'removeClass' else 'addClass']('cannot-drop')

            if ok
                stacking: handleStacking c, r, allStacks
                liveMover.moveComponents stacking.moves
                    
                target: findBestTargetContainerForRect(r, [c])
                target = activeScreen.rootComponent if c.type.name in TABLE_TYPES
                
                isAnchored: no
                if stacking.targetRect?
                    aps: []
                    r = stacking.targetRect
                    isAnchored: yes
                else
                    aps: _(computeAllSnappingPositions(target)).reject (a) -> c == a.c
                    aa: _.flatten(computeSnappings(ap, r) for ap in aps)

                    best: {
                        horz: _(a for a in aa when a.orient is 'horz').min((a) -> a.dist)
                        vert: _(a for a in aa when a.orient is 'vert').min((a) -> a.dist)
                    }
                
                    console.log "(${r.x}, ${r.y}, w ${r.w}, h ${r.h}), target ${target?.id}, best snapping horz: ${best.horz?.dist} at ${best.horz?.coord}, vert: ${best.vert?.dist} at ${best.vert?.coord}"

                    if best.horz and best.horz.dist > CONF_SNAPPING_DISTANCE then best.horz = null
                    if best.vert and best.vert.dist > CONF_SNAPPING_DISTANCE then best.vert = null

                    xa: applySnapping best.vert, r if best.vert
                    ya: applySnapping best.horz, r if best.horz
                    # isAnchored: xa or ya
            
            c.dragpos = { x: r.x, y: r.y }
            c.dragParent: null
            
            if wasAnchored and not isAnchored
                anchoredTransitionChangeTimeout.set -> $(c.node).removeClass 'anchored'
            else if isAnchored and not wasAnchored
                anchoredTransitionChangeTimeout.clear()
                $(c.node).addClass 'anchored'
            wasAnchored = isAnchored
            
            componentPositionChangedWhileDragging c
            
            if ok then { target: target } else null
            
        dropAt: (pt) ->
            $(c.node).removeClass 'dragging'
            
            if res: moveTo pt
                effects: []
                if c.type is Types.image and res.target.type.supportsImageReplacement
                    effects.push newSetImageEffect(res.target, c)
                else
                    effects.push newDropOnTargetEffect(c, res.target)
                for e in effects
                    e.apply()
                liveMover.commit()
                true
            else
                liveMover.rollback()
                false
            
        if c.node.parentNode
            c.node.parentNode.removeChild(c.node)
        activeScreen.rootComponent.node.appendChild(c.node)
        updateEffectiveSize c  # we might have just added a new component
        
        moveTo(options.startPt)
            
        { moveTo: moveTo, dropAt: dropAt }
        
    activateExistingComponentDragging: (c, startPt) ->
        dragger: null
        
        window.status = "Dragging a component."
        
        activateMode {
            mousemove: (e) ->
                pt: { x: e.pageX, y: e.pageY }
                if dragger is null
                    return if Math.abs(pt.x - startPt.x) <= 1 and Math.abs(pt.y - startPt.y) <= 1
                    beginUndoTransaction "movement of ${friendlyComponentName c}"
                    dragger: startDragging c, { startPt: startPt }
                dragger.moveTo pt
                
            mouseup: (e) ->
                if dragger isnt null
                    if dragger.dropAt { x: e.pageX, y: e.pageY }
                        componentsChanged()
                        activatePointingMode()
                    else
                        deleteComponent c
                activatePointingMode()
                
            hidesPalette: yes
        }
        
    activateNewComponentDragging: (startPt, c) ->
        beginUndoTransaction "creation of ${friendlyComponentName c}"
        cn: renderInteractiveComponentHeirarchy c
        
        dragger: startDragging c, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }
        
        window.status = "Dragging a new component."
        
        activateMode {
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                ok: dragger.dropAt { x: e.pageX, y: e.pageY }
                if ok
                    componentsChanged()
                    activatePointingMode()
                else
                    $(c.node).fadeOut 250, ->
                        $(c.node).remove()
                    activatePointingMode()
            
            hidesPalette: yes
        }
    
    $('#design-pane').bind {
        mousedown: (e) ->
            return if e.button != 0
            if mode.mousedown e, findComponentOfNode(e.target)
                e.preventDefault()

        mousemove: (e) ->
            if mode.mousemove e, findComponentOfNode(e.target)
                e.preventDefault()
            
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
                
        mouseup: (e) ->
            if mode.mouseup e, findComponentOfNode(e.target)
                e.preventDefault()
    }

    ##########################################################################################################
    #  palette
    
    paletteWanted: on
    customImagesPaletteCategory: { name: 'Custom Images (drop your image files here)', items: [] }
    customImagesPaletteGroup: null
    customImages: []
    # { id, width, height, fileName }

    bindPaletteItem: (item, compTemplate) ->
        $(item).mousedown (e) ->
            if e.which is 1
                e.preventDefault()
                c: cloneTemplateComponent compTemplate
                activateNewComponentDragging { x: e.pageX, y: e.pageY }, c
            
    renderPaletteGroupContent: (ctg, group, func) ->
        $('<div />').addClass('header').html(ctg.name).appendTo(group)
        items: $('<div />').addClass('items').appendTo(group)
        func ||= ((ct, n) ->)
        for compTemplate in ctg.items
            c: cloneTemplateComponent compTemplate
            n: renderStaticComponentHierarchy c
            $(n).attr('title', compTemplate.label || c.type.label)
            $(n).addClass('item').appendTo(items)
            bindPaletteItem n, compTemplate
            func compTemplate, n

    renderPaletteGroup: (ctg) ->
        group: $('<div />').addClass('group').appendTo($('#palette-container'))
        renderPaletteGroupContent ctg, group
        group
    
    fillPalette: ->
        for grp in MakeApp.stockImageGroups
            items: for fileData in MakeApp.imageDirectories[grp.path]
                path: "${STOCK_DIR}${grp.path}/${encodeURIComponent fileData.f}"
                {
                    type: 'image'
                    label: fileData.f.replace(/\.png$/, '')
                    image: path
                    size: { width: 30, height: 30 }
                    style: {
                        imageEffect: grp.imageEffect
                    }
                }
            MakeApp.paletteDefinition.push { name: grp.label, items: items }
        
        for ctg in MakeApp.paletteDefinition
            renderPaletteGroup ctg
            
        customImagesPaletteGroup: renderPaletteGroup customImagesPaletteCategory
        
    updateCustomImagesPalette: ->
        $(customImagesPaletteGroup).find("*").remove()
        customImagesPaletteCategory.items: for image in customImages
            {
                type: 'image'
                label: "${image.fileName} ${image.width}x${image.height}"
                image: "images/${encodeURIComponent image.id}"
                size: { width: image.width, height: image.height }
                imageEl: image
            }
        renderPaletteGroupContent customImagesPaletteCategory, customImagesPaletteGroup, (item, node) ->
            item.imageEl.node: node
            $(node).bindContextMenu '#custom-image-context-menu', item.imageEl
                    
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
        # resizePalette()
        
    
    ##########################################################################################################
    #  screens/applications
    
    renderScreenComponents: (screen, node) ->
        cn: renderStaticComponentHierarchy screen.rootComponent
        renderComponentPosition screen.rootComponent, cn
        $(node).append(cn)
    
    renderScreen: (screen) ->
        sn: domTemplate 'app-screen-template'
        $(sn).setdata('makeapp.screen', screen).attr('id', "app-screen-${screen.sid}")
        rerenderScreenContent screen, sn
        return sn
    
    rerenderScreenContent: (screen, sn) ->
        $(screen).find('.component').remove()
        $('.caption', sn).html "Screen ${screen.userIndex}"
        renderScreenComponents screen, $('.content .rendered', sn)
        
    bindScreen: (screen, sn) ->
        $(sn).bindContextMenu '#screen-context-menu', screen
        $(sn).click (e) ->
            if e.which is 1
                switchToScreen screen
                false
        
    updateScreenList: ->
        $('#screens-list > .app-screen').remove()
        _(application.screens).each (screen, index) ->
            screen.userIndex: index + 1
            screen.sid: screen.userIndex # TEMP FIXME
            appendRenderedScreenFor screen

    addScreenWithoutTransaction: ->
        application.screens.push screen: internalizeScreen {
            rootComponent: DEFAULT_ROOT_COMPONENT
        }
        screen.userIndex: application.screens.length
        screen.sid: screen.userIndex # TEMP FIXME
        appendRenderedScreenFor screen
        switchToScreen screen

    addScreen: ->
        beginUndoTransaction "creation of a new screen"
        addScreenWithoutTransaction()
        endUndoTransaction()

    deleteScreen: (screen) ->
        pos: application.screens.indexOf(screen)
        return if pos < 0

        beginUndoTransaction "deletion of a screen"
        application.screens.splice(pos, 1)
        $(screen.node).fadeOut(250)
        if application.screens.length is 0
            addScreenWithoutTransaction()
        else
            switchToScreen(application.screens[pos] || application.screens[pos-1])
        endUndoTransaction()

    duplicateScreen: (oldScreen) ->
        pos: application.screens.indexOf(oldScreen)
        return if pos < 0

        beginUndoTransaction "duplication of a screen"
        application.screens.splice pos+1, 0, screen: internalizeScreen externalizeScreen oldScreen
        screen.userIndex: application.screens.length
        screen.sid: screen.userIndex # TEMP FIXME
        appendRenderedScreenFor screen, oldScreen.node
        switchToScreen screen
        endUndoTransaction()
            
    appendRenderedScreenFor: (screen, after) ->
        sn: screen.node: renderScreen screen
        if after
            $(after).after(sn)
        else
            $('#screens-list').append(sn)
        bindScreen screen, sn
        
    updateScreenPreview: (screen) ->
        rerenderScreenContent screen, screen.node
            
    setActiveScreen: (screen) ->
        $('#screens-list > .app-screen').removeClass('active')
        $("#app-screen-${screen.sid}}").addClass('active')
        
    switchToScreen: (screen) ->
        setActiveScreen screen
        
        $('#design-area .component').remove()
            
        activeScreen = screen
        activeScreen.nextId ||= 1
        
        $('#design-area').append renderInteractiveComponentHeirarchy activeScreen.rootComponent
        traverse activeScreen.rootComponent, (c) -> updateEffectiveSize c
        
        devicePanel: $('#device-panel')[0]
        allowedArea: {
            x: 0
            y: 0
            w: 320
            h: 480
        }
        
        componentsChanged()
        
    $('#add-screen-button').click ->
        addScreen()
        false
        
    
    loadApplication: (app, appId) ->
        app.name = createNewApplicationName() unless app.name
        application = app
        applicationId = appId
        $('#app-name').html(app.name)
        updateScreenList()
        switchToScreen application.screens[0]
        
    saveApplicationChanges: ->
        serverMode.saveApplicationChanges()
        
    ##########################################################################################################

    updateSharePopover: ->
        s: JSON.stringify(externalizeApplication(application))
        $('#share-popover textarea').val(s)
        
    $('#share-button').click ->
        if paletteWanted
            paletteWanted = no
            updatePaletteVisibility 'wanted'
        
        if $('#share-popover').is(':visible')
            $('#share-popover').hidePopOver()
        else
            $('#share-popover').showPopOverPointingTo $('#share-button')
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
    
    for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
        $('#share-popover textarea').bind event, checkApplicationLoading

    ##########################################################################################################
    # inspector
    
    $('.tab').click ->
        $('.tab').removeClass 'active'
        $(this).addClass 'active'
        $('.pane').removeClass 'active'
        $('#' + this.id.replace('-tab', '-pane')).addClass 'active'
        false
    $('#insp-backgrounds-tab').trigger 'click'

    fillInspector: ->
        fillBackgroundsInspector()
    
    updateInspector: ->
        updateBackgroundsInspector()
        updatePositionInspector()
        updateTextInspector()

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
            
    updateTextInspector: ->
        pixelSize: null
        textStyleEditable: no
        bold: no
        italic: no
        if c: componentToActUpon()
            tn: textNodeOfComponent c
            if tn
                cs: getComputedStyle(tn, null)
                pixelSize: parseInt cs.fontSize
                bold: cs.fontWeight is 'bold'
                italic: cs.fontStyle is 'italic'
            textStyleEditable: c.type.textStyleEditable
        $('#pixel-size-label').html(if pixelSize then "${pixelSize} px" else "")
        $('#insp-text-pane li')[if textStyleEditable then 'removeClass' else 'addClass']('disabled')
        $('#text-bold')[if bold then 'addClass' else 'removeClass']('active')
        $('#text-italic')[if italic then 'addClass' else 'removeClass']('active')
        
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
    #  Image Upload
    
    uploadImageFile: (file) ->
        console.log "Uploading ${file.fileName} of size ${file.fileSize}"
        $.ajax {
            type: 'POST'
            url: '/images/'
            data: file
            processData: no
            beforeSend: (xhr) -> xhr.setRequestHeader("X-File-Name", file.fileName)
            contentType: 'application/octet-stream'
            dataType: 'json'
            success: (r) ->
                if r.error
                    switch r.error
                        when 'signed-out'
                            alert "Cannot save your changes because you were logged out. Please sign in again."
                        else
                            alert "Other error: ${r.error}"
                else
                    updateCustomImages()
            error: (xhr, status, e) ->
                alert "Failed to save the image: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }
    
    updateCustomImages: ->
        $.ajax {
            type: 'GET'
            url: '/images/'
            dataType: 'json'
            success: (r) ->
                if r.error
                    switch r.error
                        when 'signed-out'
                            alert "Cannot save your changes because you were logged out. Please sign in again."
                        else
                            alert "Other error: ${r.error}"
                else
                    customImages: r.images
                    updateCustomImagesPalette()
            error: (xhr, status, e) ->
                alert "Failed to retrieve a list of images: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }
    
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
            console.log "drop"
            e.preventDefault()
            for file in e.dataTransfer.files
                uploadImageFile file

    deleteCustomImage: (image) ->
        $.ajax {
            type: 'DELETE'
            url: "/images/${encodeURIComponent image.id}"
            dataType: 'json'
            success: (r) ->
                if r.error
                    switch r.error
                        when 'signed-out'
                            alert "Cannot save your changes because you were logged out. Please sign in again."
                        else
                            alert "Other error: ${r.error}"
                else
                    $(image.node).fadeOut(250)
            error: (xhr, status, e) ->
                alert "Failed to delete an image: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }
        

    ##########################################################################################################
    #  keyboard shortcuts

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
            moveComponent comp, ptMul(movement.offset, amount)

    hookKeyboardShortcuts: ->
        $('body').keydown (e) ->
            return if componentBeingDoubleClickEdited isnt null
            act: componentToActUpon()
            switch e.which
                when $.KEY_ESC then deselectComponent(); false
                when $.KEY_DELETE then deleteComponent(act) if act
                when $.KEY_ARROWUP    then moveComponentByKeyboard act, e, KB_MOVE_DIRS.up    if act
                when $.KEY_ARROWDOWN  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.down  if act
                when $.KEY_ARROWLEFT  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.left  if act
                when $.KEY_ARROWRIGHT then moveComponentByKeyboard act, e, KB_MOVE_DIRS.right if act
                when 'D'.charCodeAt(0) then duplicateComponent(act) if act and (e.ctrlKey or e.metaKey)

        
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

    initComponentTypes()
    initPalette()
    updateCustomImages()
    hookKeyboardShortcuts()
    
    createNewApplicationName: ->
        adjs = ['Best-Selling', 'Great', 'Incredible', 'Stunning', 'Gorgeous', 'Wonderful',
            'Amazing', 'Awesome', 'Fantastic', 'Beautiful', 'Unbelievable', 'Remarkable']
        i = Math.floor(Math.random() * adjs.length)
        return "My ${adjs[i]} App"
        
    createNewApplication: ->
        loadApplication internalizeApplication(MakeApp.appTemplates.basic), null
        switchToDesign()
        
    bindApplication: (app, an) ->
        app.node: an
        $(an).bindContextMenu '#application-context-menu', app
        $(an).click ->
            loadApplication app.content, app.id
            switchToDesign()

    deleteApplication: (app) ->
        $.ajax {
            type: 'DELETE'
            url: "/apps/${encodeURIComponent app.id}/"
            dataType: 'json'
            success: (r) ->
                if r.error
                    switch r.error
                        when 'signed-out'
                            alert "Cannot save your changes because you were logged out. Please sign in again."
                        else
                            alert "Other error: ${r.error}"
                else
                    $(app.node).fadeOut(250)
            error: (xhr, status, e) ->
                alert "Failed to delete an application: ${status} - ${e}"
                # TODO ERROR HANDLING!
        }
        
    refreshApplicationList: ->
        serverMode.loadApplications (apps) ->
            applicationList = apps
            $('#apps-list .app').remove()
            for appData in apps
                appId: appData.id
                app: JSON.parse(appData.body)
                app: internalizeApplication(app)
                an: domTemplate('app-template')
                $('.caption', $(an)).html(app.name)
                renderScreenComponents(app.screens[0], $('.content .rendered', an))
                $(an).appendTo('#apps-list')
                bindApplication { id: appId, content: app }, an
    
    switchToDesign: ->
        $(".screen").hide()
        $('#design-screen').show()
        activatePointingMode()
        adjustDeviceImagePosition()

    switchToDashboard: ->
        $(".screen").hide()
        $('#dashboard-screen').show()
        refreshApplicationList()
    
    $('#new-app-button').click -> createNewApplication()
        
    $('#dashboard-button').click ->
        switchToDashboard()
    
    loadDesigner: (userData) ->
        $("body").removeClass("anonymous-user authenticated-user").addClass("${userData.status}-user")
        serverMode = SERVER_MODES[userData.status]
        serverMode.adjustUI userData
        serverMode.startDesigner userData
        
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
        
    $(window).resize ->
        # resizePalette()
        adjustDeviceImagePosition()
    
    if window.location.href.match /^file:/
        loadDesigner { status: 'local' }
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
    window.mad: ->
        console.log(activeScreen)
