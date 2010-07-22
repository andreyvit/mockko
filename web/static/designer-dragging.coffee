#
# Dragging (common to existing & new component dragging)
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ dupRect }:        Mockko.geom
{ rectOf, sizeOf }: Mockko.model
layouting:          Mockko.layouting
applicator:         Mockko.applicator


CONF_DESIGNAREA_PUSHBACK_DISTANCE = 100


Mockko.startDragging: (screen, comp, options, initialMoveOptions, computeDropAction, componentPositionChanged, containerChildrenChanged, updateEffectiveSizesAndRelayoutHierarchy) ->

    origin: $('#design-area').offset()
    allowedArea: screen.allowedArea

    if comp.inDocument
        originalR: rectOf comp

    computeHotSpot: (pt) ->
        r: rectOf comp
        {
            x: if r.w then ((pt.x - origin.left) - r.x) / r.w else 0.5
            y: if r.h then ((pt.y - origin.top)  - r.y) / r.h else 0.5
        }
    hotspot: options.hotspot || computeHotSpot(options.startPt)
    liveMover: applicator.newLiveDropEffectPreviewer screen, [comp], componentPositionChanged
    wasAnchored: no
    anchoredTransitionChangeTimeout: new Timeout applicator.STACKED_COMP_TRANSITION_DURATION

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
            if effect: layouting.computeDropEffect screen, comp, rect, moveOptions
                { target, isAnchored, rect, moves }: effect
            else
                ok: no
                moves: []
        else
            { moves }: layouting.computeDeletionEffect screen, comp

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

        componentPositionChanged comp

        if ok then { target: target } else null

    dropAt: (pt, moveOptions) ->
        $(comp.node).removeClass 'dragging'

        if res: moveTo pt, moveOptions
            action: computeDropAction comp, res.target, originalSize, originalEffSize
            action.execute()
            liveMover.commit()
            if comp.parent isnt null
                # may be null if comp was deleted as part of action (e.g.. image dropped on tab bar)
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
    screen.rootComponent.node.appendChild(comp.node)

    # we might have just added a new component
    updateEffectiveSizesAndRelayoutHierarchy comp

    originalSize: comp.size
    originalEffSize: comp.effsize

    moveTo(options.startPt, initialMoveOptions)

    { moveTo, dropAt, cancel }
