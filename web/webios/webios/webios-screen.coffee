
# screen transitions

screenStack: []

cleanupScreenStack: (screenId) ->
    i: 0
    while i < screenStack.length
        if screenStack[i] == screenId
            screenStack: screenStack.slice(0, i)
            console.log "Screen Stack Cleanup"
            console.log screenStack
            return
        i += 1

slide: ($previousScreen, $targetScreen, beforeX, beforeY, afterX, afterY) ->
    $previousScreen.css('-webkit-transform', "translate(0,0)").css('-webkit-transition', "-webkit-transform linear 0.3s")
    $targetScreen.css('-webkit-transform', "translate(${beforeX}px,${beforeY}px)").show().css('-webkit-transition', "-webkit-transform linear 0.3s")
    cleanup: ->
        $previousScreen.css('-webkit-transition', 'none').css('-webkit-transform', '').hide()
        $targetScreen.css('-webkit-transition', 'none').css('-webkit-transform', '')
    run: ->
        $previousScreen.css('-webkit-transform', "translate(${afterX}px,${afterY}px)")
        $targetScreen.css('-webkit-transform', "translate(0px,0px)")
        setTimeout cleanup, 350
    setTimeout run, 1

Transitions: {
    'slide-left':  ($p, $t) -> slide $p, $t, $p.width(),  0, -$p.width(), 0; screenStack.push($p.attr('id'))
    'slide-right': ($p, $t) -> slide $p, $t, -$p.width(), 0,  $p.width(), 0
    'immediate':   ($p, $t) -> $t.show(); $p.hide()
}

window.switchScreen = (targetScreen, transition) ->
    $targetScreen: $(targetScreen)
    if $targetScreen.length == 0
        console.log "Link target screen does not exist: ${targetScreen}"
        return
    $previousScreen: $targetScreen.parent().find('.screen:visible')
    if $previousScreen.attr('id') == $targetScreen.attr('id')
        console.log "Screen links to itself: ${targetScreen}"
        return
    screenWidth: $previousScreen.width()
    Transitions[transition]($previousScreen, $targetScreen)
    cleanupScreenStack $targetScreen.attr('id')

handleTransition = (el) ->
    href: $(el).attr('href')
    if $(el).hasClass('back') or (href and href.match(/^#.*$/))
        transition: 'slide-left'
        if $(el).hasClass('back')
            transition: 'slide-right'
            if not href and screenStack.length > 0
                href: '#' + screenStack[screenStack.length - 1]
        for name, handler of Transitions
            if $(el).hasClass(name)
                transition: name
                break
        switchScreen href, transition
        return false

$ ->
    $('.link, a').bind {
        'click': -> handleTransition this
        'touchstart': -> false
        'touchend': -> handleTransition this; false
    }
