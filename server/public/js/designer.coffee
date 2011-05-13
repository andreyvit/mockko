jQuery ($) ->

    MAX_IMAGE_UPLOAD_SIZE = 1024*1024
    MAX_IMAGE_UPLOAD_SIZE_DESCR = '1 Mb'

    DEFAULT_ROOT_COMPONENT = {
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
    } = Mockko.geom

    Types = Mockko.componentTypes
    ser = Mockko.serialization
    hover = null
    inspector = null
    layouting = Mockko.layouting
    componentTree = Mockko.componentTree

    {
        renderComponentNode
        renderComponentSize, updateEffectiveSize, updateComponentTooltip
        renderComponentPosition
        renderComponentStyle, textNodeOfComponent, childrenNodeOfComponent
        renderComponentVisualProperties, renderComponentProperties
        renderComponentHierarchy, renderComponentParentship
    } = Mockko.renderer

    {
        sizeOf, rectOf, friendlyComponentName, uidOf
        traverse, skipTraversingChildren
        compWithChildrenAndParents, isComponentOrDescendant
        findChildByType
        moveComponent
    } = Mockko.model

    { commitMoves, commitMovesImmediately, STACKED_COMP_TRANSITION_DURATION } = Mockko.applicator


    ##########################################################################################################
    ## global variables

    applicationList = null
    serverMode = null
    applicationId = null
    application = null
    activeScreen = null
    mode = null
    componentBeingDoubleClickEdited = null
    undo = null


    ##########################################################################################################
    ##  undo support

    runTransaction = (changeName, change) ->
        undo.beginTransaction changeName
        change()
        undo.endTransaction()
        componentsChanged()

    setUndoChangeComponent = (comp) ->
        undo.setUndoChangeMergeMarker uidOf(comp)

    setupUndoSystem = ->
        createApplicationMemento = ->
            JSON.stringify(ser.externalizeApplication(application))
        revertToMemento = (memento) ->
            screenIndex = _(application.screens).indexOf activeScreen
            reloadApplication ser.internalizeApplication(JSON.parse(memento))
            saveApplicationChanges()
            if application.screens.length > 0
                screenIndex = Math.max(0, Math.min(application.screens.length - 1, screenIndex))
                switchToScreen application.screens[screenIndex]
        lastUndoCommandChanged = (lastChangeDescription) ->
            $('#undo-button').alterClass('disabled', lastChangeDescription is null)
            if lastChangeDescription
                $('#undo-hint span').html lastChangeDescription
        undo = Mockko.newUndoManager createApplicationMemento, revertToMemento, saveApplicationChanges, lastUndoCommandChanged

    $('#undo-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        undo.undoLastChange()


    ##########################################################################################################
    ##  global events

    componentsChanged = ->
        componentTree.rebuildComponentTree(activeScreen.rootComponent)
        traverse activeScreen.rootComponent, (child) ->
            if child.componentTree_oldParent != child.parent
                renderComponentParentship child
                renderComponentPosition child

        if $('#share-popover').is(':visible')
            updateSharePopover()

        reassignZIndexes()

        activeScreen.allStacks = Mockko.stacking.discoverStacks(activeScreen.rootComponent)

        inspector.updateInspector()
        updateScreenPreview(activeScreen)

    componentPositionChanged = (c) ->
        renderComponentPosition c
        updateEffectiveSizesAndRelayoutHierarchy c  # only needed if size has changed -- TODO check for this
        if c is hover.currentlyHovered()
            hover.updateHoverPanelPosition()
            inspector.updatePositionInspector()

    componentStyleChanged = (c) ->
        renderComponentStyle c

    componentActionChanged = (c) ->
        renderComponentStyle c
        if selection.isSelected(c)
            inspector.updateActionInspector()
        if c is hover.currentlyHovered()
            hover.updateHoverPanelPosition()

    containerChildrenChanged = (container) ->
        sorted = _(container.children).sortBy (child) -> child.abspos.x
        if _(_(sorted).zip(container.children)).any((a, b) -> a isnt b)
            childrenNode = childrenNodeOfComponent container
            for node in (n for n in childrenNode.childNodes)
                childrenNode.removeChild node
            for node in (child.node for child in sorted)
                childrenNode.appendChild node


    ##########################################################################################################
    ##  Hit Testing

    findComponentAt = (pt) ->
        if linkOverlay = hover.currentLinkOverlay()
            if linkOverlay.justAdded
                pagePt = addPtPt(pt, ptFromNode('#design-area'))
                if (d = hover.distanceToLinkOverlay(pagePt)) < linkOverlay.safeDistance
                    return linkOverlay.comp

        result = null
        visitor = (child) ->
            rect = rectOf(child)
            hitRect = if o = child.type.hitAreaOutset then insetRect rect, { l: -o, r: -o, t: -o, b: -o } else rect
            unless ptInRect(pt, hitRect)
                return skipTraversingChildren
            result = child
            if o = child.type.hitAreaInset
                # hit the container instead of children if the mouse is within o px from its border
                hitRect = insetRect rect, { l: o, r: o, t: o, b: o }
                unless ptInRect(pt, hitRect)
                    return skipTraversingChildren

        if hovered = hover.currentlyHovered()
            rect = insetRect rectOf(hovered), { l: -7, r: -7, t: -20, b: -7 }
            if ptInRect(pt, rect)
                result = hovered
                traverse hovered, visitor
                return result

        traverse activeScreen.rootComponent, visitor
        result

    findComponentByEvent = (e) ->
        origin = ptFromLT $('#design-area').offset()
        findComponentAt subPtPt({ x: e.pageX, y: e.pageY }, origin)


    ##########################################################################################################
    ##  component management

    commonDescriptionOf = (comps) ->
        if comps.length == 0
            "zero components"
        else if comps.length == 1
            friendlyComponentName comps[0]
        else
            "#{comps.length} components"

    cloneTemplateComponent = (compTemplate) ->
        c = ser.internalizeComponent compTemplate, null
        traverse c, (comp) -> comp.inDocument = no
        return c

    deleteComponentWithoutTransaction = (rootc, animated) ->
        return if rootc.type.unmovable

        effect = layouting.computeDeletionEffect activeScreen, rootc
        stacking = Mockko.stacking.handleStacking rootc, null, activeScreen.allStacks

        commitMoves stacking.moves.concat(effect.moves), [rootc], animated && STACKED_COMP_TRANSITION_DURATION, activeScreen, componentPositionChanged

        _(rootc.parent.children).removeValue rootc
        if animated
            $(rootc.node).hide 'drop', { direction: 'down' }, 'normal', -> $(rootc.node).remove()
        else
            $(rootc.node).remove()
        containerChildrenChanged rootc.parent
        selection.deselectOnRemovalOf(rootc)
        hover.componentUnhovered() if isComponentOrDescendant hover.currentlyHovered(), rootc

    deleteComponent = (rootc) ->
        runTransaction "deletion of #{friendlyComponentName rootc}", ->
            deleteComponentWithoutTransaction rootc, true

    deleteComponents = (comps) ->
        runTransaction "deletion of #{commonDescriptionOf comps}", ->
            comps.forEach (comp) ->
                deleteComponentWithoutTransaction comp, true

    insetsToEdges = (screen, comp) ->
        r = rectOf comp
        a = screen.allowedArea
        {
            l: Math.max(0, r.x - a.x)
            t: Math.max(0, r.y - a.y)
            r: Math.max(0, (a.x+a.w) - (r.x+r.w))
            b: Math.max(0, (a.y+a.h) - (r.y+r.h))
        }

    minInsets = (a, b) ->
        return a unless b?
        return b unless a?

        l: Math.min(a.l, b.l)
        r: Math.min(a.r, b.r)
        t: Math.min(a.t, b.t)
        b: Math.min(a.b, b.b)

    moveComponentsBy = (comps, offset) ->
        insets = null
        comps.forEach (comp) ->
            insets = minInsets(insets, insetsToEdges(activeScreen, comp))
        offset = {
            x: if offset.x < 0 then -Math.min(-offset.x, insets.l) else Math.min( offset.x, insets.r)
            y: if offset.y < 0 then -Math.min(-offset.y, insets.t) else Math.min( offset.y, insets.b)
        }
        return if offset.x == 0 and offset.y == 0
        # warning: this prefix (“keyboard moving of”) is also used in designer-undo.coffee
        runTransaction "keyboard moving of #{commonDescriptionOf comps}", ->
            comps.forEach (comp) ->
                setUndoChangeComponent comp
                traverse comp, (c) -> c.abspos = ptSum(c.abspos, offset)
                traverse comp, componentPositionChanged

    duplicateComponent = (comp) ->
        return if comp.type.unmovable || comp.type.singleInstance

        newComp = ser.internalizeComponent(ser.externalizeComponent(comp), comp.parent)

        $(childrenNodeOfComponent comp.parent).append renderInteractiveComponentHeirarchy newComp
        updateEffectiveSizesAndRelayoutHierarchy newComp

        effect = layouting.computeDuplicationEffect activeScreen, newComp, comp
        if effect is null
            $(newComp.node).remove()
            alert "Cannot duplicate the component because another copy does not fit into the designer"
            return

        runTransaction "duplicate #{friendlyComponentName comp}", ->
            comp.parent.children.push newComp

            layouting.adjustChildAfterPasteOrDuplication activeScreen, newComp, newComp.parent
            renderComponentStyle newComp

            newRect = effect.rect
            if newRect.w != comp.effsize.w or newRect.h != comp.effsize.h
                newComp.size = { w: newRect.w, h: newRect.h }
            moveComponent newComp, newRect
            componentPositionChanged newComp

            commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION, activeScreen, componentPositionChanged

            containerChildrenChanged comp.parent


    ##########################################################################################################
    ##  DOM rendering

    renderStaticComponentHierarchy = (c) -> renderComponentHierarchy c, false, false
    renderPaletteComponentHierarchy = (c) -> renderComponentHierarchy c, true, false
    renderInteractiveComponentHeirarchy = (c) -> renderComponentHierarchy c, true, true

    relayoutHierarchy = (c) ->
        traverse c, (child) ->
            if effect = layouting.computeRelayoutEffect activeScreen, child
                commitMovesImmediately effect.moves, componentPositionChanged
                containerChildrenChanged child

    updateEffectiveSizesAndRelayoutHierarchy = (c) ->
        traverse c, (child) -> updateEffectiveSize child
        relayoutHierarchy c

    reassignZIndexes = ->
        traverse activeScreen.rootComponent, (comp) ->
            ordered = _(comp.children).sortBy (c) -> r = rectOf c; -r.w * r.h
            _.each ordered, (c, i) -> $(c.node).css('z-index', i)


    ##########################################################################################################
    ##  Images

    imageSizeForImage = (image, effect) ->
        return image.size unless serverMode.supportsImageEffects
        switch effect
            when 'iphone-tabbar-active'   then { w: 35, h: 35 }
            when 'iphone-tabbar-inactive' then { w: 35, h: 32 }
            else image.size

    _imageEffectName = (image, effect) ->
        splitext = /^(.*)\.([^.]+)$/
        split = splitext.exec image
        if split?
            "#{split[1]}.#{effect}.#{split[2]}"
        else
            throw "Unable to split #{image} into filename and extensions"

    #
    # UI may request URLs for many images belonging to the same image group.
    #
    # To avoid issuing sheer amount of requests to server, first call will mark
    # image group as "pending", so subsequent calls will add callback to the
    # list of "waiting for image group #{foo}". All callbacks will be executed
    # when AJAX handler is executed.
    #

    groups = {}
    pending = {}

    _returnImageUrl = (image, effect, cb) ->
        unless image.group of groups
          console.error "!!! _returnImageUrl: image group URLs not cached = #{image.group}"
          return
        if !image.name
          console.error ["!!! _returnImageUrl: image has no name: ", image]
          return
        digest = groups[image.group][image.name]
        if effect
            cb "images/#{encodeURIComponent image.group}/#{encodeURIComponent (_imageEffectName image.name, effect)}?#{digest}"
        else
            cb "images/#{encodeURIComponent image.group}/#{encodeURIComponent image.name}?#{digest}"

    _updateGroup = (groupName, group) ->
        info = {}
        for imginfo in group
            info[imginfo['fileName']] = imginfo['digest']
        groups[groupName] = info

    ensureImageGroupLoaded = (group) ->
        unless group of groups
            unless group of pending
                pending[group] = []
                serverMode.loadImageGroup group, (info) ->
                    if info
                        _updateGroup group, info['images']
                        for [image, effect, callback] in pending[group]
                            _returnImageUrl image, effect, callback
                    else
                        for [image, effect, callback] in pending[group]
                            callback null
                    delete pending[group]

    getImageUrl = (image, effect, callback) ->
        unless image.group of groups or image.group of pending
            console.error "getImageUrl - image group not loaded and not loading = #{image.group}"
            return
        if image.group of pending
            pending[image.group].push([image, effect, callback])
        else
            _returnImageUrl image, effect, callback

    # TODO: remove this hack for circular dependency on designer-rendering
    window.getImageUrl = getImageUrl


    ##########################################################################################################
    ##  selection

    initSelection = (options) ->
        { selectionDidChange } = options

        selectedComponents = []

        isSelected = (candidate) -> selectedComponents.some((comp) -> comp == candidate)

        isInSelectedHierarchy = (candidate) ->
            selectedComponents.some((comp) -> isComponentOrDescendant candidate, comp)

        renderAsSelected = (comp) ->
            $(comp.node).addClass 'selected'

        renderAsNotSelected = (comp) ->
            $(comp.node).removeClass 'selected'

        select = (comp) ->
            selectedComponents.forEach (comp) -> renderAsNotSelected(comp)
            selectedComponents = [comp]
            renderAsSelected(comp)
            selectionDidChange()

        deselect = (comp) ->
            return unless isSelected(comp)
            selectedComponents = selectedComponents.filter((c) -> c != comp)
            renderAsNotSelected(comp)
            selectionDidChange()

        deselectOnRemovalOf = (removed) ->
            oldLength = selectedComponents.length

            selectedComponents.forEach (selected) ->
                if isComponentOrDescendant(selected, removed)
                    selectedComponents = selectedComponents.filter((c) -> c != selected)
                    renderAsNotSelected(selected)

            if selectedComponents.length != oldLength
                selectionDidChange()

        toggle = (comp) ->
            if isSelected(comp)
                selectedComponents = selectedComponents.filter((c) -> c != comp)
                renderAsNotSelected comp
            else if isInSelectedHierarchy(comp)
                # do nothing
            else
                selectedComponents.push(comp)
                renderAsSelected(comp)
            selectionDidChange()

        deselectAll = ->
            return if isEmpty()
            selectedComponents.forEach (comp) -> renderAsNotSelected(comp)
            selectedComponents = []
            selectionDidChange()

        isEmpty = -> selectedComponents.length == 0

        isNonEmpty = -> selectedComponents.length > 0

        components = -> selectedComponents

        { isEmpty, isNonEmpty, select, toggle, deselectAll, deselectOnRemovalOf, isSelected, isInSelectedHierarchy, components }

    selection = initSelection
        selectionDidChange: ->
            inspector.updateInspector()

    componentToActUpon = ->
        if selection.isEmpty()
            null
        else
            selection.components()[0]

    ##########################################################################################################
    ##  double-click editing

    handleComponentDoubleClick = (c) ->
        switch c.type.name
            when 'tab-bar-item'
                runTransaction "activation of #{friendlyComponentName c}", ->
                    _(c.parent.children).each (child) ->
                        newState = if c is child then on else off
                        if child.state isnt newState
                            child.state = newState
                            componentStyleChanged child
            when 'switch'
                c.state = c.type.state unless c.state?
                newStateDesc = if c.state then 'off' else 'on'
                runTransaction "turning #{friendlyComponentName c} #{newStateDesc}", ->
                    c.state = !c.state
                    componentStyleChanged c
        startComponentTextInPlaceEditing c

    startComponentTextInPlaceEditing = (c) ->
        return unless c.type.supportsText

        if c.type.wantsSmartAlignment
            alignment = Mockko.possibleAlignmentOf(c, activeScreen).bestDefiniteGuess()
            originalRect = rectOf c

        realign = ->
            if c.type.wantsSmartAlignment
                updateEffectiveSize c
                if newPos = alignment.adjustedPosition(originalRect, c.effsize)
                    c.abspos = newPos
                    componentPositionChanged c

        $(textNodeOfComponent c).startInPlaceEditing {
            before: ->
                c.dirtyText = yes;
                $(c.node).addClass 'editing';
                activateMode {
                    isInsideTextField: yes
                    debugname: "In-Place Text Edit"
                    mousedown: -> false
                    mousemove: -> false
                    mouseup: -> false
                }
                componentBeingDoubleClickEdited = c
            after:  ->
                c.dirtyText = no
                $(c.node).removeClass 'editing'
                deactivateMode()
                if componentBeingDoubleClickEdited is c
                    componentBeingDoubleClickEdited = null
            accept: (newText) ->
                if newText is ''
                    newText = "Text"
                runTransaction "text change in #{friendlyComponentName c}", ->
                    c.text = newText
                    c.dirtyText = no
                    renderComponentVisualProperties c
                    realign()
            changed: ->
                realign()
        }


    ##########################################################################################################
    ##  context menu

    $('#delete-component-menu-item').bind {
        update:   (e, comp) -> e.enabled = !comp.type.unmovable
        selected: (e, comp) -> deleteComponent comp
    }
    $('#duplicate-component-menu-item').bind {
        update:   (e, comp) -> e.enabled = !comp.type.unmovable
        selected: (e, comp) -> duplicateComponent comp
    }
    showComponentContextMenu = (comp, pt) -> $('#component-context-menu').showAsContextMenuAt pt, comp

    $('#delete-custom-image-menu-item').bind {
        selected: (e, image) -> deleteImage image
    }


    ##########################################################################################################
    ##  Mode Engine

    modeEngine = newModeEngine {
        modeDidChange: (mode) ->
            if mode
                console.log "Mode: #{mode?.debugname}"
            else
                console.log "Mode: None"
    }
    { activateMode, deactivateMode, cancelMode, dispatchToMode, activeMode } = modeEngine
    ModeMethods = {
        mouseup:      (m) -> m.mouseup
        contextmenu:  (m) -> m.contextmenu
        mousedown:    (m) -> m.mousedown
        mousemove:    (m) -> m.mousemove
        screenclick:  (m) -> m.screenclick
        escdown:      (m) -> m.escdown
    }


    ##########################################################################################################
    ##  Dragging

    computeDropAction = (comp, target, originalSize, originalEffSize) ->
        if comp.type is Types['image'] and target.type.supportsImageReplacement
            newSetImageAction target, comp
        else
            newDropOnTargetAction comp, target, originalSize, originalEffSize

    newDropOnTargetAction = (c, target, originalSize, originalEffSize) ->
        {
            execute: ->
                if c.parent != target
                    _(c.parent.children).removeValue c  if c.parent
                    c.parent = target
                    c.parent.children.push c

                if c.node.parentNode
                    c.node.parentNode.removeChild(c.node)
                (childrenNodeOfComponent c.parent).appendChild(c.node)

                if c.dragsize
                    c.size = {
                        w: if c.dragsize.w is originalEffSize.w then originalSize.w else c.dragsize.w
                        h: if c.dragsize.h is originalEffSize.h then originalSize.h else c.dragsize.h
                    }
                shift = ptDiff c.dragpos, c.abspos
                traverse c, (cc) -> cc.abspos = ptSum cc.abspos, shift
                c.dragpos = null
                c.dragsize = null
                c.dragParent = null

                traverse c, (child) -> child.inDocument = yes

                componentPositionChanged c
        }

    newSetImageAction = (target, c) ->
        {
            execute: ->
                target.image = c.image
                $(c.node).remove()
                renderComponentVisualProperties target
        }

    computeMoveOptions = (e) ->
        {
            disableSnapping: !!e.ctrlKey
        }

    activateExistingComponentDragging = (c, startPt) ->
        dragger = null

        window.status = "Dragging a component."

        activateMode {
            debugname: "Existing Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->

                pt = { x: e.pageX, y: e.pageY }
                if dragger is null
                    return if Math.abs(pt.x - startPt.x) <= 1 and Math.abs(pt.y - startPt.y) <= 1
                    undo.beginTransaction "movement of #{friendlyComponentName c}"
                    dragger = Mockko.startDragging activeScreen, c, { startPt: startPt }, computeMoveOptions(e),
                            computeDropAction, componentPositionChanged, containerChildrenChanged, updateEffectiveSizesAndRelayoutHierarchy
                    $('#hover-panel').hide()
                dragger.moveTo pt, computeMoveOptions(e)
                true

            mouseup: (e) ->
                ok = no
                if dragger isnt null
                    if dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                        undo.endTransaction()
                        componentsChanged()
                        $('#hover-panel').show()
                        ok = yes
                    else
                        undo.abandonTransaction()
                        deleteComponent c
                deactivateMode()
                selection.select(c) if ok
                true

            cancel: ->
                if dragger isnt null
                    dragger.cancel()
                    undo.rollbackTransaction()
                c.dragsize = null
                c.dragpos = null
                c.dragParent = null
                componentPositionChanged c
        }

    activateNewComponentDragging = (startPt, c, e) ->
        undo.beginTransaction "creation of #{friendlyComponentName c}"
        cn = renderInteractiveComponentHeirarchy c

        dragger = Mockko.startDragging activeScreen, c, { hotspot: { x: 0.5, y: 0.5 }, startPt: startPt }, computeMoveOptions(e),
                computeDropAction, componentPositionChanged, containerChildrenChanged, updateEffectiveSizesAndRelayoutHierarchy

        window.status = "Dragging a new component."

        activateMode {
            debugname: "New Component Dragging"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                dragger.moveTo { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                true

            mouseup: (e) ->
                ok = dragger.dropAt { x: e.pageX, y: e.pageY }, computeMoveOptions(e)
                if ok
                    undo.endTransaction()
                    componentsChanged()
                else
                    $(c.node).fadeOut 250, ->
                        $(c.node).remove()
                    undo.rollbackTransaction()
                deactivateMode()
                selection.select(c) if ok
                startComponentTextInPlaceEditing(c) if c.type.supportsText
                true

            cancel: ->
                $(c.node).fadeOut 250, ->
                    $(c.node).remove()
                    undo.rollbackTransaction()
        }

    resizingOptionsFromEvent = (e) ->
        { toggleConstrainMode: !!e.shiftKey }

    activateResizingMode = (comp, e, options) ->
        undo.beginTransaction "resizing of #{friendlyComponentName comp}"
        console.log "activating resizing mode for #{friendlyComponentName comp}"
        startPt = { x: e.pageX, y: e.pageY }
        resizer = Mockko.startResizing activeScreen, comp, startPt, options, componentPositionChanged
        activateMode {
            debugname: "Resizing"
            cancelOnMouseUp: yes
            mousemove: (e) ->
                resizer.moveTo { x:e.pageX, y:e.pageY }, resizingOptionsFromEvent(e)
                true
            mouseup: (e) ->
                resizer.dropAt { x:e.pageX, y:e.pageY }, resizingOptionsFromEvent(e)
                undo.endTransaction()
                componentsChanged()
                deactivateMode()
                true
            cancel: ->
                undo.rollbackTransaction()
        }


    ##########################################################################################################
    ##  Mouse Event Handling

    defaultMouseDown = (e, comp) ->
        if comp
            if e.metaKey
                selection.toggle comp
            else
                selection.select comp

                if not comp.type.unmovable
                    activateExistingComponentDragging comp, { x: e.pageX, y: e.pageY }
        else
            selection.deselectAll()
        true

    defaultMouseMove = (e, comp) ->
        if comp
            hover.componentHovered comp
        else if $(e.target).closest('.hover-panel').length
            #
        else
            hover.componentUnhovered()
        true

    defaultContextMenu = (e, comp) ->
        if comp then showComponentContextMenu comp, { x: e.pageX, y: e.pageY }; true
        else         false

    defaultMouseUp = (e, comp) -> false

    $('#design-pane, #link-overlay').bind {
        mousedown: (e) ->
            if e.button is 0
                comp = findComponentByEvent(e)
                e.preventDefault(); e.stopPropagation()
                dispatchToMode(ModeMethods.mousedown, e, comp) || defaultMouseDown(e, comp)
            undefined

        mousemove: (e) ->
            comp = findComponentByEvent(e)
            e.preventDefault(); e.stopPropagation()
            dispatchToMode(ModeMethods.mousemove, e, comp) || defaultMouseMove(e, comp)
            undefined

        mouseup: (e) ->
            comp = findComponentByEvent(e)
            if e.which is 3
                return if e.shiftKey
                e.stopPropagation()
            else
                handled = dispatchToMode(ModeMethods.mouseup, e, comp) || defaultMouseUp(e, comp)
                e.preventDefault() if handled
            undefined

        'dblclick': (e) ->
            comp = findComponentByEvent(e)
            if comp
                return if componentBeingDoubleClickEdited is comp
                handleComponentDoubleClick comp; false

        'contextmenu': (e) ->
            return if e.shiftKey
            comp = findComponentByEvent(e)
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

    imageGroups = []

    bindPaletteItem = (item, compTemplate) ->
        $(item).mousedown (e) ->
            if e.which is 1
                e.preventDefault()
                c = cloneTemplateComponent compTemplate
                activateNewComponentDragging { x: e.pageX, y: e.pageY }, c, e

    renderPaletteGroupContent = (ctg, group, func) ->
        # FIXME = sometimes `group` is `undefined` (at startup)
        $('<div />').addClass('header').html(ctg.name).appendTo(group)
        if ctg.isImageGroup && ctg.writeable
            $("<div />").addClass('image-upload-prompt').html("Click to upload an image (or just drop your image files here).").appendTo(group).click (e) ->
                e.preventDefault()
                fileField = $("<input />").attr({ 'type': 'file', 'multiple': 'multiple'})[0]
                document.body.appendChild(fileField)
                fileField.click()
                $(fileField).change ->
                    console.log "Got #{fileField.files.length} files"
                    if fileField.files && fileField.files.length > 0
                        uploadFiles fileField.files, ctg, (err) ->
                            $(fileField).remove()

        ctg.itemsNode = items = $('<div />').addClass('items').appendTo(group)
        func ||= ((ct, n) ->)
        for compTemplate in ctg.items
            compTemplateForPaletteInstantiation = cloneObj compTemplate
            if compTemplateForPaletteInstantiation.paletteOverride?
                $.extend compTemplateForPaletteInstantiation, compTemplateForPaletteInstantiation.paletteOverride
            if compTemplateForPaletteInstantiation.paletteTextOverride?
                compTemplateForPaletteInstantiation.text = compTemplateForPaletteInstantiation.paletteTextOverride
            c = cloneTemplateComponent(ser.externalizePaletteComponent(compTemplateForPaletteInstantiation))
            traverse c, (comp) ->
                if comp.image?
                    ensureImageGroupLoaded comp.image.group
            n = renderPaletteComponentHierarchy c
            $(n).attr('title', compTemplate.label || c.type.label)
            $(n).addClass('item').appendTo(items)
            updateEffectiveSizesAndRelayoutHierarchy c
            bindPaletteItem n, ser.externalizePaletteComponent(compTemplate)
            func compTemplate, n

    renderPaletteGroup = (ctg, permanent, itemRenderedCallback) ->
        group = $('<div />').addClass('group').appendTo($('#palette-container'))
        ctg.node = group
        renderPaletteGroupContent ctg, group, itemRenderedCallback
        if not permanent
            group.addClass('transient-group')
        group

    constrainImageSize = (imageSize, maxSize) ->
      if imageSize.w <= maxSize.w and imageSize.h <= maxSize.h
        imageSize
      else
        # need to scale up this number of times
        ratio = { x: maxSize.w / imageSize.w ; y: maxSize.h / imageSize.h }
        if ratio.x > ratio.y
          { h: maxSize.h; w: imageSize.w * ratio.y }
        else
          { w: maxSize.w; h: imageSize.h * ratio.x }

    updateImagesPalette = ->
        $('.transient-group').remove()
        for group in imageGroups
            group.isImageGroup = yes
            group.items = []
            for image in group.images
                i = {
                    type: 'image'
                    label: "#{image.fileName} #{image.width}x#{image.height}"
                    image: { name: image.fileName, group: group.id }
                    # TODO landscape
                    size: constrainImageSize { w: image.width, h: image.height }, { w: 320, h: 480 }
                    imageEl: image
                }
                if group.effect
                    i.style = { imageEffect: group.effect }
                    i.size = imageSizeForImage i, group.effect
                group.items.push(i)
            renderPaletteGroup group, false, (item, node) ->
                item.imageEl.node = node
                if group.writeable
                    $(node).bindContextMenu '#custom-image-context-menu', item.imageEl

    addCustomImagePlaceholder = (node) ->
        $(node).append $("<div />", { className: 'customImagePlaceholder' })
        $('#palette').scrollToBottom()

    storePaletteScrollPosition = ->
        localStorage['paletteScrollOffset'] = $('#palette')[0].scrollTop

    restorePaletteScrollPosition = ->
        if offset = localStorage['paletteScrollOffset']
            $('#palette')[0].scrollTop = offset
        undefined

    paletteInitialized = no
    initPalette = ->
        return if paletteInitialized
        paletteInitialized = yes

        for ctg in Mockko.paletteDefinition
            renderPaletteGroup ctg, true
        updateImagesPalette()
        restorePaletteScrollPosition()
        $('#palette').scroll(storePaletteScrollPosition)


    ##########################################################################################################
    ##  Screen List

    renderScreenComponents = (screen, node) ->
        cn = renderStaticComponentHierarchy screen.rootComponent
        renderComponentPosition screen.rootComponent, cn
        $(node).append(cn)

    renderScreen = (screen) ->
        sn = screen.node = domTemplate 'app-screen-template'
        $(sn).setdata('makeapp.screen', screen)
        rerenderScreenContent screen
        sn

    renderScreenRootComponentId = (screen) ->
        $(screen.rootComponent.node).attr('id', 'screen-' + encodeNameForId(screen.name))

    renderScreenName = (screen) ->
        $('.caption', screen.node).html screen.name
        renderScreenRootComponentId screen

    rerenderScreenContent = (screen) ->
        $(screen.node).find('.component').remove()
        renderScreenName screen
        renderScreenComponents screen, $('.content .rendered', screen.node)

    bindScreen = (screen) ->
        $(screen.node).bindContextMenu '#screen-context-menu', screen
        $('.content', screen.node).click (e) ->
            if e.which is 1
                if not dispatchToMode ModeMethods.screenclick, screen
                    switchToScreen screen
                false
        $('.caption', screen.node).click -> startRenamingScreen screen

    updateScreenList = ->
        $('#screens-list > .app-screen').remove()
        _(application.screens).each (screen, index) ->
            appendRenderedScreenFor screen

    updateActionsDueToScreenRenames = (renames) ->
        for screen in application.screens
            traverse screen.rootComponent, (comp) ->
                if comp.action && comp.action.action is Mockko.actions.switchScreen
                        if newName = renames[comp.action.screenName]
                            comp.action.screenName = newName
                            componentActionChanged comp

    keepingScreenNamesNormalized = (func) ->
        _(application.screens).each (screen, index) -> screen.originalName = screen.name; screen.nameIsBasedOnIndex = (screen.name is "Screen #{index+1}")
        func()
        # important to execute all renames at once to handle numbered screens ("Screen 1") being swapped
        renames = {}
        _(application.screens).each (screen, index) ->
            screen.name = "Screen #{index+1}" if screen.nameIsBasedOnIndex or not screen.name?
            if screen.name isnt screen.originalName
                renames[screen.originalName] = screen.name
            delete screen.nameIsBasedOnIndex if screen.nameIsBasedOnIndex?
            delete screen.originalName if screen.originalName?
        updateActionsDueToScreenRenames renames

    addScreenWithoutTransaction = ->
        screen = ser.internalizeScreen {
            'rootComponent': DEFAULT_ROOT_COMPONENT
        }
        keepingScreenNamesNormalized ->
            application.screens.push screen
        appendRenderedScreenFor screen
        switchToScreen screen

    addScreen = ->
        runTransaction "creation of a new screen", ->
            addScreenWithoutTransaction()

    startRenamingScreen = (screen) ->
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
                    oldText = screen.name
                    screen.name = newText
                    renames = {}
                    renames[oldText] = newText
                    updateActionsDueToScreenRenames renames
                    renderScreenName screen
        }
        return false

    deleteScreen = (screen) ->
        pos = application.screens.indexOf(screen)
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

    duplicateScreen = (oldScreen) ->
        pos = application.screens.indexOf(oldScreen)
        return if pos < 0

        screen = ser.internalizeScreen ser.externalizeScreen oldScreen
        screen.name = null

        runTransaction "duplication of a screen", ->
            keepingScreenNamesNormalized ->
                application.screens.splice pos+1, 0, screen
            appendRenderedScreenFor screen, oldScreen.node
        updateScreenList()
        switchToScreen screen

    appendRenderedScreenFor = (screen, after) ->
        renderScreen screen
        if after
            $(after).after(screen.node)
        else
            $('#screens-list').append(screen.node)
        bindScreen screen

    updateScreenPreview = (screen) ->
        rerenderScreenContent screen

    setActiveScreen = (screen) ->
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
                    screens = _($("#screens-list .app-screen")).map (sn) -> $(sn).getdata('makeapp.screen')
                    application.screens = screens
                updateScreenList()
    }


    ##########################################################################################################
    ##  Active Screen / Application

    switchToScreen = (screen) ->
        setActiveScreen screen

        $('#design-area .component').remove()

        activeScreen = screen

        devicePanel = $('#device-panel')[0]

        $('#design-area').append renderInteractiveComponentHeirarchy activeScreen.rootComponent
        renderScreenRootComponentId screen

        updateEffectiveSizesAndRelayoutHierarchy activeScreen.rootComponent
        componentsChanged()

        selection.deselectAll()
        hover.componentUnhovered()

    loadImageGroupsUsedInApplication = (app) ->
        # load all used image groups
        for screen in app.screens
            traverse screen.rootComponent, (c) ->
                if c.image?
                    ensureImageGroupLoaded c.image.group

    loadApplication = (app, appId) ->
        # if design screen has display:none, many inner components get zero effective size
        $('#design-screen').show()

        app.name = createNewApplicationName() unless app.name
        applicationId = appId
        application = app
        setupUndoSystem()
        reloadApplication app
        switchToScreen application.screens[0]
        saveAppToLocationHash appId

        # Not sure why, but palette scroll offset is reset every time an application
        # is loaded from Dashboard screen. A workaround is to restore it here.
        restorePaletteScrollPosition()

    reloadApplication = (app) ->
        application = app
        renderApplicationName()
        loadImageGroupsUsedInApplication app
        updateScreenList()

    saveApplicationChanges = (callback) ->
        snapshotForSimulation activeScreen
        serverMode.saveApplicationChanges ser.externalizeApplication(application), applicationId, (newId) ->
            applicationId = newId
            if callback then callback()

    renderApplicationName = ->
        $('#app-name-content').html(application.name)

    startDesignScreenApplicationNameEditing = ->
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
                    application.name = newText
        }

    $('#app-name-content').click ->
        startDesignScreenApplicationNameEditing()
        false

    ##########################################################################################################
    ##  Share (stub implementation)

    updateSharePopover = ->
        s = JSON.stringify(ser.externalizeApplication(application))
        $('#share-popover textarea').val(s)

    toggleSharePopover = ->
        if $('#share-popover').is(':visible')
            $('#share-popover').hidePopOver()
        else
            $('#share-popover').showPopOverPointingTo $('#run-button')
            updateSharePopover()

    checkApplicationLoading = ->
        v = $('#share-popover textarea').val()
        s = JSON.stringify(ser.externalizeApplication(application))

        good = yes
        if v != s && v != ''
            try
                app = JSON.parse(v)
            catch e
                good = no
            loadApplication ser.internalizeApplication(app), applicationId if app
        $('#share-popover textarea').css('background-color', if good then 'white' else '#ffeeee')
        undefined

    for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
        $('#share-popover textarea').bind event, checkApplicationLoading


    ##########################################################################################################
    ##  Image Upload

    uploadImage = (group, file, callback) ->
        console.log "Uploading #{file.fileName} of size #{file.fileSize}"
        serverMode.uploadImage group, file.fileName, file, (err) ->
            updateImages() unless err
            callback(err)

    updateImages = ->
        serverMode.loadImages (groups) ->
            imageGroups = []
            for group in groups
                _updateGroup group['name'], group['images']
                gg = {
                    id: group['id']
                    name: group['name']
                    effect: group['effect']
                    writeable: group['writeable']
                }
                gg.images = ({
                    width: img['width']
                    height: img['height']
                    fileName: img['fileName']
                    group_id: group['id']
                } for img in group['images'])
                imageGroups.push gg
            updateImagesPalette()

    # Looks up group to use to drop images to after drag-and-drop
    # FIXME: use actual group under cursor, not first writeable.
    findImageDropGroup = ->
        for group in imageGroups
            if group.writeable
                return group

    uploadFiles = (files, dropGroup, callback) ->
        errors = []
        filesToUpload = []
        for file in files
            if not file.fileName.match(/\.jpe?g$|\.png$|\.gif$/i)
                ext = file.fileName.match(/\.[^.\/\\]+$/)[1]
                errors.push { fileName: file.fileName, reason: "#{ext || 'this'} format is not supported"}
            else if file.fileSize > MAX_IMAGE_UPLOAD_SIZE
                errors.push { fileName: file.fileName, reason: "file too big, maximum size is #{MAX_IMAGE_UPLOAD_SIZE_DESCR}"}
            else
                filesToUpload.push file
        if errors.length > 0
            message = switch errors.length
                when 1 then "Cannot upload #{errors[0].fileName}: #{errors[0].reason}.\n"
                else "Cannot upload the following files:\n" + ("\t* #{e.fileName} (#{e.reason})\n" for e in errors)
            if filesToUpload.length > 0
                message += "\nThe following files WILL be uploaded: " + _(filesToUpload).map((f) -> f.fileName).join(", ")
            alert message
        filesRemaining = filesToUpload.length
        for file in filesToUpload
            addCustomImagePlaceholder dropGroup.node
            uploadImage dropGroup, file, (err) ->
                filesRemaining -= 1
                if filesRemaining is 0
                    callback() if callback
        $('#palette').scrollToBottom()

    $('body').each ->
        this.ondragenter = (e) ->
            console.log "dragenter"
            e.preventDefault()
            e.dataTransfer.dropEffect = 'copy'
            false
        this.ondragover = (e) ->
            console.log "dragover"
            e.preventDefault()
            e.dataTransfer.dropEffect = 'copy'
            false
        this.ondrop = (e) ->
            return unless e.dataTransfer?.files?.length
            console.log "drop"
            e.preventDefault()
            uploadFiles e.dataTransfer.files, findImageDropGroup()

    deleteImage = (image) ->
        serverMode.deleteImage image.group_id, image.fileName, ->
            $(image.node).fadeOut 250, ->
                $(image.node).remove()


    ##########################################################################################################
    ##  keyboard shortcuts

    KB_MOVE_DIRS = {
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

    moveComponentsByKeyboard = (comps, e, movement) ->
        return if comps.some((comp) -> layouting.hasNonFlexiblePosition(activeScreen, comp))
        if e.ctrlKey
            # TODO = duplicate
        else
            # TODO = detect if part of stack
            amount = if e.shiftKey then 10 else 1
            moveComponentsBy comps, ptMul(movement.offset, amount)

    hookKeyboardShortcuts = ->
        $('body').keydown (e) ->
            return if e.target.tagName.toLowerCase() == 'input'
            return if activeMode()?.isInsideTextField
            sel = selection.isNonEmpty()
            switch e.which
                when $.KEY_ESC
                    e.preventDefault(); e.stopPropagation()
                    dispatchToMode(ModeMethods.escdown, e) || selection.deselectAll()
                when $.KEY_DELETE, $.KEY_BACKSPACE
                    e.preventDefault(); e.stopPropagation()
                    deleteComponents(selection.components()) if sel
                when $.KEY_ARROWUP    then moveComponentsByKeyboard selection.components(), e, KB_MOVE_DIRS.up    if sel
                when $.KEY_ARROWDOWN  then moveComponentsByKeyboard selection.components(), e, KB_MOVE_DIRS.down  if sel
                when $.KEY_ARROWLEFT  then moveComponentsByKeyboard selection.components(), e, KB_MOVE_DIRS.left  if sel
                when $.KEY_ARROWRIGHT then moveComponentsByKeyboard selection.components(), e, KB_MOVE_DIRS.right if sel
                when 'D'.charCodeAt(0)
                    e.preventDefault(); e.stopPropagation()
                    duplicateComponent(componentToActUpon()) if sel and (e.ctrlKey or e.metaKey)
                when 'Z'.charCodeAt(0)
                    e.preventDefault(); e.stopPropagation()
                    undo.undoLastChange() if (e.ctrlKey or e.metaKey)
            undefined

    ##########################################################################################################
    ##  Simulation (Run)

    snapshotForSimulation = (screen) ->
        if not screen.rootComponent.node?
            throw "This hack only works for the current screen"
        screen.html = screen.rootComponent.node.outerHTML

    isRunningApplication = ->
        $('#run-iframe').is(':visible')

    getRunURL = ->
        window.location.href.replace(/\/(?:dev|designer).*$/, '/').replace(/#.*$/, '') + "R" + applicationId

    runCurrentApplication = ->
        $('#run-iframe').attr 'src', getRunURL()

        $('#run-iframe').show()
        $('#design-area').css 'visibility': 'hidden'
        adjustDeviceImagePosition()

        $('#play-button').addClass('active')

    stopRunningApplication = ->
        $('#design-area').css 'visibility': 'visible'
        $('#run-iframe').hide()
        adjustDeviceImagePosition()

        $('#play-button').removeClass('active')

    saveAndRunCurrentApplication = ->
        if applicationId?
            runCurrentApplication()
        else
            saveApplicationChanges ->
                runCurrentApplication()

    $('#buttons-pane .button').bind
        'mousedown': ->
            $(this).addClass('down')
        'mouseup': (e) ->
            $(this).removeClass('down')

    $('#play-button').click (e) ->
        if isRunningApplication()
            stopRunningApplication()
        else
            saveAndRunCurrentApplication()

    initializeRunOnDevice = ($button, $popup) ->
        $link  = $popup.find('.link-url')
        $close = $popup.find('.close')
        $copy  = $popup.find('.button-copy')
        $copyLabel = $popup.find('.button-copy-label')

        $copy.clippy('/flash/clippy-mockko.swf').bind
            'clippycopy':   (e, data) ->  data.text = getRunURL()
            'clippyover':   ->            $copyLabel.html "copy to clipboard"
            'clippyout':    ->            $copyLabel.html ""
            'clippycopied': ->            $copyLabel.html "copied!"

        updatePopup = ->
            width  = $popup.outerWidth()
            height = $popup.outerHeight()
            buttonOffset = $button.offset()
            buttonWidth  = $button.outerWidth()
            buttonHeight = $button.outerHeight()
            parentOffset = $popup.parent().offset()

            buttonHeight -= 30  # ignore the button text for the purposes of centering

            url = getRunURL()
            $link.text(url).attr('href', url)

            $popup.css
                left: buttonOffset.left + buttonWidth - parentOffset.left
                top:   (buttonOffset.top + buttonHeight / 2) - height / 2 - parentOffset.top

        popup = newPopup $popup,
                    modeEngine: modeEngine
                    toggle:     $button
                    close:      $close
                    prepare:    updatePopup

    ##########################################################################################################
    ##  Dashboard = Application List

    startDashboardApplicationNameEditing = (app) ->
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
                app.content.name = newText
                serverMode.saveApplicationChanges ser.externalizeApplication(app.content), app.id, (newId) ->
                    refreshApplicationList()
        }

    duplicateApplication = (app) ->
        content = ser.externalizeApplication(app.content)
        content.name = "#{content.name} Copy"
        serverMode.saveApplicationChanges content, null, (newId) ->
            refreshApplicationList (newApps) ->
                freshApp = _(newApps).detect (a) -> a.id is newId
                startDashboardApplicationNameEditing freshApp

    $('#rename-application-menu-item').bind {
        selected: (e, app) -> startDashboardApplicationNameEditing app
    }
    $('#duplicate-application-menu-item').bind {
        selected: (e, app) -> duplicateApplication app
    }
    $('#delete-application-menu-item').bind {
        selected: (e, app) ->
            return unless confirm("Are you sure you want to delete #{app.content.name}?")
            deleteApplication app
    }


    ##########################################################################################################
    ##  Copy/Paste

    pasteJSON = (json) ->
        targetCont = activeScreen.rootComponent
        data = JSON.parse(json)
        if data.type then data = [data]
        newComps = (ser.internalizeComponent(c, targetCont) for c in data)
        newComps = _((if c.type is Types.background then c.children else c) for c in newComps).flatten()
        pasteComponents targetCont, newComps

    pasteComponents = (targetCont, newComps) ->
        return if newComps.length is 0
        friendlyName = if newComps.length > 1 then "#{newComps.length} objects" else friendlyComponentName(newComps[0])
        runTransaction "pasting #{friendlyName}", ->
            for newComp in newComps
                # XXX FIXME hack for proper pasting of tab bar items
                if newComp.type is Types['tab-bar-item']
                    unless targetCont = findChildByType(activeScreen.rootComponent, Mockko.componentTypes['tabBar'])
                        alert "Please add a tab bar before pasting tabs"
                        return
                $(childrenNodeOfComponent targetCont).append renderInteractiveComponentHeirarchy newComp
                updateEffectiveSizesAndRelayoutHierarchy newComp

                effect = layouting.computeDuplicationEffect activeScreen, newComp
                if effect is null
                    alert "Cannot paste the components because they do not fit into the designer"
                    return

                newComp.parent = targetCont
                targetCont.children.push newComp

                commitMoves effect.moves, [newComp], STACKED_COMP_TRANSITION_DURATION, activeScreen, componentPositionChanged
                newRect = effect.rect

                moveComponent newComp, newRect
                if newRect.w != newComp.effsize.w or newRect.h != newComp.effsize.h
                    newComp.size = { w: newRect.w, h: newRect.h }
                traverse newComp, (child) -> componentPositionChanged child

                layouting.adjustChildAfterPasteOrDuplication activeScreen, newComp, newComp.parent
                renderComponentStyle newComp

    cutComponents = (comps) ->
        comps = _((if c.type is Types.background then c.children else c) for c in comps).flatten()
        friendlyName = if comps.length > 1 then "#{comps.length} objects" else friendlyComponentName(comps[0])
        runTransaction "cutting of #{friendlyName}", ->
            for comp in comps
                deleteComponentWithoutTransaction comp, false

    $(document).copiableAsText {
        gettext: -> JSON.stringify(ser.externalizeComponent(comp)) if comp = componentToActUpon()
        aftercut: -> cutComponents [comp] if comp = componentToActUpon()
        paste: (text) -> pasteJSON text
        shouldProcessCopy: -> componentToActUpon() isnt null and !activeMode()?.isInsideTextField
        shouldProcessPaste: -> !activeMode()?.isInsideTextField
    }

    #######
    # Profile

    updateUserProfile = (userInfo) ->
        $('#profile-full-name').val(userInfo['full-name'])
        $('#profile-newsletter').checked(userInfo['newsletter'])

        console.log $('#profile-full-name'), $('#profile-newsletter')

    showUserProfileScreen = ->
        $('#profile-screen').fadeIn(100)

    $('#profile-close-link').click ->
        $('#profile-screen').fadeOut(100)
        false

    $('#profile-submit-link').click -> submitProfileForm()
    $('#profile-popup').submit (e) -> e.preventDefault(); submitProfileForm()

    submitProfileForm = ->
        serverMode.setUserInfo {
            'full-name': $('#profile-full-name').val()
            'newsletter': $('#profile-newsletter').checked()
        }
        $('#profile-screen').fadeOut(100)
        false

    $('.profile-button').click ->
        showUserProfileScreen()

    ##########################################################################################################
    ##  Browser History and Back Button

    ignoreHashChanges = no

    restoreAppFromLocationHash = (fallback) ->
        return fallback() # restoring disabled b/c of Chrome 6 dev channel problem

        fallback ||= switchToDashboard

        params = $.hashparam()
        if appIdString = params['app']
            return if appIdString == 'undefined'
            appIdToLoad = parseInt(appIdString, 10)
        else
            appIdToLoad = null
        if appIdToLoad isnt null
            refreshApplicationList ->
                app = _(applicationList).detect (a) -> a.id == appIdToLoad
                if app
                    loadApplication app.content, app.id
                    switchToDesign()
                else
                    fallback()
        else
            fallback()

    saveAppToLocationHash = (appId) ->
        ignoreHashChanges = yes
        try
            $.hashparam { 'app': appId }
        finally
            ignoreHashChanges = no

    saveDashboardToLocationHash = (appId) ->
        ignoreHashChanges = yes
        $.hashparam {}
        ignoreHashChanges = no

    initBackButton = ->
        $(window).bind 'hashchange', (e) ->
            return  # restoring disabled b/c of Chrome 6 dev channel problem
            return if ignoreHashChanges
            restoreAppFromLocationHash ->

    ##########################################################################################################
    ##  Help & Vote (Feedback) Buttons

    newPopup = ($popup, options) ->

        nop = ->

        { prepare, modeEngine } = $.extend({ prepare: nop }, options || {})

        # public methods

        isOpen = ->
            $popup.is(':visible')

        close = ->
            return unless isOpen()
            $popup.fadeOut(200)
            modeEngine.deactivateMode()

        open = ->
            return if isOpen()
            prepare($popup, options)
            $popup.fadeIn(200)

            modeEngine.activateMode {
                isInsideTextField: yes
                debugname: "Popup"
                mousedown: -> close(); false
                mousemove: -> false
                mouseup: -> false
                cancel: -> close()
            }

        toggle = ->
            if isOpen() then close() else open()

        # bind events

        $(options.toggle).click(-> toggle(); undefined) if options.toggle
        $(options.close) .click(-> close();  undefined) if options.close

        { isOpen, open, close, toggle }

    initFeedbackButton = (modeEngine, $button, $popup) ->
        API_URL = 'https://mockko.uservoice.com/forums/54458/suggestions.json?client=qF52dPwrz1KQdEgRmaw&callback=?'
        retrieveVotes = ->
            $.getJSON API_URL, null, (data, status, xhr) ->
                if data.length
                    console.log ["data", data]
                    top = { title: item['title'], votes: item['vote_count'] } for item in data.slice(0, 3)
                    console.log ["top", top]
                    $list = $('#help-voting .features')
                    $list.find('li').remove()

                    for item in top
                        console.log ["item", item]
                        $("<li/>")
                            .append($("<div/>", class: 'votes', text: "#{item.votes}"))
                            .append($("<p/>", text: item.title))
                            .appendTo($list)

        popup = newPopup $popup,
                    modeEngine: modeEngine
                    toggle:     $button
                    close:      $popup.find('.close')
                    prepare:    retrieveVotes

    ##########################################################################################################

    initComponentTypes = ->
        for typeName, ct of Types
            ct.name = typeName
            ct.style ||= {}
            if not ct.supportsBackground?
                ct.supportsBackground = 'background' of ct.style
            if not ct.textStyleEditable?
                ct.textStyleEditable = ct.defaultText?
            unless ct.constrainProportionsByDefault?
                ct.constrainProportionsByDefault = no
            ct.supportsText = ct.defaultText?
            unless ct.canHazBorderRadius?
                ct.canHazBorderRadius = ct.style.borderRadius?
            unless ct.canHazColor?
                ct.canHazColor = yes
            unless ct.canHazLink?
                ct.canHazLink = yes
            ct.adjustChildAfterPasteOrDuplication ||= (->)
            if ct.pin?
                ct.allowedContainers = ['background']

    createNewApplicationName = ->
        adjs = ['Best-Selling', 'Great', 'Incredible', 'Stunning', 'Gorgeous', 'Wonderful',
            'Amazing', 'Awesome', 'Fantastic', 'Beautiful', 'Unbelievable', 'Remarkable']
        names = ("#{adj} App" for adj in adjs)
        usedNames = setOf(_.compact(app.content.name for app in (applicationList || [])))
        names = _(names).reject (n) -> n of usedNames
        if names.length == 0
            "Yet Another App"
        else
            names[Math.floor(Math.random() * names.length)]

    createNewApplication = ->
        loadApplication ser.internalizeApplication(MakeApp.appTemplates.basic), null
        switchToDesign()
        startDesignScreenApplicationNameEditing()

    bindApplication = (app, an) ->
        app.node = an
        $(an).bindContextMenu '#application-context-menu', app
        $('.content', an).click ->
            loadApplication app.content, app.id
            switchToDesign()
        $('.caption', an).click ->
            startDashboardApplicationNameEditing app
            false

    deleteApplication = (app) ->
        serverMode.deleteApplication app.id, ->
            $(app.node).fadeOut 250, ->
                $(app.node).remove()

    renderApplication = (appData) ->
        appId = appData['id']
        app = JSON.parse(appData['body'])
        app = ser.internalizeApplication(app)
        loadImageGroupsUsedInApplication app
        an = domTemplate('app-template')
        $('.caption', $(an)).html(app.name)
        renderScreenComponents(app.screens[0], $('.content .rendered', an))
        $(an).appendTo($('#apps-list'))
        app = { id: appId, content: app }
        bindApplication app, an
        app

    renderApplicaitonListGroupHeader = (name) ->
        $(domTemplate('group-header-template')).text(name).appendTo($('#apps-list'))

    renderApplicationGroup = (name, apps) ->
        renderApplicaitonListGroupHeader(name)
        renderApplication(app) for app in apps

    refreshApplicationList = (callback) ->
        serverMode.loadApplications (apps) ->
            $('#apps-list *').remove()

            users = apps['users']

            samples         = appData for appData in Mockko.sampleApplications
            myApps          = users[apps['current_user']]['apps']

            renderApplicationGroup("My Applications", myApps)

            users = info for userId, info of users when userId isnt apps['current_user']
            users = (_(users).sortBy (user) -> -user['created_at'])
            for user in users
                userDisplayName = "#{user['full_name']} <#{user['email']}>"
                renderApplicationGroup("Shared By #{userDisplayName}", user['apps'])
            renderApplicationGroup("Sample Applications", samples)
            callback(applicationList) if callback

    switchToDesign = ->
        $(".screen").hide()
        $('#design-screen').show()

        # Palette initialization need to be performed after displaying
        # #design-screen in order to make DOM calculate proper sizes of
        # elements, otherwise components will be displayed improperly.
        initPalette()
        deactivateMode() # if any
        adjustDeviceImagePosition()
        updateImages()

    switchToDashboard = ->
        $(".screen").hide()
        $('#dashboard-screen').show()
        console.log "switchToDashboard"
        refreshApplicationList()
        saveDashboardToLocationHash()

    $('#new-app-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        createNewApplication()

    $('#dashboard-button').click (e) ->
        e.preventDefault(); e.stopPropagation()
        switchToDashboard()

    startOnDashboardByDefault = ->
        restoreAppFromLocationHash switchToDashboard

    startOnApplicationByDefault = (defaultApp) ->
        restoreAppFromLocationHash ->
            loadApplication ser.internalizeApplication(defaultApp), null
            switchToDesign()

    loadDesigner = (userData) ->
        $("body").removeClass("offline-user online-user").addClass("#{userData['status']}-user")
        console.log serverMode
        serverMode.adjustUI userData
        serverMode.startDesigner userData, startOnDashboardByDefault, startOnApplicationByDefault

    adjustDeviceImagePosition = ->
        deviceOffset = $('#device-panel').offset()
        contentOffset = $('#design-area').offset()
        deviceSize = { w: $('#device-panel').outerWidth(), h: $('#device-panel').outerHeight() }
        paneSize = { w: $('#design-pane').outerWidth(), h: $('#design-pane').outerHeight() }
        contentSize = { w: $('#design-area').outerWidth(), h: $('#design-area').outerHeight() }
        deviceInsets = { x: contentOffset.left - deviceOffset.left, y: contentOffset.top - deviceOffset.top }

        devicePos = {
            x: (paneSize.w - deviceSize.w) / 2
        }
        if deviceSize.h >= paneSize.h
            contentY = (paneSize.h - contentSize.h) / 2
            devicePos.y = contentY - deviceInsets.y
        else
            devicePos.y = (paneSize.h - deviceSize.h) / 2

        # caution: magic constants 40 and 70

        $('#device-panel').css({ left: devicePos.x - 40, top: devicePos.y })
        $('#run-iframe').css
            left: devicePos.x - 40 + deviceInsets.x
            top:  devicePos.y + deviceInsets.y
        $('#buttons-pane').css left: devicePos.x + deviceSize.w + 70

    supportedBrowser = ->
        $.browser.webkit or window.location.href.match('[?&]nocheckbrowser')

    if not supportedBrowser()
        window.location = '/'
        return

    $(window).resize ->
        adjustDeviceImagePosition()

    hover = Mockko.setupHoverPanel {
        modeEngine
        componentActionChanged
        deleteComponent
        duplicateComponent
        runTransaction
        activateResizingMode
        screens: -> application.screens
        hoveredComponentChanged: ->
            inspector.updateInspector()
    }
    inspector = Mockko.setupInspector { componentToActUpon, runTransaction, componentStyleChanged, componentActionChanged, modeEngine }

    if window.location.href.match /^file:/
        serverMode = Mockko.fakeServer
    else
        serverMode = Mockko.server

    initFeedbackButton(modeEngine, $('.help-button'), $('#help-popup'))
    initializeRunOnDevice($('#run-on-device-button'), $('#run-on-device-popup'))
    initComponentTypes()
    hookKeyboardShortcuts()
    initBackButton()

    serverMode.getUserInfo (userInfo) ->
        loadDesigner userInfo
        updateUserProfile userInfo
        if not userInfo['profile-created']
            showUserProfileScreen()
