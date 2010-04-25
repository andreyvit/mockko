
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

window.inSet: (el, set) -> ihash(el) in set

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
