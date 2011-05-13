#
# Layouts
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#
# HISTORY
#
# Initially it was planned to handle most types of complex layouting via stacking,
# however a concept of Layout has distilled evolutionally.

# Using per-container layouts has never been a default choice despite being
# popular in UI toolkits. Layout classes have been introduced in order to separate
# drop/duplicate/delete code paths inside layouting functions. Initially layout
# classes have been stateless strategies, however it was found to be very natural
# to store the target container as a field instead of passing it around.
#
# PLANS & NOTES
#
# Currently only one layout drives the whole effect of a drag'n'drop operation. So, for example,
# if you're dragging a segment between two segmented controls, only the target segmented control will
# participate in drag'n'drop operation, not giving the source segmented control a chance to readjust
# after removing a segment. This is not intended.
#
# The "old" stacking code handles all four cases:
# 1) adding a component to a stack
# 2) removing a component from a stack
# 3) moving a component within a stack (“reordering”)
# 4) moving a component between stacks
#
# Similarly, the way layouts are used should be changed so that when you drag an existing component,
# both the layout of the source container and the layout of the target container participate in
# determining the effect of the dragging operation.
#
# After this is done, it would finally be possible to port the legacy stacking code into a layout class
# for table rows.
#
# Note that porting the legacy stacking code would face another challenge, namely that a stack of table rows
# is not a container. A straightforward approach to handle this problem would be to add the code for table row
# layouting into a layout class for the root component. This is not desirable, though: besides the obvious
# bloating of the root component layout, this will present problems on iPad where multiple containers
# have an ability to contain table rows (e.g. panes of a split screen, popovers).
#

{ centerSizeInRect } = Mockko.geom

{
    rectOf
    findComponentOccupyingRect, findChildByType, findComponentByTypeIntersectingRect
    findBestTargetContainerForRect
    newItemsForHorizontalStack, newItemsForHorizontalStackDuplication, computeDropEffectFromNewRects
} = Mockko.model


DUPLICATE_COMPONENT_OFFSET_X = 5
DUPLICATE_COMPONENT_OFFSET_Y = 5
DUPLICATE_COMPONENT_MIN_EDGE_INSET_X = 5
DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y = 5


class Layout
    constructor: (screen, target) ->
        @screen = screen
        @target = target

class PinnedLayout extends Layout

    computeDropEffect: (comp, rect, moveOptions) ->
        pin = comp.type.pin
        rect = pin.computeRect @screen.allowedArea, comp, (otherPin) =>
            for child in @target.children
                if child.type.pin is otherPin
                    return rectOf(child)
            null
        moves = []
        for dependantPin in pin.dependantPins
            for child in @target.children
                if child.type.pin is dependantPin
                    newRect = child.type.pin.computeRect @screen.allowedArea, child, (otherPin) =>
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
        pin = comp.type.pin
        moves = []
        for dependantPin in pin.dependantPins
            for child in @target.children
                if child.type.pin is dependantPin
                    newRect = child.type.pin.computeRect @screen.allowedArea, child, (otherPin) =>
                        return null if otherPin is pin
                        for otherChild in @target.children
                            if otherChild.type.pin is otherPin
                                return rectOf(otherChild)
                        null
                    moves.push { comp: child, abspos: newRect }
        { moves }

    relayout: -> throw "Unsupported operation = unreachable at the moment"

    hasNonFlexiblePosition: (comp) -> true

class ContainerDeterminedLayout extends Layout

    computeDropEffect: (comp, rect, moveOptions) ->
        newChildren = newItemsForHorizontalStack @target.children, comp, rect
        itemRects = @target.type.layoutChildren newChildren, rectOf(@target)
        { rect, moves } = computeDropEffectFromNewRects newChildren, itemRects, comp
        { isAnchored: yes, rect, moves }

    computeDuplicationEffect: (oldComp, newComp) ->
        newChildren = newItemsForHorizontalStackDuplication @target.children, oldComp, newComp
        itemRects = @target.type.layoutChildren newChildren, rectOf(@target)
        computeDropEffectFromNewRects newChildren, itemRects, newComp

    computeDeletionEffect: (comp) ->
        newChildren = newItemsForHorizontalStack @target.children, comp, null
        itemRects = @target.type.layoutChildren newChildren, rectOf(@target)
        { moves } = computeDropEffectFromNewRects newChildren, itemRects, comp

    relayout: ->
        children = _(@target.children).sortBy (child) -> child.abspos.x
        itemRects = @target.type.layoutChildren children, rectOf(@target)
        computeDropEffectFromNewRects children, itemRects, null

    hasNonFlexiblePosition: (comp) -> true

