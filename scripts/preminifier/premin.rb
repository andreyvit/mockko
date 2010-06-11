#! /usr/bin/env ruby
#
# Preminifier renames all JavaScript identifiers in your code into short names like aQ,
# helping you achieve better compression and better obfuscation.
#
# Preminifier is designed to be run before a respectable minifier like Closure Compiler
# in SIMPLE_OPTIMIZATIONS mode. (Of course, Preminifier is useless if you can run Closure
# Compiler in ADVANCED_OPTIMIZATIONS mode, but since that mode is incompatible with jQuery
# and generally problematic, you can't always do it.)
#
# Preminifier readily knows not to rename a lot of identifiers, including HTML5 and
# CSS3 DOM, Mozilla-, IE-, WebKit- and iPhone-specific APIs.
#
# You can also disable renaming for some of your own identifiers by providing a custom
# stoplist file (one identifier per line, # comments supported even midline).
#
# Preminifier outputs a list of old and new names (and a bit of usage context) for
# each renamed identifier. It is recommended that you look through it periodically.
#
# Copyright (C) 2010, Andrey Tarantsov <andreyvit@gmail.com>
# Distributed under the terms of the MIT license.
#

class String
  def shadow *regexps
    s = self
    fragments = []
    fragments_set = {}
    for regexp in regexps
      s = s.gsub regexp do |match|
        unless index = fragments_set[match]
          index = fragments_set[match] = fragments.size
          fragments << match.to_s
        end
        # $stderr.puts "SHADOW " + match
        "@@#{index}@@"
      end
    end
    [s, fragments]
  end
  
  def unshadow fragments
    self.gsub /@@(\d+)@@/ do
      fragments[$1.to_i]
    end
  end
end

MODE_IDENTS = ''
MODE_VARFUNC = 'var\s+|function\s+'
MODE_METHODS = '\\.'

DIG1 = ('a'..'z').to_a + ('A'..'Z').to_a
DIG2 = DIG1 + ('0'..'9').to_a
def id_to_word id
  d1 = id % DIG1.size; id /= DIG1.size
  return "#{DIG1[d1]}" if id == 0
  d2 = id % DIG2.size; id /= DIG2.size
  return "#{DIG1[d1]}#{DIG2[d2]}" if id == 0
  d3 = id % DIG2.size; id /= DIG2.size
  return "#{DIG1[d1]}#{DIG2[d2]}#{DIG2[d3]}" if id == 0
  "#{DIG1[d1]}#{DIG2[d2]}#{DIG2[d3]}#{DIG2[id]}"
end

def compute_context s
  pos = s.rindex("\n")
  s = if pos then s[pos..-1] else s end
  if s.size > 20
    p, s = s[-30..-21], s[-20..-1]
    s = $1 + s if p =~ /\b(\w*)$/
  end
  s.strip
end

