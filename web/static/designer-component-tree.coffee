#
# Change Bus: change processing & rerendering queue
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ areaOfSize, isRectStrictlyInsideRect } = Mockko.geom
{ rectOf, sizeOf, traverse, flatSubtreeOfComponent, dumpComponentTree } = Mockko.model
layouting = Mockko.layouting  # for containerAcceptsChild

pushChild = (child, container) ->
    container.children.push child
    child.parent = container

insertIntoTree = (newComponent, treeComponent) ->
    newComponentR = rectOf newComponent
    candidateChildren = []
    for child in treeComponent.children
        childR = rectOf child
        if isRectStrictlyInsideRect(newComponentR, childR) and layouting.containerAcceptsChild(child, newComponent) and layouting.containerSatisfiesChild(child, newComponent)
            return insertIntoTree newComponent, child
        if isRectStrictlyInsideRect(childR, newComponentR) and layouting.containerAcceptsChild(newComponent, child) and layouting.containerSatisfiesChild(newComponent, child)
            candidateChildren.push child
    for child in candidateChildren
        pushChild child, newComponent
    treeComponent.children = (child for child in treeComponent.children when child.parent isnt newComponent)
    pushChild newComponent, treeComponent
    undefined

rebuildComponentTree = (rootComponent) ->
    # console.log "OLD component tree:\n" + dumpComponentTree(rootComponent)

    traverse rootComponent, (child) ->
        child.componentTree_rect = r = rectOf child
        child.componentTree_area =    areaOfSize r
        child.componentTree_oldParent = child.parent

    subtree = flatSubtreeOfComponent rootComponent
    for child in subtree
        child.children = []
        child.parent = null
    newRootComponent = subtree.shift()
    unless newRootComponent is rootComponent
        throw "internal assertion error: newRootComponent isnt rootComponent"

    sorted = _(subtree).sortBy (c) -> -c.componentTree_area
    for child in sorted
        insertIntoTree child, rootComponent

    # console.log "NEW component tree:\n" + dumpComponentTree(rootComponent)

window.Mockko.componentTree = { rebuildComponentTree }