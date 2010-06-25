
jQuery ($) ->
    $('#run-in-browser').click ->
        unless $.browser.webkit
            alert("Sorry, Mockko only works in Google Chrome and Apple Safari.\n\nIf you cannot use one of these browsers, please wait till we release a downloadable native application. Thanks!")
            return false
        if navigator.userAgent.match(/iPhone|iPod/i)
            alert("Sorry, Mockko doesn't work on iPhone. It's just too small for designing things.\n\nPlease try a desktop browser. Thanks!")
            return false
        if navigator.userAgent.match(/iPad/i)
            alert("Mockko doesn't support an iPad yet. Sorry! We're sure working on it.\n\nMeanwhile, please try a desktop browser. Thanks!")
            return false