def minify_javascript orig_source, stoplists, mode, debug=false
  stoplist_set = {}
  special_stoplist = []
  stoplists.each do |word|
    if word =~ /^[a-zA-Z0-9$_]+$/
      stoplist_set[word] = true
    else
      left_boundary = (word[0] == ?$ ? '' : '\\b')
      special_stoplist << Regexp.new(left_boundary + Regexp.escape(word) + '\\b')
    end
  end

  source, fragments = orig_source.shadow(%r!/\*.*?\*/!m, %r!(\(|,)\s*?/([^/\\]|\\.)+/\w*!, %r!//.*$!, /(["'])[^\1]*?\1/, *special_stoplist)

  next_id = 1
  identifiers = {}
  identifier_context = {}

  func = lambda do |m|
    if stoplist_set[$2]
      m
    else
      unless index = identifiers[$2]
        loop do
          index = next_id
          next_id += 1
          break unless stoplist_set[id_to_word(index)]
        end
        
        identifiers[$2] = index
        identifier_context[$2] = compute_context($`)+m
      end
      $1 + id_to_word(index) + (debug ? "_#{$2}" : "") + $3
    end
  end

  source.gsub! /(#{mode})([a-zA-Z_][a-zA-Z0-9_]*)()\b/, &func
  if mode == MODE_METHODS
    source.gsub! /(\b)([a-zA-Z_][a-zA-Z0-9_]*)(\s*:)/, &func
  end
  new_source = source.unshadow(fragments)
  identifiers = identifiers.keys.sort.collect { |w| [w, identifier_context[w]] }
  [new_source, identifiers]
end

def parse_stoplist text
  text.lines.collect { |line| line.gsub(/#.*$/, '').strip() }.reject { |word| word.size == 0 }
end

def make_percent_w_string prefix, indent, words
  max_line_len = 100
  lines = []
  line = "#{prefix}%w/"
  words.each do |word|
    new_line = line + word + " "
    if new_line.size > max_line_len
      lines << line.rstrip
      line = "#{indent}"
      redo
    end
    line = new_line
  end
  lines << line.rstrip + "/"
  lines.join("\n")
end

STOPLISTS = {
  :kw => %w/break case catch continue default delete do else finally for function if in 
    instanceof new return switch this throw try typeof var void while with null false true/,
  :mozkw => %w/const export import/,
  :futurekw => %w/abstract boolean byte char class const debugger double enum export extends 
    final float goto implements import int interface long native package private protected 
    public short static super synchronized throws transient volatile/,
  :es3 => [%w/Math.E Math.LN10 Math.LN2 Math.LOG10E Math.LOG2E Math.PI Math.SQRT1_2
    Math.SQRT2 Math.abs Math.acos Math.asin Math.atan Math.atan2 Math.ceil Math.cos Math.exp
    Math.floor Math.pow Math.random Math.round Math.sin Math.sqrt Math.tan
    Number.MAX_VALUE Number.MIN_VALUE Number.NEGATIVE_INFINITY Number.NaN Number.POSITIVE_INFINITY
    Date.UTC String.fromCharCode RegExp.lastMatch RegExp.lastParen RegExp.leftContext
    Date.now Date.parse RegExp.rightContext Error.stackTraceLimit/,
    %w/ActiveXObject Arguments Array Boolean Date Error EvalError Function Infinity Math
    NaN Number Object RangeError ReferenceError RegExp ScriptEngine ScriptEngineBuildVersion
    ScriptEngineMajorVersion ScriptEngineMinorVersion String SyntaxError TypeError URIError decodeURI
    decodeURIComponent encodeURI encodeURIComponent escape isFinite isNaN parseFloat parseInt undefined
    unescape/,
    %w/__defineGetter__ __defineSetter__ __lookupGetter__ __lookupSetter__
    __noSuchMethod__ __parent__ __proto__ anchor apply arguments arity big blink bold call callee
    caller charAt charCodeAt compile concat constructor eval every exec filter fixed fontcolor fontsize
    forEach getDate getDay getFullYear getHours getMilliseconds getMinutes getMonth getSeconds getTime
    getTimezoneOffset getUTCDate getUTCDay getUTCFullYear getUTCHours getUTCMilliseconds getUTCMinutes
    getUTCMonth getUTCSeconds getYear global hasOwnProperty ignoreCase index indexOf input
    isPrototypeOf italics join lastIndex lastIndexOf length lineNumber link localeCompare match message
    multiline name pop propertyIsEnumerable prototype push quote reduce reduceRight replace reverse
    search setDate setFullYear setHours setMilliseconds setMinutes setMonth setSeconds setTime
    setUTCDate setUTCFullYear setUTCHours setUTCMilliseconds setUTCMinutes setUTCMonth setUTCSeconds
    setYear shift slice small some sort source sourceURL splice split stack strike sub substr substring
    sup test toExponential toFixed toGMTString toLocaleDateString toLocaleFormat toLocaleLowerCase
    toLocaleString toLocaleTimeString toLocaleUpperCase toLowerCase toPrecision toSource toString
    toTimeString toUTCString toUpperCase unshift unwatch valueOf watch/],
  :es5 => [%w/JSON.parse JSON.stringify/, %w/JSON/, %w/toJSON/],
  :w3c_dom1 => [%w/DOMException.DOMSTRING_SIZE_ERR DOMException.HIERARCHY_REQUEST_ERR
      DOMException.INDEX_SIZE_ERR DOMException.INUSE_ATTRIBUTE_ERR
      DOMException.INVALID_CHARACTER_ERR DOMException.NOT_FOUND_ERR DOMException.NOT_SUPPORTED_ERR
      DOMException.NO_DATA_ALLOWED_ERR DOMException.NO_MODIFICATION_ALLOWED_ERR
      DOMException.WRONG_DOCUMENT_ERR Node.ATTRIBUTE_NODE Node.CDATA_SECTION_NODE Node.COMMENT_NODE
      Node.DOCUMENT_FRAGMENT_NODE Node.DOCUMENT_NODE Node.DOCUMENT_TYPE_NODE Node.ELEMENT_NODE
      Node.ENTITY_NODE Node.ENTITY_REFERENCE_NODE Node.NOTATION_NODE
      Node.PROCESSING_INSTRUCTION_NODE Node.TEXT_NODE Node.XPATH_NAMESPACE_NODE/,
    %w/Attr CDATASection CharacterData Comment DOMException DOMImplementation Document
      DocumentFragment DocumentType Element Entity EntityReference ExceptionCode NamedNodeMap Node
      NodeList Notation ProcessingInstruction Text/,
    %w/addEventListener appendChild appendData attributes childNodes cloneNode createAttribute
      createCDATASection createComment createDocumentFragment createElement createEntityReference
      createProcessingInstruction createTextNode data deleteData dispatchEvent doctype
      documentElement entities firstChild getAttribute getAttributeNode getElementsByTagName
      getNamedItem hasChildNodes hasFeature implementation insertBefore insertData item lastChild
      nextSibling nodeName nodeType nodeValue notationName notations ownerDocument parentNode
      previousSibling publicId removeAttribute removeAttributeNode removeChild removeEventListener
      removeNamedItem replaceChild replaceData setAttribute setAttributeNode setNamedItem specified
      splitText substringData systemId tagName target value/],
  :w3c_dom2 => [%w/DOMException.INVALID_ACCESS_ERR DOMException.INVALID_MODIFICATION_ERR
      DOMException.INVALID_STATE_ERR DOMException.NAMESPACE_ERR DOMException.SYNTAX_ERR/,
    %w/HTMLAnchorElement HTMLAppletElement HTMLAreaElement HTMLBRElement HTMLBaseElement
      HTMLBaseFontElement HTMLBodyElement HTMLButtonElement HTMLCollection HTMLDListElement
      HTMLDirectoryElement HTMLDivElement HTMLDocument HTMLElement HTMLFieldSetElement
      HTMLFontElement HTMLFormElement HTMLFrameElement HTMLFrameSetElement HTMLHRElement
      HTMLHeadElement HTMLHeadingElement HTMLHtmlElement HTMLIFrameElement HTMLImageElement
      HTMLInputElement HTMLIsIndexElement HTMLLIElement HTMLLabelElement HTMLLegendElement
      HTMLLinkElement HTMLMapElement HTMLMenuElement HTMLMetaElement HTMLModElement
      HTMLOListElement HTMLObjectElement HTMLOptGroupElement HTMLOptionElement
      HTMLOptionsCollection HTMLParagraphElement HTMLParamElement HTMLPreElement HTMLQuoteElement
      HTMLScriptElement HTMLSelectElement HTMLStyleElement HTMLTableCaptionElement
      HTMLTableCellElement HTMLTableColElement HTMLTableElement HTMLTableRowElement
      HTMLTableSectionElement HTMLTextAreaElement HTMLTitleElement HTMLUListElement/,
    %w/URL aLink abbr accept acceptCharset accessKey action add align alt anchors applets archive
      areas axis background bgColor blur body border caption cellIndex cellPadding cellSpacing
      cells ch chOff charset checked cite className clear click close code codeBase codeType
      colSpan color cols compact content contentDocument cookie coords createCaption createTFoot
      createTHead dateTime declare defaultChecked defaultSelected defaultValue defer deleteCaption
      deleteCell deleteRow deleteTFoot deleteTHead dir disabled domain elements enctype event face
      focus form forms frame frameBorder getElementsByName headers height href hreflang hspace
      htmlFor httpEquiv id images insertCell insertRow isMap label lang links longDesc lowSrc
      marginHeight marginWidth maxLength media method multiple noHref noResize noShade noWrap
      object open options profile prompt readOnly referrer rel remove reset rev rowIndex rowSpan
      rows rules scheme scope scrolling sectionRowIndex select selected selectedIndex shape size
      span src standby start submit summary tBodies tFoot tHead tabIndex text title type useMap
      vAlign vLink valueType version vspace width write writeln/],
  :w3c_dom3 => [%w/DOMException.TYPE_MISMATCH_ERR DOMException.VALIDATION_ERR/,
    %w/DOMConfiguration DOMError DOMErrorHandler DOMImplementationList DOMImplementationSource
      DOMLocator DOMStringList NameList TypeInfo UserDataHandler/,
    %w/DERIVATION_EXTENSION DERIVATION_LIST DERIVATION_RESTRICTION DERIVATION_UNION NODE_ADOPTED
      NODE_CLONED NODE_DELETED NODE_IMPORTED NODE_RENAMED baseURI byteOffset canSetParameter
      columnNumber compareDocumentPosition contains containsNS createDocument createDocumentType
      documentURI domConfig getAttributeNS getAttributeNodeNS getDOMImplementation
      getDOMImplementationList getElementsByTagNameNS getFeature getName getNamespaceURI
      getParameter getUserData handle handleError hasAttribute hasAttributeNS hasAttributes
      inputEncoding internalSubset isDefaultNamespace isDerivedFrom isElementContentWhitespace
      isEqualNode isId isSameNode isSupported localName location lookupNamespaceURI lookupPrefix
      namespaceURI normalize ownerElement parameterNames prefix querySelector querySelectorAll
      relatedData relatedException relatedNode removeAttributeNS replaceWholeText schemaTypeInfo
      setAttributeNS setAttributeNodeNS setIdAttribute setIdAttributeNS setIdAttributeNode
      setParameter setUserData severity strictErrorChecking textContent typeName typeNamespace uri
      utf16Offset wholeText xmlEncoding xmlStandalone xmlVersion/],
  :window => [%w//, %w/alert clearInterval clearTimeout confirm document dump java navigator
    netscape screen self setInterval setTimeout sun top/, %w//],
  :w3c_xml => [%w/XPathException.INVALID_EXPRESSION_ERR XPathException.TYPE_ERR
      XPathNamespace.XPATH_NAMESPACE_NODE XPathResult.ANY_TYPE XPathResult.ANY_UNORDERED_NODE_TYPE
      XPathResult.BOOLEAN_TYPE XPathResult.FIRST_ORDERED_NODE_TYPE XPathResult.NUMBER_TYPE
      XPathResult.ORDERED_NODE_ITERATOR_TYPE XPathResult.ORDERED_NODE_SNAPSHOT_TYPE
      XPathResult.STRING_TYPE XPathResult.UNORDERED_NODE_ITERATOR_TYPE
      XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE/,
    %w/XMLHttpRequest XPathEvaluator XPathException XPathExpression XPathNSResolver XPathNamespace
      XPathResult/,
    %w/abort booleanValue createExpression createNSResolver evaluate getAllResponseHeaders
      getResponseHeader invalidInteratorState iterateNext numberValue onreadystatechange readyState
      responseText responseXML resultType send setRequestHeader singleNodeValue snapshotItem
      snapshotLength status statusText stringValue/],
  :w3c_range => [%w//,
    %w/DocumentRange Range RangeException/,
    %w/BAD_BOUNDARYPOINTS_ERR END_TO_END END_TO_START INVALID_NODE_TYPE_ERR START_TO_END
      START_TO_START cloneContents cloneRange collapse collapsed commonAncestorContainer
      compareBoundaryPoints createRange deleteContents detach endContainer endOffset
      extractContents insertNode selectNode selectNodeContents setEnd setEndAfter setEndBefore
      setStart setStartAfter setStartBefore startContainer startOffset surroundContents/],
  :w3c_event => [%w/Event.AT_TARGET Event.BUBBLING_PHASE Event.CAPTURING_PHASE/,
    %w/DocumentEvent Event EventListener EventTarget KeyboardEvent MouseEvent MutationEvent UIEvent/,
    %w/altKey attrChange attrName bubbles button cancelable clientX clientY createEvent ctrlKey
      currentTarget detail eventPhase getModifierState handleEvent initEvent initMutationEvent
      keyIdentifier metaKey newValue prevValue preventDefault relatedTarget screenX screenY
      shiftKey stopPropagation timeStamp/],
  :w3c_event3 => [%w//, %w//, %w/initKeyboardEvent/],
  :w3c_elementtraversal => [%w//, %w//,
    %w/childElementCount firstElementChild lastElementChild nextElementSibling
      previousElementSibling/],
  :w3c_css => [%w/CSSPrimitiveValue.CSS_ATTR CSSPrimitiveValue.CSS_CM CSSPrimitiveValue.CSS_COUNTER
      CSSPrimitiveValue.CSS_DEG CSSPrimitiveValue.CSS_DIMENSION CSSPrimitiveValue.CSS_EMS
      CSSPrimitiveValue.CSS_EXS CSSPrimitiveValue.CSS_GRAD CSSPrimitiveValue.CSS_HZ
      CSSPrimitiveValue.CSS_IDENT CSSPrimitiveValue.CSS_IN CSSPrimitiveValue.CSS_KHZ
      CSSPrimitiveValue.CSS_MM CSSPrimitiveValue.CSS_MS CSSPrimitiveValue.CSS_NUMBER
      CSSPrimitiveValue.CSS_PC CSSPrimitiveValue.CSS_PERCENTAGE CSSPrimitiveValue.CSS_PT
      CSSPrimitiveValue.CSS_PX CSSPrimitiveValue.CSS_RAD CSSPrimitiveValue.CSS_RECT
      CSSPrimitiveValue.CSS_RGBCOLOR CSSPrimitiveValue.CSS_S CSSPrimitiveValue.CSS_STRING
      CSSPrimitiveValue.CSS_UNKNOWN CSSPrimitiveValue.CSS_URI CSSRule.CHARSET_RULE
      CSSRule.FONT_FACE_RULE CSSRule.IMPORT_RULE CSSRule.MEDIA_RULE CSSRule.PAGE_RULE
      CSSRule.STYLE_RULE CSSRule.UNKNOWN_RULE CSSValue.CSS_CUSTOM CSSValue.CSS_INHERIT
      CSSValue.CSS_PRIMITIVE_VALUE CSSValue.CSS_VALUE_LIST/,
    %w/CSSCharsetRule CSSFontFaceRule CSSImportRule CSSMediaRule CSSPageRule CSSPrimitiveValue
      CSSProperties CSSRule CSSRuleList CSSStyleDeclaration CSSStyleRule CSSStyleSheet
      CSSUnknownRule CSSValue CSSValueList Counter DOMImplementationCSS DocumentCSS DocumentStyle
      ElementCSSInlineStyle LinkStyle MediaList RGBColor Rect StyleSheet StyleSheetList ViewCSS/,
    %w/azimuth backgroundAttachment backgroundColor backgroundImage backgroundPosition
      backgroundRepeat blue borderBottom borderBottomColor borderBottomStyle borderBottomWidth
      borderCollapse borderColor borderLeft borderLeftColor borderLeftStyle borderLeftWidth
      borderRight borderRightColor borderRightStyle borderRightWidth borderSpacing borderStyle
      borderTop borderTopColor borderTopStyle borderTopWidth borderWidth bottom boxSizing
      captionSide clip counterIncrement counterReset createCSSStyleSheet cssFloat cssRules cssText
      cssValueType cue cueAfter cueBefore cursor deleteRule direction display elevation emptyCells
      encoding font fontFamily fontSize fontSizeAdjust fontStretch fontStyle fontVariant fontWeight
      getComputedStyle getCounterValue getExpression getFloatValue getOverrideStyle
      getPropertyCSSValue getPropertyPriority getPropertyValue getRGBColorValue getRectValue
      getStringValue green identifier insertRule left letterSpacing lineHeight listStyle
      listStyleImage listStylePosition listStyleType margin marginBottom marginLeft marginRight
      marginTop markerOffset marks maxHeight maxWidth mediaText minHeight minWidth opacity orphans
      outline outlineColor outlineStyle outlineWidth overflow ownerNode ownerRule padding
      paddingBottom paddingLeft paddingRight paddingTop page pageBreakAfter pageBreakBefore
      pageBreakInside parentRule parentStyleSheet pause pauseAfter pauseBefore pitch pitchRange
      playDuring position primitiveType quotes red removeExpression removeProperty richness right
      selectorText separator setExpression setFloatValue setProperty setStringValue sheet speak
      speakHeader speakNumeral speakPunctuation speechRate stress style styleSheet styleSheets
      tableLayout textAlign textDecoration textIndent textShadow textTransform unicodeBidi
      verticalAlign visibility voiceFamily volume whiteSpace widows wordSpacing wordWrap zIndex/],
  :fileapi => [%w//, %w/Blob File/, %w/fileName fileSize size type urn/],
  :flash => [%w//, %w//,
    %w/GetVariable GotoFrame IsPlaying LoadMovie Pan PercentLoaded Play Rewind SetVariable
      SetZoomRect StopPlay TCallFrame TCallLabel TCurentFrame TCurrentLabel TGetProperty
      TGetPropertyAsNumber TGotoFrame TGotoLabel TPlay TSetProperty TStopPlay TotalFrames Zoom/],
  :html5 => [%w//,
    %w/CanvasGradient CanvasPattern CanvasPixelArray CanvasRenderingContext2D ClientInformation
      DOMApplicationCache Database FileList HTMLAudioElement HTMLCanvasElement HTMLMediaElement
      HTMLVideoElement ImageData MediaError MessageChannel MessageEvent MessagePort ProgressEvent
      SQLError SQLResultSet SQLResultSetRowList SQLTransaction TextMetrics TimeRanges WebSocket
      XMLHttpRequestEventTarget XMLHttpRequestUpload/,
    %w/CHECKING CLOSED CONNECTING DOWNLOADING IDLE OPEN UNCACHED UPDATEREADY URL addColorStop
      addEventListener applicationCache arc arcTo autobuffer autoplay beginPath bezierCurveTo
      buffered bufferedAmount canPlayType canvas changeVersion clearRect clip close closePath code
      complete controls createImageData createLinearGradient createPattern createRadialGradient
      currentSrc currentTime data dataTransfer defaultPlaybackRate dispatchEvent draggable
      drawImage duration end ended error executeSql files fill fillColor fillRect fillStyle
      fillText font getContext getImageData globalAlpha globalCompositeOperation height
      initMessageEvent initMessageEventNS insertId isPointInPath item lastEventId lengthComputable
      lineCap lineJoin lineTo lineWidth load loaded loop measureText miterLimit moveTo multiple
      muted networkState onLine oncached onchecking onclose ondownloading onerror onmessage
      onnoupdate onopen onprogress onupdateready openDatabase origin overrideMimeType pause paused
      play playbackRate played port1 port2 ports postMessage poster pushState putImageData
      quadraticCurveTo readTransaction readyState rect registerContentHandler
      registerProtocolHandler removeEventListener replaceState restore rotate rows rowsAffected
      save scale seekable seeking send setTransform shadowBlur shadowColor shadowOffsetX
      shadowOffsetY src start startTime status stroke strokeColor strokeRect strokeStyle strokeText
      swapCache textAlign textBaseline toDataURL total transaction transform translate update
      upload version videoHeight videoWidth volume width withCredentials/,
    %w/dropEffect ondragenter ondragover ondrop/],
  :webstorage => [%w//, %w/Storage StorageEvent WindowLocalStorage WindowSessionStorage/,
    %w/clear getItem initStorageEvent key localStorage newValue oldValue removeItem sessionStorage
      setItem storageArea url/],
  :webkit_css => [%w//, %w//,
    %w/WebkitAppearance WebkitBackgroundClip WebkitBackgroundComposite WebkitBackgroundOrigin
      WebkitBackgroundSize WebkitBinding WebkitBorderBottomLeftRadius WebkitBorderBottomRightRadius
      WebkitBorderFit WebkitBorderHorizontalSpacing WebkitBorderImage WebkitBorderRadius
      WebkitBorderTopLeftRadius WebkitBorderTopRightRadius WebkitBorderVerticalSpacing
      WebkitBoxAlign WebkitBoxDirection WebkitBoxFlex WebkitBoxFlexGroup WebkitBoxLines
      WebkitBoxOrdinalGroup WebkitBoxOrient WebkitBoxPack WebkitBoxShadow WebkitBoxSizing
      WebkitColumnBreakAfter WebkitColumnBreakBefore WebkitColumnBreakInside WebkitColumnCount
      WebkitColumnGap WebkitColumnRule WebkitColumnRuleColor WebkitColumnRuleStyle
      WebkitColumnRuleWidth WebkitColumnWidth WebkitColumns WebkitDashboardRegion
      WebkitFontSizeDelta WebkitHighlight WebkitLineBreak WebkitLineClamp
      WebkitMarginBottomCollapse WebkitMarginCollapse WebkitMarginStart WebkitMarginTopCollapse
      WebkitMarquee WebkitMarqueeDirection WebkitMarqueeIncrement WebkitMarqueeRepetition
      WebkitMarqueeSpeed WebkitMarqueeStyle WebkitMatchNearestMailBlockquoteColor WebkitNbspMode
      WebkitPaddingStart WebkitRtlOrdering WebkitTextDecorationsInEffect WebkitTextFillColor
      WebkitTextSecurity WebkitTextSizeAdjust WebkitTextStroke WebkitTextStrokeColor
      WebkitTextStrokeWidth WebkitTransform WebkitTransformOrigin WebkitTransformOriginX
      WebkitTransformOriginY WebkitTransition WebkitTransitionDuration WebkitTransitionProperty
      WebkitTransitionRepeatCount WebkitTransitionTimingFunction WebkitUserDrag WebkitUserModify
      WebkitUserSelect/],
  :gecko_css => [%w//, %w//,
    %w/MozAppearance MozBackgroundClip MozBackgroundInlinePolicy MozBackgroundOrigin MozBinding
      MozBorderBottomColors MozBorderLeftColors MozBorderRadius MozBorderRadiusBottomleft
      MozBorderRadiusBottomright MozBorderRadiusTopleft MozBorderRadiusTopright
      MozBorderRightColors MozBorderTopColors MozBoxAlign MozBoxDirection MozBoxFlex
      MozBoxOrdinalGroup MozBoxOrient MozBoxPack MozBoxSizing MozColumnCount MozColumnGap
      MozColumnWidth MozFloatEdge MozForceBrokenImageIcon MozImageRegion MozMarginEnd
      MozMarginStart MozOpacity MozOutline MozOutlineColor MozOutlineOffset MozOutlineRadius
      MozOutlineRadiusBottomleft MozOutlineRadiusBottomright MozOutlineRadiusTopleft
      MozOutlineRadiusTopright MozOutlineStyle MozOutlineWidth MozPaddingEnd MozPaddingStart
      MozUserFocus MozUserInput MozUserModify MozUserSelect/],
  :ie_css => [%w//, %w//,
    %w/addImport addRule backgroundPositionX backgroundPositionY cssText getExpression imports
      msInterpolationMode overflowX overflowY owningElement pixelHeight pixelLeft pixelTop
      pixelWidth removeExpression removeImport removeRule setExpression styleFloat zoom/],
  :webkit_dom => [%w/console.error console.info console.log console.warn/, %w//,
    %w/baseNode baseOffset console empty error extentNode extentOffset getCSSCanvasContext
      getMatchedCSSRules modify setBaseAndExtent/],
  :gecko_dom => [%w//,
    %w/BoxObject HTMLSpanElement MimeType MimeTypeArray Navigator Plugin Selection/,
    %w/Components addRange alinkColor anchorNode anchorOffset appCodeName appName appVersion async
      atob availHeight availLeft availTop availWidth back baseURIObject btoa buildID captureEvents
      characterSet clientHeight clientLeft clientTop clientWidth closed collapse collapseToEnd
      collapseToStart colorDepth compareNode comparePoint compatMode console containsNode
      contentType controllers cookieEnabled createContextualFragment createElementNS createEvent
      createNSResolver createRange createTreeWalker crypto defaultStatus defaultView
      deleteFromDocument description designMode dialogArguments directories documentURIObject
      element elementFromPoint embeds enabledPlugin evaluate execCommand extend fgColor filename
      find focusNode focusOffset forward frameElement frames fullScreen getAttention
      getBoundingClientRect getBoxObjectFor getComputedStyle getElementById getElementsByClassName
      getRangeAt getSelection globalStorage history home importNode innerHTML innerHeight
      innerWidth intersectsNode isCollapsed isPointInRange javaEnabled language lastModified left
      linkColor load loadOverlay locationbar menubar mimeTypes namedItem naturalHeight naturalWidth
      nodePrincipal offsetHeight offsetLeft offsetParent offsetTop offsetWidth onLine onabort
      onbeforeunload onblur onchange onclick onclose oncontextmenu oncopy oncut ondblclick
      ondragdrop onerror onfocus onkeydown onkeypress onkeyup onload onmousedown onmousemove
      onmouseout onmouseover onmouseup onoffline ononline onpaint onpaste onreset onresize onscroll
      onselect onsubmit onunload openDialog opener oscpu outerHeight outerWidth pageXOffset
      pageYOffset parent personalbar pixelDepth pkcs11 platform plugins popupNode postMessage
      product productSub queryCommandEnabled queryCommandIndeterm queryCommandState
      queryCommandValue rangeCount releaseEvents removeAllRanges removeRange returnValue screenX
      screenY scrollByLines scrollByPages scrollHeight scrollIntoView scrollLeft scrollMaxX
      scrollMaxY scrollTop scrollWidth scrollX scrollY scrollbars securityPolicy selectAllChildren
      selectionEnd selectionLanguageChange selectionStart sessionStorage setSelectionRange
      showModalDialog sidebar sizeToContent status statusbar stop style styleSheets suffixes
      toolbar tooltipNode updateCommands userAgent vendor vendorSub vlinkColor window x y/],
  :ie_dom => [%w//,
    %w/ClipboardData ControlRange History Location RuntimeObject TextRange Window XMLDOMDocument
      controlRange window/,
    %w/URLUnencoded XDomainRequest XMLDocument XMLHttpRequest XSLDocument abort activeElement
      addElement alinkColor all assign async attachEvent back baseName boundingHeight boundingLeft
      boundingTop boundingWidth canHaveChildren clearData clipboardData closed collapse
      compareEndPoints compatMode componentFromPoint contentEditable contentWindow
      createControlRange createEventObject createNode createPopup createRange createRangeCollection
      createStyleSheet createTextRange currentStyle dataType defaultCharset defaultStatus
      definition designMode detachEvent dialogArguments dialogHeight dialogLeft dialogTop
      dialogWidth doScroll documentMode duplicate elementFromPoint embeds execCommand execScript
      expand expando fgColor fileCreatedDate fileModifiedDate fileSize findText fireEvent forward
      frameElement frames getBookmark getBoundingClientRect getClientRects getData getElementById
      globalStorage go hasFocus hash hideFocus host hostname htmlText inRange innerText
      insertAdjacentHTML isContentEditable isEqual lastModified linkColor load loadXML
      maxConnectionsPer1_0Server maxConnectionsPerServer mergeAttributes move moveBy moveEnd
      moveStart moveTo moveToBookmark moveToElementText moveToPoint namespaces navigate nodeFromID
      nodeTypeString nodeTypedValue offscreenBuffering offsetLeft offsetTop ondataavailable
      onmouseenter onmouseleave onreadystatechange ontransformnode opener outerHTML outerHeight
      outerWidth pageXOffset pageYOffset parent parentElement parentWindow parseError parsed
      pasteHTML pathname personalbar port postMessage preserveWhiteSpace print protocol
      queryCommandEnabled queryCommandIndeterm queryCommandState queryCommandSupported
      queryCommandValue readyState recalc releaseCapture reload removeNode resizeBy resizeTo
      resolveExternals returnValue runtimeStyle screenLeft screenTop scripts scroll scrollBy
      scrollIntoView scrollTo scrollbars selectNodes selectSingleNode selection sessionStorage
      setActive setCapture setData setEndPoint showHelp showModalDialog showModelessDialog
      sourceIndex status statusbar styleSheet styleSheets toolbar transformNode
      transformNodeToObject uniqueID unselectable url validateOnParse vlinkColor xml/],
  :gecko_event => [%w//, %w//,
    %w/HORIZONTAL_AXIS VERTICAL_AXIS cancelBubble charCode explicitOriginalTarget initKeyEvent
      initMessageEvent initMouseEvent initUIEvent isChar keyCode layerX layerY originalTarget pageX
      pageY preventBubble preventCapture view which/],
  :webkit_event => [%w//, %w//, %w/wheelDeltaX wheelDeltaY/],
  :ie_event => [%w//, %w//,
    %w/Abstract Banner MoreInfo altLeft cancelBubble contentOverflow ctrlLeft dataFld fromElement
      keyCode nextPage offsetX offsetY propertyName qualifier reason recordset repeat returnValue
      saveType shiftLeft srcElement srcFilter srcUrn toElement userName wheelDelta x y/],
  :gecko_xml => [%w//, %w/DOMParser XMLSerializer/,
    %w/parseFromString serializeToStream serializeToString/],
  :ie_vml => [%w//, %w//,
    %w/coordorigin coordsize fillcolor filled path rotation strokecolor stroked strokeweight/],
  :iphone => [%w//, %w/Touch TouchEvent TouchList/,
    %w/changedTouches identifier pageX pageY rotation scale targetTouches touches/],
  :webkit_notifications => [%w//, %w/Notification NotificationCenter/,
    %w/cancel checkPermission createHTMLNotification createNotification onclose ondisplay onerror
      requestPermission show webkitNotifications/],
  :gears_symbols => [%w/gears.factory gears.workerPool google.gears/,
    %w/google/, %w//],
  :gears_types => [%w//,
    %w/GearsAddress GearsBlob GearsBlobBuilder GearsCompleteObject GearsCoords GearsDatabase
      GearsDesktop GearsErrorObject GearsFactory GearsFile GearsFileSubmitter GearsGeolocation
      GearsHttpRequest GearsHttpRequestUpload GearsLocalServer GearsManagedResourceStore
      GearsMessageObject GearsOpenFileOptions GearsPosition GearsPositionError GearsPositionOptions
      GearsProgressEvent GearsProgressObject GearsResourceStore GearsResultSet GearsTimer
      GearsWorkerPool/,
    %w/PERMISSION_DENIED POSITION_UNAVAILABLE TIMEOUT UNKNOWN_ERROR abort abortCapture accuracy
      allowCrossOrigin altitude altitudeAccuracy append blob canServeLocally capture captureBlob
      captureFile checkForUpdate city clearWatch copy country countryCode county create
      createFileSubmitter createManagedStore createShortcut createStore createWorker
      createWorkerFromUrl currentVersion enableHighAccuracy enabled execute extractMetaData field
      fieldByName fieldCount fieldName filesComplete filesTotal gearsAddress gearsAddressLanguage
      gearsLocationProviderUrls gearsRequestAddress getAllHeaders getAllResponseHeaders getAsBlob
      getBuildInfo getCapturedFileName getCurrentPosition getDragData getHeader getPermission
      getResponseHeader hasPermission isCaptured isValidRow lastErrorMessage lastInsertRowId
      lastPosition lastUpdateCheckTime latitude lengthComputable loaded longitude manifestUrl
      maximumAge newVersion next oncomplete onerror onmessage onprogress onreadystatechange
      openFiles openManagedStore openStore origin postalCode premises privateSetGlobalObject
      readyState region removeManagedStore removeStore rename requiredCookie responseBlob
      responseText rowsAffected send sendMessage sender setDropEffect setFileInputElement
      setRequestHeader singleFile status statusText street streetNumber timeout timestamp total
      updateStatus upload watchPosition/],
  :jquery => [%w/$ $.ajax $.ajaxSetup $.boxModel $.browser $.browser.version $.data $.each $.extend
      $.fn.extend $.get $.getJSON $.getScript $.grep $.inArray $.isFunction $.makeArray $.map
      $.noConflict $.param $.post $.removeData $.trim $.unique add addClass after ajaxComplete
      ajaxError ajaxSend ajaxStart ajaxStop ajaxSuccess andSelf animate append appendTo attr before
      bind blur change children click clone contents css data dblclick dequeue each empty end eq
      error fadeIn fadeOut fadeTo filter find focus get hasClass height hide hover html index
      insertAfter insertBefore is jQuery jQuery.ajax jQuery.ajaxSetup jQuery.boxModel
      jQuery.browser jQuery.browser.version jQuery.data jQuery.each jQuery.extend jQuery.fn.extend
      jQuery.get jQuery.getJSON jQuery.getScript jQuery.grep jQuery.inArray jQuery.isFunction
      jQuery.makeArray jQuery.map jQuery.noConflict jQuery.param jQuery.post jQuery.removeData
      jQuery.trim jQuery.unique keydown keypress keyup length load map mousedown mousemove mouseout
      mouseover mouseup next nextAll not offset one parent parents prepend prependTo prev prevAll
      queue ready remove removeAttr removeClass removeData replaceAll replaceWith resize scroll
      select serialize serializeArray show siblings slice slideDown slideToggle slideUp stop submit
      text toggle toggleClass trigger triggerHandler unbind unload val width wrap wrapAll wrapInner/,
    %w/$.fn $.fn.showTags jQuery.fn jQuery.fn.showTags/,
    %w/closest success/,
    %w/sortable has/],
  :undescore => %w/_ each map reduce reduceRight detect select reject all any include invoke
      pluck max min sortBy sortedIndex toArray size
      first rest last compact flatten without uniq intersect zip indexOf lastIndexOf range
      bind bindAll delay defer wrap compose
      keys values functions extend clone tap isEqual isEmpty isElement isArray isArguments
      isFunction isString isNumber isBoolean isDate isRegExp isNaN isNull isUndefined
      noConflict identity times breakLoop mixin uniqueId template
      chain value/,
}


ACTION_MINIFY = 1
ACTION_LEARN = 2
ACTION_LEARN_JQUERY = 3

action = ACTION_MINIFY
args = ARGV.dup
stoplists = STOPLISTS.values
mode = MODE_IDENTS
print_code = false
code_var_name = ''
orig_source = nil
debug = false
while args.size > 0
  arg = args.shift
  case arg
    when '-d' then debug = true
    when '-m' then mode = MODE_METHODS
    when '-v' then mode = MODE_VARFUNC
    when '--learn' then action = ACTION_LEARN
    when '--learn-jquery'
      action = ACTION_LEARN_JQUERY
    when '--learn-from-closure'
      action = ACTION_LEARN
      code_var_name = args.shift
      print_code = true
      require 'open-uri'
      orig_source = open("http://closure-compiler.googlecode.com/svn/trunk/externs/#{code_var_name}.js") { |f| f.read }
    when '--print-code'
      code_var_name = args.shift
    when '-s'
      stoplists = args.shift.strip.split(",").collect { |a| STOPLISTS[a.intern] }
    else
      puts "Unknown option #{arg}"
      exit
  end
end

user_stoplist = []
stoplist = STOPLISTS[:kw] + user_stoplist + stoplists.flatten

indent = "  "

def print_stop_list identifiers
  identifiers.each { |word, ctx| $stderr.puts sprintf('%-20s # %s', word, ctx) }
end

def jquery_dup name
  [name.gsub('$', 'jQuery'), name.gsub('jQuery', '$')].uniq
end

case action
when ACTION_LEARN
  orig_source ||= $stdin.read

  dummy, identifiers = minify_javascript orig_source, stoplist, MODE_METHODS
  specials_list = identifiers.select { |ident, ctx| ctx !~ /\.prototype\./ }.collect { |ident, ctx| if ctx =~ /\b[a-zA-Z0-9$_]+\.#{ident}/ then $& else "!!!UNMATCHED #{ident} IN #{ctx}!!!" end }.sort

  methods_list = identifiers.select { |ident, ctx| ctx =~ /\.prototype\./ }.collect { |ident, ctx| ident }
  
  stoplist += specials_list + methods_list
  dummy, identifiers = minify_javascript orig_source, stoplist, MODE_VARFUNC
  globals_list = identifiers.collect { |ident, ctx| ident }
  
  stoplist += globals_list
  dummy, identifiers = minify_javascript orig_source, stoplist, MODE_IDENTS
  others_list = identifiers.collect { |ident, ctx| ident }

  puts
  puts make_percent_w_string("#{indent}:#{code_var_name} => [", "#{indent}#{indent}#{indent}", specials_list) + ","
  puts make_percent_w_string("#{indent}#{indent}", "#{indent}#{indent}#{indent}", globals_list) + ","
  puts make_percent_w_string("#{indent}#{indent}", "#{indent}#{indent}#{indent}", methods_list) + "],"
  puts
  puts make_percent_w_string("#{code_var_name}_others = ", "#{indent}", others_list)

when ACTION_LEARN_JQUERY
  require 'rubygems'
  require 'open-uri'
  require 'json'
  src = open('http://jquery-api-browser.googlecode.com/svn/trunk/api-docs.js') { |f| f.read }
  src = src.strip['loadDocs('.size .. -');'.size-1]
  root = JSON.load(src)
  doc_method_list = root['data'].values.reject { |v| v['type'] == 'selector' }.collect { |v| jquery_dup(v['name']) }.flatten.sort.uniq
  
  sample_code = root['data'].values.collect { |v| v['examples'] || [] }.flatten.collect { |ex| ex['code'] }.join("\n")
  
  dummy, identifiers = minify_javascript sample_code, stoplist + doc_method_list, MODE_METHODS
  code_method_list = identifiers.collect { |ident, ctx| if ctx =~ /(\bjQuery|\$)(\.[a-zA-Z0-9_]+)?\.#{ident}/ then $& else nil end }.compact.collect { |n| jquery_dup(n) }.flatten.sort.uniq
  other_methods_list = identifiers.collect { |ident, ctx| if ctx =~ /(\bjQuery|\$)(\.[a-zA-Z0-9_]+)?\.#{ident}/ then nil else [ident, ctx] end }.compact.sort.uniq
  
  puts
  puts make_percent_w_string("#{indent}:jquery => [", "#{indent}#{indent}#{indent}", doc_method_list) + ","
  puts make_percent_w_string("#{indent}#{indent}", "#{indent}#{indent}#{indent}", code_method_list) + "],"
  puts
  print_stop_list other_methods_list

when ACTION_MINIFY
  orig_source = $stdin.read
  new_source, identifiers = minify_javascript orig_source, stoplist, mode, debug
  print_stop_list identifiers
  puts new_source
end
