#
# Geometry Utilities
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#


##############################################################################################################
##  Legacy

isRectInsideRect: (i, o) -> i.x >= o.x and i.x+i.w <= o.x+o.w and i.y >= o.y and i.y+i.h <= o.y+o.h

doesRectIntersectRect: (a, b) ->
    (b.x <= a.x+a.w) and (b.x+b.w >= a.x) and (b.y <= a.y+a.h) and (b.y+b.h >= a.y)

rectIntersection: (a, b) ->
    x: Math.max(a.x, b.x)
    y: Math.max(a.y, b.y)
    x2: Math.min(a.x+a.w, b.x+b.w)
    y2: Math.min(a.y+a.h, b.y+b.h)
    if x2 < x then t = x2; x2 = x; x = t
    if y2 < y then t = y2; y2 = y; y = t
    { x: x, y: y, w: x2-x, h: y2-y }

areaOfIntersection: (a, b) ->
    if doesRectIntersectRect(a, b)
        r: rectIntersection(a, b)
        r.w * r.h
    else
        0

proximityOfRectToRect: (a, b) ->
    if doesRectIntersectRect(a, b)
        r: rectIntersection(a, b)
        -(r.w * r.h)
    else
        a2: { x: a.x+a.w, y: a.y+a.h }
        b2: { x: b.x+b.w, y: b.y+b.h }
        dx: Math.min(Math.abs(a.x - b.x), Math.abs(a2.x - b.x), Math.abs(a.x - b2.x), Math.abs(a2.x - b2.x))
        dy: Math.min(Math.abs(a.y - b.y), Math.abs(a2.y - b.y), Math.abs(a.y - b2.y), Math.abs(a2.y - b2.y))
        dy*dy

ptDiff: (a, b) -> { x: a.x - b.x, y: a.y - b.y }
ptSum:  (a, b) -> { x: a.x + b.x, y: a.y + b.y }
ptMul:  (p, r) -> { x: p.x * r,   y: p.y * r   }
distancePtToPtMod: (a, b) -> Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y))
distancePtToPtSqr: (a, b) -> Math.sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))


##############################################################################################################
##  Point

ZeroPt:        { x: 0, y: 0 }
ptToString:    (pt) -> "(${pt.x},${pt.y})"
distancePtPt1: (a, b) -> Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y))
distancePtPt2: (a, b) -> Math.sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))
addPtPt:       (a, b) -> { x: a.x + b.x, y: a.y + b.y }
subPtPt:       (a, b) -> { x: a.x - b.x, y: a.y - b.y }
mulPtSize:     (p, s) -> { x: p.x * s.w, y: p.y * s.h }
ptFromLT:      (lt) -> { x: lt.left, y: lt.top }
ptFromNode:    (node) -> ptFromLT $(node).offset()
unitVecOfPtPt: (a, b) ->
    len: distancePtPt2(a, b)
    if len is 0 then ZeroPt else { x: (b.x-a.x)/len, y: (b.y-a.y)/len }
mulVecLen:     (v, len) -> { x: v.x * len, y: v.y * len }
ptInRect:      (pt, r) -> (r.x <= pt.x < r.x+r.w and r.y <= pt.y <= r.y+r.h)


##############################################################################################################
##  Size

ZeroSize:     { w: 0, h: 0 }
sizeToString: (size) -> "${size.w}x${size.h}"
domSize:      (node) -> { w: node.offsetWidth, h: node.offsetHeight }
centerOfSize: (s) -> { x: s.w / 2, y: s.h / 2 }


##############################################################################################################
##  Rect

rectToString:      (r) -> "(${r.x},${r.y} ${r.w}x${r.h})"
rectFromPtAndSize: (p, s) -> { x:p.x, y:p.y, w:s.w, h:s.h }
rectFromPtPt:      (a, b) -> canonRect { x: Math.min(a.x, b.x), x2: Math.max(a.x, b.x), y: Math.min(a.y, b.y), y2: Math.max(a.y, b.y) }
dupRect:           (r)    -> { x:r.x, y:r.y, w:r.w, h:r.h }
addRectPt:         (r, p) -> { x:r.x+p.x, y:r.y+p.y, w:r.w, h:r.h }
subRectPt:         (r, p) -> { x:r.x-p.x, y:r.y-p.y, w:r.w, h:r.h }
topLeftOf:         (r) -> { x: r.x, y: r.y }
bottomRightOf:     (r) -> { x: r.x+r.w, y: r.y+r.h }
rectOfNode:        (node) -> rectFromPtAndSize ptFromLT($(node).offset()), { w: $(node).width(), h: $(node).height() }
canonRect:         (r) -> {
    x: r.x, y: r.y
    w: (if r.w? then r.w else r.x2-r.x+1)
    h: (if r.h? then r.h else r.y2-r.y+1)
}
insetRect: (r, i) -> { x: r.x+i.l, y: r.y+i.t, w: r.w-i.l-i.r, h: r.h-i.t-i.b }

centerOfRect: (r) -> { x: r.x + r.w / 2, y: r.y + r.h / 2 }
centerSizeInRect:  (s, r) -> rectFromPtAndSize { x: r.x + (r.w-s.w) / 2, y: r.y + (r.h-s.h)/2 }, s


##############################################################################################################
##  Line / Segment

# note: this is both for a line and a segment, but the returned p1, p2 only make sense for a segment
lineFromPtPt: (p1, p2) ->
    A: p2.y - p1.y
    B: p1.x - p2.x
    C: -(A * p1.x + B * p1.y)
    { A, B, C, p1, p2 }

lineFromABPt: (A, B, pt) ->
    C: -(A * pt.x + B * pt.y)
    { A, B, C }

signum: (v) -> (v > 0) - (v < 0)

# -1, 0, 1 depending on whether the point is below, on or above the line
classifyPtLine: (pt, line) -> signum(line.A * pt.x + line.B * pt.y + line.C)

perpendicularLineThroughPoint: (line, pt) -> lineFromABPt line.B, -line.A, pt

distancePtLine: (pt, line) ->
    Math.abs(line.A * pt.x + line.B * pt.y + line.C) / Math.sqrt(line.A*line.A + line.B*line.B)

distancePtSegment: (pt, segm) ->
    # is outside the segment?
    if classifyPtLine(pt, perpendicularLineThroughPoint(segm, segm.p1)) == classifyPtLine(pt, perpendicularLineThroughPoint(segm, segm.p2))
        console.log "outside"
        Math.min(distancePtPt2(pt, segm.p1), distancePtPt2(pt, segm.p2))
    else
        console.log "inside"
        distancePtLine pt, segm

    ##############################################################################################################
##  Exports

(window.Mockko ||= {}).geom: {
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
}
