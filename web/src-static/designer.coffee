
jQuery ($) ->

    CONF_SNAPPING_DISTANCE = 5
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100

    ##########################################################################################################
    #  constants
    
    applicationList: null
    serverMode: null
    applicationId: null
    application: null
    activeScreen: null
    components: []
    ctypes: {}
    mode: null
    allowedArea: null
    componentBeingDoubleClickEdited: null
    
    # our very own idea of infinity
    INF: 100000
    
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
                    data: JSON.stringify(application)
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
        
    createApplicationMemento: -> JSON.stringify(application)
    
    revertToMemento: (memento) -> loadApplication JSON.parse(memento), applicationId
    
    $('#undo-button').click -> undoLastChange(); false
    
    undoStackChanged()
    
    ##########################################################################################################
    #  global events
    
    componentsChanged: ->
        activeScreen.components = $.extend(true, {}, components)
        endUndoTransaction()
        
        if $('#share-popover').is(':visible')
            updateSharePopover()
            
        updateZIndexes()
    
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
    
    addToComponents: (c) -> c.id ||= "c${activeScreen.nextId++}"; components.push c
    storeComponentNode: (c, cn) ->
        $(cn).setdata('moa-comp', c)
        c.node = cn
        $(cn).dblclick -> startDoubleClickEditing c
    
    deleteComponent: (rootc) ->
        beginUndoTransaction "deletion of ${friendlyComponentName rootc}"
        comps = findDescendants rootc
        comps.push rootc
        
        for c in comps
            cn: c.node
            index: _(components).indexOf c
            if index >= 0
                components.splice index, 1
            $(cn).hide 'drop', { direction: 'down' }, 'normal', -> $(cn).remove()
        componentsChanged()
            
    findDescendants: (cont) ->
        contr: rectOf cont
        c for c in components when c isnt cont && isRectInsideRect(rectOf(c), contr)
        
    findParent: (c) ->
        # a parent is a covering component of minimal area
        r: rectOf c
        _(pc for pc in components when pc != c && isRectInsideRect(r, rectOf(pc))).min (pc) -> r: rectOf(pc); r.w*r.h
        
    findIdealContainerForRect: (r, excluded) ->
        comps: _.reject components, (c) -> _.include(excluded, c)
        # find container with maximum area of overlap
        bestc: _(comps).max (c) -> areaOfIntersection(r, rectOf(c))
        if bestc and areaOfIntersection(r, rectOf(bestc)) > 0 then bestc else null

    ##########################################################################################################
    #  DOM rendering
    
    createNodeForComponent: (c) ->
        ct: ctypes[c.type]
        $("<div />").addClass("component c-${c.type} c-${c.type}-${c.styleName}").addClass(if ct.container then 'container' else 'leaf')[0]
    
    findComponentOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-comp')
        
    updateComponentPosition: (c, cn) ->
        ct: ctypes[c.type]
        location: c.dragpos || c.location
        
        $(cn || c.node).css({
            left:   "${location.x}px"
            top:    "${location.y}px"
        })
    
    updateZIndexes: ->
        ordered: _(components).sortBy (c) -> r: rectOf c; -r.w * r.h
        _.each ordered, (c, i) -> $(c.node).css('z-index', i)

    updateComponentText: (cn) -> $(cn || c.node).html(c.text) if c.text?
    
    updateComponentVisualProperties: (c, cn) ->
        updateComponentText(c, cn)
        updateEffectiveSize(c) unless cn?
    
    updateComponentProperties: (c, cn) -> updateComponentPosition(c, cn); updateComponentVisualProperties(c, cn)
    
    setTransitions: (cn, trans) -> $(cn).css('-webkit-transition', trans)


    ##########################################################################################################
    #  sizing
    
    recomputeEffectiveSizeInDimension: (userSize, policy, fullSize) ->
        userSize || policy.fixedSize?.portrait || policy.fixedSize || switch policy.autoSize
            when 'fill'    then fullSize
            when 'browser' then null
        
    recomputeEffectiveSize: (c) ->
        ct: ctypes[c.type]
        c.effsize: {
            w: recomputeEffectiveSizeInDimension c.size.width, ct.widthPolicy, 320
            h: recomputeEffectiveSizeInDimension c.size.height, ct.heightPolicy, 460
        }
        
    sizeToPx: (v) ->
        if v then "${v}px" else 'auto'
        
    updateEffectiveSize: (c) ->
        recomputeEffectiveSize c
        $(c.node).css({ width: sizeToPx(c.effsize.w), height: sizeToPx(c.effsize.h) })
        if c.effsize.w is null then c.effsize.w = c.node.offsetWidth
        if c.effsize.h is null then c.effsize.h = c.node.offsetHeight


    ##########################################################################################################
    #  stacking
    
    TABLE_TYPES = { 'plain-row': yes, 'plain-header': yes, 'grouped-row': yes }
    
    findNearbyStack: (typeName, r, draggedComps) ->
        return null unless typeName in TABLE_TYPES
        
        stack: { above: [], below: [], moveBy: INF }
        draggedComponentSet: setOf draggedComps
        for c in components
            if not inSet c, draggedComponentSet
                if c.type in TABLE_TYPES
                    sr: rectOf c
                    proximity: proximityOfRectToRect r, sr
                    if proximity < 20*20
                        if sr.y < r.y
                            stack.above.push { c: c, proximity: proximity }
                        else
                            if proximity <= 0
                                stack.moveBy: Math.min(stack.moveBy, r.y+r.h-sr.y)
                            stack.below.push { c: c, proximity: proximity }
        if stack.moveBy is INF then stack.moveBy: 0
        return stack
    


    ##########################################################################################################
    #  hover panel
    
    hoveredComponent: null
    
    updateHoverPanelPosition: ->
        return if hoveredComponent is null
        cn: hoveredComponent.node
        offset: { left: cn.offsetLeft, top: cn.offsetTop }
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
        
    componentUnhovered: ->
        return if hoveredComponent is null
        hoveredComponent = null
        $('#hover-panel').hide()
        
    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click ->
        if hoveredComponent isnt null
            $('#hover-panel').hide()
            deleteComponent hoveredComponent 
            hoveredComponent = null
    
        
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
        
        $(c.node).blur -> finishDoubleClickEditing()
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
        updateComponentProperties c
        componentsChanged()
        
        componentBeingDoubleClickEdited = null
        activatePointingMode()
    
    
    ##########################################################################################################
    #  dragging
    
    rectOf: (c) -> { x: c.location.x, y: c.location.y, w: c.effsize.w, h: c.effsize.h }
    
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
        comps: if pc is null then components else findDescendants(pc)
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
        
    newLiveMover: () ->
        {
            moveComponents: (comps, amount) ->
                comps: _.flatten([rcomp].concat(findDescendants(rcomp)) for rcomp in comps)
                componentSet: setOf comps
                for c in components
                    if c.dragpos and not inSet c, componentSet
                        c.dragpos = null
                        $(c.node).removeClass 'stacked'
                        updateComponentPosition c, c.node
                
                for c in comps
                    $(c.node).addClass 'stacked'
                    c.dragpos = { x: c.location.x + amount.x; y: c.location.y + amount.y }
                    updateComponentPosition c, c.node
                    
            finish: ->
                for c in components
                    if c.dragpos
                        c.dragpos = null
                        $(c.node).removeClass 'stacked'
                        updateComponentPosition c, c.node
        }
    
    startDragging: (c, options) ->
        origin: $('#design-area').offset()
        
        if c.node
            descendants: findDescendants c
            originalR: rectOf c
            for dc in descendants
                dc.preDragRect = rectOf dc
            allDraggedComps: [c].concat(descendants)
        else
            allDraggedComps: []
        
        computeHotSpot: (pt) ->
            r: rectOf c
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        liveMover: newLiveMover()
        
        $(c.node).addClass 'dragging'
        
        updateRectangleAndClipToArea: (pt) ->
            r: rectOf c
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
            setTransitions c.node, "-webkit-transform 0.25s linear"
            $(c.node)[if ok then 'removeClass' else 'addClass']('cannot-drop')

            if ok
                stack: findNearbyStack(c.type, r, allDraggedComps) || { below: [] }
                liveMover.moveComponents stack.below, { x: 0, y: stack.moveBy }
                    
                target: findIdealContainerForRect(r, allDraggedComps)
                
                if stack.below.length > 0
                    aps: []
                else
                    aps: _(computeAllSnappingPositions(target)).reject (a) -> _.include(allDraggedComps, a)
                aa: _.flatten(computeSnappings(ap, r) for ap in aps)

                best: {
                    horz: _(a for a in aa when a.orient is 'horz').min((a) -> a.dist)
                    vert: _(a for a in aa when a.orient is 'vert').min((a) -> a.dist)
                }
                
                console.log "(${r.x}, ${r.y}, w ${r.w}, h ${r.h}), targetcid ${target.id}, best snapping horz: ${best.horz?.dist} at ${best.horz?.coord}, vert: ${best.vert?.dist} at ${best.vert?.coord}"

                if best.horz and best.horz.dist > CONF_SNAPPING_DISTANCE then best.horz = null
                if best.vert and best.vert.dist > CONF_SNAPPING_DISTANCE then best.vert = null

                applySnapping best.vert, r if best.vert
                applySnapping best.horz, r if best.horz
            
            c.dragpos = { x: r.x, y: r.y }
            
            if descendants
                for dc in descendants
                    delta: { x: r.x - originalR.x, y: r.y - originalR.y }
                    dc.dragpos = {
                        x: dc.preDragRect.x + delta.x
                        y: dc.preDragRect.y + delta.y
                    }
                    console.log "moved ${c.id}, updated descendant ${dc.id} delta x ${delta.x}, y ${delta.y}"
                    updateComponentPosition dc, dc.node
            
            updateComponentPosition c
            updateHoverPanelPosition()
            return ok
            
        dropAt: (pt) ->
            $(c.node).removeClass 'dragging'
            
            liveMover.finish()

            if moveTo pt
                c.location = c.dragpos
                c.dragpos = null
                if descendants
                    for dc in descendants
                        dc.location = dc.dragpos
                        dc.dragpos = null
                true
            else
                false
            
        moveTo(options.startPt)
            
        { moveTo: moveTo, dropAt: dropAt }
        
    activateExistingComponentDragging: (c, startPt) ->
        beginUndoTransaction "movement of ${friendlyComponentName c}"
        
        originalLocation: c.location
        dragger: startDragging c, { startPt: startPt }
        
        window.status = "Dragging a component."
        
        activateMode {
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
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
        cn: storeComponentNode c, createNodeForComponent(c)
        $('#design-area').append c.node
        
        updateComponentProperties c
        dragger: startDragging c, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }
        
        window.status = "Dragging a new component."
        
        activateMode {
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                ok: dragger.dropAt { x: e.pageX, y: e.pageY }
                if ok
                    addToComponents c
                    updateComponentProperties c
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
    
    createNewComponent: (ct, style) ->
        c: { type: ct.type, styleName: style.styleName }
        c.size: { width: null; height: null }
        c.effsize: { w: null; h: null }
        c.location: { x: 0, y: 0 }
        c.text = ct.defaultText if ct.defaultText?
        return c

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
                    n: createNodeForComponent c
                    switch ct.palettePresentation || 'as-is'
                        when 'tile'
                            c.size = { width: 70; height: 50 }
                            $(n).addClass('palette-tile')
                    $(n).attr('title', style.label)
                    updateComponentVisualProperties c, n
                    $(n).addClass('item').appendTo(items)
                    # item: $('<div />').addClass('item')
                    # $('<img />').attr('src', "../static/iphone/images/palette/button.png").appendTo(item)
                    # caption: $('<div />').addClass('caption').html(style.label).appendTo(item)
                    # group.append item
                    bindPaletteItem n, ct, style
                    
    updatePaletteVisibility: (reason) ->
        showing: $('.palette').is(':visible')
        desired: paletteWanted && !mode.hidesPalette
        if showing and not desired
            $('.palette').hidePopOver()
        else if desired and not showing
            anim: if reason is 'mode' then 'fadein' else 'popin'
            $('.palette').showPopOverPointingTo $('#add-button'), anim
            
    resizePalette: ->
        maxPopOverSize: $(window).height() - 44 - 20
        $('.palette').css 'height', Math.min(maxPopOverSize, 600)
        if $('.palette').is(':visible')
            $('.palette').repositionPopOver $('#add-button')
        
    $('#add-button').click -> paletteWanted = !paletteWanted; updatePaletteVisibility('wanted')
    
    initPalette: ->
        fillPalette()
        resizePalette()
        
    
    ##########################################################################################################
    #  screens/applications
    
    renderScreenComponents: (screen, node) ->
        for orig in screen.components
            c: $.extend(true, {}, orig)  # deep copy
            cn: createNodeForComponent c
            updateComponentProperties c, cn
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
        
        $(c.node).remove() for c in components when c.node != null
            
        activeScreen = screen
        activeScreen.nextId ||= 1
        components = {}
        for c in activeScreen.components
            addToComponents c
            
        for c in components
            $('#design-area').append storeComponentNode(c, createNodeForComponent(c))
        
        updateComponentProperties(c, c.node) for c in components
        
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
        application.screens.push screen: {
            components: [
                {
                    id:   'root',
                    type: 'background',
                    styleName: 'striped',
                    location: { x: 0, y: 0 }
                    size: { width: 320, height: 480 }
                }
            ]
        }
        screen.userIndex: application.screens.length
        screen.sid: screen.userIndex # TEMP FIXME
        appendRenderedScreenFor screen
        switchToScreen screen
        endUndoTransaction()
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
        s: JSON.stringify(application)
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
        s: JSON.stringify(application)
        
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
                an: domTemplate('app-template')
                $('.caption', $(an)).html(app.name)
                console.log(app)
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
