
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

# sample data

myApplication: {
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
                heightPolicy: { fixedSize: 45 }
            }
            {
                type: 'navBar'
                label: 'Navigation Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { autoSize: true }
            }
            {
                type: 'toolBar'
                label: 'Tool Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: { portrait: 45, landscape: 45 } }
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
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { userSize: true, fixedSize: 20 }
            }
        ]
    }
    {
        name: "Input Controls"
        ctypes: [
            {
                type: 'onOffSwitch'
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
    application: null
    activeScreen: null
    components: {}
    cnodes: {}
    ctypes: {}
    mode: null

    ##########################################################################################################
    
    createNodeForControl: (c) -> $("<div />").addClass("component c-${c.type}")[0]
    findControlIdOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-cid')
    
    computeComponentSize: (c) ->
        ct: ctypes[c.type]
        {
            width: c.size.width || ct.widthPolicy?.fixedSize?.width || null
            height: c.size.height || ct.heightPolicy?.fixedSize?.height || null
        }
    
    updateComponentPosition: (c, cn) ->
        ct: ctypes[c.type]
        size: computeComponentSize(c)
        location: c.location
        
        $(cn).css({
            'left':   "${location.x}px"
            'top':    "${location.y}px"
            'width':  (if size.width then "${size.width}px" else 'auto')
            'height': "${size.height}px"
        })

    updateComponentText: (c, cn) -> $(cn).html(c.text) if c.text?
    
    updateComponentProperties: (c, cn) -> updateComponentPosition(c, cn); updateComponentText(c, cn)
        
    
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
    
    activateMode: (m) ->
        mode: m
        updatePaletteVisibility('mode')
    
    activatePointingMode: ->
        window.status = "Hover a component for options. Click to edit. Drag to move."
        activateMode {
            mousedown: (e, cid) ->
                activateExistingComponentDragging cid, e if cid

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
        
    activateExistingComponentDragging: (cid, e) ->
        cn: cnodes[cid]
        window.status = "Dragging a component."
        
        dragOrigin: { x: e.pageX, y: e.pageY }
        dragOriginalLocation: { x: parseInt($(cn).css('left')), y: parseInt($(cn).css('top')) }
        
        activateMode {
            mousemove: (e) ->
                pt: { x: e.pageX, y: e.pageY }
                $(cn).css({ left: dragOriginalLocation.x + (pt.x - dragOrigin.x), top: dragOriginalLocation.y + (pt.y - dragOrigin.y) })
                updateHoverPanelPosition()
                
            mouseup: (e) ->
                activatePointingMode()
                
            hidesPalette: yes
        }
        
    activateNewComponentDragging: (dragOrigin, c) ->
        cn: createNodeForControl c
        $('#design-pane').append cn
        
        hotSpot = { x: 0.5, y: 0.5 }
        designAreaOrigin: $('#design-pane').offset()
        moveTo: (pt) ->
            size: computeComponentSize(c)
            size.width ||= cn.offsetWidth
            c.location = {
                x: pt.x - designAreaOrigin.left - (size.width || 0)  * hotSpot.x
                y: pt.y - designAreaOrigin.top  - (size.height || 0) * hotSpot.y
            }
            updateComponentPosition c, cn
            
        updateComponentProperties c, cn
        moveTo dragOrigin
        
        window.status = "Dragging a new component."
        
        activateMode {
            mousemove: (e) ->
                moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                addToComponents c
                storeComponentNode c, cn
                updateComponentProperties c, cn
                activatePointingMode()
            
            hidesPalette: yes
        }
    
    $('#design-pane').bind {
        mousedown: (e) ->
            mode.mousedown e, findControlIdOfNode(e.target)

        mousemove: (e) ->
            mode.mousemove e, findControlIdOfNode(e.target)
            
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
                
        mouseup: (e) ->
            mode.mouseup e, findControlIdOfNode(e.target)
    }

    ##########################################################################################################
    
    paletteWanted: on
    
    computeInitialSize: (policy, fullSize) ->
        policy.fixedSize?.portrait || policy.fixedSize || (if policy.autoSize is 'fill' then fullSize)
    
    bindPaletteItem: (item, ct) ->
        item.mousedown (e) ->
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
    
    switchToScreen: (screen) ->
        activeScreen = screen
        activeScreen.nextId ||= 1
        components = {}
        for c in activeScreen.components
            addToComponents c
            
        for cid, c of components
            $('#design-pane').append storeComponentNode(c, createNodeForControl(c))
        
        updateComponentProperties(c, cnodes[cid]) for cid, c of components
        
    
    loadApplication: (app) ->
        application = app
        switchToScreen application.screens[0]
        
    ##########################################################################################################
    
    initComponentTypes: ->
        for ctg in ctgroups
            for ct in ctg.ctypes
                ctypes[ct.type] = ct

    initComponentTypes()
    fillPalette()
    activatePointingMode()
    
    loadApplication(myApplication)
    