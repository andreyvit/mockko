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

pickHorizontalPositionBetween: (rect, items) ->
    throw "cannot work with empty list of items" if items.length is 0
    [prevItem, prevItemRect]: [null, null]
    index: 0
    positions: for item in items.concat(null)
        itemRect: if item then rectOf(item) else null
        coord: switch
            when itemRect && prevItemRect then (prevItemRect.x+prevItemRect.w + itemRect.x) / 2
            when itemRect then itemRect.x
            when prevItemRect then prevItemRect.x+prevItemRect.w
            else throw "impossible case"
        [after, before] : [prevItem, item]
        [prevItem, prevItemRect] : [item, itemRect]
        { coord, after, before, index:index++ }

    center: rect.x + rect.w / 2
    _(positions).min (pos) -> Math.abs(center - pos.coord)

pickHorizontalRectAmong: (rect, items) ->
    throw "cannot work with empty list of items" if items.length is 0
    index: 0
    positions: for item in items
        { rect:(if item.abspos then rectOf(item) else item), item, index:index++ }

    center: rect.x + rect.w / 2
    _(positions).min (pos) -> Math.abs(pos.rect.x+pos.rect.w/2 - center)

moveComponent: (comp, newPos) ->
    delta: ptDiff(newPos, comp.abspos)
    traverse comp, (child) -> child.abspos: ptSum(child.abspos, delta)

newItemsForHorizontalStack: (items, comp, rect) ->
    if _(items).include(comp)
        filteredItems: _(_(items).without(comp)).sortBy (child) -> child.abspos.x
        if rect
            sortedItems: _(items).sortBy (child) -> child.abspos.x
            index: pickHorizontalRectAmong(rect, sortedItems).index
            filteredItems.slice(0, index).concat([comp]).concat(filteredItems.slice(index))
        else
            filteredItems
    else if items.length is 0
        [comp]
    else
        sortedItems: _(items).sortBy (child) -> child.abspos.x
        index: pickHorizontalPositionBetween(rect, sortedItems).index
        sortedItems.slice(0, index).concat([comp]).concat(sortedItems.slice(index))

newItemsForHorizontalStackDuplication: (items, oldComp, newComp) ->
    items: _(items).sortBy (child) -> child.abspos.x
    index: _(items).indexOf oldComp
    if index < 0
        items.concat([newComp])
    else
        items.slice(0, index).concat([newComp]).concat(items.slice(index))

computeDropEffectFromNewRects: (items, newRects, comp) ->
    throw "lengths do not match" unless items.length == newRects.length
    effect: { moves: [], rect: null }
    for [item, rect] in _.zip(items, newRects)
        if comp? and item is comp
            effect.rect: rect
        else
            effect.moves.push { comp: item, abspos: { x:rect.x, y:rect.y }, size: { w:rect.w, h:rect.h } }
    effect

friendlyComponentName: (c) ->
    if c.type is Mockko.componentTypes['text']
        "“${c.text}”"
    else
        label: (c.type.genericLabel || c.type.label).toLowerCase()
        if c.text then "the “${c.text}” ${label}" else aOrAn label


(window.Mockko ||= {}).model: {
    sizeOf, rectOf, friendlyComponentName
    traverse, skipTraversingChildren
    findChildByType, findBestTargetContainerForRect, findComponentByRect, findComponentByTypeIntersectingRect
    compWithChildrenAndParents, isComponentOrDescendant, findComponentOccupyingRect
    pickHorizontalPositionBetween, pickHorizontalRectAmong
    moveComponent
    newItemsForHorizontalStack, newItemsForHorizontalStackDuplication, computeDropEffectFromNewRects
}
