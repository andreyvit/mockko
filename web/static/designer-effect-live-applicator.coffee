#
# Live Previewing & Application of Drop Effects
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#


{ subPtPt }: Mockko.geom
{ traverse, skipTraversingChildren }: Mockko.model


STACKED_COMP_TRANSITION_DURATION = 200


newLiveDropEffectPreviewer: (screen, excluded, componentPositionChanged) ->
    excludedSet: setOf excluded
    traverse screen.rootComponent, (c) ->
        if inSet c, excludedSet
            return skipTraversingChildren
        $(c.node).addClass 'stackable'

    {
        moveComponents: (moves) ->
            for m in moves
                if m.comp
                    m.comps: [m.comp]
                for c in m.comps
                    if inSet c, excludedSet
                        throw "Component ${c.type.name} cannot be moved because it has been excluded!"
            componentSet: setOf _.flatten(m.comps for m in moves)

            traverse screen.rootComponent, (c) ->
                if inSet c, excludedSet
                    return skipTraversingChildren
                if inSet c, componentSet
                    return skipTraversingChildren
                if c.dragpos
                    c.dragpos: null
                    c.dragsize: null
                    c.dragParent: null
                    $(c.node).removeClass 'stacked'
                    componentPositionChanged c

            for m in moves
                for c in m.comps
                    $(c.node).addClass 'stacked'
                    offset: m.offset || subPtPt(m.abspos, c.abspos)
                    traverse c, (child) ->
                        child.dragpos: { x: child.abspos.x + offset.x; y: child.abspos.y + offset.y }
                        child.dragsize: m.size || null
                        child.dragParent: child.parent
                        componentPositionChanged child

        rollback: ->
            traverse screen.rootComponent, (c) ->
                if inSet c, excludedSet
                    return skipTraversingChildren
                $(c.node).removeClass 'stackable'
            traverse screen.rootComponent, (c) ->
                if inSet c, excludedSet
                    return skipTraversingChildren
                if c.dragpos
                    c.dragpos: null
                    c.dragsize: null
                    c.dragParent: null
                    $(c.node).removeClass 'stacked'
                    componentPositionChanged c

        commit: (delay) ->
            traverse screen.rootComponent, (c) ->
                if c.dragpos
                    c.abspos = c.dragpos
                    if c.dragsize
                        c.size: c.dragsize
                    c.dragpos: null
                    c.dragsize: null
                    c.dragParent: null
                    componentPositionChanged c

            cleanup: -> $('.component').removeClass 'stackable'
            if delay? then setTimeout(cleanup, delay) else cleanup()
    }

commitMoves: (moves, exclusions, delay, screen, componentPositionChanged) ->
    if moves.length > 0
        liveMover: newLiveDropEffectPreviewer screen, exclusions, componentPositionChanged
        liveMover.moveComponents moves
        liveMover.commit(delay)

commitMovesImmediately: (moves, componentPositionChanged) ->
    for m in moves
        for c in m.comps || [m.comp]
            offset: m.offset || subPtPt(m.abspos, c.abspos)
            traverse c, (child) ->
                child.abspos: { x: child.abspos.x + offset.x; y: child.abspos.y + offset.y }
                child.size: m.size if m.size
                componentPositionChanged child

Mockko.applicator: { newLiveDropEffectPreviewer, commitMoves, commitMovesImmediately, STACKED_COMP_TRANSITION_DURATION }
