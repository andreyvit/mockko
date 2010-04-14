
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
    components: {}
    cnodes: {}
    ctypes: {}
    mode: null
    allowedArea: null
    doubleClickEditingCid: null
    
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
                callback { apps: [ { id: 42, body: sample1 } ] }
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
        activeScreen.components = (c for cid, c of components)
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
    
    addToComponents: (c) -> c.id ||= "c${activeScreen.nextId++}"; components[c.id] = c
    storeComponentNode: (c, cn) ->
        $(cn).setdata('moa-cid', c.id); cnodes[c.id] = cn
        $(cn).dblclick -> startDoubleClickEditing c, cn
    
    deleteComponent: (rootcid) ->
        beginUndoTransaction "deletion of ${friendlyComponentName components[rootcid]}"
        cids = findDescendants rootcid
        cids.push rootcid
        
        for cid in cids
            cn: cnodes[cid]
            delete cnodes[cid]
            delete components[cid]
            $(cn).hide 'drop', { direction: 'down' }, 'normal', -> $(cn).remove()
        componentsChanged()
            
    findDescendants: (contid) ->
        contr: rectOfCID contid
        cid for cid, c of components when cid != contid && isRectInsideRect(rectOfCID(cid), contr)
        
    findParent: (cid) ->
        # a parent is a covering component of minimal area
        r: rectOfCID cid
        _(pcid for pcid in components when pcid != cid && isRectInsideRect(r, rectOfCID(pcid))).min (pcid) -> r: rectOfCID(pcid); r.w*r.h
        
    findIdealContainerForRect: (r, excluded) ->
        cids: _.reject _.keys(components), (cid) -> _.include(excluded, cid)
        # find container with maximum area of overlap
        bestcid: _(cids).max (cid) -> areaOfIntersection(r, rectOfCID(cid))
        if bestcid and areaOfIntersection(r, rectOfCID(bestcid)) > 0 then bestcid else null

    ##########################################################################################################
    #  DOM rendering
    
    createNodeForComponent: (c) ->
        ct: ctypes[c.type]
        $("<div />").addClass("component c-${c.type} c-${c.type}-${c.styleName}").addClass(if ct.container then 'container' else 'leaf')[0]
    
    findCidOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-cid')
    
    computeComponentSize: (c, cn) ->
        ct: ctypes[c.type]
        {
            width: c.size.width || ct.widthPolicy?.fixedSize?.width || cn?.offsetWidth || null
            height: c.size.height || ct.heightPolicy?.fixedSize?.height || cn?.offsetHeight || null
        }
        
    updateComponentPosition: (c, cn) ->
        ct: ctypes[c.type]
        location: c.dragpos || c.location
        
        $(cn).css({
            left:   "${location.x}px"
            top:    "${location.y}px"
        })
    
    updateZIndexes: ->
        ordered: _(_.keys components).sortBy (cid) -> r: rectOfCID cid; -r.w * r.h
        _.each ordered, (cid, i) -> $(cnodes[cid]).css('z-index', i)

    updateComponentText: (c, cn) -> $(cn).html(c.text) if c.text?
    
    updateComponentVisualProperties: (c, cn) -> updateComponentText(c, cn); updateEffectiveSize(c, cn)
    
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
        
    updateEffectiveSize: (c, cn) ->
        recomputeEffectiveSize c
        $(cn).css({ width: sizeToPx(c.effsize.w), height: sizeToPx(c.effsize.h) })
        if c.effsize.w is null then c.effsize.w = cn.offsetWidth
        if c.effsize.h is null then c.effsize.h = cn.offsetHeight


    ##########################################################################################################
    #  stacking
    
    TABLE_TYPES = { 'plain-row': yes, 'plain-header': yes, 'grouped-row': yes }
    
    findNearbyStack: (typeName, r, draggedCIDs) ->
        return null unless typeName in TABLE_TYPES
        
        stack: { above: [], below: [], moveBy: INF }
        draggedCIDs: stringSetWith draggedCIDs
        for cid, c of components
            if not (cid in draggedCIDs)
                if c.type in TABLE_TYPES
                    sr: rectOfC c
                    proximity: proximityOfRectToRect r, sr
                    if proximity < 20*20
                        if sr.y < r.y
                            stack.above.push { cid: cid, proximity: proximity }
                        else
                            if proximity <= 0
                                stack.moveBy: Math.min(stack.moveBy, r.y+r.h-sr.y)
                            stack.below.push { cid: cid, proximity: proximity }
        if stack.moveBy is INF then stack.moveBy: 0
        return stack
    


    ##########################################################################################################
    #  hover panel
    
    hoveredCid: null
    
    updateHoverPanelPosition: ->
        return if hoveredCid is null
        cn: cnodes[hoveredCid]
        offset: { left: cn.offsetLeft, top: cn.offsetTop }
        $('#hover-panel').css({ left: offset.left, top: offset.top })
    
    componentHovered: (cid) ->
        return unless cnodes[cid]?  # the component is being deleted right now
        return if hoveredCid is cid
        
        ct: ctypes[components[cid].type]
        if ct.container
            $('#hover-panel').addClass('container').removeClass('leaf')
        else
            $('#hover-panel').removeClass('container').addClass('leaf')
        $('#hover-panel').fadeIn(100) if hoveredCid is null
        hoveredCid = cid
        updateHoverPanelPosition()
        
    componentUnhovered: ->
        return if hoveredCid is null
        hoveredCid = null
        $('#hover-panel').hide()
        
    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click ->
        if hoveredCid isnt null
            $('#hover-panel').hide()
            deleteComponent hoveredCid 
            hoveredCid = null
    
        
    # pauseHoverPanel: -> $('#hover-panel').fadeOut(100) if hoveredCid isnt null
    # resumeHoverPanel: -> updateHoverPanelPosition $('#hover-panel').fadeIn(100) if hoveredCid isnt null
    

    ##########################################################################################################
    #  double-click editing
    
    startDoubleClickEditing: (c, cn) ->
        activatePointingMode()
        
        ct: ctypes[c.type]
        return unless ct.defaultText?
        
        doubleClickEditingCid = c.id
        $(cn).addClass 'editing'
        cn.contentEditable = true
        cn.focus()
        
        originalText: c.text
        
        $(cn).blur -> finishDoubleClickEditing()
        $(cn).keydown (e) ->
            if e.keyCode == 13 then finishDoubleClickEditing(); false
            if e.keyCode == 27 then finishDoubleClickEditing(originalText); false
        
        baseMode = mode
        mode: $.extend({}, baseMode, {
            mousedown: (e, cid) ->
                return false if cid is doubleClickEditingCid
                finishDoubleClickEditing()
                baseMode.mousedown e, cid
        })
        
    finishDoubleClickEditing: (overrideText) ->
        return if doubleClickEditingCid is null
        
        c:  components[doubleClickEditingCid]
        cn: cnodes[doubleClickEditingCid]

        beginUndoTransaction "text change in ${friendlyComponentName c}"
        
        $(cn).removeClass 'editing'
        cn.contentEditable = false
        
        $(cn).unbind 'blur'
        $(cn).unbind 'keydown'
        
        c.text = overrideText || $(cn).text()
        updateComponentProperties c, cn
        componentsChanged()
        
        doubleClickEditingCid = null
        activatePointingMode()
    
    
    ##########################################################################################################
    #  dragging
    
    rectOfC: (c) -> { x: c.location.x, y: c.location.y, w: c.effsize.w, h: c.effsize.h }
    rectOfCID: (cid) -> rectOfC components[cid]
    
    computeSnappingPositionsOfComponent: (cid) ->
        r: rectOfCID cid
        _.compact [
            { orient: 'vert', type: 'edge', cid: cid, coord: r.x } if r.x > allowedArea.x
            { orient: 'vert', type: 'edge', cid: cid, coord: r.x + r.w } if r.x+r.w < allowedArea.x+allowedArea.w
            { orient: 'vert', type: 'center', cid: cid, coord: r.x + r.w / 2 }
            { orient: 'horz', type: 'edge', cid: cid, coord: r.y } if r.y > allowedArea.y
            { orient: 'horz', type: 'edge', cid: cid, coord: r.y + r.h } if r.y+r.h < allowedArea.y+allowedArea.h
            { orient: 'horz', type: 'center', cid: cid, coord: r.y + r.h / 2 }
        ]
        
    computeChildrenSnappingPositionsOfContainer: (cid) -> computeSnappingPositionsOfComponent cid
        
    computeAllSnappingPositions: (pcid) ->
        cids: if pcid is null then _.keys(components) else findDescendants(pcid)
        r: _.flatten(computeSnappingPositionsOfComponent cid for cid in cids)
        if pcid is null then r else r.concat computeChildrenSnappingPositionsOfContainer pcid
        
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
            mousedown: (e, cid) ->
                if cid
                    activateExistingComponentDragging cid, { x: e.pageX, y: e.pageY }
                    true

            mousemove: (e, cid) ->
                if cid
                    componentHovered cid
                else if $(e.target).closest('.hover-panel').length
                    #
                else
                    componentUnhovered()
                    
            mouseup: (e) -> #
            
            hidesPalette: no
        }
        
    newLiveMover: () ->
        {
            moveComponents: (cids, amount) ->
                cids: _.flatten([rcid].concat(findDescendants(rcid)) for rcid in cids)
                cidSet: stringSetWith cids
                for cid, c of components
                    if c.dragpos and not (cid in cidSet)
                        c.dragpos = null
                        $(cnodes[cid]).removeClass 'stacked'
                        updateComponentPosition c, cnodes[cid]
                
                for cid in cids
                    $(cnodes[cid]).addClass 'stacked'
                    c: components[cid]
                    c.dragpos = { x: c.location.x + amount.x; y: c.location.y + amount.y }
                    updateComponentPosition c, cnodes[cid]
                    
            finish: ->
                for cid, c of components
                    if c.dragpos
                        c.dragpos = null
                        $(cnodes[cid]).removeClass 'stacked'
                        updateComponentPosition c, cnodes[cid]
        }
    
    startDragging: (c, cn, options) ->
        origin: $('#design-pane').offset()
        
        if c.id
            descendantIds: findDescendants c.id
            console.log descendantIds
            originalR: rectOfC c
            originalDescendantsRs: {}
            for dcid in descendantIds
                originalDescendantsRs[dcid] = rectOfCID dcid
            allDraggedIds: [c.id].concat(descendantIds)
        else
            allDraggedIds: []
        
        computeHotSpot: (pt) ->
            r: rectOfC c
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        liveMover: newLiveMover()
        
        $(cn).addClass 'dragging'
        
        updateRectangleAndClipToArea: (pt) ->
            r: rectOfC c
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
            setTransitions cn, "-webkit-transform 0.25s linear"
            $(cn)[if ok then 'removeClass' else 'addClass']('cannot-drop')

            if ok
                stack: findNearbyStack(c.type, r, allDraggedIds) || { below: [] }
                liveMover.moveComponents _(stack.below).pluck('cid'), { x: 0, y: stack.moveBy }
                    
                targetcid: findIdealContainerForRect(r, allDraggedIds)
                
                if stack.below.length > 0
                    aps: []
                else
                    aps: _(computeAllSnappingPositions(targetcid)).reject (a) -> _.include(allDraggedIds, a.cid)
                aa: _.flatten(computeSnappings(ap, r) for ap in aps)

                best: {
                    horz: _(a for a in aa when a.orient is 'horz').min((a) -> a.dist)
                    vert: _(a for a in aa when a.orient is 'vert').min((a) -> a.dist)
                }
                
                console.log "(${r.x}, ${r.y}, w ${r.w}, h ${r.h}), targetcid ${targetcid}, best snapping horz: ${best.horz?.dist} at ${best.horz?.coord}, vert: ${best.vert?.dist} at ${best.vert?.coord}"

                if best.horz and best.horz.dist > CONF_SNAPPING_DISTANCE then best.horz = null
                if best.vert and best.vert.dist > CONF_SNAPPING_DISTANCE then best.vert = null

                applySnapping best.vert, r if best.vert
                applySnapping best.horz, r if best.horz
            
            c.dragpos = { x: r.x, y: r.y }
            
            if descendantIds
                for dcid in descendantIds
                    delta: { x: r.x - originalR.x, y: r.y - originalR.y }
                    components[dcid].dragpos = {
                        x: originalDescendantsRs[dcid].x + delta.x
                        y: originalDescendantsRs[dcid].y + delta.y
                    }
                    console.log "moved ${c.id}, updated descendant ${dcid} delta x ${delta.x}, y ${delta.y}"
                    updateComponentPosition components[dcid], cnodes[dcid]
            
            updateComponentPosition c, cn
            updateHoverPanelPosition()
            return ok
            
        dropAt: (pt) ->
            $(cn).removeClass 'dragging'
            
            liveMover.finish()

            if moveTo pt
                c.location = c.dragpos
                c.dragpos = null
                if descendantIds
                    for dcid in descendantIds
                        components[dcid].location = components[dcid].dragpos
                        components[dcid].dragpos = null
                true
            else
                false
            
        moveTo(options.startPt)
            
        { moveTo: moveTo, dropAt: dropAt }
        
    activateExistingComponentDragging: (cid, startPt) ->
        beginUndoTransaction "movement of ${friendlyComponentName components[cid]}"
        c: components[cid]
        cn: cnodes[cid]
        
        originalLocation: c.location
        dragger: startDragging c, cn, { startPt: startPt }
        
        window.status = "Dragging a component."
        
        activateMode {
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                if dragger.dropAt { x: e.pageX, y: e.pageY }
                    componentsChanged()
                    activatePointingMode()
                else
                    deleteComponent cid
                    activatePointingMode()
                
            hidesPalette: yes
        }
        
    activateNewComponentDragging: (startPt, c) ->
        beginUndoTransaction "creation of ${friendlyComponentName c}"
        cn: createNodeForComponent c
        $('#design-pane').append cn
        
        updateComponentProperties c, cn
        dragger: startDragging c, cn, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }
        
        window.status = "Dragging a new component."
        
        activateMode {
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                ok: dragger.dropAt { x: e.pageX, y: e.pageY }
                if ok
                    addToComponents c
                    storeComponentNode c, cn
                    updateComponentProperties c, cn
                    componentsChanged()
                    activatePointingMode()
                else
                    $(cn).fadeOut 250, ->
                        $(cn).remove()
                    activatePointingMode()
            
            hidesPalette: yes
        }
    
    $('#design-pane').bind {
        mousedown: (e) ->
            if mode.mousedown e, findCidOfNode(e.target)
                e.preventDefault()

        mousemove: (e) ->
            if mode.mousemove e, findCidOfNode(e.target)
                e.preventDefault()
            
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
                
        mouseup: (e) ->
            if mode.mouseup e, findCidOfNode(e.target)
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
            c.location.x -= 47
            c.location.y -= 139
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
        
        $(cn).remove() for cid, cn of cnodes
            
        activeScreen = screen
        activeScreen.nextId ||= 1
        components = {}
        for c in activeScreen.components
            addToComponents c
            
        for cid, c of components
            $('#design-pane').append storeComponentNode(c, createNodeForComponent(c))
        
        updateComponentProperties(c, cnodes[cid]) for cid, c of components
        
        devicePanel: $('#device-panel')[0]
        allowedArea: {
            x: 47
            y: 139
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
                    location: { x: 47, y: 139 }
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
    
    sample0: {
        screens: [{
            components: [
                {
                    type: 'barButton',
                    text: 'Back',
                    location: { x: 50, y: 100 }
                    size: {}
                }
            ]
        }]
    }
    
    sample1: {"screens":[{"components":[{"type":"background","styleName":"striped","size":{"width":320,"height":480},"location":{"x":47,"y":139},"id":"root","effsize":{"w":320,"h":480}},{"type":"statusBar","size":{"width":320,"height":20},"location":{"x":47,"y":139},"id":"c13","effsize":{"w":320,"h":20}},{"type":"navBar","size":{"width":320,"height":44},"location":{"x":47,"y":159},"id":"c14","effsize":{"w":320,"h":44}},{"type":"text","styleName":"bar-title","size":{"width":null,"height":20},"location":{"x":159,"y":171},"text":"Some text","id":"c32","effsize":{"w":96,"h":20}},{"type":"backButton","styleName":"plain","size":{"width":null,"height":30},"location":{"x":56,"y":166},"text":"Back","id":"c33","effsize":{"w":62,"h":30}},{"type":"barButton","styleName":"normal","size":{"width":null,"height":30},"location":{"x":309,"y":166},"text":"Edit","id":"c38","effsize":{"w":46,"h":30}},{"type":"buyButton","styleName":"green","size":{"width":80,"height":25},"location":{"x":279,"y":256.5},"text":"BUY NOW","id":"c43","effsize":{"w":80,"h":25}},{"type":"buyButton","styleName":"blue","size":{"width":80,"height":25},"location":{"x":279,"y":212.5},"text":"$0.99","id":"c44","effsize":{"w":80,"h":25}},{"type":"plain-row","styleName":"white","size":{"width":320,"height":44},"location":{"x":47,"y":203},"id":"c45","effsize":{"w":320,"h":44}},{"type":"plain-row","styleName":"white","size":{"width":320,"height":44},"location":{"x":47,"y":247},"id":"c46","effsize":{"w":320,"h":44}},{"type":"coloredButton","styleName":"white","size":{"width":null,"height":44},"location":{"x":255,"y":519},"text":"Call","id":"c47","effsize":{"w":81,"h":44}},{"type":"coloredButton","styleName":"gray","size":{"width":null,"height":44},"location":{"x":60,"y":519},"text":"Delete Contact","id":"c48","effsize":{"w":184,"h":44}},{"type":"plain-row","styleName":"white","size":{"width":320,"height":44},"location":{"x":47,"y":291},"id":"c49","effsize":{"w":320,"h":44}},{"type":"buyButton","styleName":"blue","size":{"width":80,"height":25},"location":{"x":279,"y":300.5},"text":"$1.99","id":"c50","effsize":{"w":80,"h":25}},{"type":"plain-row","styleName":"dark","size":{"width":320,"height":44},"location":{"x":47,"y":335},"id":"c52","effsize":{"w":320,"h":44}},{"type":"plain-row","styleName":"dark","size":{"width":320,"height":44},"location":{"x":47,"y":379},"id":"c53","effsize":{"w":320,"h":44}},{"type":"plain-row","styleName":"metal","size":{"width":320,"height":44},"location":{"x":47,"y":423},"id":"c54","effsize":{"w":320,"h":44}},{"type":"plain-row","styleName":"metal","size":{"width":320,"height":44},"location":{"x":47,"y":467},"id":"c55","effsize":{"w":320,"h":44}},{"type":"tabBar","styleName":"plain","size":{"width":320,"height":49},"location":{"x":47,"y":571},"id":"c56","effsize":{"w":320,"h":49}},{"type":"text","styleName":"row-white","size":{"width":null,"height":20},"location":{"x":60,"y":300},"text":"Angry Birds","id":"c57","effsize":{"w":114,"h":20}},{"type":"text","styleName":"row-white","size":{"width":null,"height":20},"location":{"x":61,"y":217},"text":"iFart","id":"c58","effsize":{"w":44,"h":20}},{"type":"text","styleName":"row-white","size":{"width":null,"height":20},"location":{"x":59.99999999999999,"y":261},"text":"Make App","id":"c59","effsize":{"w":94,"h":20}},{"type":"text","styleName":"row-metal","size":{"width":null,"height":20},"location":{"x":58,"y":435},"text":"Novosibirsk","id":"c60","effsize":{"w":114,"h":20}},{"type":"text","styleName":"row-metal","size":{"width":null,"height":20},"location":{"x":58,"y":479},"text":"Cupertino","id":"c61","effsize":{"w":94,"h":20}},{"type":"text","styleName":"row-metal","size":{"width":null,"height":20},"location":{"x":276,"y":435},"text":"5:00 pm","id":"c62","effsize":{"w":76,"h":20}},{"type":"text","styleName":"row-metal","size":{"width":null,"height":20},"location":{"x":276,"y":479},"text":"4:00 am","id":"c63","effsize":{"w":75,"h":20}},{"type":"text","styleName":"row-dark","size":{"width":null,"height":20},"location":{"x":60,"y":347},"text":"Dark rows","id":"c64","effsize":{"w":97,"h":20}},{"type":"text","styleName":"row-dark","size":{"width":null,"height":20},"location":{"x":61,"y":391},"text":"are nice too","id":"c65","effsize":{"w":113,"h":20}}],"nextId":66,"userIndex":1,"sid":1},{"components":[{"id":"root","type":"background","styleName":"striped","location":{"x":47,"y":139},"size":{"width":320,"height":480},"effsize":{"w":320,"h":480},"dragpos":null},{"type":"coloredButton","styleName":"red","size":{"width":null,"height":null},"effsize":{"w":184,"h":44},"location":{"x":115,"y":357},"text":"Delete Contact","dragpos":null,"id":"c1"}],"userIndex":2,"sid":2,"nextId":2},{"components":[{"id":"root","type":"background","styleName":"striped","location":{"x":47,"y":139},"size":{"width":320,"height":480},"effsize":{"w":320,"h":480}}],"userIndex":3,"sid":3,"nextId":1}]}
    
    createNewApplicationName: ->
        adjs = ['Best-Selling', 'Great', 'Glorious', 'Stunning', 'Gorgeous']
        i = Math.floor(Math.random() * adjs.length)
        return "My ${adjs[i]} App"
        
    createNewApplication: ->
        loadApplication sample1, null
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
