
window.MakeApp ||= {};
window.MakeApp.appTemplates = {};

window.MakeApp.appTemplates.simple: {
    'screens': [{
        'components': [
            {
                'type': 'barButton',
                'text': 'Back',
                'location': { 'x': 50, 'y': 100 }
                'size': {}
            }
        ]
    }]
}


window.MakeApp.appTemplates.basic = {
    'screens': [
        {
            'components': [
                {
                    'type': "background"
                    'styleName': "striped"
                    'location': { x: 0, y: 0 }
                }
                {
                    'type': "statusBar",
                    'styleName': "grey"
                    'location': { x: 0, y: 0 }
                }
                {
                    'type': "navBar",
                    'styleName': "grey"
                    'location': { x: 0, y: 20 }
                }
            ]
        }
    ]
};
