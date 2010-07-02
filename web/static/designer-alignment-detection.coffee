#
# Alignment Detection
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ rectOf, findComponentByRect, compWithChildrenAndParents }: Mockko.model
{ centerOfRect }: Mockko.geom


ALIGNMENT_DETECTION_CENTER_FUZZINESS_PX: 2
ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX: 17
ALIGNMENT_DETECTION_SIBLING_FUZZINESS_PX: 12
Alignments: {
    left: {
        bestDefiniteGuess: -> this
        cssValue: 'left'
        adjustedPosition: (originalRect, newSize) -> null
    }
    center: {
        bestDefiniteGuess: -> this
        cssValue: 'center'
        adjustedPosition: (originalRect, newSize) ->
            c: centerOfRect originalRect
            { x: c.x - newSize.w/2, y: originalRect.y }
    }
    right: {
        bestDefiniteGuess: -> this
        cssValue: 'right'
        adjustedPosition: (originalRect, newSize) ->
            { x: originalRect.x+originalRect.w - newSize.w, y: originalRect.y }
    }
    tight: {
        bestDefiniteGuess: -> Alignments.left
    }
    unknown: {
        bestDefiniteGuess: -> Alignments.left
    }
}
(->
    for name, al of Alignments
        al.name: name
)()
Edges: {
    top: {
        siblingRect: (r, distance) -> { x: r.x, w: r.w, h: distance, y: r.y - distance }
    }
    bottom: {
        siblingRect: (r, distance) -> { x: r.x, w: r.w, h: distance, y: r.y + r.h }
    }
    left: {
        siblingRect: (r, distance) -> { y: r.y, h: r.h, w: distance, x: r.x - distance }
    }
    right: {
        siblingRect: (r, distance) -> { y: r.y, h: r.h, w: distance, x: r.x + r.w }
    }
}

possibleAlignmentOf: (comp, screen) ->
    return Alignments.unknown unless comp.parent

    pr: rectOf comp.parent
    cr: rectOf comp

    return Alignments.left  if pr.x <= cr.x <= pr.x + ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX
    return Alignments.right if pr.x+pr.w - ALIGNMENT_DETECTION_EDGE_FUZZINESS_PX <= cr.x+cr.w <= pr.x+pr.w

    nonSiblings: setOf compWithChildrenAndParents comp
    findConstrainingSibling: (edge) -> findComponentByRect(screen.rootComponent, edge.siblingRect(cr, ALIGNMENT_DETECTION_SIBLING_FUZZINESS_PX), nonSiblings)

    leftSibling:  findConstrainingSibling Edges.left
    rightSibling: findConstrainingSibling Edges.right
    return Alignments.tight if leftSibling and rightSibling
    return Alignments.right if rightSibling
    return Alignments.left  if leftSibling

    if Math.abs(centerOfRect(pr).x - centerOfRect(cr).x) <= ALIGNMENT_DETECTION_CENTER_FUZZINESS_PX
        return Alignments.center

    return Alignments.unknown


Mockko.possibleAlignmentOf: possibleAlignmentOf
