
# segmented control

SegmentedControl: (el) ->
    $el: $(el)
    $prev: $()
    $el.find('li').bind {
        'click': ->
            $el.find('li').removeClass('active')
            $(this).addClass('active')
            false
        'touchstart': (e) ->
            document.title: "touchstart"
            ($prev: $el.find('li.active')).removeClass('active')
            $(this).addClass('active')
        'touchend': ->
            document.title: "touchend"
            $prev: $()
            false
        'touchcancel': ->
            document.title: "touchcancel"
            $el.find('li.active').removeClass('active')
            $prev.addClass('active')
            $prev: $()
            false
    }

$.fn.webiosSegmentedControl: ->
    this.each ->
        SegmentedControl(this)

$ ->
    $('.segmented').webiosSegmentedControl()
