
jQuery.fn.runWebKitAnimation: (animationClass, classesToAdd, classesToRemove) ->
    this.one 'webkitAnimationEnd', => this.removeClass("${animationClass} ${classesToRemove || ''}")
    this.addClass "${animationClass} ${classesToAdd || ''}"
        
jQuery.fn.showPopOverPointingTo: (tipControl, animation) ->
    return if this.is(':visible')
    
    tipControl: jQuery(tipControl)
    tip: this.find('.tip')
    offset: tipControl.offset()
    center: offset.left + tipControl.outerWidth() / 2
    bottom: offset.top + tipControl.outerHeight()
    
    tipSize: { width: 32, height: 16 }
    
    popoverWidth: this.outerWidth()
    
    popoverOffset: { left: center - popoverWidth/2, top: bottom + tipSize.height }
    popoverOffset.left = Math.min(popoverOffset.left, jQuery(window).width() - popoverWidth - 5)
    parentOffset: jQuery(this.parent()).offset()
    
    this.css({ top: popoverOffset.top - parentOffset.top, left: popoverOffset.left - parentOffset.left })
    tip.css('left', center - popoverOffset.left - tipSize.width / 2)
    this.one 'webkitAnimationEnd', => this.removeClass('popin')
    this.runWebKitAnimation (animation || 'popin'), 'visible', ''
    
jQuery.fn.hidePopOver: ->
    return unless this.is(':visible')
    this.runWebKitAnimation 'fadeout', '', 'visible'

jQuery.fn.togglePopOver: (tipControl) ->
    if this.is(':visible') then this.hidePopOver() else this.showPopOverPointingTo tipControl
    
jQuery.fn.setdata: (id, newData) -> $.data(this[0], id, newData); this
jQuery.fn.getdata: (id) -> $.data(this[0], id)

# definitions

ctgroups: [
    {
        name: "Bars"
        ctypes: [
            {
                type: 'statusBar'
                label: 'Status Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: 20 }
            }
            {
                type: 'tabBar'
                label: 'Tab Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: 49 }
            }
            {
                type: 'navBar'
                label: 'Navigation Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
            }
            {
                type: 'toolbar'
                label: 'Tool Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
            }
        ]
    }
    {
        name: "Buttons"
        ctypes: [
            {
                type: 'barButton'
                label: 'Bar Button'
                defaultText: "Back"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { fixedSize: { portrait: 30, landscape: 30 } }
            }
            {
                type: 'roundedButton'
                label: 'Rounded Button'
                defaultText: "Call"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { userSize: true, fixedSize: 44 }
            }
            {
                type: 'coloredButton'
                label: 'Colored Button'
                defaultText: "Delete Contact"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { userSize: true, fixedSize: 44 }
            }
            {
                type: 'buyButton'
                label: 'Buy Button'
                defaultText: "Buy"
                widthPolicy: { userSize: true, fixedSize: 80 } #autoSize: 'browser'
                heightPolicy: { userSize: true, fixedSize: 25 }
            }
        ]
    }
    {
        name: "Input Controls"
        ctypes: [
            {
                type: 'switch'
                label: 'On/Off Switch'
                widthPolicy: { fixedSize: 94 }
                heightPolicy: { fixedSize: 27 }
            }
            {
                type: 'slider'
                label: 'Slider'
                widthPolicy: { userSize: true, fixedSize: 118 }
                heightPolicy: { fixedSize: 23 }
            }
            {
                type: 'pageControl'
                label: 'Page Control'
                widthPolicy: { userSize: true, fixedSize: 38 }
                heightPolicy: { fixedSize: 36 }
            }
            {
                type: 'segmentedControl'
                label: 'Segmented Control'
                widthPolicy: { userSize: true, fixedSize: 207 }
                heightPolicy: { fixedSize: 44 }
    
                styles: {
                    normal: {
                    }
                    bar: {
                        heightPolicy: { fixedSize: 30 }
                    }
                }
            }
            {
                type: 'stars'
                label: 'Stars'
                widthPolicy: { fixedSize: 50 }
                heightPolicy: { fixedSize: 27 }
            }
        ]
    }
    {
        name: "Misc"
        ctypes: [
            {
                type: 'progressBar'
                label: 'Progress Bar'
                widthPolicy: { userSize: true, fixedSize: 150 }
                heightPolicy: { fixedSize: 9 }
            }
            {
                type: 'progressBarBarStyle'
                label: 'Progress Bar 2'
                widthPolicy: { userSize: true, fixedSize: 150 }
                heightPolicy: { fixedSize: 11 }
            }
            {
                type: 'progressIndicator'
                label: 'Progress Indicator'
                widthPolicy: { userSize: true, fixedSize: 150 }
                heightPolicy: { fixedSize: 11 }
    
                styles: {
                    largeWhite: {
                        width: 37
                        height: 37
                    }
                    gray: {
                        width: 20
                        height: 20
                    }
                    white: {
                        width: 20
                        height: 20
                    }
                }
            }
        ]
    }
]

