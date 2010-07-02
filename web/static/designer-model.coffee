#
# Model Geometry & Utilities
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

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



sizeOf: (c) -> { w: c.effsize.w, h: c.effsize.h }
rectOf: (c) -> { x: c.abspos.x, y: c.abspos.y, w: c.effsize.w, h: c.effsize.h }

skipTraversingChildren: {}
# traverse(comp-or-array-of-comps, [parent], func)
traverse: (comp, parent, func) ->
    return if not comp?
    if not func
        func = parent; parent = null
    if _.isArray comp
        for child in comp
            traverse child, parent, func
    else
        r: func(comp, parent)
        if r isnt skipTraversingChildren
            for child in comp.children || []
                traverse child, comp, func
    null

findChildByType: (parent, type) ->
    _(parent.children).detect (child) -> child.type is type

findBestTargetContainerForRect: (root, r, excluded) ->
    trav: (comp) ->
        return null if _.include excluded, comp

        bestHere: null
        for child in comp.children
            if res: trav(child)
                if bestHere == null or res.area > bestHere.area
                    bestHere = res

        if bestHere is null
            rc: rectOf comp
            if isRectInsideRect r, rc
                if (area: areaOfIntersection r, rc) > 0
                    bestHere: { comp: comp, area: area }
        else
            bestHere

    trav(root)?.comp || root

findComponentByRect: (root, r, exclusionSet) ->
    match: null
    traverse root, (comp) ->
        unless inSet comp, exclusionSet
            if doesRectIntersectRect r, rectOf comp
                # don't return yet to find the innermost match
                match: r
    match

findComponentByTypeIntersectingRect: (root, type, rect, exclusionSet) ->
    match: null
    traverse root, (comp) ->
        if inSet comp, exclusionSet
            return skipTraversingChildren
        if not (doesRectIntersectRect rect, rectOf comp)
            return skipTraversingChildren
        if comp.type is type
            match: comp
    match

compWithChildrenAndParents: (comp) ->
    items: []
    traverse comp, (child) -> items.push child
    while comp: comp.parent
        items.push comp
    items

findComponentOccupyingRect: (root, r, exclusionSet) ->
    match: null
    traverse root, (comp) ->
        if not exclusionSet? or not inSet comp, exclusionSet
            # consider the space to be occupied if any leaf components intersects the given rect,
            # or if there is another container placed exactly at the given rect (e.g. an already
            # existing duplicate of the component in question)
            if comp.type.container
                candidate: no
                if comp isnt root
                    rect: rectOf comp
                    if rect.x == r.x && rect.y == r.y && rect.w == r.w && rect.h == r.h
                        candidate: yes
            else
                candidate: yes
            if candidate
                if doesRectIntersectRect r, rectOf comp
                    # don't return yet to find the innermost match
                    match: comp
    match

isComponentOrDescendant: (candidate, possibleAncestor) ->
    match: no
    traverse possibleAncestor, (child) ->
        match: yes if child is candidate
    match


(window.Mockko ||= {}).model: {
    sizeOf, rectOf
    traverse, skipTraversingChildren
    findChildByType, findBestTargetContainerForRect, findComponentByRect, findComponentByTypeIntersectingRect
    compWithChildrenAndParents, isComponentOrDescendant, findComponentOccupyingRect
}
