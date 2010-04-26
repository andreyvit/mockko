
window.MakeApp: {} unless window.MakeApp?
window.MakeApp.paletteDefinition: [
    {
        name: "Backgrounds"
        ctypes: [
            {
                type: 'background'
                label: 'Background'
                container: yes
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { autoSize: 'fill' }
                
                palettePresentation: 'tile'
                
                styles: [
                    {
                        styleName: 'striped'
                        label: 'Striped'
                    }
                    {
                        styleName: 'white'
                        label: 'White'
                    }
                    {
                        styleName: 'black'
                        label: 'Black'
                    }
                ]
            }
        ]
    }
    {
        name: "Text"
        ctypes: [
            {
                type: 'text'
                label: 'Text'
                defaultText: "Some text"
                widthPolicy: { autoSize: 'browser' }
                heightPolicy: { fixedSize: 20 }
                
                styles: [
                    {
                        styleName: 'plain'
                        label: 'Plain'
                        style: {
                            fontSize: 17
                            textColor: '#000'
                        }
                    }
                    {
                        styleName: 'bar-title'
                        label: 'Bar Title'
                        style: {
                        	fontSize: 20
                        	fontBold: yes
                        	textColor: '#fff'
                        	textShadowStyleName: 'dark-above'
                        }
                    }
                    {
                        styleName: 'row-white'
                        label: 'for White Row'
                        style: {
                            fontBold: yes
                            fontSize: 20
                            textColor: '#000'
                        }
                    }
                    {
                        styleName: 'row-roundrect-white'
                        label: 'for White Rounded-Rectangle Row'
                        style: {
                            fontSize: 17
                            fontBold: yes
                            textColor: '#000'
                        }
                    }
                    {
                        styleName: 'row-dark'
                        label: 'for Dark Row'
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#fff'
                        }
                    }
                    {
                        styleName: 'row-metal'
                        label: 'for Metal Row'
                        style: {
                            fontSize: 20
                            fontBold: yes
                            textColor: '#fff'
                            textShadowStyleName: 'dark-above'
                        }
                    }
                ]
            }
        ]
    }
    {
        name: "Bars"
        ctypes: [
            {
                type: 'statusBar'
                label: 'Status Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: 20 }
                styles: [
                    {
                        styleName: 'grey'
                        label: 'Grey Status Bar'
                    }
                    {
                        styleName: 'black-opaque'
                        label: 'Black Opaque Status Bar'
                    }
                    {
                        styleName: 'black-translucent'
                        label: 'Black Translucent Status Bar'
                    }
                ]
            }
            {
                type: 'tabBar'
                label: 'Tab Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: 49 }
                container: yes
            }
            {
                type: 'tab-bar-item'
                label: 'Tab Bar Item'
                defaultText: 'My Tab'
                widthPolicy: { fixedSize: 60 }
                heightPolicy: { fixedSize: 44 }
                container: yes
                html: '<div><div class="icon"></div><div class="label"></div></div>'
                textSelector: '.label'
                textStyleEditable: no
            }
            {
                type: 'navBar'
                label: 'Navigation Bar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
                container: yes
                styles: [
                    {
                        styleName: 'grey'
                        label: 'Grey Navigation Bar'
                    }
                    {
                        styleName: 'black-opaque'
                        label: 'Black Opaque Navigation Bar'
                    }
                    {
                        styleName: 'black-translucent'
                        label: 'Black Translucent Navigation Bar'
                    }
                ]
                children: [
                    {
                        type: 'text'
                        styleName: 'bar-title'
                        text: "Title"
                        location: { x: 139, y: 12 }
                        size: { width: null, height: null }
                    }
                    {
                        type: 'backButton'
                        styleName: 'plain'
                        text: "Back"
                        location: { x: 7, y: 7 }
                        size: { width: null, height: null }
                    }
                    {
                        type: 'barButton'
                        styleName: 'normal'
                        text: "Edit"
                        location: { x: 262, y: 7 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'toolbar'
                label: 'Toolbar'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { fixedSize: { portrait: 44, landscape: 44 } }
                container: yes
                styles: [
                    {
                        styleName: 'grey'
                        label: 'Grey Toolbar'
                    }
                    {
                        styleName: 'black-opaque'
                        label: 'Black Opaque Toolbar'
                    }
                    {
                        styleName: 'black-translucent'
                        label: 'Black Translucent Toolbar'
                    }
                ]
            }
        ]
    }
    {
        name: "Buttons"
        ctypes: [
            {
                type: 'backButton'
                label: 'Back Button'
                genericLabel: 'Button'
                defaultText: "Back"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { fixedSize: { portrait: 30, landscape: 30 } }
            }
            {
                type: 'barButton'
                label: 'Bar Button'
                genericLabel: 'Button'
                defaultText: "Edit"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { fixedSize: { portrait: 30, landscape: 30 } }
                styles: [
                    {
                        styleName: 'normal'
                        label: 'Bar Button'
                    }
                    {
                        styleName: 'done'
                        label: 'Bar Button (Done)'
                    }
                ]
            }
            {
                type: 'roundedButton'
                label: 'Rounded Button'
                genericLabel: 'Button'
                defaultText: "Call"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { userSize: true, fixedSize: 44 }
            }
            {
                type: 'coloredButton'
                label: 'Colored Button'
                genericLabel: 'Button'
                defaultText: "Delete Contact"
                widthPolicy: { userSize: true, autoSize: 'browser' }
                heightPolicy: { userSize: true, fixedSize: 44 }
                styles: [
                    {
                        styleName: 'red'
                        label: 'Red Button'
                    }
                    {
                        styleName: 'gray'
                        label: 'Gray Button'
                    }
                    {
                        styleName: 'white'
                        label: 'White Button'
                    }
                ]
            }
            {
                type: 'buyButton'
                label: 'Buy Button'
                genericLabel: 'Button'
                defaultText: "BUY NOW"
                widthPolicy: { userSize: true, fixedSize: 80 } #autoSize: 'browser'
                heightPolicy: { userSize: true, fixedSize: 25 }
                styles: [
                    {
                        styleName: 'green'
                        label: 'Buy Button'
                    }
                    {
                        styleName: 'blue'
                        label: 'Price Button'
                    }
                ]
            }
        ]
    }
    {
        name: "Table/List Rows"
        ctypes: [
            {
                type: 'plain-row'
                label: 'Edge-to-Edge Row'
                container: yes
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { userSize: true, fixedSize: 44 }
                styles: [
                    {
                        styleName: 'white'
                        label: 'White Edge-To-Edge'
                        childrenStyles: {
                            'main-label': {
                                styleName: 'row-white'
                            }
                        }
                    }
                    {
                        styleName: 'dark'
                        label: 'Dark Edge-To-Edge'
                        childrenStyles: {
                            'main-label': {
                                styleName: 'row-dark'
                            }
                        }
                    }
                    {
                        styleName: 'metal'
                        label: 'Metal Edge-To-Edge'
                        childrenStyles: {
                            'main-label': {
                                styleName: 'row-metal'
                            }
                        }
                    }
                    {
                        styleName: 'plastic'
                        label: 'Plastic Edge-To-Edge'
                        childrenStyles: {
                            'main-label': {
                                styleName: 'row-dark'
                            }
                        }
                    }
                ]
                children: [
                    {
                        type: 'text'
                        styleRef: 'main-label'
                        text: "Some text"
                        location: { x: 8, y: 12 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'plain-header'
                label: 'Header'
                defaultText: "Cities"
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { userSize: true, fixedSize: 20 }
            }
            {
                type: 'roundrect-row'
                group: 'roundrect-rows'
                label: 'Rounded Rect Row'
                widthPolicy: { autoSize: 'fill' }
                heightPolicy: { userSize: true, fixedSize: 44 }
                html: '<div><div class="inner"></div></div>'
                topInset: 17  # not handled currently
                children: [
                    {
                        type: 'text'
                        styleName: 'row-roundrect-white'
                        text: "Some text"
                        location: { x: 20, y: 13 }
                        size: { width: null, height: null }
                    }
                ]
            }
            {
                type: 'roundrect-header'
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
        ]
    }
    {
        name: "Input Controls"
        ctypes: [
            {
                type: 'switch'
                label: 'On/Off Switch'
                widthPolicy: { fixedSize: 94 }
                heightPolicy: { fixedSize: 27 }
            }
            {
                type: 'slider'
                label: 'Slider'
                widthPolicy: { userSize: true, fixedSize: 118 }
                heightPolicy: { fixedSize: 23 }
            }
            {
                type: 'pageControl'
                label: 'Page Control'
                widthPolicy: { userSize: true, fixedSize: 38 }
                heightPolicy: { fixedSize: 36 }
            }
            {
                type: 'segmentedControl'
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
            {
                type: 'stars'
                label: 'Stars'
                widthPolicy: { fixedSize: 50 }
                heightPolicy: { fixedSize: 27 }
            }
        ]
    }
    {
        name: "Misc"
        ctypes: [
            {
                type: 'progressBar'
                label: 'Progress Bar'
                widthPolicy: { userSize: true, fixedSize: 150 }
                heightPolicy: { fixedSize: 9 }
            }
            {
                type: 'progressBarBarStyle'
                label: 'Progress Bar 2'
                widthPolicy: { userSize: true, fixedSize: 150 }
                heightPolicy: { fixedSize: 11 }
            }
            {
                type: 'progressIndicator'
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
        ]
    }
]

MakeApp.textShadowStyles: {
    none: {
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
	
}
