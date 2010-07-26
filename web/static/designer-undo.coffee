#
# Undo
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

DONT_MERGE_UNDO_STEPS_AFTER_MS: 5000

(window.Mockko ||= {}).newUndoManager: (createApplicationMemento, revertToMemento, saveApplicationChanges, lastCommandChanged) ->
    undoStack: []
    lastChange: null

    beginTransaction: (changeName) ->
        if lastChange isnt null
            console.log "Make-App Internal Warning: implicitly closing an unclosed undo change: ${lastChange.name}"
        lastChange: { memento: createApplicationMemento(), name: changeName, at: Date.now() }
        console.log "Start: ${lastChange.name}"

    setCurrentChangeName: (changeName) -> lastChange.name: changeName

    endTransaction: ->
        return if lastChange is null
        if lastChange.memento != createApplicationMemento()
            console.log "Change: ${lastChange.name}"
            if undoStack.length > 0
                previousChange: undoStack[undoStack.length - 1]
                if lastChange.at - previousChange.at < DONT_MERGE_UNDO_STEPS_AFTER_MS
                    if mergableChanges previousChange, lastChange
                        lastChange.memento: previousChange.memento
                        undoStack.pop()
            undoStack.push lastChange
            undoStackChanged()
            saveApplicationChanges()
        lastChange = null

    mergableChanges: (previous, current) ->
        name: current.name
        if previous.name == name
            if name.match(/^keyboard moving of/)
                return yes
        no

    rollbackTransaction: ->
        console.log "Rollback: ${lastChange.name}"
        revertToMemento lastChange.memento
        lastChange: null

    abandonTransaction: ->
        lastChange: null

    undoStackChanged: ->
        if undoStack.length != 0
            lastCommandChanged "Undo ${undoStack[undoStack.length-1].name}"
        else
            lastCommandChanged null

    undoLastChange: ->
        return if undoStack.length == 0
        change: undoStack.pop()
        console.log "Undoing: ${change.name}"
        revertToMemento change.memento
        undoStackChanged()

    undoStackChanged()
    
    {
        beginTransaction, endTransaction, rollbackTransaction, abandonTransaction
        setCurrentChangeName, undoLastChange
    }