jQuery ($) ->

    CONF_ANCHORING_DISTANCE = 10
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100

    ##########################################################################################################
    
    application: null
    activeScreen: null
    components: {}
    cnodes: {}
    ctypes: {}
    mode: null
    allowedArea: null

    ##########################################################################################################
    
    componentsChanged: ->
        activeScreen.components = (c for cid, c of components)
        
        if $('#share-popover').is(':visible')
            updateSharePopover()

    ##########################################################################################################
    
    createNodeForControl: (c) -> $("<div />").addClass("component c-${c.type}")[0]
    findControlIdOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-cid')
    
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

    updateComponentText: (c, cn) -> $(cn).html(c.text) if c.text?
    
    updateComponentProperties: (c, cn) -> updateComponentPosition(c, cn); updateComponentText(c, cn)
    
    setTransitions: (cn, trans) -> $(cn).css('-webkit-transition', trans)

    ##########################################################################################################
    
    hoveredControlId: null
    
    updateHoverPanelPosition: ->
        return if hoveredControlId is null
        cn: cnodes[hoveredControlId]
        offset: { left: cn.offsetLeft, top: cn.offsetTop }
        $('#hover-panel').css({ left: offset.left, top: offset.top })
    
    componentHovered: (cid) ->
        $('#hover-panel').fadeIn(100) if hoveredControlId is null
        hoveredControlId = cid
        updateHoverPanelPosition()
        
    componentUnhovered: ->
        return if hoveredControlId is null
        hoveredControlId = null
        $('#hover-panel').hide()
        
    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click ->
        if hoveredControlId isnt null
            $('#hover-panel').hide()
            deleteComponent hoveredControlId 
            hoveredControlId = null
    
        
    # pauseHoverPanel: -> $('#hover-panel').fadeOut(100) if hoveredControlId isnt null
    # resumeHoverPanel: -> updateHoverPanelPosition $('#hover-panel').fadeIn(100) if hoveredControlId isnt null
    
    ##########################################################################################################
    
    rectOfComponent: (cn) ->
        { x: cn.offsetLeft, y: cn.offsetTop, w: cn.offsetWidth, h: cn.offsetHeight }
    
    computeAnchoringPositionsOfComponent: (cid) ->
        r: rectOfComponent cnodes[cid]
        [
            { orient: 'vert', cid: cid, coord: r.x }
            { orient: 'vert', cid: cid, coord: r.x + r.w }
            { orient: 'horz',  cid: cid, coord: r.y }
            { orient: 'horz',  cid: cid, coord: r.y + r.h }
        ]
        
    computeAllAnchoringPositions: ->
        _.flatten(computeAnchoringPositionsOfComponent cid for cid, c of components)
        
    computeAnchorings: (ap, r) ->
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
                
    applyAnchoring: (a, r) ->
        switch a.atype
            when 'left'   then r.x = a.coord
            when 'right'  then r.x = a.coord - r.w
            when 'top'    then r.y = a.coord
            when 'bottom' then r.y = a.coord - r.h
    
    activateMode: (m) ->
        mode: m
        updatePaletteVisibility('mode')
    
    activatePointingMode: ->
        window.status = "Hover a component for options. Click to edit. Drag to move."
        activateMode {
            mousedown: (e, cid) ->
                activateExistingComponentDragging cid, { x: e.pageX, y: e.pageY } if cid

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
        aps: _(computeAllAnchoringPositions()).select((a) -> c.id isnt a.cid)

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
            setTransitions cn, "-webkit-transform 0.25s linear"
            [r, ok] = updateRectangleAndClipToArea(pt)
            $(cn)[if ok then 'removeClass' else 'addClass']('cannot-drop')

            if ok
                aa: _.flatten(computeAnchorings(ap, r) for ap in aps)

                best: {
                    horz: _(a for a in aa when a.orient is 'horz').min((a) -> a.dist)
                    vert: _(a for a in aa when a.orient is 'vert').min((a) -> a.dist)
                }

                # console.log "pos: (${pos.x}, ${pos.y}), best anchoring horz: ${best.horz?.dist} at ${best.horz?.coord}, vert: ${best.vert?.dist} at ${best.vert?.coord}"

                if best.horz and best.horz.dist > CONF_ANCHORING_DISTANCE then best.horz = null
                if best.vert and best.vert.dist > CONF_ANCHORING_DISTANCE then best.vert = null

                applyAnchoring best.vert, r if best.vert
                applyAnchoring best.horz, r if best.horz
            
            c.location = { x: r.x, y: r.y }
            
            updateComponentPosition c, cn
            updateHoverPanelPosition()
            return ok
            
        dropAt: (pt) -> moveTo pt
            
        moveTo(options.startPt)
            
        { moveTo: moveTo, dropAt: dropAt }
        
    activateExistingComponentDragging: (cid, startPt) ->
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
        cn: createNodeForControl c
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
            e.preventDefault()
            mode.mousedown e, findControlIdOfNode(e.target)

        mousemove: (e) ->
            e.preventDefault()
            mode.mousemove e, findControlIdOfNode(e.target)
            
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
                
        mouseup: (e) ->
            e.preventDefault()
            mode.mouseup e, findControlIdOfNode(e.target)
    }

    ##########################################################################################################
    
    paletteWanted: on
    
    computeInitialSize: (policy, fullSize) ->
        policy.fixedSize?.portrait || policy.fixedSize || (if policy.autoSize is 'fill' then fullSize)
    
    bindPaletteItem: (item, ct) ->
        item.mousedown (e) ->
            e.preventDefault()
            c: { type: ct.type }
            c.size: {
                width:  computeInitialSize(ct.widthPolicy, 320)
                height: computeInitialSize(ct.heightPolicy, 460)
            }
            c.location: { x: 0, y: 0 }
            c.text = ct.defaultText if ct.defaultText?
            activateNewComponentDragging { x: e.pageX, y: e.pageY }, c
    
    fillPalette: ->
        $content: $('.palette .content')
        for ctg in ctgroups
            for ct in ctg.ctypes
                item: $('<div />').addClass('item')
                $('<img />').attr('src', "../static/iphone/images/palette/button.png").appendTo(item)
                caption: $('<div />').addClass('caption').html(ct.label).appendTo(item)
                $content.append item
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
    
    addToComponents: (c) -> c.id ||= "c${activeScreen.nextId++}"; components[c.id] = c
    storeComponentNode: (c, cn) -> $(cn).setdata('moa-cid', c.id); cnodes[c.id] = cn
    
    deleteComponent: (cid) ->
        cn: cnodes[cid]
        $(cn).hide 'drop', { direction: 'down' }, 'normal', ->
            $(cn).remove()
            delete cnodes[cid]
            delete components[cid]
            componentsChanged()
    
    switchToScreen: (screen) ->
        $(cn).remove() for cid, cn of cnodes
            
        activeScreen = screen
        activeScreen.nextId ||= 1
        components = {}
        for c in activeScreen.components
            addToComponents c
            
        for cid, c of components
            $('#design-pane').append storeComponentNode(c, createNodeForControl(c))
        
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
        for ctg in ctgroups
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
    
    sample1: {"screens":[{"components":[{"type":"statusBar","size":{"width":320,"height":20},"location":{"x":47,"y":139},"id":"c13"},{"type":"navBar","size":{"width":320,"height":44},"location":{"x":47,"y":159},"id":"c14"},{"type":"tabBar","size":{"width":320,"height":49},"location":{"x":47,"y":570},"id":"c15"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":268},"text":"Back","id":"c16"},{"type":"roundedButton","size":{"width":null,"height":44},"location":{"x":97,"y":493},"text":"Call","id":"c17"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":268},"id":"c18"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":312},"text":"Back","id":"c21"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":362},"text":"Back","id":"c22"},{"type":"barButton","size":{"width":null,"height":30},"location":{"x":62,"y":412},"text":"Back","id":"c23"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":315},"id":"c24"},{"type":"coloredButton","size":{"width":null,"height":44},"location":{"x":212,"y":493},"text":"Delete Contact","id":"c25"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":365},"id":"c26"},{"type":"switch","size":{"width":94,"height":27},"location":{"x":259,"y":415},"id":"c27"}],"nextId":28}]}
    
    loadApplication sample1
