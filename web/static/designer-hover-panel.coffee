#
# Hover Panel & Action Arrow Overlay
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{
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


LINK_ARROW_MOUSEMOVE_SAFE_DISTANCE: 20
LINK_ARROW_INITIAL_MOUSEMOVE_MIN_SAFE_DISTANCE: 15
FIRST_HOVER_BUTTON_OFFSET: -8
HOVER_BUTTON_WIDTH: 16
MIN_DISTANCE_FROM_LAST_HOVER_BUTTON_TO_TOP_CENTER_HANDLE: 10


# options.modeEngine
# options.runTransaction
# options.screens()
# options.deleteComponent()
# options.duplicateComponent()
# options.activateResizingMode(comp, pt, { hmode, vmode })
# options.hoveredComponentChanged()
# options.componentActionChanged(comp)

Mockko.setupHoverPanel: (options) ->
    modes: options.modeEngine
    hoveredComponent: null

    RESIZING_HANDLES = ['tl', 'tc', 'tr', 'cl', 'cr', 'bl', 'bc', 'br']

    adjustHorizontalSizingMode: (comp, hmode) ->
        if comp.type.widthPolicy.userSize then hmode else 'c'
    adjustVerticalSizingMode: (comp, vmode) ->
        if comp.type.heightPolicy.userSize then vmode else 'c'

    updateHoverPanelPosition: ->
        return if hoveredComponent is null
        refOffset: $('#design-area').offset()
        compOffset: $(hoveredComponent.node).offset()
        r: {
            x: compOffset.left - refOffset.left
            y: compOffset.top - refOffset.top
            w: $(hoveredComponent.node).outerWidth()
            h: $(hoveredComponent.node).outerHeight()
        }
        $('#hover-panel').css({ left: r.x, top: r.y })
        [r.x, r.y]: [-6, -6]
        xpos: { 'l': r.x, 'c': r.x + r.w/2, 'r': r.x + r.w - 1 }
        ypos: { 't': r.y, 'c': r.y + r.h/2, 'b': r.y + r.h - 1 }
        xenable: { 'l': yes, 'c': (hoveredComponent.effsize.w >= 23), 'r': yes }
        yenable: { 't': yes, 'c': (hoveredComponent.effsize.h >= 23), 'b': yes }
        # hoveredComponent.effsize.w < 63 or hoveredComponent.effsize.h <= 25
        controlsOutside: not (hoveredComponent.parent?.type?.hitAreaInset)
        topCenterHandleVisible: yes
        linkButtonVisible: hoveredComponent.type.canHazLink
        unlinkButtonVisible: hoveredComponent.type.canHazLink and hoveredComponent.action?
        numberOfButtons: 2 + linkButtonVisible + unlinkButtonVisible
        if (not controlsOutside) and r.w/2 < FIRST_HOVER_BUTTON_OFFSET + numberOfButtons*HOVER_BUTTON_WIDTH + MIN_DISTANCE_FROM_LAST_HOVER_BUTTON_TO_TOP_CENTER_HANDLE
            topCenterHandleVisible: no
        _($('#hover-panel .resizing-handle')).each (handle, index) ->
            [vmode, hmode]: [RESIZING_HANDLES[index][0], RESIZING_HANDLES[index][1]]
            pos: { x: xpos[hmode], y: ypos[vmode] }
            [vmode, hmode]: [adjustVerticalSizingMode(hoveredComponent, vmode), adjustHorizontalSizingMode(hoveredComponent, hmode)]
            disabled: (vmode is 'c' and hmode is 'c')
            visible: xenable[RESIZING_HANDLES[index][1]] and yenable[RESIZING_HANDLES[index][0]] and (controlsOutside or index isnt 0)
            if index is 1 and not topCenterHandleVisible
                visible: no
            $(handle).css({ left: pos.x, top: pos.y }).alterClass('disabled', disabled).alterClass('hidden', not visible)
        $('#hover-panel .duplicate-handle').alterClass('disabled', hoveredComponent.type.singleInstance)
        $('#hover-panel').alterClass('controls-outside', controlsOutside)
        $('.link-handle').alterClass('disabled', not linkButtonVisible)
        $('.unlink-handle').alterClass('disabled', not unlinkButtonVisible)
        if hoveredComponent.action?
            renderActionOverlay(hoveredComponent)
        else
            hideLinkOverlay()

    componentHovered: (c) ->
        # the component is being deleted right now
        return unless c.node?
        return if hoveredComponent is c
        if c.type.unmovable
            componentUnhovered()
            return

        ct: c.type
        if ct.container
            $('#hover-panel').addClass('container').removeClass('leaf')
        else
            $('#hover-panel').removeClass('container').addClass('leaf')
        $('#hover-panel').fadeIn(100) if hoveredComponent is null
        hoveredComponent = c
        updateHoverPanelPosition()
        options.hoveredComponentChanged()

    componentUnhovered: ->
        return if hoveredComponent is null
        hoveredComponent = null
        $('#hover-panel').hide()
        hideLinkOverlay()
        options.hoveredComponentChanged()

    $('#hover-panel').hide()
    $('#hover-panel .delete-handle').click ->
        if hoveredComponent isnt null
            $('#hover-panel').hide()
            options.deleteComponent hoveredComponent
            hoveredComponent = null

    $('#hover-panel .duplicate-handle').click ->
        if hoveredComponent isnt null
            options.duplicateComponent hoveredComponent

    _($('.hover-panel .resizing-handle')).each (handle, index) ->
        $(handle).mousedown (e) ->
            return if hoveredComponent is null
            [vmode, hmode]: [RESIZING_HANDLES[index][0], RESIZING_HANDLES[index][1]]
            [vmode, hmode]: [adjustVerticalSizingMode(hoveredComponent, vmode), adjustHorizontalSizingMode(hoveredComponent, hmode)]
            disabled: (vmode is 'c' and hmode is 'c')
            return if disabled
            options.activateResizingMode hoveredComponent, e, { vmode: vmode, hmode: hmode }
            false

    activeLinkOverlay: null

    renderLinkOverlay: (sourceComp, destR) ->
        compR:  rectOfNode sourceComp.node
        compPt: centerOfRect compR
        destPt: { x: destR.x+destR.w, y: destR.y+destR.h/2 }
        designAreaR: rectOfNode $('#design-pane')
        clipR:  canonRect { x: Math.min(designAreaR.x, destR.x+destR.w), y: designAreaR.y, x2: designAreaR.x+designAreaR.w-1, y2: designAreaR.y+designAreaR.h-1 }

        $('#link-overlay').css({ 'opacity': 0.2 })
        canvas: $('#link-overlay').attr({ 'width': clipR.w, 'height': clipR.h }).css({ 'left': clipR.x, 'top': clipR.y, 'width': clipR.w, 'height': clipR.h }).show()[0]

        activeLinkOverlay: {
            start: compPt
            end:   destPt
            comp:  sourceComp
            justAdded: no
        }

        startPt: subPtPt compPt, clipR
        endPt:   subPtPt destPt, clipR
        clipX: 2
        if endPt.x < clipX
            endPt.y: startPt.y + (endPt.y-startPt.y) * ((clipX-startPt.x) / (endPt.x-startPt.x))
            endPt.x: clipX

        ctx: canvas.getContext '2d'
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        ctx.beginPath()
        ctx.moveTo(startPt.x, startPt.y)
        ctx.lineTo(endPt.x, endPt.y)
        arrowPt: mulVecLen(unitVecOfPtPt(endPt, startPt), 10)
        ctx.save()
        ctx.translate(endPt.x, endPt.y)
        ctx.save()
        ctx.rotate(Math.PI/180*20)
        ctx.moveTo(0, 0)
        ctx.lineTo(arrowPt.x, arrowPt.y)
        ctx.restore()
        ctx.rotate(-Math.PI/180*20)
        ctx.moveTo(0, 0)
        ctx.lineTo(arrowPt.x, arrowPt.y)
        ctx.restore()
        ctx.strokeStyle: "rgba(0, 0, 127, 0.8)"
        ctx.lineWidth: 2
        ctx.stroke()

    hideLinkOverlay: ->
        $('#link-overlay').fadeOut(100)
        activeLinkOverlay: null

    animateLinkOverlaySet: ->
        return unless activeLinkOverlay
        # TODO: cancel this animation if hovering another comp
        $('#link-overlay').animate({ 'opacity': 1 }, 500)
        activeLinkOverlay.justAdded: yes

    animateLinkRemoved: (callback) ->
        $('#link-overlay').fadeOut(500, callback)
        activeLinkOverlay: null

    distanceToLinkOverlay: (pt) ->
        distancePtSegment pt, lineFromPtPt(activeLinkOverlay.start, activeLinkOverlay.end)

    renderActionOverlay: (comp) ->
        if comp.action && comp.action.action is Mockko.actions.switchScreen
            screenName: comp.action.screenName
            screen: _(options.screens()).detect (s) -> s.name is screenName
            if screen
                renderLinkOverlay comp, rectOfNode(screen.node)
                return
        hideLinkOverlay()

    $('.link-handle').bind {
        'mousedown': (e) ->
            if hoveredComponent isnt null
                startLinkDragging hoveredComponent, e
    }
    $('.unlink-handle').click (e) ->
        if hoveredComponent isnt null
            options.runTransaction "remove link", ->
                hoveredComponent.action: null
                animateLinkRemoved ->
                    options.componentActionChanged hoveredComponent

    startLinkDragging: (sourceComp, initialE) ->
        lastCandidate: null

        onmousemove: (e) ->
            r: { x: e.pageX, y: e.pageY, w: 0, h: 0 }
            lastCandidate: _({ screen, dist: distancePtPt2(r, centerOfRect(rectOfNode(screen.node))) } for screen in options.screens()).min (o) -> o.dist
            if lastCandidate.dist > 100
                lastCandidate: null
            if lastCandidate
                renderLinkOverlay sourceComp, rectOfNode(lastCandidate.screen.node)
            else
                renderLinkOverlay sourceComp, r
            e.preventDefault()
            e.stopPropagation()

        onmouseup: (e) ->
            pt: { x: e.pageX, y: e.pageY }
            onmousemove(e)
            if lastCandidate
                options.runTransaction "set link", ->
                    sourceComp.action: Mockko.actions.switchScreen.create(lastCandidate.screen)
                    options.componentActionChanged sourceComp
                animateLinkOverlaySet()
                activeLinkOverlay.safeDistance: Math.max(LINK_ARROW_MOUSEMOVE_SAFE_DISTANCE, distanceToLinkOverlay(pt) + LINK_ARROW_INITIAL_MOUSEMOVE_MIN_SAFE_DISTANCE)
                # activateInspector 'action'
            else
                # TODO: render old link if any
                renderActionOverlay sourceComp
            modes.deactivateMode()

        modes.activateMode {
            isScreenLinkingMode: yes
            activated: ->
                document.addEventListener 'mousemove', onmousemove, true
                document.addEventListener 'mouseup',   onmouseup,   true
                $('#screens-list').addClass('prominent')
            deactivated: ->
                document.removeEventListener 'mousemove', onmousemove, true
                document.removeEventListener 'mouseup',   onmouseup,   true
                $('#screens-list').removeClass('prominent')
        }
        onmousemove(initialE)

    currentlyHovered: -> hoveredComponent
    currentLinkOverlay: -> activeLinkOverlay

    {
        updateHoverPanelPosition, componentHovered, componentUnhovered, currentlyHovered, currentLinkOverlay
        distanceToLinkOverlay
    }
