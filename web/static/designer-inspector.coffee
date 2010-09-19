#
# Inspector
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

{ textNodeOfComponent } = Mockko.renderer
{ friendlyComponentName } = Mockko.model


Mockko.setupInspector = (hooks) ->
    { componentToActUpon, componentStyleChanged, componentActionChanged, runTransaction, modeEngine:modes } = hooks

    ##############################################################################################################
    ##  Supporting Stuff

    activateInspector = (name) ->
        $("#insp-#{name}-tab").trigger 'click'

    bindStyleChangeButton = (button, func) ->
        savedComponent = null
        cancelStyle = ->
            if savedComponent
                savedComponent.stylePreview = null
                componentStyleChanged savedComponent
                savedComponent = null

        $(button).bind {
            mouseover: ->
                cancelStyle()
                return if $(button).is('.disabled')
                if c = savedComponent = componentToActUpon()
                    c.stylePreview = cloneObj(c.style)
                    func(c, c.stylePreview)
                    componentStyleChanged c

            mouseout: cancelStyle

            click: ->
                cancelStyle()
                return if $(button).is('.disabled')
                if c = componentToActUpon()
                    c.stylePreview = null
                    runTransaction "changing style of #{friendlyComponentName c}", ->
                        s = func(c, c.style)
                        # TODO: do something with it -- does not merit an additional dependency at the moment
                        # if s && s.constructor == String
                        #     undo.setCurrentChangeName s.replace(/\bcomp\b/, friendlyComponentName(c))
                        componentStyleChanged c
        }


    ##############################################################################################################
    ##  Backgrounds Inspector

    setupBackgroundInspector = ->
        $pal = $('#backgrounds-palette')
        for bg in Mockko.backgroundStyles
            node = domTemplate('background-swatch-template')
            $(node).attr({'id': "bg-#{bg.name}", 'title': bg.label}).addClass("bg-#{bg.name}").appendTo($pal)
            bindBackground node, bg

    bindBackground = (swatch, bg) ->
        bindStyleChangeButton swatch, (c, style) ->
            style.background = bg.name
            "setting background of comp to #{bg.label}"

    updateBackgroundsInspector = ->
        enabled = no
        $('#insp-backgrounds-pane li').removeClass 'active'
        if c = componentToActUpon()
            enabled = c.type.supportsBackground
            if enabled
                if active = c.style.background || ''
                    $("#bg-#{active}").addClass 'active'
        $('#insp-backgrounds-pane li').alterClass 'disabled', !enabled


    ##############################################################################################################
    ##  Position Inspector

    updatePositionInspector = ->
        if c = componentToActUpon()
            abspos = c.dragpos || c.abspos
            relpos = { x: abspos.x - c.parent.abspos.x, y: abspos.y - c.parent.abspos.y } if c.parent?
            $('#insp-rel-pos').html(if c.parent? then "(#{relpos.x}, #{relpos.y})" else "&mdash;")
            $('#insp-abs-pos').html "(#{abspos.x}, #{abspos.y})"
            $('#insp-size').html "#{c.effsize.w}x#{c.effsize.h}"
        else
            $('#insp-rel-pos').html "&mdash;"
            $('#insp-abs-pos').html "&mdash;"
            $('#insp-size').html "&mdash;"


    ##############################################################################################################
    ##  Text Inspector

    ignorePickerUpdates = no

    formatHexColor = (color) ->
        if (m = color.match(/^\s*([a-hA-H0-9]{6})\s*$/)) or (m = color.match(/^\s*#([a-hA-H0-9]{6})\s*/))
            return m[1].toLowerCase()
        if (m = color.match(/^\s*([a-hA-H0-9]{3})\s*$/)) or (m = color.match(/^\s*#([a-hA-H0-9]{3})\s*/))
            return (m[1][0] + m[1][0] + m[1][1] + m[1][1] + m[1][2] + m[1][2]).toLowerCase()
        return null

    setupTextInspector = ->
        bindStyleChangeButton $('#make-size-smaller'), (c, style) ->
            if tn = textNodeOfComponent c
                currentSize = c.style.fontSize || parseInt getComputedStyle(tn, null).fontSize
                style.fontSize = currentSize - 1
                "decreasing font size of comp to #{style.fontSize} px"
        bindStyleChangeButton $('#make-size-bigger'), (c, style) ->
            if tn = textNodeOfComponent c
                currentSize = c.style.fontSize || parseInt getComputedStyle(tn, null).fontSize
                style.fontSize = currentSize + 1
                "increasing font size of comp to #{style.fontSize} px"

        bindStyleChangeButton $('#text-bold'), (c, style) ->
            if tn = textNodeOfComponent c
                currentState = if c.style.fontBold? then c.style.fontBold else getComputedStyle(tn, null).fontWeight is 'bold'
                style.fontBold = not currentState
                if style.fontBold then "making comp bold" else "making comp non-bold"

        bindStyleChangeButton $('#text-italic'), (c, style) ->
            if tn = textNodeOfComponent c
                currentState = if c.style.fontItalic? then c.style.fontItalic else getComputedStyle(tn, null).fontStyle is 'italic'
                style.fontItalic = not currentState
                if style.fontItalic then "making comp italic" else "making comp non-italic"

        bindStyleChangeButton $('#shadow-none'), (c, style) -> updateShadowStyle 'none', c, style
        bindStyleChangeButton $('#shadow-dark-above'), (c, style) -> updateShadowStyle 'dark-above', c, style
        bindStyleChangeButton $('#shadow-light-below'), (c, style) -> updateShadowStyle 'light-below', c, style

        $('#pick-color-button').click ->
            if $('#color-picker').is(':visible')
                $('#color-picker').hide()
            else if $('#pick-color-button').is(':not(.disabled)')
                offsets = {
                    button: $('#pick-color-button').offset()
                    pickerParent: $('#color-picker').parent().offset()
                }
                pickerSize = {
                    width: $('#color-picker').outerWidth()
                    height: $('#color-picker').outerHeight()
                }
                $('#color-picker').css {
                    left: offsets.button.left - pickerSize.width/2  - offsets.pickerParent.left
                    top:  offsets.button.top  - pickerSize.height - 10 - offsets.pickerParent.top
                }
                $('#color-picker').show()

        $('#text-color-input').focus ->
            modes.activateMode {
                isTextColorEditingMode: yes
                isInsideTextField: yes
                deactivated:  ->
                    # $('#color-picker').hide(200)
                    commitTextColor(true)
                    updateTextInspector()
                cancel: -> $('#text-color-input').blur()
                mousemove: -> false
                mouseup: -> false
            }
        $('#text-color-input').blur ->
            if modes.activeMode()?.isTextColorEditingMode
                modes.deactivateMode()

        # color picker

        $('#text-color-input').livechange -> commitTextColor(false); true

        commit = (color, context) ->
            return if ignorePickerUpdates
            $('#text-color-input').val color.val('hex')
            commitTextColor(true)

        $('#color-picker').jPicker {
            images: {
                clientPath: 'static/theme/images/jpicker/'
            }
        }, commit, commit


    updateTextInspector = ->
        pixelSize = null
        textStyleEditable = no
        bold = no
        italic = no
        textColor = null
        if c = componentToActUpon()
            tn = textNodeOfComponent c
            if tn
                cs = getComputedStyle(tn, null)
                pixelSize = parseInt cs.fontSize
                bold = cs.fontWeight is 'bold'
                italic = cs.fontStyle is 'italic'
                textColor = if c.style.textColor then formatHexColor c.style.textColor else null
            textStyleEditable = c.type.textStyleEditable
        $('#pixel-size-label').html(if pixelSize then "#{pixelSize} px" else "")
        $('#insp-text-pane li')[if textStyleEditable then 'removeClass' else 'addClass']('disabled')
        $('#text-bold')[if bold then 'addClass' else 'removeClass']('active')
        $('#text-italic')[if italic then 'addClass' else 'removeClass']('active')
        if textColor is null
            $('#text-color-input').attr('disabled', 'disabled')
        else
            $('#text-color-input').removeAttr('disabled')
        $('#text-color-input').val(textColor || '') unless modes.activeMode()?.isTextColorEditingMode
        $('#pick-color-button').alterClass('disabled', textColor is null or !textStyleEditable)
        $('#pick-color-swatch').css 'background-color', (if textColor then '#'+textColor else 'transparent')
        setColorToPicker(textColor) if textColor
        if textColor is null and $('#color-picker').is(':visible')
            $('#color-picker').hide()

    updateShadowStyle = (shadowStyleName, c, style) ->
        style.textShadowStyleName = shadowStyleName
        "changing text shadow of comp to #{Mockko.textShadowStyles[shadowStyleName].label}"

    setColorToPicker = (color) ->
        ignorePickerUpdates = yes
        $.jPicker.List[0].color.active.val('hex', color)
        ignorePickerUpdates = no

    commitTextColor = (fromPicker) ->
        if (fromPicker or modes.activeMode()?.isTextColorEditingMode) and (c = componentToActUpon())
            originalColor = $('#text-color-input').val()
            color = formatHexColor originalColor
            $('#text-color-input').alterClass('invalid', color is null)

            if color and color isnt c.style.textColor
                runTransaction "color change", ->
                    c.style.textColor = '#' + color
                componentStyleChanged c

            if fromPicker and color and color isnt originalColor
                $('#text-color-input').val(color)

            setColorToPicker(color) unless fromPicker


    ##############################################################################################################
    ##  Action Inspector

    setupActionInspector = ->
        $('#no-action-button').click (e) ->
            modes.cancelMode()
            if c = componentToActUpon()
                if enabled = not c.type.forbidsAction
                    runTransaction "clearing action of #{friendlyComponentName c}", ->
                        c.action = null
                        componentActionChanged c
                        updateActionInspector()

        $('#set-action-button').click (e) ->
            if modes.activeMode()?.isActionPickingMode
                modes.deactivateMode()
            else if c = componentToActUpon()
                if enabled = not c.type.forbidsAction
                    activateActionPickingMode c

    updateActionInspector = ->
        # enabled = no
        # current = ""
        # actionSet = no
        # actionCleared = no
        # if activeMode()?.isActionPickingMode
        #     enabled = yes
        #     current = "&larr; click on a screen in the left pane (ESC to cancel)"
        #     actionSet = yes
        # else if c = componentToActUpon()
        #     if enabled = not c.type.forbidsAction
        #         if act = c.action
        #             current = act.action.describe(act, application)
        #             actionSet = yes
        #         else
        #             current = ""
        #             actionCleared = yes
        # $('#chosen-action-label').html(current)
        # $('#set-action-button, #no-action-button')[if enabled then 'removeClass' else 'addClass']('disabled')
        # $('#set-action-button')[if actionSet then 'addClass' else 'removeClass']('active')
        # $('#no-action-button')[if actionCleared then 'addClass' else 'removeClass']('active')


    ##############################################################################################################
    ##  Integration

    updateInspectorVisibility = ->
        $('#inspector').alterClass 'visible', !!(componentToActUpon())

    updateInspector = ->
        updateInspectorVisibility()
        updateBackgroundsInspector()
        updatePositionInspector()
        updateTextInspector()
        updateActionInspector()

    $('.tab').click ->
        $('.tab').removeClass 'active'
        $(this).addClass 'active'
        $('.pane').removeClass 'active'
        $('#' + this.id.replace('-tab', '-pane')).addClass 'active'
        false

    setupTextInspector()
    setupActionInspector()
    setupBackgroundInspector()
    updateInspector()
    activateInspector 'backgrounds'

    { updateInspector, updateActionInspector, updatePositionInspector }
