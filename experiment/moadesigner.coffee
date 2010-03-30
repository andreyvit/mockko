
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
                type: 'button',
                text: 'Back',
                location: { x: 50, y: 100 }
                size: {}
            }
        ]
    }]
}

# definitions

componentTypes: {
    button: {
        label: "button"
        image: "button"
        initialSize: { height: 30 }
    }
}

jQuery ($) ->
    application: null
    activeScreen: null
    components: {}
    cnodes: {}
    mode: null

    ##########################################################################################################
    
    createNodeForControl: (c) -> $("<div />").addClass("component c-${c.type}")[0]
    findControlIdOfNode: (n) -> if ($cn: $(n).closest('.component')).size() then $cn.getdata('moa-cid')
    
    computeComponentSize: (c) ->
        ct: componentTypes[c.type]
        {
            width: c.size.width || ct.initialSize.width
            height: c.size.height || ct.initialSize.height
        }
    
    updateComponentPosition: (c, cn) ->
        cn ||= cnodes[c.id]
        ct: componentTypes[c.type]
        size: computeComponentSize(c)
        location: c.location
        
        $(cn).css({
            'left':   "${location.x}px"
            'top':    "${location.y}px"
            'width':  (if size.width then "${size.width}px" else 'auto')
            'height': "${size.height}px"
        })

    updateComponentText: (c) -> $(cnodes[c.id]).html(c.text) if c.text?
    
    updateComponentProperties: (c) -> updateComponentPosition(c); updateComponentText(c)
        
    
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
        $('#hover-panel').fadeOut(100)
        
    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click -> #
    
        
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
            c.location = {
                x: pt.x - designAreaOrigin.left - size.width  * hotSpot.x
                y: pt.y - designAreaOrigin.top  - size.height * hotSpot.y
            }
            updateComponentPosition c, cn
        moveTo dragOrigin
        
        window.status = "Dragging a new component."
        
        activateMode {
            mousemove: (e) ->
                moveTo { x: e.pageX, y: e.pageY }
                
            mouseup: (e) ->
                addToComponents c
                storeComponentNode c, cn
                updateComponentProperties c
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
    
    fillPalette: ->
        $content: $('.palette .content')
        for i in [1..20]
            for key, ct of componentTypes
                item: $('<div />').addClass('item')
                $('<img />').attr('src', "images/palette/${ct.image}.png").appendTo(item)
                caption: $('<div />').addClass('caption').html(ct.label).appendTo(item)
                $content.append item
            
                item.mousedown (e) ->
                    c: { type: ct.typeName }
                    c.size: { width: 100, height: 50 }
                    c.location: { x: 0, y: 0 }
                    activateNewComponentDragging { x: e.pageX, y: e.pageY }, c
                    
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
    
    switchToScreen: (screen) ->
        activeScreen = screen
        activeScreen.nextId ||= 1
        components = {}
        for c in activeScreen.components
            addToComponents c
            
        for cid, c of components
            $('#design-pane').append storeComponentNode(c, createNodeForControl(c))
        
        updateComponentProperties(c) for cid, c of components
        
    
    loadApplication: (app) ->
        application = app
        switchToScreen application.screens[0]
        
    ##########################################################################################################
    
    initComponentTypes: ->
        for typeName, ct of componentTypes
            ct.typeName = typeName

    initComponentTypes()
    fillPalette()
    activatePointingMode()
    
    loadApplication(myApplication)
    