#
# Creating and updating DOM nodes based on the model
# Mockko iPhone Prototyping System
#
# Copyright (C) 2010, Andrey Tarantsov, Mikhail Gusarov
#

# copied here to break a dependency
rectOf: (c) -> { x: c.abspos.x, y: c.abspos.y, w: c.effsize.w, h: c.effsize.h }


##  DOM node

renderComponentNode: (c) ->
    ct: c.type
    movability: if ct.unmovable then "unmovable" else "movable"
    tagName: c.type.tagName || "div"
    $(ct.html || "<${tagName} />").addClass("component c-${c.type.name} ${c.styleName || ''} c-${c.type.name}-${c.styleName || 'nostyle'}").addClass(if ct.container then 'container' else 'leaf').setdata('moa-comp', c).addClass(movability)[0]


##  position

renderComponentPosition: (c, cn) ->
    ct: c.type
    relpos: switch
        when c.dragpos
            {
                'x': c.dragpos.x - ((c.dragParent?.dragpos || c.dragParent?.abspos)?.x || 0)
                'y': c.dragpos.y - ((c.dragParent?.dragpos || c.dragParent?.abspos)?.y || 0)
            }
        else
            {
                'x': c.abspos.x - ((c.parent?.dragpos && false || c.parent?.abspos)?.x || 0)
                'y': c.abspos.y - ((c.parent?.dragpos && false || c.parent?.abspos)?.y || 0)
            }
    $(cn || c.node).css({
        left:   "${relpos.x}px"
        top:    "${relpos.y}px"
    })


##  size

recomputeEffectiveSizeInDimension: (userSize, policy, fullSize) ->
    userSize || policy.fixedSize?.portrait || policy.fixedSize || switch policy.autoSize
        when 'fill'    then fullSize
        when 'browser' then null

sizeToPx: (v) ->
    if v then "${v}px" else 'auto'

renderComponentSize: (c, cn) ->
    ct: c.type
    size: c.dragsize || c.size
    effsize: {
        w: recomputeEffectiveSizeInDimension size.w, ct.widthPolicy, 320
        h: recomputeEffectiveSizeInDimension size.h, ct.heightPolicy, 480
    }
    $(cn || c.node).css('width', sizeToPx(effsize.w))
    $(cn || c.node).css('height', sizeToPx(effsize.h))
    return effsize

updateEffectiveSize: (c) ->
    if c.dragsize
        renderComponentSize c
        return
    c.effsize: renderComponentSize c
    # get browser-computed size if needed
    if c.effsize.w is null then c.effsize.w = c.node.offsetWidth
    if c.effsize.h is null then c.effsize.h = c.node.offsetHeight
    updateComponentTooltip c

updateComponentTooltip: (c) ->
    r: rectOf c
    $(c.node).attr('title', "${c.type.label} — (${r.x}, ${r.y}) ${r.w}x${r.h}")


## style

encodeActionAsURL: (comp) ->
    if comp.action?
        comp.action.action.encodeActionAsURL(comp.action)
    else
        ""

imageNodeOfComponent: (c, cn) ->
    cn ||= c.node
    return null unless c.type.supportsImage
    if c.type.imageSelector then $(c.type.imageSelector, cn)[0] else cn

textNodeOfComponent: (c, cn) ->
    cn ||= c.node
    return null unless c.type.supportsText
    if c.type.textSelector then $(c.type.textSelector, cn)[0] else cn

renderImageDefault: (comp, node, imageUrl) ->
    if imageUrl
        $(imageNodeOfComponent comp, node).css { backgroundImage: "url(${imageUrl})"}

renderComponentStyle: (c, cn) ->
    cn ||= c.node

    dynamicStyle: if c.type.dynamicStyle then c.type.dynamicStyle(c) else {}
    style: $.extend({}, dynamicStyle, c.stylePreview || c.style)
    css: {}
    css.fontSize: style.fontSize if style.fontSize?
    if c.type.canHazColor
        css.color: style.textColor if style.textColor?
    css.fontWeight: (if style.fontBold then 'bold' else 'normal') if style.fontBold?
    css.fontStyle: (if style.fontItalic then 'italic' else 'normal') if style.fontItalic?

    if style.textShadowStyleName?
        for k, v of Mockko.textShadowStyles[style.textShadowStyleName].css
            css[k] = v

    $(textNodeOfComponent c, cn).css css

    if style.background?
        if not (Mockko.backgroundStylesByName[style.background])
            console.log "!! Unknown backgrond style ${style.background} for ${c.type.name}"
        bgn: cn || c.node
        if bgsel: c.type.backgroundSelector
            bgn: $(bgn).find(bgsel)[0]
        bgn.className: _((bgn.className || '').trim().split(/\s+/)).reject((n) -> n.match(/^bg-/)).
            concat(["bg-${style.background}"]).join(" ")

    if c.state?
        $(cn).removeClass('state-on state-off').addClass("state-${c.state && 'on' || 'off'}")
    if c.text? and not c.dirtyText
        $(textNodeOfComponent c, cn).html(c.text)
    if c.image?
        getImageUrl c.image, (style.imageEffect || null), (imageUrl) ->
            (c.type.renderImage || renderImageDefault)(c, cn, imageUrl)
    actionURL: encodeActionAsURL(c)
    $(cn).attr('action', actionURL)
    $(cn).alterClass('has-action', actionURL != '')


##  combined

renderComponentVisualProperties: (c, cn) ->
    renderComponentStyle c, cn
    if cn?
        renderComponentSize c, cn
    else
        updateEffectiveSize c

renderComponentProperties: (c, cn) -> renderComponentPosition(c, cn); renderComponentVisualProperties(c, cn)

_renderComponentHierarchy: (c, storeFunc) ->
    n: storeFunc c, renderComponentNode(c)
    for child in c.children || []
        childNode: _renderComponentHierarchy(child, storeFunc)
        $(n).append(childNode)
    n

renderComponentHierarchy: (c, saveNodes, positionRoot) ->
    n: _renderComponentHierarchy c, (ch, n) ->
        ch.node: n if saveNodes
        renderComponentVisualProperties ch, n
        renderComponentPosition ch, n if ch != c
        n
    renderComponentPosition c if positionRoot
    n


##########################################################################################################
##  exports

(window.Mockko ||= {}).renderer: {
    renderComponentNode
    renderComponentSize, updateEffectiveSize, updateComponentTooltip
    renderComponentPosition
    renderComponentStyle, textNodeOfComponent
    renderComponentVisualProperties, renderComponentProperties
    renderComponentHierarchy
}
