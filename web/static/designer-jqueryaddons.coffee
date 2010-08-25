
# This has long grown past being just for jQuery addons.
# Now this file contains all self-contained widgets and functions.

jQuery.fn.runWebKitAnimation: (animationClass, classesToAdd, classesToRemove) ->
    this.one 'webkitAnimationEnd', => this.removeClass("${animationClass} ${classesToRemove || ''}")
    this.addClass "${animationClass} ${classesToAdd || ''}"

jQuery.fn.repositionPopOver: (tipControl) ->
    tipControl: jQuery(tipControl)
    tip: this.find('.tip')
    offset: tipControl.offset()
    center: offset.left + tipControl.outerWidth() / 2
    bottom: offset.top + tipControl.outerHeight()

    tipSize: { width: 37, height: 20 }

    popoverWidth: this.outerWidth()

    popoverOffset: { left: center - popoverWidth/2, top: bottom + tipSize.height }
    popoverOffset.left = Math.min(popoverOffset.left, jQuery(window).width() - popoverWidth - 5)
    parentOffset: jQuery(this.parent()).offset()

    this.css({ top: popoverOffset.top - parentOffset.top, left: popoverOffset.left - parentOffset.left })
    tip.css('left', center - popoverOffset.left - tipSize.width / 2)

jQuery.fn.showPopOverPointingTo: (tipControl, animation) ->
    return if this.is(':visible')
    this.repositionPopOver tipControl
    this.one 'webkitAnimationEnd', => this.removeClass('popin')
    this.runWebKitAnimation (animation || 'popin'), 'visible', ''

jQuery.fn.hidePopOver: ->
    return unless this.is(':visible')
    this.runWebKitAnimation 'fadeout', '', 'visible'

jQuery.fn.togglePopOver: (tipControl) ->
    if this.is(':visible') then this.hidePopOver() else this.showPopOverPointingTo tipControl

jQuery.fn.setdata: (id, newData) -> $.data(this[0], id, newData); this
jQuery.fn.getdata: (id) -> $.data(this[0], id)

$.extend $.fn, {
    alterClass: (className, state) ->
        this[if state then 'addClass' else 'removeClass'](className)
}

$.fn.showAsContextMenuAt: (pt, context) ->
    $menu: $(this)
    $items: $menu.find('li')
    $items.each ->
        evt: jQuery.Event('update')
        evt.enabled: true
        $(this).trigger evt, [context]
        $(this)[if evt.enabled then 'removeClass' else 'addClass']('disabled')
    return unless $menu.has("li:not(.disabled)").length

    $items.unbind('.contextmenu').bind 'click.contextmenu', -> dismiss(); $(this).trigger 'selected', [context]
    $menu.css({ left: pt.x || pt.pageX, top: pt.y || pt.pageY }).fadeIn(150)

    dismiss: ->
        $menu.fadeOut(75)
        document.removeEventListener 'keydown', dismissOnEvent, true
        document.removeEventListener 'mousedown', dismissOnMouse, true
        $items.unbind('.contextmenu')
    dismissOnEvent: (e) -> dismiss(); e.stopPropagation(); e.preventDefault(); false
    dismissOnMouse: (e) -> dismissOnEvent(e) unless $(e.target).closest('ul')[0] is $menu[0]

    document.addEventListener 'keydown', dismissOnEvent, true
    document.addEventListener 'mousedown', dismissOnMouse, true

$.fn.bindContextMenu: (menu, context) ->
    this.bind {
        'contextmenu': (e) ->
            # e.cancelBubble = true
            # e.returnValue = false
            # if e.stopPropagation then e.stopPropagation()
            # if e.preventDefault then e.preventDefault()
            setTimeout (-> $(menu).showAsContextMenuAt e, context), 0
            false
        'mouseup': (e) ->
            if e.which is 3
                e.stopPropagation()
                return
    }

window.stringSetWith: (list) ->
    set: {}
    for item in list
        set[item] = true
    return set

window.cloneObj: (o) ->
    return o if o == null || typeof o != "object"
    return o if o.constructor != Object && o.constructor != Array
    if o.constructor == Date || o.constructor == RegExp || o.constructor == Function ||
    o.constructor == String || o.constructor == Number || o.constructor == Boolean
        return new o.constructor o

    if o.constructor == Array
        $.extend({}, {o:o}).o
    else
        $.extend({}, o)

window.ihash: (->
    nextValue: 0
    ihash: (value) ->
        return value.toString() unless value instanceof Object
        return value.__ihash || (value.__ihash = "#" + ++nextValue)
)()

window.setOf: (list) ->
    set: {}
    for item in list
        set[ihash item] = item
    return set

window.inSet: (el, set) -> ihash(el) of set

window.timeouts: {
    set: (ms, func) -> setTimeout(func, ms)
    clear: (t) -> clearTimeout(t)
    reset: (t, ms, func) -> this.clear(t) if t; this.set(ms, func)
}

