
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
        initialSize: { height: 30 }
    }
}
            
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
        
        
class DesignPane

    constructor: (screenDesignerV, $designPane) ->
        renderedElements: Mo.newDelegatedMap screenDesignerV, 'renderedElements'
        
        isDragging: false
        isMouseDown: false
        dragOrigin: null
        dragOriginalLocation: null
        draggedComponent: null
        $draggedComponentNode: null
        
        Mo.sub renderedElements, {
            added: (e) ->
                $designPane.append(e.value)
            removed: (e) ->
                $(e.value).remove()
        }
        
        new HoverView screenDesignerV, $designPane
        
        $designPane.mousedown (e) ->
            $target: $(e.target)
            isMouseDown: true
            
            # if ($comp: $target.closest('.component')).length
            #     component: $.data($comp[0], 'component') if $comp.length
            #     isDragging: false
            #     dragOrigin: { x: e.pageX, y: e.pageY }
            #     dragOriginalLocation: { x: parseInt($target.css('left')), y: parseInt($target.css('top')) }
            #     draggedComponent: component
            #     console.log(dragOriginalLocation)    

        $designPane.mousemove (e) ->
            $target: $(e.target)
            $comp: $target.closest('.component')
            component: $.data($comp[0], 'component') if $comp.length
            
            # pt: { x: e.pageX, y: e.pageY }
            # if !isDragging && component && isMouseDown && (Math.abs(pt.x - dragOrigin.x) > 2 || Math.abs(pt.y - dragOrigin.y) > 2)
            #     isDragging: true
            #     draggedComponent: component
            #     $draggedComponentNode: $target
            #     
            # if isDragging
            #     $draggedComponentNode.css({ left: dragOriginalLocation.x + (pt.x - dragOrigin.x), top: dragOriginalLocation.y + (pt.y - dragOrigin.y) })
            #     if draggedComponent == hoveredComponent
            #         repositionHoverForComponent draggedComponent
            #     return
                
            if component
                screenDesignerV.get().hoverComponent component, 'mousemove'
            else if $target.closest('.hover-panel').length
                #
            else
                window.status = $target[0].toString()
                screenDesignerV.get().unhoverComponent 'mousemove'
                
        $designPane.mouseup (e) ->
            $target: $(e.target)
            isMouseDown: false
            isDragging: false

$ ->
    Mo.startDumpingEvents()
    rootDesigner: new RootDesigner()
    currentScreenDesigner: Mo.newDelegatedValue rootDesigner.currentApplicationDesigner, 'currentScreenDesigner'
    new DesignPane currentScreenDesigner, $('#design-pane')
    rootDesigner.openApplication (new Application myApplication), 'openSampleApplication'
