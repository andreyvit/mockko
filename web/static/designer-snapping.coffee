#
# Undo
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ rectOf }: Mockko.model


CONF_SNAPPING_DISTANCE: 5


class Snapping
    constructor: (magnet, anchor) ->
        @magnet: magnet
        @anchor: anchor
        @affects: magnet.affects
        @distance: Math.abs(@magnet.coord - @anchor.coord)
    isValid: ->
        @distance <= CONF_SNAPPING_DISTANCE

Snappings: {}

class Snappings.left extends Snapping
    apply: (rect) -> rect.x: @anchor.coord
class Snappings.leftonly extends Snappings.left
class Snappings.right extends Snapping
    apply: (rect) -> rect.x: @anchor.coord - rect.w
class Snappings.rightonly extends Snappings.right
class Snappings.xcenter extends Snapping
    apply: (rect) -> rect.x: @anchor.coord - rect.w/2

class Snappings.top extends Snapping
    apply: (rect) -> rect.y: @anchor.coord
class Snappings.bottom extends Snapping
    apply: (rect) -> rect.y: @anchor.coord - rect.h
class Snappings.ycenter extends Snapping
    apply: (rect) -> rect.y: @anchor.coord - rect.h/2

Snappings.left.snapsTo:    (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.leftonly
Snappings.right.snapsTo:   (anchor) -> anchor.snappingClass is Snappings.left or anchor.snappingClass is Snappings.right or anchor.snappingClass is Snappings.rightonly
Snappings.xcenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.xcenter
_([Snappings.left, Snappings.right, Snappings.xcenter]).each (s) -> s.affects: 'x'

Snappings.top.snapsTo:     (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
Snappings.bottom.snapsTo:  (anchor) -> anchor.snappingClass is Snappings.top or anchor.snappingClass is Snappings.bottom
Snappings.ycenter.snapsTo: (anchor) -> anchor.snappingClass is Snappings.ycenter
_([Snappings.top, Snappings.bottom, Snappings.ycenter]).each (s) -> s.affects: 'y'

Anchors: {}
class Anchors.line
    constructor: (comp, snappingClass, coord) ->
        @comp:    comp
        @coord:   coord
        @snappingClass: snappingClass
        @affects: @snappingClass.affects
    snapTo: (anchor) ->
        if @snappingClass.snapsTo anchor
            new @snappingClass(this, anchor)
        else
            null

computeOuterAnchors: (comp, r, allowedArea) ->
    _.compact [
        new Anchors.line(comp, Snappings.left,    r.x)            if r.x > allowedArea.x
        new Anchors.line(comp, Snappings.right,   r.x + r.w)      if r.x+r.w < allowedArea.x+allowedArea.w
        new Anchors.line(comp, Snappings.xcenter, r.x + r.w / 2)
        new Anchors.line(comp, Snappings.top,     r.y)            if r.y > allowedArea.y
        new Anchors.line(comp, Snappings.bottom,  r.y + r.h)      if r.y+r.h < allowedArea.y+allowedArea.h
        new Anchors.line(comp, Snappings.ycenter, r.y + r.h / 2)
    ]

computeInnerAnchors: (comp, forComp, allowedArea) ->
    anchors: _.flatten(computeOuterAnchors(child, rectOf(child), allowedArea) for child in comp.children)
    rect: rectOf(comp)
    anchors: anchors.concat computeOuterAnchors(comp, rect, allowedArea)
    if comp.type.name is 'plain-row'
        anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 8)
        anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 43)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 8-8-10)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 43)
    if comp.type.name is 'roundrect-row'
        anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 20)
        anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 55)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 20-8-10)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 55)
    if comp.type.name is 'navBar'
        anchors.push new Anchors.line(comp, Snappings.leftonly, rect.x + 5)
        anchors.push new Anchors.line(comp, Snappings.rightonly, rect.x+rect.w - 5)
    anchors

computeMagnets: (comp, rect, allowedArea) -> computeOuterAnchors(comp, rect, allowedArea)

computeSnappings: (anchors, magnets) ->
    snappings: []
    for magnet in magnets
        for anchor in anchors
            if snapping: magnet.snapTo anchor
                snappings.push snapping
    snappings

chooseSnappings: (snappings) ->
    bestx: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'x'), (s) -> s.distance)
    besty: _.min(_.select(snappings, (s) -> s.isValid() and s.affects is 'y'), (s) -> s.distance)
    _.compact [bestx, besty]


Mockko.snapping: {
    computeInnerAnchors, computeMagnets, computeSnappings, chooseSnappings
}
