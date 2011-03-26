
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

`
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-17047204-1']);
_gaq.push(['_setDomainName', 'none']);
_gaq.push(['_setAllowLinker', true]);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script');
ga.type = 'text/javascript';
ga.async = true;
ga.src = ('https:' == document.location.protocol ?
'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0];
s.parentNode.insertBefore(ga, s);
})();
var uservoiceOptions = {
  /* required */
  key: 'mockko',
  host: 'votebox.mockko.com',
  forum: '54458',
  showTab: true,
  /* optional */
  alignment: 'left',
  background_color:'#f00',
  text_color: 'white',
  hover_color: '#06C',
  lang: 'en'
};

function _loadUserVoice() {
  var s = document.createElement('script');
  s.setAttribute('type', 'text/javascript');
  s.setAttribute('src', ("https:" == document.location.protocol ? "https://" : "http://") + "cdn.uservoice.com/javascripts/widgets/tab.js");
  document.getElementsByTagName('head')[0].appendChild(s);
}
_loadSuper = window.onload;
window.onload = (typeof window.onload != 'function') ? _loadUserVoice : function() { _loadSuper(); _loadUserVoice(); };
`