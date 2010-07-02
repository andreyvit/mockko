#
# Resizing
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ ptDiff }: Mockko.geom


INF: 100000  # our very own idea of infinity


Mockko.startResizing: (screen, comp, startPt, options, componentPositionChanged) ->
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
            allowedArea: screen.allowedArea

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
            componentPositionChanged comp

        dropAt: (pt) ->
            @moveTo pt
            comp.abspos: comp.dragpos
            comp.dragpos: null
            comp.dragParent: null
    }
