
##########################################################################################################
## imports

{
    #  Legacy
    isRectInsideRect, doesRectIntersectRect, rectIntersection, areaOfIntersection, proximityOfRectToRect
    ptDiff, ptSum, ptMul, distancePtToPtMod, distancePtToPtSqr
    #  Point
    ZeroPt, ptToString, distancePtPt1, distancePtPt2, addPtPt, subPtPt, mulPtSize, ptFromLT, ptFromNode
    unitVecOfPtPt, mulVecLen, ptInRect
    #  Size
    ZeroSize, sizeToString, domSize, centerOfSize
    #  Rect
    rectToString, rectFromPtAndSize, rectFromPtPt, dupRect, addRectPt, subRectPt, topLeftOf, bottomRightOf
    rectOfNode, canonRect, insetRect, centerOfRect, centerSizeInRect
    #  Line / Segment
    lineFromPtPt, lineFromABPt, signum, classifyPtLine, perpendicularLineThroughPoint, distancePtLine
    distancePtSegment
}: Mockko.geom


window.Pins: {
    bottom: {
        computeRect: (area, comp, findRectOfPinned) ->
            hp: comp.type.heightPolicy
            h: hp.fixedSize.portrait || hp.fixedSize
            { x: area.x, w: area.w, y: area.y+area.h-h, h: h }
        dependantPins: []
    }
    top: {
        computeRect: (area, comp, findRectOfPinned) ->
            hp: comp.type.heightPolicy
            h: hp.fixedSize.portrait || hp.fixedSize
            { x: area.x, w: area.w, y: area.y, h: h }
        dependantPins: []
    }
    secondTop: {
        computeRect: (area, comp, findRectOfPinned) ->
            hp: comp.type.heightPolicy
            h: hp.fixedSize.portrait || hp.fixedSize
            pinned: findRectOfPinned(Pins.top)
            { x: area.x, w: area.w, y: (if pinned then pinned.y+pinned.h else area.y), h: h }
        dependantPins: []
    }
    secondBottom: {
        computeRect: (area, comp, findRectOfPinned) ->
            hp: comp.type.heightPolicy
            h: hp.fixedSize.portrait || hp.fixedSize
            pinned: findRectOfPinned(Pins.bottom)
            { x: area.x, w: area.w, y: (if pinned then pinned.y else area.y+area.h)-h, h: h }
        dependantPins: []
    }
}
Pins.top.dependantPins.push Pins.secondTop
Pins.bottom.dependantPins.push Pins.secondBottom

