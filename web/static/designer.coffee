jQuery ($) ->

    CONF_SNAPPING_DISTANCE = 5
    CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100
    STACKED_COMP_TRANSITION_DURATION = 200

    MAX_IMAGE_UPLOAD_SIZE: 1024*1024
    MAX_IMAGE_UPLOAD_SIZE_DESCR: '1 Mb'

    DUPLICATE_COMPONENT_OFFSET_X: 5
    DUPLICATE_COMPONENT_OFFSET_Y: 5
    DUPLICATE_COMPONENT_MIN_EDGE_INSET_X: 5
    DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y: 5

    INF: 100000  # our very own idea of infinity

    DEFAULT_ROOT_COMPONENT: {
        type: "background"
        size: { w: 320, h: 480 }
        abspos: { x: 0, y: 0 }
        id: "root"
    }


    ##########################################################################################################
    ## imports

    {
        #  Legacy
        isRectInsideRect, doesRectIntersectRect, rectIntersection, areaOfIntersection, proximityOfRectToRect
        ptDiff, ptSum, ptMul, distancePtToPtMod, distancePtToPtSqr
        #  Point
        ZeroPt, ptToString, distancePtPt1, distancePtPt2, addPtPt, subPtPt, mulPtSize, ptFromLT, ptFromNode
        unitVecOfPtPt, mulVecLen, ptInRect
        #  Size
        ZeroSize, sizeToString, domSize, centerOfSize
        #  Rect
        rectToString, rectFromPtAndSize, rectFromPtPt, dupRect, addRectPt, subRectPt, topLeftOf, bottomRightOf
        rectOfNode, canonRect, insetRect, centerOfRect, centerSizeInRect
        #  Line / Segment
        lineFromPtPt, lineFromABPt, signum, classifyPtLine, perpendicularLineThroughPoint, distancePtLine
        distancePtSegment
    }: Mockko.geom

    Types: Mockko.componentTypes
    ser: Mockko.serialization
    hover: null

    {
        renderComponentNode
        renderComponentSize, updateEffectiveSize, updateComponentTooltip
        renderComponentPosition
        renderComponentStyle, textNodeOfComponent
        renderComponentVisualProperties, renderComponentProperties
        renderComponentHierarchy
    }: Mockko.renderer

    {
        sizeOf, rectOf
        traverse, skipTraversingChildren
        findChildByType, findBestTargetContainerForRect, findComponentByRect
        findComponentByTypeIntersectingRect
        compWithChildrenAndParents, isComponentOrDescendant, findComponentOccupyingRect
        pickHorizontalPositionBetween, pickHorizontalRectAmong
        moveComponent
        newItemsForHorizontalStack, newItemsForHorizontalStackDuplication, computeDropEffectFromNewRects
    }: Mockko.model

    ##########################################################################################################
    ## global variables

    applicationList: null
    serverMode: null
    applicationId: null
    application: null
    activeScreen: null
    mode: null
    allowedArea: null
    componentBeingDoubleClickEdited: null
    allStacks: null
    undo: null


    ##########################################################################################################
    ##  undo support

    friendlyComponentName: (c) ->
        if c.type is Types['text']
            "“${c.text}”"
        else
            label: (c.type.genericLabel || c.type.label).toLowerCase()
            if c.text then "the “${c.text}” ${label}" else aOrAn label

    runTransaction: (changeName, change) ->
        undo.beginTransaction changeName
        change()
        undo.endTransaction()
        componentsChanged()

    setupUndoSystem: ->
        createApplicationMemento: ->
            JSON.stringify(ser.externalizeApplication(application))
        revertToMemento: (memento) ->
            screenIndex: _(application.screens).indexOf activeScreen
            reloadApplication ser.internalizeApplication(JSON.parse(memento))
            saveApplicationChanges()
            if application.screens.length > 0
                screenIndex: Math.max(0, Math.min(application.screens.length - 1, screenIndex))
                switchToScreen application.screens[screenIndex]
        lastUndoCommandChanged: (lastChangeDescription) ->
            $('#undo-button').alterClass('disabled', lastChangeDescription is null)
            if lastChangeDescription
                $('#undo-hint span').html lastChangeDescription
        undo: Mockko.newUndoManager createApplicationMemento, revertToMemento, saveApplicationChanges, lastUndoCommandChanged

    $('#undo-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        undo.undoLastChange()


    ##########################################################################################################
    ##  DOM templates

    domTemplates = {}
    $('.template').each ->
        domTemplates[this.id] = this
        $(this).removeClass('template').remove()
    domTemplate: (id) ->
        domTemplates[id].cloneNode(true)


    ##########################################################################################################
    ##  global events

    componentsChanged: ->
        if $('#share-popover').is(':visible')
            updateSharePopover()

        reassignZIndexes()

        allStacks: Mockko.stacking.discoverStacks(activeScreen.rootComponent)

        updateInspector()
        updateScreenPreview(activeScreen)

    componentPositionChangedWhileDragging: (c) ->
        renderComponentPosition c
        renderComponentSize c
        if c is hover.currentlyHovered()
            hover.updateHoverPanelPosition()
            updatePositionInspector()

    componentPositionChangedPernamently: (c) ->
        renderComponentPosition c
        updateEffectiveSize c
        if c is hover.currentlyHovered()
            hover.updateHoverPanelPosition()
            updatePositionInspector()

    componentStyleChanged: (c) ->
        renderComponentStyle c

    componentActionChanged: (c) ->
        renderComponentStyle c
        if c is componentToActUpon()
            updateActionInspector()
        if c is hover.currentlyHovered()
            hover.updateHoverPanelPosition()

    containerChildrenChanged: (container) ->
        sorted: _(container.children).sortBy (child) -> child.abspos.x
        if _(_(sorted).zip(container.children)).any((a, b) -> a isnt b)
            for node in (n for n in container.node.childNodes)
                container.node.removeChild node
            for node in (child.node for child in sorted)
                container.node.appendChild node


    ##########################################################################################################
    ##  Component Utilities

    commitMoves: (moves, exclusions, delay) ->
        if moves.length > 0
            liveMover: newLiveMover exclusions
            liveMover.moveComponents moves
            liveMover.commit(delay)

    commitMovesImmediately: (moves) ->
        for m in moves
            for c in m.comps || [m.comp]
                offset: m.offset || subPtPt(m.abspos, c.abspos)
                traverse c, (child) ->
                    child.abspos: { x: child.abspos.x + offset.x; y: child.abspos.y + offset.y }
                    child.size: m.size if m.size
                    componentPositionChangedPernamently child


    ##########################################################################################################
    ##  Hit Testing

    findComponentAt: (pt) ->
        if linkOverlay: hover.currentLinkOverlay()
            if linkOverlay.justAdded
                pagePt: addPtPt(pt, ptFromNode('#design-area'))
                if (d: hover.distanceToLinkOverlay(pagePt)) < linkOverlay.safeDistance
                    return linkOverlay.comp

        result: null
        visitor: (child) ->
            rect: rectOf(child)
            hitRect: if o: child.type.hitAreaOutset then insetRect rect, { l: -o, r: -o, t: -o, b: -o } else rect
            unless ptInRect(pt, hitRect)
                return skipTraversingChildren
            result: child
            if o: child.type.hitAreaInset
                # hit the container instead of children if the mouse is within o px from its border
                hitRect: insetRect rect, { l: o, r: o, t: o, b: o }
                unless ptInRect(pt, hitRect)
                    return skipTraversingChildren

        if hovered: hover.currentlyHovered()
            rect: insetRect rectOf(hovered), { l: -7, r: -7, t: -20, b: -7 }
            if ptInRect(pt, rect)
                result: hovered
                traverse hovered, visitor
                return result

        traverse activeScreen.rootComponent, visitor
        result

    findComponentByEvent: (e) ->
        origin: ptFromLT $('#design-area').offset()
        findComponentAt subPtPt({ x: e.pageX, y: e.pageY }, origin)


    ##########################################################################################################
    ##  component management

    cloneTemplateComponent: (compTemplate) ->
        c: ser.internalizeComponent compTemplate, null
        traverse c, (comp) -> comp.inDocument: no
        return c

    deleteComponentWithoutTransaction: (rootc, animated) ->
        return if rootc.type.unmovable

        effect: computeDeletionEffect rootc
        stacking: Mockko.stacking.handleStacking rootc, null, allStacks

        liveMover: newLiveMover [rootc]
        liveMover.moveComponents stacking.moves.concat(effect.moves)
        liveMover.commit(animated && STACKED_COMP_TRANSITION_DURATION)

        _(rootc.parent.children).removeValue rootc
        if animated
            $(rootc.node).hide 'drop', { direction: 'down' }, 'normal', -> $(rootc.node).remove()
        else
            $(rootc.node).remove()
        containerChildrenChanged rootc.parent
        deselectComponent() if isComponentOrDescendant selectedComponent, rootc
        hover.componentUnhovered() if isComponentOrDescendant hover.currentlyHovered(), rootc

    deleteComponent: (rootc) ->
        runTransaction "deletion of ${friendlyComponentName rootc}", ->
            deleteComponentWithoutTransaction rootc, true

    moveComponentBy: (comp, offset) ->
        runTransaction "keyboard moving of ${friendlyComponentName comp}", ->
            traverse comp, (c) -> c.abspos: ptSum(c.abspos, offset)
            traverse comp, componentPositionChangedPernamently

    duplicateComponent: (comp) ->
        return if comp.type.unmovable || comp.type.singleInstance

        newComp: ser.internalizeComponent(ser.externalizeComponent(comp), comp.parent)

        $(comp.parent.node).append renderInteractiveComponentHeirarchy newComp
        updateEffectiveSizesInHierarchy newComp
        relayoutHierarchy newComp

        effect: computeDuplicationEffect newComp, comp
        if effect is null
            $(newComp.node).remove()
            alert "Cannot duplicate the component because another copy does not fit into the designer"
            return

        runTransaction "duplicate ${friendlyComponentName comp}", ->
            comp.parent.children.push newComp

            newRect: effect.rect
            if newRect.w != comp.effsize.w or newRect.h != comp.effsize.h
                newComp.size: { w: newRect.w, h: newRect.h }
            moveComponent newComp, newRect
            componentPositionChangedPernamently newComp

            commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION

            containerChildrenChanged comp.parent


    ##########################################################################################################
    ##  DOM rendering

    renderStaticComponentHierarchy: (c) -> renderComponentHierarchy c, false, false
    renderPaletteComponentHierarchy: (c) -> renderComponentHierarchy c, true, false
    renderInteractiveComponentHeirarchy: (c) -> renderComponentHierarchy c, true, true

    updateEffectiveSizesInHierarchy: (c) ->
        traverse c, (child) ->
            updateEffectiveSize child

    relayoutHierarchy: (c) ->
        traverse c, (child) ->
            if effect: computeContainerLayout(child).relayout()
                commitMovesImmediately effect.moves
                containerChildrenChanged child

    reassignZIndexes: ->
        traverse activeScreen.rootComponent, (comp) ->
            ordered: _(comp.children).sortBy (c) -> r: rectOf c; -r.w * r.h
            _.each ordered, (c, i) -> $(c.node).css('z-index', i)


    ##########################################################################################################
    ##  Images

    imageSizeForImage: (image, effect) ->
        return image.size unless serverMode.supportsImageEffects
        switch effect
            when 'iphone-tabbar-active'   then { w: 35, h: 35 }
            when 'iphone-tabbar-inactive' then { w: 35, h: 32 }
            else image.size

    _imageEffectName: (image, effect) ->
        splitext: /^(.*)\.([^.]+)$/
        split: splitext.exec image
        if split?
            "${split[1]}.${effect}.${split[2]}"
        else
            throw "Unable to split ${image} into filename and extensions"

    #
    # UI may request URLs for many images belonging to the same image group.
    #
    # To avoid issuing sheer amount of requests to server, first call will mark
    # image group as "pending", so subsequent calls will add callback to the
    # list of "waiting for image group $foo". All callbacks will be executed
    # when AJAX handler is executed.
    #

    groups: {}
    pending: {}

    _returnImageUrl: (image, effect, cb) ->
        throw "image group URLs not cached: ${image.group}" unless image.group of groups
        digest: groups[image.group][image.name]
        if effect
            cb "images/${encodeURIComponent image.group}/${encodeURIComponent (_imageEffectName image.name, effect)}?${digest}"
        else
            cb "images/${encodeURIComponent image.group}/${encodeURIComponent image.name}?${digest}"

    _updateGroup: (groupName, group) ->
        info: {}
        for imginfo in group
            info[imginfo['fileName']]: imginfo['digest']
        groups[groupName]: info

    ensureImageGroupLoaded: (group) ->
        unless group of groups
            unless group of pending
                pending[group]: []
                serverMode.loadImageGroup group, (info) ->
                    _updateGroup group, info['images']
                    for [image, effect, callback] in pending[group]
                        _returnImageUrl image, effect, callback
                    delete pending[group]

    getImageUrl: (image, effect, callback) ->
        throw "image group not loaded and not loading: ${image.group}" unless image.group of groups or image.group of pending
        if image.group of pending
            pending[image.group].push([image, effect, callback])
        else
            _returnImageUrl image, effect, callback

    # TODO: remove this hack for circular dependency on designer-rendering
    window.getImageUrl: getImageUrl


    ##########################################################################################################
    ##  selection

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

    componentToActUpon: -> selectedComponent || hover.currentlyHovered()


    ##########################################################################################################
    ##  double-click editing

    handleComponentDoubleClick: (c) ->
        switch c.type.name
            when 'tab-bar-item'
                runTransaction "activation of ${friendlyComponentName c}", ->
                    _(c.parent.children).each (child) ->
                        newState: if c is child then on else off
                        if child.state isnt newState
                            child.state: newState
                            renderComponentStyle child
            when 'switch'
                c.state: c.type.state unless c.state?
                newStateDesc: if c.state then 'off' else 'on'
                runTransaction "turning ${friendlyComponentName c} ${newStateDesc}", ->
                    c.state: !c.state
                    renderComponentStyle c
        startComponentTextInPlaceEditing c

    startComponentTextInPlaceEditing: (c) ->
        return unless c.type.supportsText

        if c.type.wantsSmartAlignment
            alignment: Mockko.possibleAlignmentOf(c, activeScreen).bestDefiniteGuess()
            originalRect: rectOf c

        realign: ->
            if c.type.wantsSmartAlignment
                updateEffectiveSize c
                if newPos: alignment.adjustedPosition(originalRect, c.effsize)
                    c.abspos: newPos
                    renderComponentPosition c
                    hover.updateHoverPanelPosition()

        $(textNodeOfComponent c).startInPlaceEditing {
            before: ->
                c.dirtyText: yes;
                $(c.node).addClass 'editing';
                activateMode {
                    isInsideTextField: yes
                    debugname: "In-Place Text Edit"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                }
                componentBeingDoubleClickEdited: c
            after:  ->
                c.dirtyText: no
                $(c.node).removeClass 'editing'
                deactivateMode()
                if componentBeingDoubleClickEdited is c
                    componentBeingDoubleClickEdited: null
            accept: (newText) ->
                if newText is ''
                    newText: "Text"
                runTransaction "text change in ${friendlyComponentName c}", ->
                    c.text: newText
                    c.dirtyText: no
                    renderComponentVisualProperties c
                    realign()
            changed: ->
                realign()
        }


    ##########################################################################################################
    ##  context menu

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
        selected: (e, image) -> deleteImage image
    }


    ##########################################################################################################
    ##  Mode Engine

    modeEngine: newModeEngine {
        modeDidChange: (mode) ->
            if mode
                console.log "Mode: ${mode?.debugname}"
            else
                console.log "Mode: None"
    }
    { activateMode, deactivateMode, cancelMode, dispatchToMode, getActiveMode: activeMode }: modeEngine
    ModeMethods: {
        mouseup:      (m) -> m.mouseup
        contextmenu:  (m) -> m.contextmenu
        mousedown:    (m) -> m.mousedown
        mousemove:    (m) -> m.mousemove
        screenclick:  (m) -> m.screenclick
        escdown:      (m) -> m.escdown
    }


    ##########################################################################################################
    ##  Snapping

    class Snapping
        constructor: (magnet, anchor) ->
            @magnet: magnet
            @anchor: anchor
            @affects: magnet.affects
            @distance: Math.abs(@magnet.coord - @anchor.coord)
        isValid: ->
            @distance <= CONF_SNAPPING_DISTANCE

    Snappings: {}

    class Snappings.left extends Snapping
        apply: (rect) -> rect.x: @anchor.coord
    class Snappings.leftonly extends Snappings.left
    class Snappings.right extends Snapping
        apply: (rect) -> rect.x: @anchor.coord - rect.w
    class Snappings.rightonly extends Snappings.right
    class Snappings.xcenter extends Snapping
        apply: (rect) -> rect.x: @anchor.coord - rect.w/2

    class Snappings.top extends Snapping
        apply: (rect) -> rect.y: @anchor.coord
    class Snappings.bottom extends Snapping
        apply: (rect) -> rect.y: @anchor.coord - rect.h
    class Snappings.ycenter extends Snapping
        apply: (rect) -> rect.y: @anchor.coord - rect.h/2

    Snappings.left.snapsTo:    (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.leftonly
    Snappings.right.snapsTo:   (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.rightonly
    Snappings.xcenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.xcenter
    _([Snappings.left, Snappings.right, Snappings.xcenter]).each (s) -> s.affects: 'x'

    Snappings.top.snapsTo:     (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
    Snappings.bottom.snapsTo:  (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
    Snappings.ycenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.ycenter
    _([Snappings.top, Snappings.bottom, Snappings.ycenter]).each (s) -> s.affects: 'y'

    Anchors: {}
    class Anchors.line
        constructor: (comp, snappingClass, coord) ->
            @comp:    comp
            @coord:   coord
            @snappingClass: snappingClass
            @affects: @snappingClass.affects
        snapTo: (anchor) ->
            if @snappingClass.snapsTo anchor
                new @snappingClass(this, anchor)
            else
                null

    computeOuterAnchors: (comp, r) ->
        _.compact [
            new Anchors.line(comp, Snappings.left,    r.x)            if r.x > allowedArea.x
            new Anchors.line(comp, Snappings.right,   r.x + r.w)      if r.x+r.w < allowedArea.x+allowedArea.w
            new Anchors.line(comp, Snappings.xcenter, r.x + r.w / 2)
            new Anchors.line(comp, Snappings.top,     r.y)            if r.y > allowedArea.y
            new Anchors.line(comp, Snappings.bottom,  r.y + r.h)      if r.y+r.h < allowedArea.y+allowedArea.h
            new Anchors.line(comp, Snappings.ycenter, r.y + r.h / 2)
        ]

    computeInnerAnchors: (comp, forComp) ->
        anchors: _.flatten(computeOuterAnchors(child, rectOf(child)) for child in comp.children)
        rect: rectOf(comp)
        anchors: anchors.concat computeOuterAnchors(comp, rect)
        if comp.type.name is 'plain-row'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 8)
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 43)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8-8-10)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 43)
        if comp.type.name is 'roundrect-row'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 20)
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 55)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20-8-10)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 55)
        if comp.type.name is 'navBar'
            anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 5)
            anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 5)
        anchors

    computeMagnets: (comp, rect) -> computeOuterAnchors(comp, rect)

    computeSnappings: (anchors, magnets) ->
        snappings: []
        for magnet in magnets
            for anchor in anchors
                if snapping: magnet.snapTo anchor
                    snappings.push snapping
        snappings

    chooseSnappings: (snappings) ->
        bestx: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'x'), (s) -> s.distance)
        besty: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'y'), (s) -> s.distance)
        _.compact [bestx, besty]


    ##########################################################################################################
    ##  General Dragging

    newLiveMover: (excluded) ->
        excludedSet: setOf excluded
        traverse activeScreen.rootComponent, (c) ->
            if inSet c, excludedSet
                return skipTraversingChildren
            $(c.node).addClass 'stackable'

        {
            moveComponents: (moves) ->
                for m in moves
                    if m.comp
                        m.comps: [m.comp]
                    for c in m.comps
                        if inSet c, excludedSet
                            throw "Component ${c.type.name} cannot be moved because it has been excluded!"
                componentSet: setOf _.flatten(m.comps for m in moves)

                traverse activeScreen.rootComponent, (c) ->
                    if inSet c, excludedSet
                        return skipTraversingChildren
                    if inSet c, componentSet
                        return skipTraversingChildren
                    if c.dragpos
                        c.dragpos: null
                        c.dragsize: null
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c

                for m in moves
                    for c in m.comps
                        $(c.node).addClass 'stacked'
                        offset: m.offset || subPtPt(m.abspos, c.abspos)
                        traverse c, (child) ->
                            child.dragpos: { x: child.abspos.x + offset.x; y: child.abspos.y + offset.y }
                            child.dragsize: m.size || null
                            child.dragParent: child.parent
                            componentPositionChangedWhileDragging child

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
                        c.dragsize: null
                        c.dragParent: null
                        $(c.node).removeClass 'stacked'
                        componentPositionChangedWhileDragging c

            commit: (delay) ->
                traverse activeScreen.rootComponent, (c) ->
                    if c.dragpos
                        c.abspos = c.dragpos
                        if c.dragsize
                            c.size: c.dragsize
                        c.dragpos: null
                        c.dragsize: null
                        c.dragParent: null
                        componentPositionChangedPernamently c

                cleanup: -> $('.component').removeClass 'stackable'
                if delay? then setTimeout(cleanup, delay) else cleanup()
        }

    startDragging: (comp, options, initialMoveOptions) ->
        origin: $('#design-area').offset()

        if comp.inDocument
            originalR: rectOf comp

        computeHotSpot: (pt) ->
            r: rectOf comp
            {
                x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
                y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
            }
        hotspot: options.hotspot || computeHotSpot(options.startPt)
        liveMover: newLiveMover [comp]
        wasAnchored: no
        anchoredTransitionChangeTimeout: new Timeout STACKED_COMP_TRANSITION_DURATION

        $(comp.node).addClass 'dragging'

        updateRectangleAndClipToArea: (pt) ->
            r: sizeOf comp
            r.x: pt.x - origin.left - r.w * hotspot.x
            r.y: pt.y - origin.top  - r.h * hotspot.y
            unsnappedRect: dupRect r

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

            [r, unsnappedRect, insideArea.x && insideArea.y]

        moveTo: (pt, moveOptions) ->
            [rect, unsnappedRect, ok] = updateRectangleAndClipToArea(pt)

            if ok
                if effect: computeDropEffect comp, rect, moveOptions
                    { target, isAnchored, rect, moves }: effect
                else
                    ok: no
                    moves: []
            else
                { moves }: computeDeletionEffect comp

            unless ok
                rect: unsnappedRect

            $(comp.node)[if ok then 'removeClass' else 'addClass']('cannot-drop')
            liveMover.moveComponents moves

            comp.dragpos = { x: rect.x, y: rect.y }
            comp.dragsize: { w: rect.w, h: rect.h }
            comp.dragParent: null

            if wasAnchored and not isAnchored
                anchoredTransitionChangeTimeout.set -> $(comp.node).removeClass 'anchored'
            else if isAnchored and not wasAnchored
                anchoredTransitionChangeTimeout.clear()
                $(comp.node).addClass 'anchored'
            wasAnchored = isAnchored

            componentPositionChangedWhileDragging comp

            if ok then { target: target } else null

        dropAt: (pt, moveOptions) ->
            $(comp.node).removeClass 'dragging'

            if res: moveTo pt, moveOptions
                effects: []
                if comp.type is Types['image'] and res.target.type.supportsImageReplacement
                    effects.push newSetImageEffect(res.target, comp)
                else
                    effects.push newDropOnTargetEffect(comp, res.target, originalSize, originalEffSize)
                for e in effects
                    e.apply()
                liveMover.commit()
                containerChildrenChanged comp.parent
                true
            else
                comp.dragpos: null
                comp.dragsize: null
                comp.dragParent: null
                liveMover.commit()
                false

        cancel: ->
            $(comp.node).removeClass 'dragging cannot-drop'
            liveMover.rollback()

        if comp.node.parentNode
            comp.node.parentNode.removeChild(comp.node)
        activeScreen.rootComponent.node.appendChild(comp.node)

        # we might have just added a new component
        updateEffectiveSizesInHierarchy comp
        relayoutHierarchy comp

        originalSize: comp.size
        originalEffSize: comp.effsize

        moveTo(options.startPt, initialMoveOptions)

        { moveTo, dropAt, cancel }


    ##########################################################################################################
    ##  Layouts & Effects Computation

    class Layout
        constructor: (target) ->
            @target: target

    class PinnedLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            pin: comp.type.pin
            rect: pin.computeRect allowedArea, comp, (otherPin) =>
                for child in @target.children
                    if child.type.pin is otherPin
                        return rectOf(child)
                null
            moves: []
            for dependantPin in pin.dependantPins
                for child in @target.children
                    if child.type.pin is dependantPin
                        newRect: child.type.pin.computeRect allowedArea, child, (otherPin) =>
                            return rect if otherPin is pin
                            for otherChild in @target.children
                                if otherChild.type.pin is otherPin
                                    return rectOf(otherChild)
                            null
                        moves.push { comp: child, abspos: newRect }
            { isAnchored: yes, rect, moves }

        computeDuplicationEffect: (oldComp, newComp) ->
            if oldComp is newComp
                # this is a paste op
                return { rect: rectOf(newComp), moves: [] }
            null

        computeDeletionEffect: (comp) ->
            pin: comp.type.pin
            moves: []
            for dependantPin in pin.dependantPins
                for child in @target.children
                    if child.type.pin is dependantPin
                        newRect: child.type.pin.computeRect allowedArea, child, (otherPin) =>
                            return null if otherPin is pin
                            for otherChild in @target.children
                                if otherChild.type.pin is otherPin
                                    return rectOf(otherChild)
                            null
                        moves.push { comp: child, abspos: newRect }
            { moves }

        relayout: -> throw "Unsupported operation: unreachable at the moment"

    class ContainerDeterminedLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, rect
            itemRects: @target.type.layoutChildren newChildren, rectOf(@target)
            { rect, moves }: computeDropEffectFromNewRects newChildren, itemRects, comp
            { isAnchored: yes, rect, moves }

        computeDuplicationEffect: (oldComp, newComp) ->
            newChildren: newItemsForHorizontalStackDuplication @target.children, oldComp, newComp
            itemRects: @target.type.layoutChildren newChildren, rectOf(@target)
            computeDropEffectFromNewRects newChildren, itemRects, newComp

        computeDeletionEffect: (comp) ->
            newChildren: newItemsForHorizontalStack @target.children, comp, null
            itemRects: @target.type.layoutChildren newChildren, rectOf(@target)
            { moves }: computeDropEffectFromNewRects newChildren, itemRects, comp

        relayout: ->
            children: _(@target.children).sortBy (child) -> child.abspos.x
            itemRects: @target.type.layoutChildren children, rectOf(@target)
            computeDropEffectFromNewRects children, itemRects, null

    class RegularLayout extends Layout

        computeDropEffect: (comp, rect, moveOptions) ->
            stacking: Mockko.stacking.handleStacking comp, rect, allStacks
            if stacking.targetRect?
                { isAnchored: yes, rect: stacking.targetRect, moves: stacking.moves }
            else
                anchors: _(computeInnerAnchors(@target, comp)).reject (a) -> comp == a.comp
                magnets: computeMagnets(comp, rect)
                snappings: computeSnappings(anchors, magnets)

                unless moveOptions.disableSnapping
                    snappings: chooseSnappings snappings
                    for snapping in snappings
                        snapping.apply rect

                { isAnchored: no, rect, moves: [] }

        computeDuplicationEffect: (oldComp, newComp) ->
            rect: rectOf(oldComp)
            rect.y += rect.h
            stacking: Mockko.stacking.handleStacking oldComp, rect, allStacks, 'duplicate'

            if stacking.targetRect
                return { rect: stacking.targetRect, moves: stacking.moves }
            else
                usableBounds: rectOf activeScreen.rootComponent

                rect: rectOf(oldComp)
                while rect.x+rect.w <= usableBounds.x+usableBounds.w - DUPLICATE_COMPONENT_MIN_EDGE_INSET_X
                    found: findComponentOccupyingRect activeScreen.rootComponent, rect
                    return { rect, moves: [] } unless found
                    rect.x += found.effsize.w + DUPLICATE_COMPONENT_OFFSET_X

                rect: rectOf(oldComp)
                while rect.y+rect.h <= usableBounds.y+usableBounds.h - DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y
                    found: findComponentOccupyingRect activeScreen.rootComponent, rect
                    return { rect, moves: [] } unless found
                    rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y

                # when everything else fails, just pick a position not occupied by exact duplicate
                rect: rectOf(oldComp)
                while rect.y+rect.h <= usableBounds.y+usableBounds.h
                    found: no
                    traverse activeScreen.rootComponent, (c) -> found: c if c.abspos.x == rect.x && c.abspos.y == rect.y
                    # handle (0,0) case
                    found: null if found is activeScreen.rootComponent
                    return { rect, moves: [] } unless found
                    rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y
                return null

        computeDeletionEffect: (comp) ->
            { moves: [] }

        relayout: ->
            #

    class TableRowLayout extends RegularLayout
        #

    computeContainerLayout: (container) ->
        if container.type.layoutChildren
            new ContainerDeterminedLayout(container)
        else
            new RegularLayout(container)

    # either target or rect is specified
    computeLayout: (comp, target, rect) ->
        return null unless target? or rect?

        if pin: comp.type.pin
            new PinnedLayout(activeScreen.rootComponent)
        else if comp.type.isTableRow
            new TableRowLayout(activeScreen.rootComponent)
        else if comp.type.name is 'tab-bar-item'
            if target: findChildByType(activeScreen.rootComponent, Types['tabBar'])
                new ContainerDeterminedLayout(target)
            else
                null
        else if (target and target.type.name is 'toolbar') or (rect and (target: findComponentByTypeIntersectingRect(activeScreen.rootComponent, Types['toolbar'], rect, setOf [comp])))
            new ContainerDeterminedLayout(target)
        else
            unless target
                for possibleType in comp.type.allowedContainers || []
                    if target: findComponentByTypeIntersectingRect activeScreen.rootComponent, Types[possibleType], rect, setOf [comp]
                        break
                unless target
                    target: findBestTargetContainerForRect activeScreen.rootComponent, rect, [comp]
            if target
                computeContainerLayout target
            else
                null

    computeDropEffect: (comp, rect, moveOptions) ->
        if comp.type.name is 'image' and (target: findComponentByTypeIntersectingRect(activeScreen.rootComponent, Types['tab-bar-item'], rect, setOf [comp]))
            return { target, moves: [], isAnchored: yes, rect: centerSizeInRect(comp.effsize, rectOf target) }

        if layout: computeLayout comp, null, rect
            if comp.type.singleInstance
                for child in layout.target.children
                    if child.type is comp.type
                        return null

            eff: layout.computeDropEffect comp, rect, moveOptions
            eff.target: layout.target
            return eff
        else
            return null

    computeDuplicationEffect: (newComp, oldComp) ->
        oldComp ||= newComp
        if layout: computeLayout(oldComp, oldComp.parent)
            layout.computeDuplicationEffect oldComp, newComp
        else
            null

    computeDeletionEffect: (comp) ->
        return { moves: [] } unless comp.parent

        if layout: computeLayout comp, comp.parent
            layout.computeDeletionEffect comp
        else
            { moves: [] }


    ##########################################################################################################
    ##  Dragging Specifics


    newDropOnTargetEffect: (c, target, originalSize, originalEffSize) ->
        {
            apply: ->
                if c.parent != target
                    _(c.parent.children).removeValue c  if c.parent
                    c.parent = target
                    c.parent.children.push c

                if c.node.parentNode
                    c.node.parentNode.removeChild(c.node)
                c.parent.node.appendChild(c.node)

                if c.dragsize
                    c.size: {
                        w: if c.dragsize.w is originalEffSize.w then originalSize.w else c.dragsize.w
                        h: if c.dragsize.h is originalEffSize.h then originalSize.h else c.dragsize.h
                    }
                shift: ptDiff c.dragpos, c.abspos
                traverse c, (cc) -> cc.abspos: ptSum cc.abspos, shift
                c.dragpos: null
                c.dragsize: null
                c.dragParent: null

                traverse c, (child) -> child.inDocument: yes

                componentPositionChangedPernamently c
        }

    newSetImageEffect: (target, c) ->
        {
            apply: ->
                target.image: c.image
                $(c.node).remove()
                renderComponentVisualProperties target
        }

    computeMoveOptions: (e) ->
        {
            disableSnapping: !!e.ctrlKey
        }

    activateExistingComponentDragging: (c, startPt) ->
        dragger: null

        window.status = "Dragging a component."

        activateMode {
            debugname: "Existing Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->

                pt: { x: e.pageX, y: e.pageY }
                if dragger is null
                    return if Math.abs(pt.x - startPt.x) <= 1 and Math.abs(pt.y - startPt.y) <= 1
                    undo.beginTransaction "movement of ${friendlyComponentName c}"
                    dragger: startDragging c, { startPt: startPt }, computeMoveOptions(e)
                    $('#hover-panel').hide()
                dragger.moveTo pt, computeMoveOptions(e)
                true

            mouseup: (e) ->
                if dragger isnt null
                    if dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                        undo.endTransaction()
                        componentsChanged()
                        $('#hover-panel').show()
                    else
                        undo.abandonTransaction()
                        deleteComponent c
                deactivateMode()

                true

            cancel: ->
                if dragger isnt null
                    dragger.cancel()
                    undo.rollbackTransaction()
                c.dragsize: null
                c.dragpos: null
                c.dragParent: null
                componentPositionChangedWhileDragging c
        }

    activateNewComponentDragging: (startPt, c, e) ->
        undo.beginTransaction "creation of ${friendlyComponentName c}"
        cn: renderInteractiveComponentHeirarchy c

        dragger: startDragging c, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }, computeMoveOptions(e)

        window.status = "Dragging a new component."

        activateMode {
            debugname: "New Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                true

            mouseup: (e) ->
                ok: dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                if ok
                    undo.endTransaction()
                    componentsChanged()
                else
                    $(c.node).fadeOut 250, ->
                        $(c.node).remove()
                    undo.rollbackTransaction()
                deactivateMode()
                true

            cancel: ->
                $(c.node).fadeOut 250, ->
                    $(c.node).remove()
                    undo.rollbackTransaction()
        }

    startResizing: (comp, startPt, options) ->
        originalSize: comp.size
        baseSize: comp.effsize
        console.log "base size:"
        console.log baseSize
        originalPos: comp.abspos
        {
            moveTo: (pt) ->
                delta: ptDiff(pt, startPt)
                newPos: {}
                newSize: {}
                console.log options
                minimumSize: comp.type.minimumSize || { w: 4, h: 4 }

                maxSizeDecrease: { x: baseSize.w - minimumSize.w; y : baseSize.h - minimumSize.h }

                maxSizeIncrease: { x: INF; y: INF }
                maxSizeIncrease.x: switch options.hmode
                    when 'l' then originalPos.x - allowedArea.x
                    else          allowedArea.x+allowedArea.w - (originalPos.x+baseSize.w)
                maxSizeIncrease.y: switch options.vmode
                    when 't' then originalPos.y - allowedArea.y
                    else          allowedArea.y+allowedArea.h - (originalPos.y+baseSize.h)

                switch options.hmode
                    when 'l' then delta.x: Math.max(-maxSizeIncrease.x, Math.min( maxSizeDecrease.x, delta.x))
                    else          delta.x: Math.min( maxSizeIncrease.x, Math.max(-maxSizeDecrease.x, delta.x))
                switch options.vmode
                    when 't' then delta.y: Math.max(-maxSizeIncrease.y, Math.min( maxSizeDecrease.y, delta.y))
                    else          delta.y: Math.min( maxSizeIncrease.y, Math.max(-maxSizeDecrease.y, delta.y))

                [newSize.w, newPos.x]: switch
                    when delta.w is 0 or options.hmode is 'c' then [originalSize.w, originalPos.x]
                    when options.hmode is 'r' then [baseSize.w + delta.x, originalPos.x]
                    when options.hmode is 'l' then [baseSize.w - delta.x, originalPos.x + delta.x]
                    else throw "Internal Error: unknown resize hmode ${options.hmode}"
                [newSize.h, newPos.y]: switch
                    when delta.h is 0 or options.vmode is 'c' then [originalSize.h, originalPos.y]
                    when options.vmode is 'b' then [baseSize.h + delta.y, originalPos.y]
                    when options.vmode is 't' then [baseSize.h - delta.y, originalPos.y + delta.y]
                    else throw "Internal Error: unknown resize vmode ${options.vmode}"
                comp.size: newSize
                comp.dragpos: newPos
                comp.dragParent: comp.parent
                console.log "resizing to ${comp.size.w} x ${comp.size.h}"
                updateEffectiveSize comp
                renderComponentPosition comp
                hover.updateHoverPanelPosition()
                relayoutHierarchy comp

            dropAt: (pt) ->
                @moveTo pt
                comp.abspos: comp.dragpos
                comp.dragpos: null
                comp.dragParent: null
        }

    activateResizingMode: (comp, startPt, options) ->
        undo.beginTransaction "resizing of ${friendlyComponentName comp}"
        console.log "activating resizing mode for ${friendlyComponentName comp}"
        resizer: startResizing comp, startPt, options
        activateMode {
            debugname: "Resizing"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                resizer.moveTo { x:e.pageX, y:e.pageY }
                true
            mouseup: (e) ->
                resizer.dropAt { x:e.pageX, y:e.pageY }
                undo.endTransaction()
                componentsChanged()
                deactivateMode()
                true
            cancel: ->
                undo.rollbackTransaction()
        }


    ##########################################################################################################
    ##  Mouse Event Handling

    defaultMouseDown: (e, comp) ->
        if comp
            selectComponent comp
            if not comp.type.unmovable
                activateExistingComponentDragging comp, { x: e.pageX, y: e.pageY }
        else
            deselectComponent()
        true

    defaultMouseMove: (e, comp) ->
        if comp
            hover.componentHovered comp
        else if $(e.target).closest('.hover-panel').length
            #
        else
            hover.componentUnhovered()
        true

    defaultContextMenu: (e, comp) ->
        if comp then showComponentContextMenu comp, { x: e.pageX, y: e.pageY }; true
        else         false

    defaultMouseUp: (e, comp) -> false

    $('#design-pane, #link-overlay').bind {
        mousedown: (e) ->
            if e.button is 0
                comp: findComponentByEvent(e)
                e.preventDefault(); e.stopPropagation()
                dispatchToMode(ModeMethods.mousedown, e, comp) || defaultMouseDown(e, comp)
            undefined

        mousemove: (e) ->
            comp: findComponentByEvent(e)
            e.preventDefault(); e.stopPropagation()
            dispatchToMode(ModeMethods.mousemove, e, comp) || defaultMouseMove(e, comp)
            undefined

        mouseup: (e) ->
            comp: findComponentByEvent(e)
            if e.which is 3
                return if e.shiftKey
                e.stopPropagation()
            else
                handled: dispatchToMode(ModeMethods.mouseup, e, comp) || defaultMouseUp(e, comp)
                e.preventDefault() if handled
            undefined

        'dblclick': (e) ->
            comp: findComponentByEvent(e)
            if comp
                return if componentBeingDoubleClickEdited is comp
                handleComponentDoubleClick comp; false

        'contextmenu': (e) ->
            return if e.shiftKey
            comp: findComponentByEvent(e)
            console.log ["contextmenu", e]
            setTimeout (-> dispatchToMode(ModeMethods.contextmenu, e, comp) || defaultContextMenu(e, comp)), 1
            false
    }

    $('body').mouseup (e) ->
        # console.log "mouseup on document"
        cancelMode() if activeMode()?.cancelOnMouseUp

    $(document).mouseout (e) ->
        if e.target is document.documentElement
            # console.log "mouseout on window"
            cancelMode() if activeMode()?.cancelOnMouseUp

    ##########################################################################################################
    ##  palette

    customImages: {}

    bindPaletteItem: (item, compTemplate) ->
        $(item).mousedown (e) ->
            if e.which is 1
                e.preventDefault()
                c: cloneTemplateComponent compTemplate
                activateNewComponentDragging { x: e.pageX, y: e.pageY }, c, e

    renderPaletteGroupContent: (ctg, group, func) ->
        $('<div />').addClass('header').html(ctg.name).appendTo(group)
        ctg.itemsNode: items: $('<div />').addClass('items').appendTo(group)
        func ||= ((ct, n) ->)
        for compTemplate in ctg.items
            c: cloneTemplateComponent(ser.externalizePaletteComponent(compTemplate))
            n: renderPaletteComponentHierarchy c
            $(n).attr('title', compTemplate.label || c.type.label)
            $(n).addClass('item').appendTo(items)
            updateEffectiveSizesInHierarchy c
            relayoutHierarchy c
            bindPaletteItem n, ser.externalizePaletteComponent(compTemplate)
            func compTemplate, n

    renderPaletteGroup: (ctg, permanent) ->
        group: $('<div />').addClass('group').appendTo($('#palette-container'))
        renderPaletteGroupContent ctg, group
        if not permanent
            group.addClass('transient-group')
        group

    constrainImageSize: (imageSize, maxSize) ->
      if imageSize.w <= maxSize.w and imageSize.h <= maxSize.h
        imageSize
      else
        # need to scale up this number of times
        ratio: { x: maxSize.w / imageSize.w ; y: maxSize.h / imageSize.h }
        if ratio.x > ratio.y
          { h: maxSize.h; w: imageSize.w * ratio.y }
        else
          { w: maxSize.w; h: imageSize.h * ratio.x }

    updateCustomImagesPalette: ->
        $('.transient-group').remove()
        for group_id, group of customImages
            ensureImageGroupLoaded group_id
            group.items: []
            for image in group.images
                i: {
                    type: 'image'
                    label: "${image.fileName} ${image.width}x${image.height}"
                    image: { name: image.fileName, group: group_id }
                    # TODO landscape
                    size: constrainImageSize { w: image.width, h: image.height }, { w: 320, h: 480 }
                    imageEl: image
                }
                if group.effect
                    i.style = { imageEffect: group.effect }
                    i.size = imageSizeForImage i, group.effect
                group.items.push(i)
            renderPaletteGroup group, false
            renderPaletteGroupContent group, group.element, (item, node) ->
                item.imageEl.node: node
                $(node).bindContextMenu '#custom-image-context-menu', item.imageEl

    addCustomImagePlaceholder: ->
        # FIXME: draw this placeholder in proper place
        #$(customImagesPaletteCategory.itemsNode).append $("<div />", { className: 'customImagePlaceholder' })
        $('#palette').scrollToBottom()

    paletteInitialized: no
    initPalette: ->
        return if paletteInitialized
        paletteInitialized: yes

        for ctg in Mockko.paletteDefinition
            renderPaletteGroup ctg, true
        updateCustomImagesPalette()


    ##########################################################################################################
    ##  Screen List

    renderScreenComponents: (screen, node) ->
        cn: renderStaticComponentHierarchy screen.rootComponent
        renderComponentPosition screen.rootComponent, cn
        $(node).append(cn)

    renderScreen: (screen) ->
        sn: screen.node: domTemplate 'app-screen-template'
        $(sn).setdata('makeapp.screen', screen)
        rerenderScreenContent screen
        sn

    renderScreenRootComponentId: (screen) ->
        $(screen.rootComponent.node).attr('id', 'screen-' + encodeNameForId(screen.name))

    renderScreenName: (screen) ->
        $('.caption', screen.node).html screen.name
        renderScreenRootComponentId screen

    rerenderScreenContent: (screen) ->
        $(screen.node).find('.component').remove()
        renderScreenName screen
        renderScreenComponents screen, $('.content .rendered', screen.node)

    bindScreen: (screen) ->
        $(screen.node).bindContextMenu '#screen-context-menu', screen
        $('.content', screen.node).click (e) ->
            if e.which is 1
                if not dispatchToMode ModeMethods.screenclick, screen
                    switchToScreen screen
                false
        $('.caption', screen.node).click -> startRenamingScreen screen

    updateScreenList: ->
        $('#screens-list > .app-screen').remove()
        _(application.screens).each (screen, index) ->
            appendRenderedScreenFor screen

    updateActionsDueToScreenRenames: (renames) ->
        for screen in application.screens
            traverse screen.rootComponent, (comp) ->
                if comp.action && comp.action.action is Mockko.actions.switchScreen
                        if newName: renames[comp.action.screenName]
                            comp.action.screenName: newName
                            componentActionChanged comp

    keepingScreenNamesNormalized: (func) ->
        _(application.screens).each (screen, index) -> screen.originalName: screen.name; screen.nameIsBasedOnIndex: (screen.name is "Screen ${index+1}")
        func()
        # important to execute all renames at once to handle numbered screens ("Screen 1") being swapped
        renames: {}
        _(application.screens).each (screen, index) ->
            screen.name: "Screen ${index+1}" if screen.nameIsBasedOnIndex or not screen.name?
            if screen.name isnt screen.originalName
                renames[screen.originalName]: screen.name
            delete screen.nameIsBasedOnIndex if screen.nameIsBasedOnIndex?
            delete screen.originalName if screen.originalName?
        updateActionsDueToScreenRenames renames

    addScreenWithoutTransaction: ->
        screen: ser.internalizeScreen {
            rootComponent: DEFAULT_ROOT_COMPONENT
        }
        keepingScreenNamesNormalized ->
            application.screens.push screen
        appendRenderedScreenFor screen
        switchToScreen screen

    addScreen: ->
        runTransaction "creation of a new screen", ->
            addScreenWithoutTransaction()

    startRenamingScreen: (screen) ->
        return if activeMode()?.screenBeingRenamed is screen
        $('.caption', screen.node).startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "Screen Name Editing"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    screenBeingRenamed: screen
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                runTransaction "screen rename", ->
                    oldText: screen.name
                    screen.name: newText
                    renames: {}
                    renames[oldText]: newText
                    updateActionsDueToScreenRenames renames
                    renderScreenName screen
        }
        return false

    deleteScreen: (screen) ->
        pos: application.screens.indexOf(screen)
        return if pos < 0

        runTransaction "deletion of a screen", ->
            keepingScreenNamesNormalized ->
                application.screens.splice(pos, 1)
            $(screen.node).fadeOut 250, ->
                $(screen.node).remove()
            if application.screens.length is 0
                addScreenWithoutTransaction()
            else
                switchToScreen(application.screens[pos] || application.screens[pos-1])

    duplicateScreen: (oldScreen) ->
        pos: application.screens.indexOf(oldScreen)
        return if pos < 0

        screen: ser.internalizeScreen ser.externalizeScreen oldScreen
        screen.name: null

        runTransaction "duplication of a screen", ->
            keepingScreenNamesNormalized ->
                application.screens.splice pos+1, 0, screen
            appendRenderedScreenFor screen, oldScreen.node
        updateScreenList()
        switchToScreen screen

    appendRenderedScreenFor: (screen, after) ->
        renderScreen screen
        if after
            $(after).after(screen.node)
        else
            $('#screens-list').append(screen.node)
        bindScreen screen

    updateScreenPreview: (screen) ->
        rerenderScreenContent screen

    setActiveScreen: (screen) ->
        $('#screens-list > .app-screen').removeClass('active')
        $(screen.node).addClass('active')

    $('#add-screen-button').click -> addScreen(); false

    $('#rename-screen-menu-item').bind {
        selected: (e, screen) -> startRenamingScreen screen
    }
    $('#duplicate-screen-menu-item').bind {
        selected: (e, screen) -> duplicateScreen screen
    }
    $('#delete-screen-menu-item').bind {
        selected: (e, screen) -> deleteScreen screen
    }

    $('#screens-list').sortable {
        items: '.app-screen'
        axis: 'y'
        distance: 5
        opacity: 0.8
        update: (e, ui) ->
            runTransaction "reordering screens", ->
                keepingScreenNamesNormalized ->
                    screens: _($("#screens-list .app-screen")).map (sn) -> $(sn).getdata('makeapp.screen')
                    application.screens: screens
                updateScreenList()
    }


    ##########################################################################################################
    ##  Active Screen / Application

    switchToScreen: (screen) ->
        setActiveScreen screen

        $('#design-area .component').remove()

        activeScreen = screen

        devicePanel: $('#device-panel')[0]
        allowedArea: {
            x: 0
            y: 0
            w: 320
            h: 480
        }

        $('#design-area').append renderInteractiveComponentHeirarchy activeScreen.rootComponent
        renderScreenRootComponentId screen

        updateEffectiveSizesInHierarchy activeScreen.rootComponent
        relayoutHierarchy activeScreen.rootComponent
        componentsChanged()

        deselectComponent()
        hover.componentUnhovered()

    loadImageGroupsUsedInApplication: (app) ->
        # load all used image groups
        for screen in app.screens
            traverse screen.rootComponent, (c) ->
                if c.image?
                    ensureImageGroupLoaded c.image.group

    loadApplication: (app, appId) ->
        app.name: createNewApplicationName() unless app.name
        applicationId: appId
        application: app
        setupUndoSystem()
        reloadApplication app
        switchToScreen application.screens[0]

    reloadApplication: (app) ->
        application: app
        renderApplicationName()
        loadImageGroupsUsedInApplication app
        updateScreenList()

    saveApplicationChanges: (callback) ->
        snapshotForSimulation activeScreen
        serverMode.saveApplicationChanges ser.externalizeApplication(application), applicationId, (newId) ->
            applicationId: newId
            if callback then callback()

    renderApplicationName: ->
        $('#app-name-content').html(application.name)

    $('#app-name-content').click ->
        return if activeMode()?.isAppRenamingMode
        $('#app-name-content').startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "App Name Editing"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    isAppRenamingMode: yes
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                runTransaction "application rename", ->
                    application.name: newText
        }
        false

    ##########################################################################################################
    ##  Share (stub implementation)

    updateSharePopover: ->
        s: JSON.stringify(ser.externalizeApplication(application))
        $('#share-popover textarea').val(s)

    toggleSharePopover: ->
        if $('#share-popover').is(':visible')
            $('#share-popover').hidePopOver()
        else
            $('#share-popover').showPopOverPointingTo $('#run-button')
            updateSharePopover()

    checkApplicationLoading: ->
        v: $('#share-popover textarea').val()
        s: JSON.stringify(ser.externalizeApplication(application))

        good: yes
        if v != s && v != ''
            try
                app: JSON.parse(v)
            catch e
                good: no
            loadApplication ser.internalizeApplication(app), applicationId if app
        $('#share-popover textarea').css('background-color', if good then 'white' else '#ffeeee')
        undefined

    for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
        $('#share-popover textarea').bind event, checkApplicationLoading

    ##########################################################################################################
    ## inspector

    $('.tab').click ->
        $('.tab').removeClass 'active'
        $(this).addClass 'active'
        $('.pane').removeClass 'active'
        $('#' + this.id.replace('-tab', '-pane')).addClass 'active'
        false

    activateInspector: (name) ->
        $("#insp-${name}-tab").trigger 'click'

    activateInspector 'backgrounds'

    fillInspector: ->
        fillBackgroundsInspector()

    updateInspector: ->
        updateBackgroundsInspector()
        updatePositionInspector()
        updateTextInspector()
        updateActionInspector()

    bindBackground: (swatch, bg) ->
        bindStyleChangeButton swatch, (c, style) ->
            style.background: bg.name
            "setting background of comp to ${bg.label}"

    fillBackgroundsInspector: ->
        $pal: $('#backgrounds-palette')
        for bg in Mockko.backgroundStyles
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

    formatHexColor: (color) ->
        if (m: color.match(/^\s*([a-hA-H0-9]{6})\s*$/)) or (m: color.match(/^\s*#([a-hA-H0-9]{6})\s*/))
            return m[1].toLowerCase()
        if (m: color.match(/^\s*([a-hA-H0-9]{3})\s*$/)) or (m: color.match(/^\s*#([a-hA-H0-9]{3})\s*/))
            return (m[1][0] + m[1][0] + m[1][1] + m[1][1] + m[1][2] + m[1][2]).toLowerCase()
        return null

    updateTextInspector: ->
        pixelSize: null
        textStyleEditable: no
        bold: no
        italic: no
        textColor: null
        if c: componentToActUpon()
            tn: textNodeOfComponent c
            if tn
                cs: getComputedStyle(tn, null)
                pixelSize: parseInt cs.fontSize
                bold: cs.fontWeight is 'bold'
                italic: cs.fontStyle is 'italic'
                textColor: if c.style.textColor then formatHexColor c.style.textColor else null
            textStyleEditable: c.type.textStyleEditable
        $('#pixel-size-label').html(if pixelSize then "${pixelSize} px" else "")
        $('#insp-text-pane li')[if textStyleEditable then 'removeClass' else 'addClass']('disabled')
        $('#text-bold')[if bold then 'addClass' else 'removeClass']('active')
        $('#text-italic')[if italic then 'addClass' else 'removeClass']('active')
        if textColor is null
            $('#text-color-input').attr('disabled', 'disabled')
        else
            $('#text-color-input').removeAttr('disabled')
        $('#text-color-input').val(textColor || '') unless activeMode()?.isTextColorEditingMode
        $('#pick-color-button').alterClass('disabled', textColor is null or !textStyleEditable)
        $('#pick-color-swatch').css 'background-color', (if textColor then '#'+textColor else 'transparent')
        setColorToPicker(textColor) if textColor
        if textColor is null and $('#color-picker').is(':visible')
            $('#color-picker').hide()

    $('#pick-color-button').click ->
        if $('#color-picker').is(':visible')
            $('#color-picker').hide()
        else if $('#pick-color-button').is(':not(.disabled)')
            offsets: {
                button: $('#pick-color-button').offset()
                pickerParent: $('#color-picker').parent().offset()
            }
            pickerSize: {
                width: $('#color-picker').outerWidth()
                height: $('#color-picker').outerHeight()
            }
            $('#color-picker').css {
                left: offsets.button.left - pickerSize.width/2  - offsets.pickerParent.left
                top:  offsets.button.top  - pickerSize.height - 10 - offsets.pickerParent.top
            }
            $('#color-picker').show()

    ignorePickerUpdates: no

    setColorToPicker: (color) ->
        ignorePickerUpdates: yes
        $.jPicker.List[0].color.active.val('hex', color)
        ignorePickerUpdates: no

    commitTextColor: (fromPicker) ->
        if (fromPicker or activeMode()?.isTextColorEditingMode) and (c: componentToActUpon())
            originalColor: $('#text-color-input').val()
            color: formatHexColor originalColor
            $('#text-color-input').alterClass('invalid', color is null)

            if color and color isnt c.style.textColor
                runTransaction "color change", ->
                    c.style.textColor: '#' + color
                renderComponentStyle c

            if fromPicker and color and color isnt originalColor
                $('#text-color-input').val(color)

            setColorToPicker(color) unless fromPicker

    initColorPicker: ->

        $('#text-color-input').livechange -> commitTextColor(false); true

        commit: (color, context) ->
            return if ignorePickerUpdates
            $('#text-color-input').val color.val('hex')
            commitTextColor(true)

        $('#color-picker').jPicker {
            images: {
                clientPath: 'static/theme/images/jpicker/'
            }
        }, commit, commit
    initColorPicker()

    $('#text-color-input').focus ->
        activateMode {
            isTextColorEditingMode: yes
            isInsideTextField: yes
            deactivated:  ->
                # $('#color-picker').hide(200)
                commitTextColor(true)
                updateTextInspector()
            cancel: -> $('#text-color-input').blur()
            mousemove: -> false
            mouseup: -> false
        }
    $('#text-color-input').blur ->
        if activeMode()?.isTextColorEditingMode
            deactivateMode()

    updateActionInspector: ->
        # enabled: no
        # current: ""
        # actionSet: no
        # actionCleared: no
        # if activeMode()?.isActionPickingMode
        #     enabled: yes
        #     current: "&larr; click on a screen in the left pane (ESC to cancel)"
        #     actionSet: yes
        # else if c: componentToActUpon()
        #     if enabled: not c.type.forbidsAction
        #         if act: c.action
        #             current: act.action.describe(act, application)
        #             actionSet: yes
        #         else
        #             current: ""
        #             actionCleared: yes
        # $('#chosen-action-label').html(current)
        # $('#set-action-button, #no-action-button')[if enabled then 'removeClass' else 'addClass']('disabled')
        # $('#set-action-button')[if actionSet then 'addClass' else 'removeClass']('active')
        # $('#no-action-button')[if actionCleared then 'addClass' else 'removeClass']('active')

    activateActionPickingMode: (c) ->
        activateMode {
            screenclick: (screen) ->
                runTransaction "action change", ->
                    c.action: Mockko.actions.switchScreen.create(screen)
                    componentActionChanged c
                    deactivateMode()
                    updateActionInspector()
            activated:   -> updateActionInspector()
            deactivated: -> updateActionInspector()
            escdown:     -> deactivateMode(); true
            mousemove:   -> true
            isActionPickingMode: yes
        }

    $('#no-action-button').click (e) ->
        cancelMode()
        if c: componentToActUpon()
            if enabled: not c.type.forbidsAction
                runTransaction "clearing action of ${friendlyComponentName c}", ->
                    c.action: null
                    componentActionChanged c
                    updateActionInspector()

    $('#set-action-button').click (e) ->
        if activeMode()?.isActionPickingMode
            deactivateMode()
        else if c: componentToActUpon()
            if enabled: not c.type.forbidsAction
                activateActionPickingMode c

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
                    runTransaction "changing style of ${friendlyComponentName c}", ->
                        s: func(c, c.style)
                        if s && s.constructor == String
                            undo.setCurrentChangeName s.replace(/\bcomp\b/, friendlyComponentName(c))
                        componentStyleChanged c
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
        "changing text shadow of comp to ${Mockko.textShadowStyles[shadowStyleName].label}"

    bindStyleChangeButton $('#shadow-none'), (c, style) -> updateShadowStyle 'none', c, style
    bindStyleChangeButton $('#shadow-dark-above'), (c, style) -> updateShadowStyle 'dark-above', c, style
    bindStyleChangeButton $('#shadow-light-below'), (c, style) -> updateShadowStyle 'light-below', c, style

    setupInspector: ->
        fillInspector()
        updateInspector()


    ##########################################################################################################
    ##  Image Upload

    uploadImage: (group, file) ->
        console.log "Uploading ${file.fileName} of size ${file.fileSize}"
        serverMode.uploadImage group, file.fileName, file, ->
            updateCustomImages()

    updateCustomImages: ->
        serverMode.loadImages (groups) ->
            for group in groups
                _updateGroup group['name'], group['images']
                gg: {
                    name: group['name'] + (if group['writeable'] then ' (drop your image files here)' else '')
                    effect: group['effect']
                    writeable: group['writeable']
                }
                gg.images: ({
                    width: img['width']
                    height: img['height']
                    fileName: img['fileName']
                } for img in group['images'])
                customImages[group['id']]: gg
            updateCustomImagesPalette()

    # Looks up group to use to drop images to after drag-and-drop
    findImageDropGroup: ->
        for groupId, groupInfo of customImages
            if groupInfo.writeable
                return groupId

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
            return unless e.dataTransfer?.files?.length
            console.log "drop"
            e.preventDefault()
            errors: []
            filesToUpload: []
            for file in e.dataTransfer.files
                if not file.fileName.match(/\.jpg$|\.png$|\.gif$/)
                    ext: file.fileName.match(/\.[^.\/\\]+$/)[1]
                    errors.push { fileName: file.fileName, reason: "${ext || 'this'} format is not supported"}
                else if file.fileSize > MAX_IMAGE_UPLOAD_SIZE
                    errors.push { fileName: file.fileName, reason: "file too big, maximum size is ${MAX_IMAGE_UPLOAD_SIZE_DESCR}"}
                else
                    filesToUpload.push file
            if errors.length > 0
                message: switch errors.length
                    when 1 then "Cannot upload ${errors[0].fileName}: ${errors[0].reason}.\n"
                    else "Cannot upload the following files:\n" + ("\t* ${e.fileName} (${e.reason})\n" for e in errors)
                if filesToUpload.length > 0
                    message += "\nThe following files WILL be uploaded: " + _(filesToUpload).map((f) -> f.fileName).join(", ")
                alert message
            dropGroup: findImageDropGroup()
            for file in filesToUpload
                addCustomImagePlaceholder()
                uploadImage dropGroup, file
            $('#palette').scrollToBottom()

    deleteImage: (image) ->
        serverMode.deleteImage image.id, ->
            $(image.node).fadeOut 250, ->
                $(image.node).remove()


    ##########################################################################################################
    ##  keyboard shortcuts

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
            moveComponentBy comp, ptMul(movement.offset, amount)

    hookKeyboardShortcuts: ->
        $('body').keydown (e) ->
            return if activeMode()?.isInsideTextField
            act: componentToActUpon()
            switch e.which
                when $.KEY_ESC then dispatchToMode(ModeMethods.escdown, e) || deselectComponent(); false
                when $.KEY_DELETE, $.KEY_BACKSPACE then deleteComponent(act) if act
                when $.KEY_ARROWUP    then moveComponentByKeyboard act, e, KB_MOVE_DIRS.up    if act
                when $.KEY_ARROWDOWN  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.down  if act
                when $.KEY_ARROWLEFT  then moveComponentByKeyboard act, e, KB_MOVE_DIRS.left  if act
                when $.KEY_ARROWRIGHT then moveComponentByKeyboard act, e, KB_MOVE_DIRS.right if act
                when 'D'.charCodeAt(0) then duplicateComponent(act) if act and (e.ctrlKey or e.metaKey)
                when 'Z'.charCodeAt(0) then undo.undoLastChange() if (e.ctrlKey or e.metaKey)

    ##########################################################################################################
    ##  Simulation (Run)

    snapshotForSimulation: (screen) ->
        if not screen.rootComponent.node?
            throw "This hack only works for the current screen"
        screen.html: screen.rootComponent.node.outerHTML

    runCurrentApplication: ->
        $('#run-screen').show()
        url: window.location.href.replace(/\/(?:dev|designer).*$/, '/').replace(/#.*$/, '') + "R" + applicationId
        console.log url
        $('#run-address-label a').attr('href', url).html(url)
        $('#run-iframe').attr 'src', url

    $('#run-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        if e.shiftKey
            toggleSharePopover()
            return
        if applicationId?
            runCurrentApplication()
        else
            saveApplicationChanges ->
                runCurrentApplication()

    $('#run-stop-button').click ->
        $('#run-screen').hide()

    ##########################################################################################################
    ##  Dashboard: Application List

    startDashboardApplicationNameEditing: (app) ->
        return if activeMode()?.appBeingRenamed is app
        $('.caption', app.node).startInPlaceEditing {
            before: ->
                activateMode {
                    isInsideTextField: yes
                    debugname: "App Name Editing (Dashboard)"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                    appBeingRenamed: app
                }
            after:  ->
                deactivateMode()
            accept: (newText) ->
                app.content.name: newText
                serverMode.saveApplicationChanges ser.externalizeApplication(app.content), app.id, (newId) ->
                    refreshApplicationList()
        }

    duplicateApplication: (app) ->
        content: ser.externalizeApplication(app.content)
        content.name: "${content.name} Copy"
        serverMode.saveApplicationChanges content, null, (newId) ->
            refreshApplicationList (newApps) ->
                freshApp: _(newApps).detect (a) -> a.id is newId
                startDashboardApplicationNameEditing freshApp

    $('#rename-application-menu-item').bind {
        selected: (e, app) -> startDashboardApplicationNameEditing app
    }
    $('#duplicate-application-menu-item').bind {
        selected: (e, app) -> duplicateApplication app
    }
    $('#delete-application-menu-item').bind {
        selected: (e, app) ->
            return unless confirm("Are you sure you want to delete ${app.content.name}?")
            deleteApplication app
    }


    ##########################################################################################################
    ##  Copy/Paste

    pasteJSON: (json) ->
        targetCont: activeScreen.rootComponent
        data: JSON.parse(json)
        if data.type then data: [data]
        newComps: (ser.internalizeComponent(c, targetCont) for c in data)
        newComps: _((if c.type is Types.background then c.children else c) for c in newComps).flatten()
        pasteComponents targetCont, newComps

    pasteComponents: (targetCont, newComps) ->
        return if newComps.length is 0
        friendlyName: if newComps.length > 1 then "${newComps.length} objects" else friendlyComponentName(newComps[0])
        runTransaction "pasting ${friendlyName}", ->
            for newComp in newComps
                newComp.parent: targetCont
                targetCont.children.push newComp
                $(targetCont.node).append renderInteractiveComponentHeirarchy newComp
                updateEffectiveSizesInHierarchy newComp
                relayoutHierarchy newComp

                effect: computeDuplicationEffect newComp
                if effect is null
                    alert "Cannot paste the components because they do not fit into the designer"
                    return
                commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION
                newRect: effect.rect

                moveComponent newComp, newRect
                if newRect.w != newComp.effsize.w or newRect.h != newComp.effsize.h
                    newComp.size: { w: newRect.w, h: newRect.h }
                traverse newComp, (child) -> renderComponentPosition child; updateEffectiveSize child

    cutComponents: (comps) ->
        comps: _((if c.type is Types.background then c.children else c) for c in comps).flatten()
        friendlyName: if comps.length > 1 then "${comps.length} objects" else friendlyComponentName(comps[0])
        runTransaction "cutting of ${friendlyName}", ->
            for comp in comps
                deleteComponentWithoutTransaction comp, false

    $(document).copiableAsText {
        gettext: -> JSON.stringify(ser.externalizeComponent(comp)) if comp: componentToActUpon()
        aftercut: -> cutComponents [comp] if comp: componentToActUpon()
        paste: (text) -> pasteJSON text
        shouldProcessCopy: -> componentToActUpon() isnt null and !activeMode()?.isInsideTextField
        shouldProcessPaste: -> !activeMode()?.isInsideTextField
    }


    ##########################################################################################################

    initComponentTypes: ->
        for typeName, ct of Types
            ct.name: typeName
            ct.style ||= {}
            if not ct.supportsBackground?
                ct.supportsBackground: 'background' of ct.style
            if not ct.textStyleEditable?
                ct.textStyleEditable: ct.defaultText?
            ct.supportsText: ct.defaultText?
            unless ct.canHazColor?
                ct.canHazColor: yes
            unless ct.canHazLink?
                ct.canHazLink: yes

    createNewApplicationName: ->
        adjs = ['Best-Selling', 'Great', 'Incredible', 'Stunning', 'Gorgeous', 'Wonderful',
            'Amazing', 'Awesome', 'Fantastic', 'Beautiful', 'Unbelievable', 'Remarkable']
        names: ("${adj} App" for adj in adjs)
        usedNames: setOf(_.compact(app.content.name for app in (applicationList || [])))
        names: _(names).reject (n) -> n of usedNames
        if names.length == 0
            "Yet Another App"
        else
            names[Math.floor(Math.random() * names.length)]

    createNewApplication: ->
        $('#design-screen').show()
        loadApplication ser.internalizeApplication(MakeApp.appTemplates.basic), null
        switchToDesign()

    bindApplication: (app, an) ->
        app.node: an
        $(an).bindContextMenu '#application-context-menu', app
        $('.content', an).click ->
            $('#design-screen').show()
            loadApplication app.content, app.id
            switchToDesign()
        $('.caption', an).click ->
            startDashboardApplicationNameEditing app
            false

    deleteApplication: (app) ->
        serverMode.deleteApplication app.id, ->
            $(app.node).fadeOut 250, ->
                $(app.node).remove()
                updateApplicationListWidth()

    updateApplicationListWidth: ->
        # 250 is the width of #sample-apps-separator
        $('#apps-list-container').css 'width', (160+60) * $('#apps-list-container .app').length + 250

    renderApplication: (appData, destination, show_name) ->
        appId: appData['id']
        app: JSON.parse(appData['body'])
        app: ser.internalizeApplication(app)
        loadImageGroupsUsedInApplication app
        an: domTemplate('app-template')
        $('.caption', $(an)).html(if show_name then app.name + ' (' + appData['nickname'] + ')' else app.name)
        renderScreenComponents(app.screens[0], $('.content .rendered', an))
        $(an).appendTo(destination)
        app: { id: appId, content: app }
        bindApplication app, an
        app

    refreshApplicationList: (callback) ->
        serverMode.loadApplications (apps) ->
            $('#apps-list .app').remove()
            applicationList: for appData in apps['apps'] when not appData['sample']
                renderApplication appData, '#apps-list-container',
                    apps['current_user'] != appData['created_by']
            $('#sample-apps-separator').detach().appendTo('#apps-list-container')
            for appData in apps['apps'].concat(Mockko.sampleApplications) when appData['sample']
                renderApplication appData, '#apps-list-container', false
            updateApplicationListWidth()
            callback(applicationList) if callback

    switchToDesign: ->
        $(".screen").hide()
        $('#design-screen').show()
        initPalette()
        deactivateMode() # if any
        adjustDeviceImagePosition()
        updateCustomImages()

    switchToDashboard: ->
        $(".screen").hide()
        $('#dashboard-screen').show()
        console.log "switchToDashboard"
        refreshApplicationList()

    $('#new-app-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        createNewApplication()

    $('#dashboard-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        switchToDashboard()

    loadDesigner: (userData) ->
        $("body").removeClass("offline-user online-user").addClass("${userData['status']}-user")
        console.log serverMode
        serverMode.adjustUI userData
        serverMode.startDesigner userData, switchToDashboard, (app) ->
            $('#design-screen').show()
            loadApplication ser.internalizeApplication(app), null
            switchToDesign()
            
        console.log "done"

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

    supportedBrowser: ->
        $.browser.webkit or window.location.href.match('[?&]nocheckbrowser')

    if not supportedBrowser()
        window.location: '/'
        return

    $(window).resize ->
        adjustDeviceImagePosition()

    hover: Mockko.setupHoverPanel {
        modeEngine
        componentActionChanged
        runTransaction
        activateResizingMode
        screens: -> application.screens
        hoveredComponentChanged: ->
            updateInspector()
    }
    setupInspector()

    if window.location.href.match /^file:/
        serverMode: Mockko.fakeServer
    else
        serverMode: Mockko.server

    initComponentTypes()
    hookKeyboardShortcuts()

    serverMode.getUserInfo (userInfo) ->
        loadDesigner userInfo