window.Timeout: (defaultMS) ->
    value: null
    this.set: (ms, func) ->
        if not func?
            func = ms
            ms = defaultMS
        clearTimeout value if value
        value = setTimeout func, ms
    this.clear: ->
        clearTimeout value if value
        value = null
    this

window.returning: (value, func) ->
    func(value)
    value

_.mixin {
    find: (array, pred) ->
        result: undefined
        _.each array, (item) ->
            if pred(item)
                result: item
                _.breakLoop()
        return result

    removeValue: (array, value) ->
        index: _.indexOf array, value
        if index >= 0
            array.splice index, 1
}

$.extend $, {
    KEY_ENTER:       13
    KEY_BACKSPACE:   8
    KEY_TAB:         9
    KEY_ESC:         27
    KEY_PAGEUP:      33
    KEY_PAGEDOWN:    34
    KEY_END:         35
    KEY_HOME:        36
    KEY_ARROWLEFT:   37
    KEY_ARROWUP:     38
    KEY_ARROWRIGHT:  39
    KEY_ARROWDOWN:   40
    KEY_INSERT:      45
    KEY_DELETE:      46
    KEY_F1:          112
}

# TODO: fire change events when doing cut/copy/paste, etc
jQuery.fn.startInPlaceEditing: (->
    nop: ->
    cancelActiveEditor: nop
    acceptActiveEditor: nop
    DEFAULT_OPTIONS: { before: nop, accept: nop, cancel: nop, after: nop, changed: nop }

    startInPlaceEditing: (options) ->
        cancelActiveEditor()
        options: jQuery.extend({}, DEFAULT_OPTIONS, options)
        $el: this
        savedHTML: $el.html()
        previouslySeenHTML: savedHTML

        startEditing: ->
            $el.css '-webkit-user-select', 'auto'
            $el[0].contentEditable: yes
            setTimeout((-> $el.focus()), 1)
            document.addEventListener 'keydown', handleKeyDown, true
            document.addEventListener 'mousedown', handleMouseDown, true
            document.addEventListener 'mousemove', handleMouseMoveOrUp, true
            document.addEventListener 'mouseup', handleMouseMoveOrUp, true
            $el.bind 'blur.in-place-editor', ->
                acceptActiveEditor(); true
            $el.bind 'change.in-place-editor', -> alert 'change!'

        stopEditing: ->
            $el.css '-webkit-user-select', ''
            $el[0].contentEditable: no
            $el[0].blur()
            document.removeEventListener 'keydown', handleKeyDown, true
            document.removeEventListener 'mousedown', handleMouseDown, true
            document.removeEventListener 'mousemove', handleMouseMoveOrUp, true
            document.removeEventListener 'mouseup', handleMouseMoveOrUp, true
            $el.unbind '.in-place-editor'

        cancelActiveEditor: ->
            [cancelActiveEditor, acceptActiveEditor]: [nop, nop]
            stopEditing()
            $el.html(savedHTML)
            options.cancel()
            options.after($el[0])

        acceptActiveEditor: ->
            [cancelActiveEditor, acceptActiveEditor]: [nop, nop]
            stopEditing()
            checkChange()
            options.accept($el.text() || '')
            options.after($el[0])

        checkChange: ->
            currentHTML: $el.html()
            if currentHTML isnt previouslySeenHTML
                previouslySeenHTML: currentHTML
                options.changed($el.text() || '')

        handleKeyDown: (e) ->
            setTimeout checkChange, 1
            switch e.which
                when 13 then acceptActiveEditor(); false
                when 27 then cancelActiveEditor(); false
                else    e.stopPropagation(); true

        handleMouseDown: (e) ->
            setTimeout checkChange, 1
            if e.target is $el[0]
                e.stopPropagation(); true
            else
                acceptActiveEditor(); true

        handleMouseMoveOrUp: (e) ->
            if e.target is $el[0]
                e.stopPropagation()
                return

        startEditing()
        options.before($el[0])
        undefined
)()

(($) ->
    hiddenCopyTextArea: null
    $ -> hiddenCopyTextArea: $("<textarea />", { css: { 'display': 'none', 'z-index': 9999, 'position': 'absolute', 'left': 0, 'top': 0, 'width': 0, 'height': 0 }}).appendTo($("body"))
    hideTextAreaTimeout: null
    hideTextArea: ->
        hiddenCopyTextArea.hide()
        $('body').focus()
    hideTextAreaLater: ->
        clearTimeout hideTextAreaTimeout if hideTextAreaTimeout
        setTimeout hideTextArea, 10

    $.fn.copiableAsText: (options) ->
        options: { gettext: options } if options.constructor is Function

        this.each ->
            this['onbeforecopy']: this['onbeforecut']: (e) ->
                return if options.shouldProcessCopy && !options.shouldProcessCopy()
                data: options.gettext(this)
                hiddenCopyTextArea.val(data || '').show().focus()
                hiddenCopyTextArea[0].select()
                hideTextAreaLater()
            this['oncopy']: (e) ->
                return if options.shouldProcessCopy && !options.shouldProcessCopy()
                hideTextAreaLater()
            this['oncut']: (e) ->
                return if options.shouldProcessCopy && !options.shouldProcessCopy()
                hideTextAreaLater()
                options.aftercut() if options.aftercut
            if options.paste
                this['onbeforepaste']: (e) ->
                    e.returnValue: false  # some Googled magic... dunno where this is documented
                this['onpaste']: (e) ->
                    return if options.shouldProcessPaste && !options.shouldProcessPaste()
                    e.preventDefault()
                    if data: e.clipboardData.getData("text/plain")
                        options.paste(data)
)(jQuery)