(window.Mockko ||= {}).componentTypes: {
    'background': {
        type: 'background'
        label: 'Background'
        container: yes
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { autoSize: 'fill' }
        unmovable: yes
        supportsBackground: yes
        canHazLink: no
        style: {
            background: 'striped'
        }
    }
    'image': {
        type: 'image'
        label: 'Image'
        widthPolicy: { fixedSize: 30, userSize: yes }
        heightPolicy: { fixedSize: 30, userSize: yes }
        supportsImage: yes
        supportsImageReplacement: no
        tagName: 'img'
        renderImage: (comp, node, imageUrl) ->
          node.src: imageUrl
        tooltip: (comp) ->
            comp.image.name
    }
    'text': {
        label: 'Text'
        defaultText: "Some text"
        widthPolicy: { autoSize: 'browser' }
        heightPolicy: { autoSize: 'browser' }
        wantsSmartAlignment: yes
    }
    'rect': {
        label: 'Rectangle'
        widthPolicy:  { userSize: true, fixedSize: 150 }
        heightPolicy: { userSize: true, fixedSize: 44 }
        container: yes
        supportsBackground: yes
        style: {
            background: 'transparent'
        }
    }
    'statusBar': {
        label: 'Status Bar'
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: 20 }
        pin: Pins.top
        singleInstance: yes
        canHazLink: no
    }
    'tabBar': {
        label: 'Tab Bar'
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: 49 }
        container: yes
        pin: Pins.bottom
        singleInstance: yes
        hitAreaInset: 10
        hitAreaOutset: 10
        canHazLink: no

        layoutChildren: (children, tabBarRect) ->
            count: children.length
            [hinset, hgap, vinset]: [5, 2, 3]
            tabHeight: 44
            itemSize: { w: (tabBarRect.w - 2*hinset - hgap*(count-1)) / count
                        h: tabHeight }
            pt: { x: tabBarRect.x + hinset, y: tabBarRect.y + vinset }
            switch count
                when 0 then []
                when 1 then [rectFromPtAndSize(pt, itemSize)]
                else
                    index: 0
                    while index++ < count
                        r: rectFromPtAndSize(pt, itemSize)
                        pt.x += itemSize.w + hgap
                        r
    }
    'tab-bar-item': {
        label: 'Tab Bar Item'
        defaultText: 'My Tab'
        widthPolicy: { fixedSize: 60 }
        heightPolicy: { fixedSize: 44 }
        container: yes
        html: '<div><div class="icon"></div><div class="label"></div></div>'
        textSelector: '.label'
        textStyleEditable: no
        imageSelector: '.icon'
        supportsImage: yes
        supportsImageReplacement: yes
        state: off
        dynamicStyle: (comp) ->
            {
                imageEffect: if comp.state then 'iphone-tabbar-active' else 'iphone-tabbar-inactive'
                textColor: if comp.state then '#fff' else '#eee'
            }
    }
    'navBar': {
        label: 'Navigation Bar'
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
        container: yes
        pin: Pins.secondTop
        singleInstance: yes
        canHazLink: no
    }
    'backButton': {
        label: 'Back Button'
        genericLabel: 'Button'
        defaultText: "Back"
        widthPolicy: { userSize: true, autoSize: 'browser' }
        heightPolicy: { fixedSize: { portrait: 30, landscape: 30 } }
        style: {
        	textColor: '#fff'
        	textShadowStyleName: 'dark-above'
        	fontSize: 12
        	fontBold: yes
        }
        wantsSmartAlignment: yes
    }
    'barButton': {
        label: 'Bar Button'
        genericLabel: 'Button'
        defaultText: "Edit"
        widthPolicy: { userSize: true, autoSize: 'browser' }
        heightPolicy: { fixedSize: { portrait: 30, landscape: 30 } }
        style: {
        	textColor: '#fff'
        	textShadowStyleName: 'dark-above'
        	fontSize: 12
        	fontBold: yes
        }
        wantsSmartAlignment: yes
    }
    'toolbar': {
        label: 'Toolbar'
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
        container: yes
        pin: Pins.secondBottom
        singleInstance: yes
        canHazLink: no

        layoutChildren: (children, outerRect) ->
            return [] if children.length is 0

            totalW: _(children).reduce 0, (memo, child) -> memo + child.effsize.w
            hgap = (outerRect.w - totalW) / (children.length + 1)

            x: outerRect.x + hgap
            for child in children
                r: rectFromPtAndSize { x: x, y: outerRect.y + (outerRect.h-child.effsize.h)/2 }, child.effsize
                x += child.effsize.w + hgap
                r
    }
    'roundedButton': {
        label: 'Rounded Button'
        genericLabel: 'Button'
        defaultText: "Call"
        widthPolicy: { userSize: true, autoSize: 'browser' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        style: {
            textColor: '#516691'
            fontBold: yes
        }
    }
    'coloredButton': {
        label: 'Colored Button'
        genericLabel: 'Button'
        defaultText: "Delete Contact"
        widthPolicy: { userSize: true, autoSize: 'browser' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        style: {
            fontBold: yes
            fontSize: 20
        }
    }
    'buyButton': {
        label: 'Buy Button'
        genericLabel: 'Button'
        defaultText: "BUY NOW"
        widthPolicy: { userSize: true, fixedSize: 80 } #autoSize: 'browser'
        heightPolicy: { userSize: true, fixedSize: 25 }
        style: {
            fontSize: 12
            textColor: '#fff'
            textShadowStyleName: 'dark-above'
        }
    }
    'plain-header': {
        label: 'Header'
        isTableRow: yes
        defaultText: "B"
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: 23 }
        style: {
            textColor: '#fff'
            fontSize: 16
            fontBold: yes
            textShadowStyleName: 'dark-below'
        }
    }
    'plain-row': {
        label: 'Edge-to-Edge Row'
        isTableRow: yes
        container: yes
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        supportsBackground: yes
    }
    'roundrect-header': {
        label: 'Header'
        isTableRow: yes
        defaultText: "Header"
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        style: {
            fontSize: 17
            textShadowStyleName: 'light-below'
            fontBold: yes
            textColor: '#4c566c'
        }
    }
    'roundrect-row': {
        group: 'roundrect-rows'
        label: 'Rounded Rect Row'
        isTableRow: yes
        container: yes
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        html: '<div><div class="inner"></div></div>'
        topInset: 17  # not handled currently
        supportsBackground: yes
        style: {
            background: 'white'
        }
        backgroundSelector: '.inner'
        childrenSelector: '.inner'
        childrenOffset: { x: -10, y: 0 }  # compensate for .inner margins
    }
    'switch': {
        label: 'On/Off Switch'
        widthPolicy: { fixedSize: 94 }
        heightPolicy: { fixedSize: 27 }
    }
    'slider': {
        label: 'Slider'
        widthPolicy: { userSize: true, fixedSize: 118 }
        heightPolicy: { fixedSize: 23 }
    }
    'pageControl': {
        label: 'Page Control'
        widthPolicy: { userSize: true, fixedSize: 38 }
        heightPolicy: { fixedSize: 36 }
    }
    'segmentedControl': {
        label: 'Segmented Control'
        widthPolicy: { userSize: true, fixedSize: 207 }
        heightPolicy: { fixedSize: 44 }

        styles: {
            normal: {
            }
            bar: {
                heightPolicy: { fixedSize: 30 }
            }
        }
    }
    'stars': {
        label: 'Stars'
        widthPolicy: { fixedSize: 50 }
        heightPolicy: { fixedSize: 27 }
    }
    'progressBar': {
        label: 'Progress Bar'
        widthPolicy: { userSize: true, fixedSize: 150 }
        heightPolicy: { fixedSize: 9 }
    }
    'progressBarBarStyle': {
        label: 'Progress Bar 2'
        widthPolicy: { userSize: true, fixedSize: 150 }
        heightPolicy: { fixedSize: 11 }
    }
    'progressIndicator': {
        label: 'Progress Indicator'
        widthPolicy: { userSize: true, fixedSize: 150 }
        heightPolicy: { fixedSize: 11 }

        styles: {
            largeWhite: {
                width: 37
                height: 37
            }
            gray: {
                width: 20
                height: 20
            }
            white: {
                width: 20
                height: 20
            }
        }
    }
    'map': {
        label: 'Map'
        container: yes
        widthPolicy:  { userSize: true, fixedSize: 320 }
        heightPolicy: { userSize: true, fixedSize: 320 }
    }
    'map-marker': {
        label: 'Map Marker'
        widthPolicy:  { fixedSize: 20 }
        heightPolicy: { fixedSize: 34 }
    }
    'map-gps-location': {
        label: 'Current GPS Location'
        widthPolicy:  { fixedSize: 65 }
        heightPolicy: { fixedSize: 65 }
    }
    'map-pin': {
        label: 'iPhone-Style Pin'
        widthPolicy:  { fixedSize: 32 }
        heightPolicy: { fixedSize: 37 }
    }
    'map-callout': {
        label: 'Callout'
        container: yes
        defaultText: '123 Ave.'
        widthPolicy:  { userSize: yes; fixedSize: 116 }
        heightPolicy: { fixedSize: 35 }
        style: {
            fontSize: 15
        }
    }
    'segmented': {
        label: 'Segmented Control'
        container: yes
        widthPolicy:  { userSize: yes; fixedSize: 160 }
        heightPolicy: { fixedSize: 39 }
        html: '<ul class="segmented"></ul>'
        hitAreaInset: 10
        hitAreaOutset: 10
        canHazLink: no

        layoutChildren: (children, outerRect) ->
            return [] if children.length is 0

            remainingContainerW: outerRect.w
            remainingChildrenCount: children.length

            x: outerRect.x
            for child in children
                w: remainingContainerW / remainingChildrenCount
                r: { x: x, y: outerRect.y, w, h: outerRect.h }
                x += w
                remainingContainerW -= w
                remainingChildrenCount -= 1
                r
    }
    'segment': {
        label: 'Segment of Segmented Control'
        defaultText: 'Segment'
        widthPolicy:  { fixedSize: 100 }
        heightPolicy: { fixedSize: 39 }
        html: '<li class="segment"></li>'
        canHazColor: no
        allowedContainers: ['segmented']
    }
}

