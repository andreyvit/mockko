
# segmented control
$ ->
    $('.segmented li').live 'click', ->
        $(this).closest('.segmented').find('li').removeClass('active')
        $(this).addClass('active')