String.prototype.trim: -> this.replace(/^\s+/, '').replace(/\s+$/, '')

window.newModeEngine: (options) ->
    nop: ->
    activeMode: null
    options: $.extend({ modeDidChange: nop }, options)

    activateMode: (mode) -> (activeMode?.cancel || nop)(); oldMode: activeMode; activeMode: mode; (oldMode?.deactivated || nop)(); (activeMode?.activated || nop)(); options.modeDidChange(activeMode)
    deactivateMode:      -> oldMode: activeMode; activeMode: null; (oldMode?.deactivated || nop)(); options.modeDidChange(activeMode)
    cancelMode:          -> (activeMode?.cancel || nop)(); deactivateMode()
    getActiveMode:       -> activeMode

    # dispatchToMode(((a) -> a.methodname), arg1, arg2)
    dispatchToMode: (method, args...) ->
        throw "null method passed to dispatchToMode" unless method
        if not activeMode
            false
        else if func: method(activeMode)
            func.apply(activeMode, args)
        else
            console.log "cancelling mode b/c of ${method}"
            cancelMode()
            false

    { activateMode, deactivateMode, cancelMode, dispatchToMode, activeMode: getActiveMode }

jQuery.fn.scrollToBottom: -> this.scrollTop(this[0].scrollHeight)

unless window.console?
    window.console: {
        log: ->
    }

$.fn.livechange: (handler) ->
    this.each ->
        $self: $(this)
        lastValue: null
        checkForChanges: ->
            if (val: $self.val()) isnt lastValue
                lastValue: val
                handler(val)
        for event in ['change', 'blur', 'keydown', 'keyup', 'keypress', 'focus', 'mouseover', 'mouseout', 'paste', 'input']
            $self.bind "${event}.livechange", checkForChanges


window.encodeNameForId: (name) -> encodeURIComponent(name).replace('%', '_')

window.aOrAn: (s) -> if s[0] of {'a': yes, 'e': yes, 'i': yes, 'o': yes, 'u': yes} then "an ${s}" else "a ${s}"

window.domTemplate: (->
    domTemplates: {}
    $ ->
        $('.template').each ->
            domTemplates[this.id]: this
            $(this).removeClass('template').remove()
    domTemplate: (id) -> domTemplates[id].cloneNode(true)
)()

# Decorates a function to output a trace of all its call to the console.
# Usage:
#     var myFunc = tracing("myFunc", function(a, b){ return a + b; });
window.tracing: (->
    MAX_LEVEL: 20  # never trace deeper than this
    INDENT_STEP: "  "
    level: 0
    indents: [""]
    for i in [1..MAX_LEVEL]
        indents.push(indents[i-1] + INDENT_STEP)
    tracing: (fname, func) ->
        wrapper: (args...) ->
            if level <= MAX_LEVEL
                indent: indents[level]
                console.log ["${indent}${fname}"].concat(args)
            level += 1
            try
                rv: func(args...)
            finally
                level -= 1
            if level <= MAX_LEVEL
                console.log ["${indent}/${fname}", rv]
            return rv
        wrapper.wrapped: func
        wrapper
    tracing
)()
# window.factorial: tracing "factorial", (n) ->
#     switch n
#         when 0, 1 then 1
#         else factorial(n-1) * n

$.fn.checked: (v) ->
    if v?
        if v
            this.attr('checked', 'checked')
        else
            this.removeAttr('checked')
    else
        this.attr('checked')

$.parseparam: (qs) ->
    qs:     qs.replace(/\+/g, ' ')
    params: {}
    args:   qs.split('&')
    index:  0
    for i in [0 ... args.length]
        pair: args[i].split('=');
        name: decodeURIComponent(pair[0])
        if pair.length == 2
            value: decodeURIComponent(pair[1])
        else
            value: name
            name: ""+index
            index += 1
        params[name] = value
    params

$.hashparam: (newValues) ->
    if newValues?
        newHash: '#' + $.param(newValues)
        if location.hash != newHash
            location.hash = '#' + $.param(newValues)
    else
        $.parseparam((location.hash || '#').substring(1))

_.mixin {
    groupBy: (arr, func) ->
        dict = {}
        for item in arr
            dict[func(item)] = item
        dict
}