(window.Mockko ||= {}).paletteDefinition: [
    {
        name: "Text"
        items: [
            {
                type: 'text'
                text: 'Single-Line Text'
                style: {
                    fontSize: 17
                    textColor: '#000'
                }
            }
        ]
    }
    {
        name: "Shapes"
        items: [
            {
                type: 'rect'
            }
        ]
    }
    {
        name: "Status Bar"
        items: [
            {
                type: 'statusBar'
                label: 'Grey Status Bar'
                styleName: 'grey'
            }
            {
                type: 'statusBar'
                label: 'Black Opaque Status Bar'
                styleName: 'black-opaque'
            }
            {
                type: 'statusBar'
                label: 'Black Translucent Status Bar'
                styleName: 'black-translucent'
            }
        ]
    }
    {
        name: "Tab Bar"
        items: [
            {
                type: 'tabBar'
                label: 'Tab Bar'
                children: [
                    {
                        type: 'tab-bar-item'
                        text: "Tab 1"
                        image: { group: 'glyphish-icons', name: '53-house.png' }
                        state: on
                    }
                    {
                        type: 'tab-bar-item'
                        text: "Tab 2"
                        image: { group: 'glyphish-icons', name: '83-calendar.png' }
                        state: off
                    }
                ]
            }
            {
                type: 'tab-bar-item'
                image: { group: 'glyphish-icons', name: '28-star.png' }
                state: off
            }
        ]
    }
    {
        name: "Navigation Bar"
        items: [
            {
                type: 'navBar'
                styleName: 'grey'
                label: 'Grey Navigation Bar'
                children: [
                    {
                        type: 'text'
                        styleName: 'normal'
                        text: "Title"
                        location: { x: 139, y: 12 }
                        size: { width: null, height: null }
                        style: {
                        	fontSize: 20
                        	fontBold: yes
                        	textColor: '#fff'
                        	textShadowStyleName: 'dark-above'
                        }
                    }
                    {
                        type: 'backButton'
                        styleName: 'normal'
                        text: "Back"
                        location: { x: 5, y: 7 }
                        size: { width: null, height: null }
                    }
                    {
                        type: 'barButton'
                        styleName: 'normal'
                        text: "Edit"
                        location: { x: 269, y: 7 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'navBar'
                styleName: 'black-opaque'
                label: 'Black Opaque Navigation Bar'
                children: [
                    {
                        type: 'text'
                        styleName: 'black'
                        text: "Title"
                        location: { x: 139, y: 12 }
                        size: { width: null, height: null }
                        style: {
                        	fontSize: 20
                        	fontBold: yes
                        	textColor: '#fff'
                        	textShadowStyleName: 'dark-above'
                        }
                    }
                    {
                        type: 'backButton'
                        styleName: 'black'
                        text: "Back"
                        location: { x: 7, y: 7 }
                        size: { width: null, height: null }
                    }
                    {
                        type: 'barButton'
                        styleName: 'black'
                        text: "Edit"
                        location: { x: 269, y: 7 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'navBar'
                styleName: 'black-translucent'
                label: 'Black Translucent Navigation Bar'
                children: [
                    {
                        type: 'text'
                        styleName: 'black'
                        text: "Title"
                        location: { x: 139, y: 12 }
                        size: { width: null, height: null }
                        style: {
                        	fontSize: 20
                        	fontBold: yes
                        	textColor: '#fff'
                        	textShadowStyleName: 'dark-above'
                        }
                    }
                    {
                        type: 'backButton'
                        styleName: 'black'
                        text: "Back"
                        location: { x: 7, y: 7 }
                        size: { width: null, height: null }
                    }
                    {
                        type: 'barButton'
                        styleName: 'black'
                        text: "Edit"
                        location: { x: 269, y: 7 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'backButton'
                label: 'Grey Back Button'
                styleName: 'normal'
                style: {
                }
            }
            {
                type: 'backButton'
                label: 'Black Back Button'
                styleName: 'black'
                style: {
                }
            }
            {
                type: 'barButton'
                label: 'Black Back Button'
                styleName: 'black'
                style: {
                }
            }
            {
                type: 'barButton'
                label: 'Grey Bar Button'
                styleName: 'normal'
                style: {
                }
            }
            {
                type: 'barButton'
                label: 'Grey Bar Button (Done Style)'
                styleName: 'done'
                style: {
                }
            }
            {
                type: 'barButton'
                label: 'Black Bar Button'
                styleName: 'black'
                style: {
                }
            }
        ]
    }
    {
        name: "Toolbar"
        items: [
            {
                type: 'toolbar'
                label: 'Grey Toolbar'
                styleName: 'grey'
                children: [
                    {
                        type: 'barButton'
                        styleName: 'normal'
                        text: "Do something"
                    }
                ]
            }
            {
                type: 'toolbar'
                styleName: 'black-opaque'
                label: 'Black Opaque Toolbar'
                children: [
                    {
                        type: 'barButton'
                        styleName: 'black'
                        text: "Do something"
                    }
                ]
            }
            {
                type: 'toolbar'
                styleName: 'black-translucent'
                label: 'Black Translucent Toolbar'
                children: [
                    {
                        type: 'barButton'
                        styleName: 'black'
                        text: "Do something"
                    }
                ]
            }
        ]
    }
    {
        name: "Buttons"
        items: [
            {
                type: 'roundedButton'
            }
            {
                type: 'coloredButton'
                styleName: 'red'
                label: 'Red Button'
                style: {
                    textColor: '#fff'
                    textShadowStyleName: 'dark-above'
                }
            }
            {
                type: 'coloredButton'
                styleName: 'gray'
                label: 'Gray Button'
                style: {
                    textColor: '#fff'
                }
            }
            {
                type: 'coloredButton'
                styleName: 'white'
                label: 'White Button'
                style: {
                    textColor: '#000'
                    textShadowStyleName: 'light-below'
                }
            }
            {
                type: 'buyButton'
                styleName: 'green'
                label: 'Buy Button'
            }
            {
                type: 'buyButton'
                styleName: 'blue'
                label: 'Price Button'
            }
        ]
    }
    {
        name: "Segmented Control"
        items: [
            {
                type: 'segmented'
                size: { w: 200 }
                styleName: 'plain'
                children: [
                    {
                        type: 'segment'
                        text: 'None'
                        location: { x: 0, y: 0 }
                    }
                    {
                        type: 'segment'
                        text: 'A'
                        location: { x: 1, y: 0 }
                    }
                    {
                        type: 'segment'
                        text: 'B'
                        location: { x: 2, y: 0 }
                    }
                ]
            }
            {
                type: 'segment'
                text: 'C'
                styleName: 'plain'
                size: { w: 100 }
            }
            {
                type: 'segmented'
                size: { w: 200 }
                styleName: 'bordered'
                children: [
                    {
                        type: 'segment'
                        text: 'None'
                        location: { x: 0, y: 0 }
                    }
                    {
                        type: 'segment'
                        text: 'A'
                        location: { x: 1, y: 0 }
                    }
                    {
                        type: 'segment'
                        text: 'B'
                        location: { x: 2, y: 0 }
                    }
                ]
            }
            {
                type: 'segment'
                text: 'C'
                styleName: 'bordered'
                size: { w: 100 }
            }
        ]
    }
    {
        name: "Edge-to-Edge List"
        items: [
            {
                type: 'plain-header'
            }
            {
                type: 'plain-row'
                styleName: 'white'
                label: 'White Edge-To-Edge'
                style: {
                    background: 'white'
                }
                children: [
                    {
                        type: 'text'
                        styleName: 'row-white'
                        text: "Some text"
                        location: { x: 8, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontBold: yes
                            fontSize: 20
                            textColor: '#000'
                        }
                    }
                ]
            }
            {
                type: 'plain-row'
                style: {
                    background: 'white'
                }
                children: [
                    {
                        type: 'text'
                        text: "John Appleseed"
                        location: { x: 8, y: 10.5 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'text'
                        text: "mobile"
                        location: { x: 237, y: 13 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 16
                            fontBold: no
                            textColor: '#666666'
                        }
                    }
                    {
                        type: 'image'
                        location: { x: 295, y: 9 }
                        size: { w: 25, h: 26 }
                        image: { group: "iphone-accessories", name: "20-detail-disclosure-button.png" }
                    }
                ]
            }
            {
                type: 'plain-row'
                style: {
                    background: 'white'
                }
                children: [
                    {
                        type: 'text'
                        text: "John Appleseed"
                        location: { x: 8, y: 5 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'text'
                        text: "mobile"
                        location: { x: 8, y: 25 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 12
                            fontBold: no
                            textColor: '#666666'
                        }
                    }
                    {
                        type: 'text'
                        text: "Yesterday"
                        location: { x: 221, y: 14 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 14
                            fontBold: no
                            textColor: '#007fff'
                        }
                    }
                    {
                        type: 'image'
                        location: { x: 295, y: 9 }
                        size: { w: 25, h: 26 }
                        image: { group: "iphone-accessories", name: "20-detail-disclosure-button.png" }
                    }
                ]
            }
            {
                type: 'plain-row'
                style: {
                    background: 'white'
                }
                children: [
                    {
                        type: 'text'
                        text: "Two Of Us"
                        location: { x: 8, y: 5 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'text'
                        text: "The Beatles"
                        location: { x: 8, y: 25 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 12
                            fontBold: no
                            textColor: '#666666'
                        }
                    }
                ]
            }
            {
                type: 'plain-row'
                size: { h: 79 }
                style: {
                    background: 'white'
                }
                children: [
                    {
                        type: "image"
                        location: { x: 0, y: 0 }
                        size: { w: 73, h: 78 }
                        style: {
                            imageEffect: "iphone-tabbar-active"
                        }
                        image: { group: "glyphish-icons", name: "16-line-chart.png" }
                    }
                    {
                        type: "text"
                        text: "David Pogue",
                        location: { x: 90, y: 13 }
                        size: { w: null, h: null }
                        style: {
                            fontSize: 17
                            textColor: "#000000"
                            fontBold: true
                        }
                    }
                    {
                        type: "text"
                        text: "When it comes to tech, sim…"
                        location: { x: 90, y: 35 }
                        style: {
                            fontSize: 14
                            textColor: "#000000"
                            fontBold: true
                        }
                    }
                    {
                        type: "text"
                        text: "21:57"
                        location: { x: 90, y: 53 }
                        style: {
                            fontSize: 14
                            textColor: "#7f7f7f"
                            fontBold: true
                        }
                    }
                    {
                        type: "text"
                        text: "6/27/06"
                        location: { x: 257, y: 53 }
                        style: {
                            fontSize: 14
                            textColor: "#7f7f7f"
                            fontBold: true
                        }
                    }
                ]
            }
            {
                type: 'plain-row'
                styleName: 'dark'
                label: 'Dark Edge-To-Edge'
                style: {
                    background: 'dark'
                }
                children: [
                    {
                        type: 'text'
                        styleName: 'row-dark'
                        text: "Some text"
                        location: { x: 8, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#fff'
                        }
                    }
                ]
            }
            {
                type: 'plain-row'
                styleName: 'metal'
                label: 'Metal Edge-To-Edge'
                style: {
                    background: 'metal'
                }
                children: [
                    {
                        type: 'text'
                        styleName: 'row-metal'
                        text: "Some text"
                        location: { x: 8, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#fff'
                            textShadowStyleName: 'dark-above'
                        }
                    }
                ]
            }
            {
                type: "plain-row"
                size: {
                    h: 54
                }
                styleName: 'metal'
                style: {
                    background: 'metal'
                }
                children: [
                    {
                        type: 'image'
                        location: {
                            x: 6
                            y: 2.5
                        }
                        size: {
                            w: 51
                            h: 46
                        }
                        style: {
                            imageEffect: "iphone-tabbar-active"
                        }
                        image: {
                            group: "glyphish-icons"
                            name: "21-skull.png"
                        }
                    }
                    {
                        type: 'text'
                        location: {
                            x: 57
                            y: 5.5
                        }
                        style: {
                            fontSize: 11
                            textColor: "#7f7f7f"
                            fontBold: true
                            textShadowStyleName: "light-below"
                        }
                        text: "Clickgamer.com"
                    }
                    {
                        type: 'text'
                        location: {
                            x: 57
                            y: 18.5
                        }
                        style: {
                            fontSize: 14
                            textColor: "#000000"
                            fontBold: true
                            textShadowStyleName: "light-below"
                        }
                        text: "Angry Birds"
                    }
                    {
                        type: 'text'
                        location: {
                            x: 95
                            y: 35.5
                        }
                        style: {
                            fontSize: 11
                            textColor: "#7f7f7f"
                            fontBold: false
                            textShadowStyleName: "light-below"
                        }
                        text: "194 Ratings"
                    }
                    {
                        type: 'text'
                        location: {
                            x: 57
                            y: 35.5
                        }
                        style: {
                            fontSize: 11
                            textColor: "#7f7f7f"
                            fontBold: true
                            textShadowStyleName: "light-below"
                        }
                        text: "* * * * *"
                    }
                    {
                        type: 'text'
                        location: {
                            x: 267
                            y: 19
                        }
                        style: {
                            fontSize: 11
                            textColor: "#7f7f7f"
                            fontBold: true
                            fontItalic: false
                            textShadowStyleName: "light-below"
                        }
                        text: "$0.99"
                    }
                    {
                        type: 'image'
                        location: {
                            x: 304
                            y: 17.5
                        }
                        size: {
                            w: 8
                            h: 14
                        }
                        image: {
                            group: "iphone-accessories"
                            name: "10-disclosure-indicator.png"
                        }
                    }
                ]
            }
            {
                type: 'plain-row'
                styleName: 'plastic'
                label: 'Plastic Edge-To-Edge'
                style: {
                    background: 'plastic'
                }
                children: [
                    {
                        type: 'text'
                        styleName: 'row-dark'
                        text: "Some text"
                        location: { x: 8, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#fff'
                        }
                    }
                ]
            }
        ]
    }
    {
        name: "Rounded-Rectangle List"
        items: [
            {
                type: 'roundrect-header'
            }
            {
                type: 'roundrect-row'
                children: [
                    {
                        type: 'text'
                        styleName: 'row-roundrect-white'
                        text: "Some text"
                        location: { x: 20, y: 13 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000'
                        }
                    }
                ]
            }
            {
                type: 'roundrect-row'
                children: [
                    {
                        type: 'text'
                        styleName: 'row-roundrect-white'
                        text: "phone"
                        location: { x: 54, y: 13 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: no
                            textColor: '#0000bf'
                        }
                    }
                    {
                        type: 'text'
                        styleName: 'row-roundrect-white'
                        text: "+1 (234) 567 89 10"
                        location: { x: 107, y: 13 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                ]
            }
            {
                type: 'roundrect-row'
                children: [
                    {
                        type: 'text'
                        styleName: 'row-roundrect-white'
                        text: "Airplane Mode"
                        location: { x: 20, y: 13 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'switch'
                        styleName: 'row-roundrect-white'
                        text: "+1 (234) 567 89 10"
                        location: { x: 206, y: 8.5 }
                        size: { width: null, height: null }
                        state: on
                    }
                ]
            }
            {
                type: 'roundrect-row'
                children: [
                    {
                        type: 'text'
                        text: "Show Preview"
                        location: { x: 20, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'text'
                        text: "2 lines"
                        location: { x: 233, y: 12 }
                        size: { width: null, height: null }
                        style: {
                            fontSize: 17
                            fontBold: no
                            textColor: '#000000'
                        }
                    }
                    {
                        type: 'image'
                        location: { x: 292, y: 15 }
                        size: { w: 8, h: 14 }
                        image: { group: "iphone-accessories", name: "10-disclosure-indicator.png" }
                    }
                ]
            }
        ]
    }
    {
        name: "Input Controls"
        items: [
            {
                type: 'switch'
                state: on
            }
        ]
    }
    {
        name: 'Maps'
        items: [
            {
                type: 'map'
            }
            {
                type: 'map-marker'
                styleName: 'red'
            }
            {
                type: 'map-marker'
                styleName: 'blue'
            }
            {
                type: 'map-pin'
                styleName: 'red'
            }
            {
                type: 'map-gps-location'
            }
            {
                type: 'map-callout'
                text: '123 Avenue'
            }
        ]
    }
    {
        name: "Misc"
        items: [
        ]
    }
]

(window.Mockko ||= {}).textShadowStyles: {
    'none': {
        label: 'none'
        css: {
            'text-shadow': 'none'
        }
    }
    'dark-above': {
        label: 'dark (above the object)'
        css: {
            'text-shadow': '0px -1px rgba(0,0,0,0.5)'
        }
    }
    'light-below': {
        label: 'light (below the object)'
        css: {
            'text-shadow': '0px 1px rgba(255,255,255,0.5)'
        }
    }
    'dark-below': {
        label: 'dark (below the object)'
        css: {
            'text-shadow': '0px 1px rgba(0,0,0,0.75)'
        }
    }

}

(window.Mockko ||= {}).backgroundStyles: [
    {
        name: 'transparent'
        label: 'Transparent'
    }
    {
        name: "striped"
        label: "Striped"
    }
    {
        name: "white"
        label: "White"
    }
    {
        name: "black"
        label: "Black"
    }
    {
        name: "metal"
        label: "Metal"
    }
    {
        name: "plastic"
        label: "Plastic"
    }
    {
        name: "dark"
        label: "Dark"
    }
]
(window.Mockko ||= {}).backgroundStylesByName: (->
    result: {}
    for bg in Mockko.backgroundStyles
        result[bg.name]: bg
    result
)()
