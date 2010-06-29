
# screen transitions

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
    'slide-left':  ($p, $t) -> slide $p, $t, $p.width(),  0, -$p.width(), 0
    'slide-right': ($p, $t) -> slide $p, $t, -$p.width(), 0,  $p.width(), 0
    'immediate':   ($p, $t) -> $t.show(); $p.hide()
}

window.switchScreen: (targetScreen, transition) ->
    $targetScreen: $(targetScreen)
    $previousScreen: $targetScreen.parent().find('.screen:visible')
    screenWidth: $previousScreen.width()
    Transitions[transition]($previousScreen, $targetScreen)

$ ->
    $('.link[href], a[href]').live 'click', ->
        if m: ($(this).attr('href')).match(/^#.*$/)
            transition: 'slide-left'
            if $(this).hasClass('back')
                transition: 'slide-right'
            for name, handler of Transitions
                if $(this).hasClass(name)
                    transition: name
                    break
            switchScreen m[0], transition
            return false
