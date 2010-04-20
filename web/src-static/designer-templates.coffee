
window.MakeApp ||= {};
window.MakeApp.appTemplates = {};

window.MakeApp.appTemplates.simple: {
    screens: [{
        components: [
            {
                type: 'barButton',
                text: 'Back',
                location: { x: 50, y: 100 }
                size: {}
            }
        ]
    }]
}


window.MakeApp.appTemplates.basic = {
    screens: [
        {
            components: [
                {
                    type: "background"
                    styleName: "striped"
                    size: { width: 320, height: 480 }
                    location: { x: 0, y: 0 }
                    id: "root"
                }
                {
                    type: "statusBar",
                    styleName: "grey"
                    size: { width: null, height: null }
                    location: { x: 0, y: 0 }
                    id: "c13"
                }
                {
                    type: "navBar",
                    styleName: "grey"
                    size: { width: null, height: null }
                    location: { x: 0, y: 20 }
                    id: "c14"
                }
            ]
        }
    ]
};
