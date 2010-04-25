
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
    ctypes: {}
    mode: null
    allowedArea: null
    componentBeingDoubleClickEdited: null
    allStacks: null
    
    # our very own idea of infinity
    INF: 100000
    
    DEFAULT_ROOT_COMPONENT: {
        type: "background"
        styleName: "striped"
        size: { width: 320, height: 480 }
        location: { x: 0, y: 0 }
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
    
    externalizeComponent: (c) ->
        {
            type: c.type
            location: cloneObj c.location
            effsize: cloneObj c.effsize
            size: cloneObj c.size
            styleName: c.styleName
            text: c.text
            children: (externalizeComponent(child) for child in c.children || [])
        }
        
    internalizeComponent: (c) ->
        {
            type: c.type
            location: cloneObj c.location
            # we'll recompute the effective size anyway
            # effsize: cloneObj c.effsize
            size: cloneObj c.size
            styleName: c.styleName
            text: c.text
            children: (internalizeComponent(child) for child in c.children || [])
            inDocument: yes
        }
        
    externalizeScreen: (screen) ->
        {
            rootComponent: externalizeComponent(screen.rootComponent)
        }
        
    internalizeScreen: (screen) ->
        rootComponent: internalizeComponent(screen.rootComponent || DEFAULT_ROOT_COMPONENT)
        assignParentsToChildrenOf rootComponent
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
        ct: ctypes[c.type]
        label: (ct.genericLabel || ct.label).toLowerCase()
        if c.text then "the “${c.text}” ${label}" else aOrAn label
    
    beginUndoTransaction: (changeName) ->
        if lastChange isnt null
            console.log "Make-App Internal Warning: implicitly closing an unclosed undo change: ${lastChange.name}"
        lastChange: { memento: createApplicationMemento(), name: changeName }
        
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
    
    ##########################################################################################################
    #  component management
    
    assignNameIfStillUnnamed: (c, screen) -> c.id ||= "c${screen.nextId++}"
    
    storeAndBindComponentNode: (c, cn) ->
        c.node = cn
        $(cn).dblclick -> startDoubleClickEditing c; false
    
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
        
    assignParentsToChildrenOf: (c) -> traverse c.children, c, (child, parent) -> child.parent = parent
    
    createNewComponent: (ct, style) ->
        c: { type: ct.type, styleName: style.styleName }
        c.size: { width: null; height: null }
        c.effsize: { w: null; h: null }
        c.location: { x: 0, y: 0 }
        c.text = ct.defaultText if ct.defaultText?
        c.children = if ct.children then (internalizeComponent(child) for child in ct.children) else []
        traverse c, (comp) -> comp.inDocument: no
        c.parent: null
        assignParentsToChildrenOf c
        return c
    
    deleteComponent: (rootc) ->
        beginUndoTransaction "deletion of ${friendlyComponentName rootc}"

        stacking: handleStacking rootc, null, allStacks
        
        liveMover: newLiveMover [rootc]
        liveMover.moveComponents stacking.moves
        liveMover.commit(STACKED_COMP_TRANSITION_DURATION)

        _(rootc.parent.children).removeValue rootc
        $(rootc.node).hide 'drop', { direction: 'down' }, 'normal', -> $(rootc.node).remove()
        componentsChanged()

    duplicateComponent: (comp) ->
        beginUndoTransaction "duplicate ${friendlyComponentName comp}"

        rect: rectOf comp
        rect.y += rect.h
        stacking: handleStacking comp, rect, allStacks, 'duplicate'
        
        newComp: internalizeComponent(externalizeComponent(comp))
        newComp.id: null  # make sure it is reassigned
        newComp.parent: comp.parent
        
        
        if stacking.targetRect
            # part of stack, so add directly below
            liveMover: newLiveMover [comp]
            liveMover.moveComponents stacking.moves
            liveMover.commit(STACKED_COMP_TRANSITION_DURATION)
            
            newComp.location: {
                x: stacking.targetRect.x - newComp.parent.abspos.x
                y: stacking.targetRect.y - newComp.parent.abspos.y
            }
        else
            if comp.abspos.x + 2*comp.effsize.w + 5 + 5 <= 320
                newComp.location: {
                    x: comp.location.x + comp.effsize.w + 5
                    y: comp.location.y
                }
            else
                newComp.location: {
                    x: comp.location.x
                    y: comp.location.y + comp.effsize.h + 5
                }

        comp.parent.children.push newComp
        $(comp.parent.node).append renderInteractiveComponentHeirarchy newComp
        updateAbsolutePositions newComp
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
                area: areaOfIntersection r, rectOf comp
                if area > 0
                    bestHere: { comp: comp, area: area }
            else
                bestHere
        
        trav(activeScreen.rootComponent)?.comp || activeScreen.rootComponent

    ##########################################################################################################
    #  DOM rendering
    
    createNodeForComponent: (c) ->
        ct: ctypes[c.type]
        $(ct.html || "<div />").addClass("component c-${c.type} c-${c.type}-${c.styleName}").addClass(if ct.container then 'container' else 'leaf').setdata('moa-comp', c)[0]
        
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
        ct: ctypes[c.type]
        location: c.dragpos || c.location
        
        console.log "Move ${c.id} to (${location.x}, ${location.y})"
        $(cn || c.node).css({
            left:   "${location.x}px"
            top:    "${location.y}px"
        })
    
    reassignZIndexes: ->
        traverse activeScreen.rootComponent, (comp) ->
            ordered: _(comp.children).sortBy (c) -> r: rectOf c; -r.w * r.h
            _.each ordered, (c, i) -> $(c.node).css('z-index', i)

    renderComponentText: (c, cn) -> $(cn || c.node).html(c.text) if c.text?
    
    renderComponentVisualProperties: (c, cn) ->
        renderComponentText(c, cn)
        if cn?
            renderComponentSize c, cn
        else
            updateEffectiveSize c
    
    renderComponentProperties: (c, cn) -> renderComponentPosition(c, cn); renderComponentVisualProperties(c, cn)
    
    updateAbsolutePositions: (comp) ->
        trav: (c, parentPos) ->
            c.abspos: { x: c.location.x + parentPos.x, y: c.location.y + parentPos.y }
            for child in c.children
                trav child, c.abspos
        trav(comp, (if comp.parent then comp.parent.abspos else { x: 0, y: 0 }))
    
    componentPositionChangedWhileDragging: (c) ->
        renderComponentPosition c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()
    
    componentPositionChangedPernamently: (c) ->
        renderComponentPosition c
        updateAbsolutePositions c
        if c is hoveredComponent
            updateHoverPanelPosition()
            updatePositionInspector()


    ##########################################################################################################
    #  sizing
    
    recomputeEffectiveSizeInDimension: (userSize, policy, fullSize) ->
        userSize || policy.fixedSize?.portrait || policy.fixedSize || switch policy.autoSize
            when 'fill'    then fullSize
            when 'browser' then null
        
    sizeToPx: (v) ->
        if v then "${v}px" else 'auto'
        
    renderComponentSize: (c, cn) ->
        ct: ctypes[c.type]
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
    
    isContainer: (c) -> ctypes[c.type].container
    
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
                    groupName: ctypes[cur.type].group || 'default'
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
        peers: _(container.children).select (c) -> c.type in TABLE_TYPES
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
        return { moves: [] } unless comp.type in TABLE_TYPES
        
        sourceStack: if action == 'duplicate' then null else comp.stack
        targetStack: if rect? then _(stacks).find (s) -> proximityOfRectToRect(rect, s.rect) < 20 * 20 else null
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
        
        ct: ctypes[c.type]
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
        
    # pauseHoverPanel: -> $('#hover-panel').fadeOut(100) if hoveredComponent isnt null
    # resumeHoverPanel: -> updateHoverPanelPosition $('#hover-panel').fadeIn(100) if hoveredComponent isnt null
    

    ##########################################################################################################
    #  double-click editing
    
    startDoubleClickEditing: (c) ->
        activatePointingMode()
        
        ct: ctypes[c.type]
        return unless ct.defaultText?
        
        componentBeingDoubleClickEdited = c
        $(c.node).addClass 'editing'
        c.node.contentEditable = true
        c.node.focus()
        
        originalText: c.text
        
        $(c.node).blur -> finishDoubleClickEditing() if c is componentBeingDoubleClickEdited
        $(c.node).keydown (e) ->
            if e.keyCode == 13 then finishDoubleClickEditing(); false
            if e.keyCode == 27 then finishDoubleClickEditing(originalText); false
        
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

        beginUndoTransaction "text change in ${friendlyComponentName c}"
        
        $(c.node).removeClass 'editing'
        c.node.contentEditable = false
        
        $(c.node).unbind 'blur'
        $(c.node).unbind 'keydown'
        
        c.text = overrideText || $(c.node).text()
        renderComponentVisualProperties c
        componentsChanged()
        
        $(c.node).blur()
        componentBeingDoubleClickEdited = null
        activatePointingMode()
    
    
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
        updatePaletteVisibility('mode')
    
    activatePointingMode: ->
        window.status = "Hover a component for options. Click to edit. Drag to move."
        activateMode {
            mousedown: (e, c) ->
                if c
                    activateExistingComponentDragging c, { x: e.pageX, y: e.pageY }
                    true

            mousemove: (e, c) ->
                if c
                    componentHovered c
                else if $(e.target).closest('.hover-panel').length
                    #
                else
                    componentUnhovered()
                    
            mouseup: (e) -> #
            
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
                        c.dragpos = null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c
                
                for m in moves
                    for c in m.comps
                        $(c.node).addClass 'stacked'
                        c.dragpos = { x: c.location.x + m.offset.x; y: c.location.y + m.offset.y }
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
                        c.dragpos = null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c
                    
                traverse activeScreen.rootComponent, (c) ->
                    if not _.include excluded, c
                        $(c.node).removeClass 'stackable'
                traverse activeScreen.rootComponent, (c) ->
                    if c.dragpos
                        c.location = {
                            x: c.dragpos.x - c.parent.abspos.x
                            y: c.dragpos.y - c.parent.abspos.y
                        }
                        c.dragpos = null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedPernamently c
                    
            commit: (delay) ->
                traverse activeScreen.rootComponent, (c) ->
                    if c.dragpos
                        c.location = {
                            x: c.dragpos.x - c.parent.abspos.x
                            y: c.dragpos.y - c.parent.abspos.y
                        }
                        c.dragpos = null
                        componentPositionChangedPernamently c

                cleanup: -> $('.component').removeClass 'stackable'
                if delay? then setTimeout(cleanup, delay) else cleanup()
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
                target = activeScreen.rootComponent if c.type in TABLE_TYPES
                
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
                if c.parent != res.target
                    _(c.parent.children).removeValue c  if c.parent
                    c.parent = res.target
                    c.parent.children.push c

                if c.node.parentNode
                    c.node.parentNode.removeChild(c.node)
                c.parent.node.appendChild(c.node)
                    
                c.location = {
                    x: c.dragpos.x - c.parent.abspos.x
                    y: c.dragpos.y - c.parent.abspos.y
                }
                c.dragpos = null
                    
                c.inDocument = yes
                componentPositionChangedPernamently c

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
        beginUndoTransaction "movement of ${friendlyComponentName c}"
        
        originalLocation: c.location
        dragger: null
        
        window.status = "Dragging a component."
        
        activateMode {
            mousemove: (e) ->
                pt: { x: e.pageX, y: e.pageY }
                if dragger is null
                    return if Math.abs(pt.x - startPt.x) <= 1 and Math.abs(pt.y - startPt.y) <= 1
                    dragger: startDragging c, { startPt: startPt }
                dragger.moveTo pt
                
            mouseup: (e) ->
                if dragger is null
                    activatePointingMode()
                else if dragger.dropAt { x: e.pageX, y: e.pageY }
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
                    traverse c, (child) -> assignNameIfStillUnnamed child, activeScreen
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

    bindPaletteItem: (item, ct, style) ->
        $(item).mousedown (e) ->
            e.preventDefault()
            c: createNewComponent ct, style
            activateNewComponentDragging { x: e.pageX, y: e.pageY }, c
    
    fillPalette: ->
        $content: $('#palette-container')
        for ctg in MakeApp.paletteDefinition
            group: $('<div />').addClass('group').appendTo($content)
            $('<div />').addClass('header').html(ctg.name).appendTo(group)
            items: $('<div />').addClass('items').appendTo(group)
            for ct in ctg.ctypes
                styles: ct.styles || [{ styleName: 'plain', label: ct.label }]
                for style in styles
                    c: createNewComponent ct, style
                    switch ct.palettePresentation || 'as-is'
                        when 'tile' then c.size = { width: 70; height: 50 }
                        
                    n: renderStaticComponentHierarchy c
                    switch ct.palettePresentation || 'as-is'
                        when 'tile' then $(n).addClass('palette-tile')
                    $(n).attr('title', style.label)
                    $(n).addClass('item').appendTo(items)
                    # item: $('<div />').addClass('item')
                    # $('<img />').attr('src', "../static/iphone/images/palette/button.png").appendTo(item)
                    # caption: $('<div />').addClass('caption').html(style.label).appendTo(item)
                    # group.append item
                    bindPaletteItem n, ct, style
                    
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
        sn: domTemplate('app-screen-template')
        $('.caption', sn).html("Screen ${screen.userIndex}")
        $(sn).attr 'id', "app-screen-${screen.sid}"
        renderScreenComponents(screen, $('.content .rendered', sn))
        return sn
        
    bindScreen: (screen, sn) ->
        $(sn).click ->
            switchToScreen screen
            false
        
    updateScreenList: ->
        $('#screens-list > .app-screen').remove()
        _(application.screens).each (screen, index) ->
            screen.userIndex: index + 1
            screen.sid: screen.userIndex # TEMP FIXME
            appendRenderedScreenFor screen
            
    appendRenderedScreenFor: (screen) ->
        sn: renderScreen screen
        $('#screens-list').append(sn)
        bindScreen screen, sn
            
    setActiveScreen: (screen) ->
        $('#screens-list > .app-screen').removeClass('active')
        $("#app-screen-${screen.sid}}").addClass('active')
        
    switchToScreen: (screen) ->
        setActiveScreen screen
        
        $('#design-area .component').remove()
            
        activeScreen = screen
        activeScreen.nextId ||= 1
        
        $('#design-area').append renderInteractiveComponentHeirarchy activeScreen.rootComponent
        updateAbsolutePositions activeScreen.rootComponent
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
        beginUndoTransaction "creation of a new screen"
        application.screens.push screen: internalizeScreen {
            rootComponent: DEFAULT_ROOT_COMPONENT
        }
        screen.userIndex: application.screens.length
        screen.sid: screen.userIndex # TEMP FIXME
        appendRenderedScreenFor screen
        switchToScreen screen
        endUndoTransaction()
        false
        
    
    loadApplication: (app, appId) ->
        app = internalizeApplication(app)
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
            loadApplication app, applicationId if app
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
    $('#insp-position-tab').trigger 'click'
    
    updateInspector: ->
        updatePositionInspector()
        
    updatePositionInspector: ->
        if hoveredComponent is null
            $('#insp-rel-pos').html "&mdash;"
            $('#insp-abs-pos').html "&mdash;"
            $('#insp-size').html "&mdash;"
        else
            c: hoveredComponent
            abspos: c.dragpos || c.abspos
            relpos: { x: abspos.x - c.parent.abspos.x, y: abspos.y - c.parent.abspos.y } if c.parent?
            $('#insp-rel-pos').html(if c.parent? then "(${relpos.x}, ${relpos.y})" else "&mdash;")
            $('#insp-abs-pos').html "(${abspos.x}, ${abspos.y})"
            $('#insp-size').html "${c.effsize.w}x${c.effsize.h}"
            
    updateInspector()
        
        
    ##########################################################################################################
    
    initComponentTypes: ->
        for ctg in MakeApp.paletteDefinition
            for ct in ctg.ctypes
                ctypes[ct.type] = ct

    initComponentTypes()
    initPalette()
    
    createNewApplicationName: ->
        adjs = ['Best-Selling', 'Great', 'Glorious', 'Stunning', 'Gorgeous']
        i = Math.floor(Math.random() * adjs.length)
        return "My ${adjs[i]} App"
        
    createNewApplication: ->
        loadApplication MakeApp.appTemplates.basic, null
        switchToDesign()
        
    bindApplication: (app, appId, an) ->
        $(an).click ->
            loadApplication app, appId
            switchToDesign()
        
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
                bindApplication app, appId, an
    
    switchToDesign: ->
        $(".screen").hide()
        $('#design-screen').show()
        activatePointingMode()

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
        
    $(window).resize -> resizePalette()
    
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
