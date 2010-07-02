#
# Undo
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

(window.Mockko ||= {}).newUndoManager: (createApplicationMemento, revertToMemento, saveApplicationChanges, lastCommandChanged) ->
    undoStack: []
    lastChange: null

    beginTransaction: (changeName) ->
        if lastChange isnt null
            console.log "Make-App Internal Warning: implicitly closing an unclosed undo change: ${lastChange.name}"
        lastChange: { memento: createApplicationMemento(), name: changeName }
        console.log "Start: ${lastChange.name}"

    setCurrentChangeName: (changeName) -> lastChange.name: changeName

    endTransaction: ->
        return if lastChange is null
        if lastChange.memento != createApplicationMemento()
            console.log "Change: ${lastChange.name}"
            undoStack.push lastChange
            undoStackChanged()
            saveApplicationChanges()
        lastChange = null

    rollbackTransaction: ->
        console.log "Rollback: ${lastChange.name}"
        revertToMemento lastChange.memento
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
        beginTransaction, endTransaction, rollbackTransaction, setCurrentChangeName, undoLastChange
    }
