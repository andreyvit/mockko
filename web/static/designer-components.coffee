
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

(window.MakeApp ||= {}).componentTypes: {
    'background': {
        type: 'background'
        label: 'Background'
        container: yes
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { autoSize: 'fill' }
        unmovable: yes
        supportsBackground: yes
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
    }
    'tabBar': {
        label: 'Tab Bar'
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: 49 }
        container: yes
        pin: Pins.bottom
        singleInstance: yes
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
        defaultText: "B"
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { fixedSize: 20 }
        style: {
            textColor: '#fff'
            fontSize: 16
            fontBold: yes
            textShadowStyleName: 'dark-below'
        }
    }
    'plain-row': {
        label: 'Edge-to-Edge Row'
        container: yes
        widthPolicy: { autoSize: 'fill' }
        heightPolicy: { userSize: true, fixedSize: 44 }
        supportsBackground: yes
    }
    'roundrect-header': {
        label: 'Header'
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
}

window.MakeApp: {} unless window.MakeApp?
window.MakeApp.paletteDefinition: [
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
                        image: { kind: 'stock', group: 'glyphish/icons', name: '53-house.png' }
                        location: { x: 5, y: 3 }
                        size: { w: 154, h: null }
                        state: on
                    }
                    {
                        type: 'tab-bar-item'
                        text: "Tab 2"
                        image: { kind: 'stock', group: 'glyphish/icons', name: '83-calendar.png' }
                        location: { x: 161, y: 3 }
                        size: { w: 154, h: null }
                        state: off
                    }
                ]
            }
            {
                type: 'tab-bar-item'
                image: { kind: 'stock', group: 'glyphish/icons', name: '28-star.png' }
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
                        location: { x: 108.5, y: 7 }
                        size: { width: null, height: null }
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
                        location: { x: 108.5, y: 7 }
                        size: { width: null, height: null }
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
                        location: { x: 108.5, y: 7 }
                        size: { width: null, height: null }
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
                backgroundSelector: '.inner'
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

MakeApp.textShadowStyles: {
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

MakeApp.backgroundStyles: [
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

MakeApp.stockImageGroups: [
    {
        name: "glyphish-icons"
        label: "Glyphish Tav Bar Icons"
        path: 'glyphish/icons'
        imageEffect: 'iphone-tabbar-active'
    }
    {
        name: "glyphish-mini-icons"
        label: "Glyphish Toolbar & Navbar Icons"
        path: 'glyphish/mini-icons'
        imageEffect: 'iphone-tabbar-inactive'
    }
    {
        name: "iphone-accessories"
        label: "iPhone Accessory Icons"
        path: 'iphone-accessories'
        imageEffect: null
    }
]