class RegularLayout extends Layout

    computeDropEffect: (comp, rect, moveOptions) ->
        stacking = Mockko.stacking.handleStacking comp, rect, @screen.allStacks
        if stacking.targetRect?
            { isAnchored: yes, rect: stacking.targetRect, moves: stacking.moves }
        else
            anchors = _(Mockko.snapping.computeInnerAnchors(@target, comp, @screen.allowedArea)).reject (a) -> comp == a.comp
            magnets = Mockko.snapping.computeMagnets(comp, rect, @screen.allowedArea)
            snappings = Mockko.snapping.computeSnappings(anchors, magnets)

            unless moveOptions.disableSnapping
                snappings = Mockko.snapping.chooseSnappings snappings
                for snapping in snappings
                    snapping.apply rect

            { isAnchored: no, rect, moves: [] }

    computeDuplicationEffect: (oldComp, newComp) ->
        rect = rectOf(oldComp)
        rect.y += rect.h
        stacking = Mockko.stacking.handleStacking oldComp, rect, @screen.allStacks, 'duplicate'

        if stacking.targetRect
            return { rect: stacking.targetRect, moves: stacking.moves }
        else
            allowedArea = @screen.allowedArea
            rect = rectOf(oldComp)
            while rect.x+rect.w <= allowedArea.x+allowedArea.w - DUPLICATE_COMPONENT_MIN_EDGE_INSET_X
                found = findComponentOccupyingRect @screen.rootComponent, rect
                return { rect, moves: [] } unless found
                rect.x += found.effsize.w + DUPLICATE_COMPONENT_OFFSET_X

            rect = rectOf(oldComp)
            while rect.y+rect.h <= allowedArea.y+allowedArea.h - DUPLICATE_COMPONENT_MIN_EDGE_INSET_Y
                found = findComponentOccupyingRect @screen.rootComponent, rect
                return { rect, moves: [] } unless found
                rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y

            # when everything else fails, just pick a position not occupied by exact duplicate
            rect = rectOf(oldComp)
            while rect.y+rect.h <= allowedArea.y+allowedArea.h
                found = no
                traverse @screen.rootComponent, (c) -> found = c if c.abspos.x == rect.x && c.abspos.y == rect.y
                # handle (0,0) case
                found = null if found is @screen.rootComponent
                return { rect, moves: [] } unless found
                rect.y += found.effsize.h + DUPLICATE_COMPONENT_OFFSET_Y
            return null

    computeDeletionEffect: (comp) ->
        { moves: [] }

    relayout: ->
        #

    hasNonFlexiblePosition: (comp) -> false

class TableRowLayout extends RegularLayout
    #

computeContainerLayout = (screen, container) ->
    if container.type.layoutChildren
        new ContainerDeterminedLayout(screen, container)
    else
        new RegularLayout(screen, container)

containerAcceptsChild = (container, candidateChild) ->
    if container.type.allowedChildren
        return candidateChild.type.name in container.type.allowedChildren
    else
        return true

containerSatisfiesChild = (container, candidateChild) ->
    if allowed = candidateChild.type.allowedContainers
        container.type.name in allowed
    else
        yes

# either target or rect is specified
# (note: I'd really want to split up this function into determineDropTarget(comp, rect) and
# then use computeContainerLayout(target), but I expect that for some target containers,
# the layout to use will depend on the rect and/or comp)
computeLayout = (screen, comp, target, rect) ->
    return null unless target? or rect?

    if pin = comp.type.pin
        new PinnedLayout(screen, screen.rootComponent)
    else if comp.type.isTableRow
        new TableRowLayout(screen, screen.rootComponent)
    else if comp.type.name is 'tab-bar-item'
        if target = findChildByType(screen.rootComponent, Mockko.componentTypes['tabBar'])
            new ContainerDeterminedLayout(screen, target)
        else
            null
    else if (target and target.type.name is 'toolbar') or (rect and (target = findComponentByTypeIntersectingRect(screen.rootComponent, Mockko.componentTypes['toolbar'], rect, setOf [comp])))
        new ContainerDeterminedLayout(screen, target)
    else
        unless target
            for possibleType in comp.type.allowedContainers || []
                if target = findComponentByTypeIntersectingRect screen.rootComponent, Mockko.componentTypes[possibleType], rect, setOf [comp]
                    break
            unless target
                target = findBestTargetContainerForRect screen.rootComponent, rect, [comp]
            while not containerAcceptsChild target, comp
                target = target.parent

        if target
            computeContainerLayout screen, target
        else
            null


computeDropEffect = (screen, comp, rect, moveOptions) ->
    if comp.type.name is 'image' and (target = findComponentByTypeIntersectingRect(screen.rootComponent, Mockko.componentTypes['tab-bar-item'], rect, setOf [comp]))
        return { target, moves: [], isAnchored: yes, rect: centerSizeInRect(comp.effsize, rectOf target) }

    if layout = computeLayout screen, comp, null, rect
        if comp.type.singleInstance
            for child in layout.target.children
                if child.type is comp.type
                    return null

        eff = layout.computeDropEffect comp, rect, moveOptions
        eff.target = layout.target
        return eff
    else
        return null

computeDuplicationEffect = (screen, newComp, oldComp) ->
    oldComp ||= newComp
    if layout = computeLayout screen, oldComp, oldComp.parent
        layout.computeDuplicationEffect oldComp, newComp
    else
        null

computeDeletionEffect = (screen, comp) ->
    return { moves: [] } unless comp.parent

    if layout = computeLayout screen, comp, comp.parent
        layout.computeDeletionEffect comp
    else
        { moves: [] }

computeRelayoutEffect = (screen, comp) ->
    computeContainerLayout(screen, comp).relayout()

hasNonFlexiblePosition = (screen, comp) ->
    return true if comp.type is Mockko.componentTypes['background']
    if layout = computeLayout(screen, comp, comp.parent)
        return layout.hasNonFlexiblePosition(comp)
    return false

adjustChildAfterPasteOrDuplication = (screen, child, container) ->
    container.type.adjustChildAfterPasteOrDuplication(screen, child, container)

Mockko.layouting = {
    computeRelayoutEffect
    computeDropEffect
    computeDuplicationEffect
    computeDeletionEffect
    hasNonFlexiblePosition
    adjustChildAfterPasteOrDuplication
    containerAcceptsChild, containerSatisfiesChild
}
