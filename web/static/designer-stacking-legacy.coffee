#
# Stacking (legacy concept, to be replaced with layout classes)
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ proximityOfRectToRect, rectFromPtAndSize }: Mockko.geom
{ rectOf, traverse }: Mockko.model

INF: 42*42*42*42


discoverStacks: (root) ->
    stacks: []
    traverse root, (c) ->
        c.stack = null; c.previousStackSibling = null; c.nextStackSibling = null

    traverse root, (c) ->
        if c.type.container
            discoverStacksInComponent c, stacks

    $(root.node).find('.component').removeClass('in-stack first-in-stack last-in-stack odd-in-stack even-in-stack first-in-group last-in-group odd-in-group even-in-group')
    for stack in stacks
        prev: null
        index: 1
        indexInGroup: 1
        prevGroupName: null
        $(stack.items[0].node).addClass('first-in-stack')
        for cur in stack.items
            groupName: cur.type.group || 'default'
            if groupName != prevGroupName
                $(cur.node).addClass('first-in-group')
                $(prev.node).addClass('last-in-group') if prev
                indexInGroup: 1
            prevGroupName: groupName

            $(cur.node).addClass("in-stack ${if index % 2 is 0 then 'even' else 'odd'}-in-stack")
            $(cur.node).addClass("${if indexInGroup % 2 is 0 then 'even' else 'odd'}-in-group")
            index += 1
            indexInGroup += 1

            cur.stack = stack
            if prev
                prev.nextStackSibling = cur
                cur.previousStackSibling = prev
            prev = cur
        $(prev.node).addClass('last-in-group') if prev
        $(prev.node).addClass('last-in-stack') if prev
    stacks

discoverStacksInComponent: (container, stacks) ->
    peers: _(container.children).select (c) -> c.type.isTableRow
    peers: _(peers).sortBy (c) -> c.abspos.y

    contentSoFar: []
    lastStackItem: null
    stackMinX: INF
    stackMaxX: -INF

    canBeStacked: (c) ->
        minX: c.abspos.x
        maxX: c.abspos.x + c.effsize.w
        return no if maxX < stackMinX or minX > stackMaxX
        return no unless lastStackItem.abspos.y + lastStackItem.effsize.h == c.abspos.y
        yes

    flush: ->
        rect: { x: stackMinX, w: stackMaxX - stackMinX, y: contentSoFar[0].abspos.y }
        rect.h = lastStackItem.abspos.y + lastStackItem.effsize.h - rect.y
        stacks.push { type: 'vertical', items: contentSoFar, rect: rect }

        contentSoFar: []
        lastStackItem: null
        stackMinX: INF
        stackMaxX: -INF

    for peer in peers
        flush() if lastStackItem isnt null and not canBeStacked(peer)
        contentSoFar.push peer
        lastStackItem = peer
        stackMinX: Math.min(stackMinX, peer.abspos.x)
        stackMaxX: Math.max(stackMaxX, peer.abspos.x + peer.effsize.w)
    flush() if lastStackItem isnt null


# stackSlice(from, inclFrom?, [to, inclTo?])
stackSlice: (from, inclFrom, to, inclTo) ->
    res: []
    res.push from if inclFrom
    item: from.nextStackSibling
    while item? and item isnt to
        res.push item
        item: item.nextStackSibling
    res.push to if inclTo
    return res

findStackByProximity: (rect, stacks) ->
    _(stacks).find (s) -> proximityOfRectToRect(rect, s.rect) < 20 * 20

handleStacking: (comp, rect, stacks, action) ->
    return { moves: [] } unless comp.type.isTableRow

    sourceStack: if action == 'duplicate' then null else comp.stack
    targetStack: if rect? then findStackByProximity(rect, stacks) else null

    handleVerticalStacking comp, rect, sourceStack, targetStack

handleVerticalStacking: (comp, rect, sourceStack, targetStack) ->
    if sourceStack && sourceStack.items.length == 1
        if targetStack is sourceStack
            targetStack: null
        sourceStack: null

    return { moves: [] } unless sourceStack? or targetStack?

    if sourceStack == targetStack
      target: _(targetStack.items).min (c) -> proximityOfRectToRect rectOf(c), rect
      if target is comp
        return { targetRect: rectOf(comp), moves: [] }
      else if rect.y > comp.abspos.y
        # moving down
        return {
          targetRect: rectFromPtAndSize target.abspos, comp.effsize
          moves: [
            { comps: stackSlice(comp, no, target, yes), offset: { x: 0, y: -comp.effsize.h } }
          ]
        }
      else
        # moving up
        return {
            targetRect: rectFromPtAndSize target.abspos, comp.effsize
            moves: [
                { comps: stackSlice(target, yes, comp, no), offset: { x: 0, y: comp.effsize.h } }
            ]
        }
    else
        res: { moves: [] }
        if targetStack?
            firstItem: _(targetStack.items).first()
            lastItem: _(targetStack.items).last()
            # fake components serving as placeholders
            bofItem: {
                abspos: { x: firstItem.abspos.x, y: firstItem.abspos.y - comp.effsize.h }
                effsize: { w: comp.effsize.w, h: comp.effsize.h }
            }
            eofItem: {
                abspos: { x: lastItem.abspos.x, y: lastItem.abspos.y + lastItem.effsize.h }
                effsize: { w: comp.effsize.w, h: comp.effsize.h }
            }
            target: _(targetStack.items.concat([bofItem, eofItem])).min (c) -> proximityOfRectToRect rectOf(c), rect
            res.targetRect = rectFromPtAndSize target.abspos, comp.effsize
            if target isnt eofItem and target isnt bofItem
                res.moves.push { comps: stackSlice(target, yes), offset: { x: 0, y: comp.effsize.h } }
        if sourceStack?
            res.moves.push { comps: stackSlice(comp, no), offset: { x: 0, y: -comp.effsize.h } }
        return res


Mockko.stacking: { discoverStacks, handleStacking }
