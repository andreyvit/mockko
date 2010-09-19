#
# Resizing
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ ptDiff, addPtPt } = Mockko.geom
{ traverse } = Mockko.model


INF = 100000  # our very own idea of infinity


Mockko.startResizing = (screen, comp, startPt, options, componentPositionChanged) ->
    originalSize = comp.size
    baseSize = comp.effsize
    console.log "base size:"
    console.log baseSize
    originalPos = comp.abspos

    moveTo = (pt, ptOptions) ->
        delta = ptDiff(pt, startPt)
        constrained = ((options.hmode isnt 'c' and options.vmode isnt 'c') and comp.type.constrainProportionsByDefault and (baseSize.w > 0 and baseSize.h > 0))
        if ptOptions.toggleConstrainMode
            constrained = not constrained

        newPos = {}
        newSize = {}
        console.log options
        minimumSize = comp.type.minimumSize || { w: 4, h: 4 }
        allowedArea = screen.allowedArea

        maxSizeDecrease = { x: baseSize.w - minimumSize.w; y : baseSize.h - minimumSize.h }

        maxSizeIncrease = { x: INF; y: INF }
        maxSizeIncrease.x = switch options.hmode
            when 'l' then originalPos.x - allowedArea.x
            else          allowedArea.x+allowedArea.w - (originalPos.x+baseSize.w)
        maxSizeIncrease.y = switch options.vmode
            when 't' then originalPos.y - allowedArea.y
            else          allowedArea.y+allowedArea.h - (originalPos.y+baseSize.h)

        # convert mouse delta (“how many pixels the mouse moved”) into size delta
        # (“how many pixels the size should increase”) — this only affects the sign
        delta = {
            x: if options.hmode is 'l' then -delta.x else delta.x
            y: if options.vmode is 't' then -delta.y else delta.y
        }

        if constrained
            ratioWH = baseSize.w / baseSize.h

            maxSize = {
                w: baseSize.w + maxSizeIncrease.x
                h: baseSize.h + maxSizeIncrease.y
            }
            maxSize = {
                w: Math.min(maxSize.w, maxSize.h * ratioWH)
                h: Math.min(maxSize.h, maxSize.w / ratioWH)
            }
            minSize = {
                w: baseSize.w - maxSizeDecrease.x
                h: baseSize.h - maxSizeDecrease.y
            }
            minSize = {
                w: Math.max(minSize.w, minSize.h * ratioWH)
                h: Math.max(minSize.h, minSize.w / ratioWH)
            }

            newSize = {
                w: baseSize.w + delta.x
                h: baseSize.h + delta.y
            }
            newSize = {
                w: Math.max(minSize.w, Math.min(maxSize.w, newSize.w))
                h: Math.max(minSize.h, Math.min(maxSize.h, newSize.h))
            }
            newSize = switch
                when baseSize.w > baseSize.h then { w: newSize.w, h: newSize.w * baseSize.h / baseSize.w }
                when baseSize.w < baseSize.h then { h: newSize.h, w: newSize.h * baseSize.w / baseSize.h }
                else                              newSize

            delta = {
                x: newSize.w - baseSize.w
                y: newSize.h - baseSize.h
            }
        else
            delta = {
                x: Math.min( maxSizeIncrease.x, Math.max(-maxSizeDecrease.x, delta.x))
                y: Math.min( maxSizeIncrease.y, Math.max(-maxSizeDecrease.y, delta.y))
            }

        [newSize.w, newPos.x] = switch
            when delta.w is 0 or options.hmode is 'c' then [originalSize.w, originalPos.x]
            when options.hmode is 'r' then [baseSize.w + delta.x, originalPos.x]
            when options.hmode is 'l' then [baseSize.w + delta.x, originalPos.x - delta.x]
            else throw "Internal Error = unknown resize hmode #{options.hmode}"
        [newSize.h, newPos.y] = switch
            when delta.h is 0 or options.vmode is 'c' then [originalSize.h, originalPos.y]
            when options.vmode is 'b' then [baseSize.h + delta.y, originalPos.y]
            when options.vmode is 't' then [baseSize.h + delta.y, originalPos.y - delta.y]
            else throw "Internal Error = unknown resize vmode #{options.vmode}"
        comp.size = newSize

        delta = ptDiff(newPos, originalPos)
        traverse comp, (child) ->
            child.dragpos = addPtPt(child.abspos, delta)
            child.dragParent = child.parent
            componentPositionChanged child

    dropAt = (pt, ptOptions) ->
        @moveTo pt, ptOptions
        traverse comp, (child) ->
            child.abspos = child.dragpos
            child.dragpos = null
            child.dragParent = null

    { moveTo, dropAt }
