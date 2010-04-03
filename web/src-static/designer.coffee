
jQuery ($) ->

    CONF_SNAPPING_DISTANCE = 5
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100

    ##########################################################################################################
    #  constants
    
    application: null
    activeScreen: null
    components: {}
    cnodes: {}
    ctypes: {}
    mode: null
    allowedArea: null
    doubleClickEditingCid: null

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
        
    createApplicationMemento: -> JSON.stringify(application)
    
    revertToMemento: (memento) -> loadApplication JSON.parse(memento)
    
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
        $("<div />").addClass("component c-${c.type}").addClass(if ct.container then 'container' else 'leaf')[0]
    
    findCidOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-cid')
    
    computeComponentSize: (c, cn) ->
        ct: ctypes[c.type]
        {
            width: c.size.width || ct.widthPolicy?.fixedSize?.width || cn?.offsetWidth || null
            height: c.size.height || ct.heightPolicy?.fixedSize?.height || cn?.offsetHeight || null
        }
    
    updateComponentPosition: (c, cn) ->
        ct: ctypes[c.type]
        size: computeComponentSize(c, null)
        location: c.location
        
        $(cn).css({
            'left':   "${location.x}px"
            'top':    "${location.y}px"
            'width':  (if size.width then "${size.width}px" else 'auto')
            'height': "${size.height}px"
        })
        
        r: rectOfComponent cn
        
    updateZIndexes: ->
        ordered: _(_.keys components).sortBy (cid) -> r: rectOfComponent cnodes[cid]; -r.w * r.h
        _.each ordered, (cid, i) -> $(cnodes[cid]).css('z-index', i)

    updateComponentText: (c, cn) -> $(cn).html(c.text) if c.text?
    
    updateComponentProperties: (c, cn) -> updateComponentPosition(c, cn); updateComponentText(c, cn)
    
    setTransitions: (cn, trans) -> $(cn).css('-webkit-transition', trans)

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
            
    $('#hover-panel .move-handle').mousedown (e) ->
        e.preventDefault()
        e.stopPropagation()
        activateExistingComponentDragging hoveredCid, { x: e.pageX, y: e.pageY }
    
        
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
    
    rectOfComponent: (cn) ->
        { x: cn.offsetLeft, y: cn.offsetTop, w: cn.offsetWidth, h: cn.offsetHeight }
    rectOfCID: (cid) -> rectOfComponent cnodes[cid]
    
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
                    if not ctypes[components[cid].type].container
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
    
    startDragging: (c, cn, options) ->
        origin: $('#design-pane').offset()
        
        if c.id
            descendantIds: findDescendants c.id
            console.log descendantIds
            originalR: rectOfComponent cn
            originalDescendantsRs: {}
            for dcid in descendantIds
                originalDescendantsRs[dcid] = rectOfComponent cnodes[dcid]
            allDraggedIds: [c.id].concat(descendantIds)
        else
            allDraggedIds: []
        
        computeHotSpot: (pt) ->
            r: rectOfComponent cn
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        
        updateRectangleAndClipToArea: (pt) ->
            r: rectOfComponent cn
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
                targetcid: findIdealContainerForRect(r, allDraggedIds)
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
            
            c.location = { x: r.x, y: r.y }
            
            if descendantIds
                for dcid in descendantIds
                    delta: { x: r.x - originalR.x, y: r.y - originalR.y }
                    components[dcid].location = {
                        x: originalDescendantsRs[dcid].x + delta.x
                        y: originalDescendantsRs[dcid].y + delta.y
                    }
                    console.log "moved ${c.id}, updated descendant ${dcid} delta x ${delta.x}, y ${delta.y}"
                    updateComponentPosition components[dcid], cnodes[dcid]
            
            updateComponentPosition c, cn
            updateHoverPanelPosition()
            return ok
            
        dropAt: (pt) -> moveTo pt
            
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
                    setTransitions cn, "all 0.25s default"
                    c.location = originalLocation
                    updateComponentPosition c, cn
                    updateHoverPanelPosition()
                    $(cn).removeClass 'cannot-drop'
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
    
    computeInitialSize: (policy, fullSize) ->
        policy.fixedSize?.portrait || policy.fixedSize || (if policy.autoSize is 'fill' then fullSize)
    
    createNewComponent: (ct) ->
        c: { type: ct.type }
        c.size: {
            width:  computeInitialSize(ct.widthPolicy, 320)
            height: computeInitialSize(ct.heightPolicy, 460)
        }
        c.location: { x: 0, y: 0 }
        c.text = ct.defaultText if ct.defaultText?
        return c

    bindPaletteItem: (item, ct) ->
        item.mousedown (e) ->
            e.preventDefault()
            c: createNewComponent ct
            activateNewComponentDragging { x: e.pageX, y: e.pageY }, c
    
    fillPalette: ->
        $content: $('.palette .content')
        for ctg in MakeApp.paletteDefinition
            group: $('<div />').addClass('group').appendTo($content)
            $('<div />').addClass('header').html(ctg.name).appendTo(group)
            for ct in ctg.ctypes
                item: $('<div />').addClass('item')
                $('<img />').attr('src', "../static/iphone/images/palette/button.png").appendTo(item)
                caption: $('<div />').addClass('caption').html(ct.label).appendTo(item)
                group.append item
                bindPaletteItem item, ct
                    
    updatePaletteVisibility: (reason) ->
        showing: $('.palette').is(':visible')
        desired: paletteWanted && !mode.hidesPalette
        if showing and not desired
            $('.palette').hidePopOver()
        else if desired and not showing
            anim: if reason is 'mode' then 'fadein' else 'popin'
            $('.palette').showPopOverPointingTo $('#add-button'), anim
            
    $('#add-button').click -> paletteWanted = !paletteWanted; updatePaletteVisibility('wanted')
    
    ##########################################################################################################
    #  screens/applications
    
    switchToScreen: (screen) ->
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
        
    
    loadApplication: (app) ->
        application = app
        switchToScreen application.screens[0]
        
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
            loadApplication app if app
        $('#share-popover textarea').css('background-color', if good then 'white' else '#ffeeee')
    
    for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
        $('#share-popover textarea').bind event, checkApplicationLoading
        
    ##########################################################################################################
    
    initComponentTypes: ->
        for ctg in MakeApp.paletteDefinition
            for ct in ctg.ctypes
                ctypes[ct.type] = ct

    initComponentTypes()
    fillPalette()
    activatePointingMode()
    
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
    
    sample1: {"screens":[{"components":[{"type":"background","size":{"width":320,"height":480},"location":{"x":47,"y":139},"id":"root"},{"type":"statusBar","size":{"width":320,"height":20},"location":{"x":47,"y":139},"id":"c13"},{"type":"navBar","size":{"width":320,"height":44},"location":{"x":47,"y":159},"id":"c14"},{"type":"tabBar","size":{"width":320,"height":49},"location":{"x":47,"y":570},"id":"c15"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":268},"text":"Back","id":"c16"},{"type":"roundedButton","size":{"width":null,"height":44},"location":{"x":97,"y":493},"text":"Call","id":"c17"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":268},"id":"c18"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":312},"text":"Back","id":"c21"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":362},"text":"Back","id":"c22"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":412},"text":"Back","id":"c23"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":315},"id":"c24"},{"type":"coloredButton","size":{"width":null,"height":44},"location":{"x":212,"y":493},"text":"Delete Contact","id":"c25"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":365},"id":"c26"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":415},"id":"c27"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":54,"y":166},"text":"Back","id":"c28"},{"type":"text","size":{"width":null,"height":20},"location":{"x":178,"y":166},"text":"Some text","id":"c32"}],"nextId":33}]}
    
    loadApplication sample1
