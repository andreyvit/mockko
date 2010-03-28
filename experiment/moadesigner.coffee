
jQuery.fn.runWebKitAnimation: (animationClass, classesToAdd, classesToRemove) ->
    this.one 'webkitAnimationEnd', => this.removeClass("${animationClass} ${classesToRemove || ''}")
    this.addClass "${animationClass} ${classesToAdd || ''}"
        
jQuery.fn.showPopOver: (tipControl) ->
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
    this.runWebKitAnimation 'popin', 'visible', ''
    
jQuery.fn.hidePopOver: ->
    return unless this.is(':visible')
    this.runWebKitAnimation 'fadeout', '', 'visible'

jQuery.fn.togglePopOver: (tipControl) ->
    if this.is(':visible') then this.hidePopOver() else this.showPopOver tipControl

# sample data

myApplication: {
    screens: [{
        components: [
            {
                type: 'button',
                text: 'Back',
                location: { x: 50, y: 100 }
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

for typeName, type of componentTypes
    type.typeName = typeName
            
# model

class Application
    
    constructor: (jsonApp) ->
        @screens: Mo.newList()
        
        for s in jsonApp.screens
            @screens.add (new Screen s), 'load'
        
        
class Screen
    constructor: (jsonScreen) ->
        @components: Mo.newSet()
        
        for c in jsonScreen.components
            @components.add (new Component c), 'load'

class Component
    constructor: (jsonComp) ->
        for k, v of jsonComp
            this[k] = v

    
# view model
        
renderComponent: (component) ->
    componentType: componentTypes[component.type]
    size: {
        width: component.width || componentType.initialSize.width
        height: component.height || componentType.initialSize.height
    }
    location: component.location

    el: $('<div />').attr({
        'class': "component c-${component.type}"
    }).css({
        'left':   "${location.x}px"
        'top':    "${location.y}px"
        'width':  (if size.width then "${size.width}px" else 'auto')
        'height': "${size.height}px"
    }).html(component.text || '')[0]
    
    $.data(el, 'component', component)
    return el


class RootDesigner
    
    constructor: ->
        @currentApplication: Mo.newValue()
        @currentApplicationDesigner: Mo.newSingleValueMapping @currentApplication, (a) -> new ApplicationDesigner a
        
    openApplication: (application, cause) ->
        @currentApplication.set application, cause


class ApplicationDesigner
    
    constructor: (application) ->
        @currentScreen: Mo.newValue null
        @screenDesigners: Mo.newComputedMapping application.screens, (screen) -> new ScreenDesigner screen
        @currentScreenDesigner: Mo.newLookupValue @screenDesigners, @currentScreen
        
        Mo.sub application.screens, {
            added: (e) =>
                if @currentScreen.get() == null
                    this.switchScreen e.value
        }
        
    switchScreen: (screen) ->
        @currentScreen.set screen, 'switchScreen'


class ScreenDesigner
    
    constructor: (screen) ->
        @hoveredComponent: Mo.newValue null
        @renderedElements: Mo.newComputedMapping screen.components, renderComponent
        @paletteVisible: Mo.newValue false
        @paletteTemporarilyHidden: Mo.newValue false
        
        Mo.sub screen.components, {
            removed: (e) =>
                if e.value == @hoveredComponent.get()
                    @hoveredComponent.set null, 'hoveredComponentRemoved'
        }
        
    hoverComponent: (component, cause) ->
        @hoveredComponent.set component, cause
        
    unhoverComponent: (cause) ->
        @hoveredComponent.set null, cause

# view

class HoverView
    
    constructor: (screenDesignerV, $designPane) ->
        hoveredComponentV: Mo.newDelegatedValue screenDesignerV, 'hoveredComponent'
        
        createHandle: (kind, handler) ->
            $('<div />').attr({ 'class': "handle ${kind}-handle" }).click (e) ->
                component: $.data($hoverPanel[0], 'hovered-component')
                handler(component)
                
        $hoverPanel: $('<div />').attr({ 'class': 'hover-panel' }).
            hide().append(createHandle('delete', (c) ->)).
            append(createHandle('duplicate', (c) ->)).
            appendTo($designPane)

        repositionHoverForComponent: (component) ->
            tag: screenDesignerV.get().renderedElements.at(component)
            console.log(tag)
            $tag: $(tag)
            offset: { left: $tag[0].offsetLeft, top: $tag[0].offsetTop }
            $hoverPanel.css({ left: offset.left, top: offset.top }).show()
            
        Mo.sub hoveredComponentV, (e) ->
            hoveredComponent: e.value
            
            if hoveredComponent == null
                $.data($hoverPanel[0], 'hovered-component', null)
                $hoverPanel.hide()
            else
                repositionHoverForComponent hoveredComponent
                $.data($hoverPanel[0], 'hovered-component', hoveredComponent)
                
newComponentOfType: (type) ->
    new Component { type: type.typeName }
        
class DesignPane

    constructor: (screenDesignerV) ->
        $designPane: $('#design-pane')
        renderedElements: Mo.newDelegatedMap screenDesignerV, 'renderedElements'
        
        Mo.sub renderedElements, {
            added: (e) ->
                $designPane.append(e.value)
            removed: (e) ->
                $(e.value).remove()
        }
        
        new HoverView screenDesignerV, $designPane
        
        mode: Mo.newValue null
        setMode: (m) -> mode.set m
        
        newNormalMode: ->
            {
                mousedown: (e, component, componentElement) ->
                    if component
                        setMode(newExistingComponentDragMode component, componentElement, e)

                mousemove: (e, component, componentElement) ->
                    if component
                        screenDesignerV.get().hoverComponent component, 'mousemove'
                    else if $(e.target).closest('.hover-panel').length
                        #
                    else
                        screenDesignerV.get().unhoverComponent 'mousemove'
                        
                mouseup: (e) -> #
            }
            
        newExistingComponentDragMode: (component, componentElement, e) ->
            dragOrigin: { x: e.pageX, y: e.pageY }
            dragOriginalLocation: { x: parseInt($(componentElement).css('left')), y: parseInt($(componentElement).css('top')) }
            
            {
                mousemove: (e) ->
                    pt: { x: e.pageX, y: e.pageY }
                    $(componentElement).css({ left: dragOriginalLocation.x + (pt.x - dragOrigin.x), top: dragOriginalLocation.y + (pt.y - dragOrigin.y) })
                    
                mouseup: (e) ->
                    setMode(newNormalMode())
            }
            
        newNewComponentDragMode: (component, componentElement, e) ->
            dragOrigin: { x: e.pageX, y: e.pageY }
            # dragOriginalLocation: { x: parseInt($(componentElement).css('left')), y: parseInt($(componentElement).css('top')) }
            
            {
                mousemove: (e) ->
                    pt: { x: e.pageX, y: e.pageY }
                    $(componentElement).offset({ left: pt.x, top: pt.y })
                    
                mouseup: (e) ->
                    setMode(newNormalMode())
            }
            
        setMode newNormalMode()
        
        $designPane.mousedown (e) ->
            componentElement: $(e.target).closest('.component')[0]
            component: $.data(componentElement, 'component') if componentElement
            mode.get().mousedown e, component, componentElement

        $designPane.mousemove (e) ->
            componentElement: $(e.target).closest('.component')[0]
            component: $.data(componentElement, 'component') if componentElement
            mode.get().mousemove e, component, componentElement
            
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
                
        $designPane.mouseup (e) ->
            componentElement: $(e.target).closest('.component')[0]
            component: $.data(componentElement, 'component') if componentElement
            mode.get().mouseup e, component, componentElement
            
        $palette: $('.palette')
        paletteVisible: Mo.newDelegatedValue screenDesignerV, 'paletteVisible'
        
        $content: $palette.find('.content')
        for i in [1..20]
            for key, componentType of componentTypes
                item: $('<div />').addClass('item')
                $('<img />').attr('src', "images/palette/${componentType.image}.png").appendTo(item)
                caption: $('<div />').addClass('caption').html(componentType.label).appendTo(item)
                $content.append item
                
                item.mousedown (e) ->
                    component: newComponentOfType componentType
                    component.size: { width: 100, height: 50 }
                    component.location: { x: 0, y: 0 }
                    el: renderComponent component
                    $designPane.append(el)
                    setMode newNewComponentDragMode component, el, e
                
        Mo.sub paletteVisible, (e) ->
            if e.value
                $('.palette').showPopOver($('#add-button'))
            else
                $('.palette').hidePopOver()
    
            
$ ->
    Mo.startDumpingEvents()
    rootDesigner: new RootDesigner()
    currentScreenDesigner: Mo.newDelegatedValue rootDesigner.currentApplicationDesigner, 'currentScreenDesigner'
    new DesignPane currentScreenDesigner
    rootDesigner.openApplication (new Application myApplication), 'openSampleApplication'
        
    $('#add-button').click ->
        d: currentScreenDesigner.get()
        d.paletteVisible.set !d.paletteVisible.get()
        
    currentScreenDesigner.get().paletteVisible.set true
    