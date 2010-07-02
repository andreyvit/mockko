
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


sampleApplicationsJSON: [
    '''
    {"name":"Clock","screens":[{"rootComponent":{"type":"background","location":{"x":0,"y":0},"size":{},"style":{"background":"striped"},"action":null,"children":[{"type":"statusBar","location":{"x":0,"y":0},"size":{},"styleName":"grey","style":{},"action":null,"children":[]},{"type":"tabBar","location":{"x":0,"y":431},"size":{},"style":{},"action":null,"children":[{"type":"tab-bar-item","location":{"x":5,"y":3},"size":{"w":76,"h":44},"style":{},"text":"World Clock","action":null,"children":[],"state":true,"image":{"kind":"stock","group":"glyphish-icons","name":"71-compass.png"}},{"type":"tab-bar-item","location":{"x":83,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Alarm","action":{"action":"switch-screen","screenName":"Alarm"},"children":[],"state":false,"image":{"group":"glyphish-icons","name":"124-bullhorn.png"}},{"type":"tab-bar-item","location":{"x":161,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Stopwatch","action":null,"children":[],"state":false,"image":{"group":"glyphish-icons","name":"78-stopwatch.png"}},{"type":"tab-bar-item","location":{"x":239,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Timer","action":null,"children":[],"state":false,"image":{"group":"glyphish-icons","name":"81-dashboard.png"}}]},{"type":"navBar","location":{"x":0,"y":20},"size":{},"styleName":"grey","style":{},"action":null,"children":[{"type":"text","location":{"x":101.5,"y":12},"size":{},"styleName":"normal","style":{"fontSize":20,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"World Clock","action":null,"children":[]},{"type":"barButton","location":{"x":280,"y":8.5},"size":{},"styleName":"normal","style":{"fontSize":18,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"+","action":null,"children":[]},{"type":"barButton","location":{"x":5,"y":7},"size":{},"styleName":"normal","style":{"fontSize":12,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"Edit","action":null,"children":[]}]},{"type":"plain-row","location":{"x":0,"y":64},"size":{"h":81},"styleName":"metal","style":{"background":"metal"},"action":null,"children":[{"type":"text","location":{"x":8,"y":32},"size":{},"styleName":"row-metal","style":{"fontSize":15,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Novosibirsk","action":null,"children":[]},{"type":"text","location":{"x":227,"y":18},"size":{},"styleName":"row-metal","style":{"fontSize":25,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"4:10","action":null,"children":[]},{"type":"text","location":{"x":278,"y":24},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#000000","fontBold":false,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"AM","action":null,"children":[]},{"type":"text","location":{"x":253,"y":46},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#666666","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Today","action":null,"children":[]}]},{"type":"plain-row","location":{"x":0,"y":145},"size":{"h":81},"styleName":"metal","style":{"background":"metal"},"action":null,"children":[{"type":"text","location":{"x":8,"y":32},"size":{},"styleName":"row-metal","style":{"fontSize":15,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Brussels","action":null,"children":[]},{"type":"text","location":{"x":213,"y":18},"size":{},"styleName":"row-metal","style":{"fontSize":25,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"11:10","action":null,"children":[]},{"type":"text","location":{"x":279,"y":24},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#000000","fontBold":false,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"PM","action":null,"children":[]},{"type":"text","location":{"x":220,"y":46},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#666666","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Yesterday","action":null,"children":[]}]},{"type":"plain-row","location":{"x":0,"y":226},"size":{"h":81},"styleName":"metal","style":{"background":"metal"},"action":null,"children":[{"type":"text","location":{"x":8,"y":32},"size":{},"styleName":"row-metal","style":{"fontSize":15,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Portland","action":null,"children":[]},{"type":"text","location":{"x":227,"y":18},"size":{},"styleName":"row-metal","style":{"fontSize":25,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"2:10","action":null,"children":[]},{"type":"text","location":{"x":279,"y":24},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#000000","fontBold":false,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"PM","action":null,"children":[]},{"type":"text","location":{"x":220,"y":46},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#666666","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Yesterday","action":null,"children":[]}]}]},"name":"World Clock","html":"<div class=\\"component c-background c-background-nostyle container unmovable bg-striped\\" style=\\"left: 0px; top: 0px; width: 320px; height: 480px; \\" action=\\"\\" id=\\"screen-World_20Clock\\"><div class=\\"component c-statusBar c-statusBar-grey leaf movable\\" style=\\"left: 0px; top: 0px; width: 320px; height: 20px; z-index: 5; \\" action=\\"\\"></div><div class=\\"component c-tabBar c-tabBar-nostyle container movable\\" style=\\"left: 0px; top: 431px; width: 320px; height: 49px; z-index: 3; \\" action=\\"\\"><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-on\\" style=\\"left: 5px; top: 3px; width: 76px; height: 44px; z-index: 3; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--71-compass.png/iphone-tabbar-active); \\"></div><div class=\\"label\\" style=\\"color: rgb(255, 255, 255); \\">World Clock</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off has-action\\" style=\\"left: 83px; top: 3px; width: 76px; height: 44px; z-index: 0; \\" action=\\"screen:Alarm\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--124-bullhorn.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">Alarm</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off\\" style=\\"left: 161px; top: 3px; width: 76px; height: 44px; z-index: 2; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--78-stopwatch.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">Stopwatch</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off\\" style=\\"left: 239px; top: 3px; width: 76px; height: 44px; z-index: 1; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--81-dashboard.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">Timer</div></div></div><div class=\\"component c-navBar c-navBar-grey container movable\\" style=\\"left: 0px; top: 20px; width: 320px; height: 44px; z-index: 4; \\" action=\\"\\"><div class=\\"component c-text c-text-normal leaf movable\\" style=\\"left: 101.5px; top: 12px; font-size: 20px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: auto; z-index: 0; \\" action=\\"\\">World Clock</div><div class=\\"component c-barButton c-barButton-normal leaf movable\\" style=\\"left: 280px; top: 8.5px; font-size: 18px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: 30px; z-index: 2; \\" action=\\"\\">+</div><div class=\\"component c-barButton c-barButton-normal leaf movable\\" style=\\"left: 5px; top: 7px; font-size: 12px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: 30px; z-index: 1; \\" action=\\"\\">Edit</div></div><div class=\\"component c-plain-row c-plain-row-metal container movable bg-metal first-in-stack first-in-group in-stack odd-in-stack odd-in-group\\" style=\\"left: 0px; top: 64px; width: 320px; height: 81px; z-index: 2; \\" action=\\"\\"><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 32px; font-size: 15px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">Novosibirsk</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 227px; top: 18px; font-size: 25px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 0; \\" action=\\"\\">4:10</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 278px; top: 24px; font-size: 18px; color: rgb(0, 0, 0); font-weight: normal; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 3; \\" action=\\"\\">AM</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 253px; top: 46px; font-size: 18px; color: rgb(102, 102, 102); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 2; \\" action=\\"\\">Today</div></div><div class=\\"component c-plain-row c-plain-row-metal container movable bg-metal in-stack even-in-stack even-in-group\\" style=\\"left: 0px; top: 145px; width: 320px; height: 81px; z-index: 0; \\" action=\\"\\"><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 32px; font-size: 15px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 2; \\" action=\\"\\">Brussels</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 213px; top: 18px; font-size: 25px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 0; \\" action=\\"\\">11:10</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 279px; top: 24px; font-size: 18px; color: rgb(0, 0, 0); font-weight: normal; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 3; \\" action=\\"\\">PM</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 220px; top: 46px; font-size: 18px; color: rgb(102, 102, 102); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">Yesterday</div></div><div class=\\"component c-plain-row c-plain-row-metal container movable bg-metal in-stack odd-in-stack odd-in-group last-in-group last-in-stack\\" style=\\"left: 0px; top: 226px; width: 320px; height: 81px; z-index: 1; \\" action=\\"\\"><div class=\\"component c-text c-text-row-metal leaf movable selected\\" style=\\"font-size: 15px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; z-index: 2; left: 8px; top: 32px; width: auto; height: auto; \\" action=\\"\\">Portland</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 227px; top: 18px; font-size: 25px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">2:10</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 279px; top: 24px; font-size: 18px; color: rgb(0, 0, 0); font-weight: normal; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 3; \\" action=\\"\\">PM</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 220px; top: 46px; font-size: 18px; color: rgb(102, 102, 102); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 0; \\" action=\\"\\">Yesterday</div></div></div>"},{"rootComponent":{"type":"background","location":{"x":0,"y":0},"size":{},"style":{"background":"striped"},"action":null,"children":[{"type":"statusBar","location":{"x":0,"y":0},"size":{},"styleName":"grey","style":{},"action":null,"children":[]},{"type":"tabBar","location":{"x":0,"y":431},"size":{},"style":{},"action":null,"children":[{"type":"tab-bar-item","location":{"x":5,"y":3},"size":{"w":76,"h":44},"style":{},"text":"World Clock","action":{"action":"switch-screen","screenName":"World Clock"},"children":[],"state":false,"image":{"group":"glyphish-icons","name":"71-compass.png"}},{"type":"tab-bar-item","location":{"x":83,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Alarm","action":null,"children":[],"state":true,"image":{"group":"glyphish-icons","name":"124-bullhorn.png"}},{"type":"tab-bar-item","location":{"x":161,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Stopwatch","action":null,"children":[],"state":false,"image":{"group":"glyphish-icons","name":"78-stopwatch.png"}},{"type":"tab-bar-item","location":{"x":239,"y":3},"size":{"w":76,"h":44},"style":{},"text":"Timer","action":null,"children":[],"state":false,"image":{"group":"glyphish-icons","name":"81-dashboard.png"}}]},{"type":"navBar","location":{"x":0,"y":20},"size":{},"styleName":"grey","style":{},"action":null,"children":[{"type":"text","location":{"x":131.5,"y":12},"size":{},"styleName":"normal","style":{"fontSize":20,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"Alarm","action":null,"children":[]},{"type":"barButton","location":{"x":280,"y":8.5},"size":{},"styleName":"normal","style":{"fontSize":18,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"+","action":null,"children":[]},{"type":"barButton","location":{"x":5,"y":7},"size":{},"styleName":"normal","style":{"fontSize":12,"textColor":"#fff","fontBold":true,"fontItalic":false,"textShadowStyleName":"dark-above"},"text":"Edit","action":null,"children":[]}]},{"type":"plain-row","location":{"x":0,"y":64},"size":{"h":81},"styleName":"metal","style":{"background":"metal"},"action":null,"children":[{"type":"text","location":{"x":8,"y":12},"size":{},"styleName":"row-metal","style":{"fontSize":25,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"8:45","action":null,"children":[]},{"type":"text","location":{"x":62,"y":18},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"AM","action":null,"children":[]},{"type":"text","location":{"x":8,"y":40},"size":{},"styleName":"row-metal","style":{"fontSize":12,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Every day","action":null,"children":[]},{"type":"text","location":{"x":8,"y":55},"size":{},"styleName":"row-metal","style":{"fontSize":12,"textColor":"#666666","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Good morning!","action":null,"children":[]},{"type":"switch","location":{"x":218,"y":27},"size":{},"style":{},"action":null,"children":[],"state":true}]},{"type":"plain-row","location":{"x":0,"y":145},"size":{"h":81},"styleName":"metal","style":{"background":"metal"},"action":null,"children":[{"type":"text","location":{"x":8,"y":12},"size":{},"styleName":"row-metal","style":{"fontSize":25,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"8:49","action":null,"children":[]},{"type":"text","location":{"x":62,"y":18},"size":{},"styleName":"row-metal","style":{"fontSize":18,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"AM","action":null,"children":[]},{"type":"text","location":{"x":8,"y":40},"size":{},"styleName":"row-metal","style":{"fontSize":12,"textColor":"#000000","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Every day","action":null,"children":[]},{"type":"text","location":{"x":8,"y":55},"size":{},"styleName":"row-metal","style":{"fontSize":12,"textColor":"#666666","fontBold":true,"fontItalic":false,"textShadowStyleName":"light-below"},"text":"Hey, it's time to get up!","action":null,"children":[]},{"type":"switch","location":{"x":218,"y":27},"size":{},"style":{},"action":null,"children":[],"state":false}]}]},"name":"Alarm","html":"<div class=\\"component c-background c-background-nostyle container unmovable bg-striped\\" style=\\"left: 0px; top: 0px; width: 320px; height: 480px; \\" action=\\"\\" id=\\"screen-Alarm\\"><div class=\\"component c-statusBar c-statusBar-grey leaf movable\\" style=\\"left: 0px; top: 0px; width: 320px; height: 20px; z-index: 4; \\" action=\\"\\"></div><div class=\\"component c-tabBar c-tabBar-nostyle container movable\\" style=\\"left: 0px; top: 431px; width: 320px; height: 49px; z-index: 2; \\" action=\\"\\"><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off has-action\\" style=\\"left: 5px; top: 3px; width: 76px; height: 44px; z-index: 3; \\" action=\\"screen:World_20Clock\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--71-compass.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">World Clock</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-on\\" style=\\"left: 83px; top: 3px; width: 76px; height: 44px; z-index: 0; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--124-bullhorn.png/iphone-tabbar-active); \\"></div><div class=\\"label\\" style=\\"color: rgb(255, 255, 255); \\">Alarm</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off\\" style=\\"left: 161px; top: 3px; width: 76px; height: 44px; z-index: 2; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--78-stopwatch.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">Stopwatch</div></div><div class=\\"component c-tab-bar-item c-tab-bar-item-nostyle container movable state-off\\" style=\\"left: 239px; top: 3px; width: 76px; height: 44px; z-index: 1; \\" action=\\"\\"><div class=\\"icon\\" style=\\"background-image: url(http://www.mockko.com/images/stock--glyphish--icons--81-dashboard.png/iphone-tabbar-inactive); \\"></div><div class=\\"label\\" style=\\"color: rgb(238, 238, 238); \\">Timer</div></div></div><div class=\\"component c-navBar c-navBar-grey container movable\\" style=\\"left: 0px; top: 20px; width: 320px; height: 44px; z-index: 3; \\" action=\\"\\"><div class=\\"component c-text c-text-normal leaf movable\\" style=\\"left: 131.5px; top: 12px; font-size: 20px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">Alarm</div><div class=\\"component c-barButton c-barButton-normal leaf movable\\" style=\\"left: 280px; top: 8.5px; font-size: 18px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: 30px; z-index: 2; \\" action=\\"\\">+</div><div class=\\"component c-barButton c-barButton-normal leaf movable\\" style=\\"left: 5px; top: 7px; font-size: 12px; color: rgb(255, 255, 255); font-weight: bold; font-style: normal; text-shadow: rgba(0, 0, 0, 0.496094) 0px -1px; width: auto; height: 30px; z-index: 0; \\" action=\\"\\">Edit</div></div><div class=\\"component c-plain-row c-plain-row-metal container movable bg-metal first-in-stack first-in-group in-stack odd-in-stack odd-in-group\\" style=\\"left: 0px; top: 64px; width: 320px; height: 81px; z-index: 1; \\" action=\\"\\"><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 12px; font-size: 25px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">8:45</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 62px; top: 18px; font-size: 18px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 4; \\" action=\\"\\">AM</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 40px; font-size: 12px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 3; \\" action=\\"\\">Every day</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 55px; font-size: 12px; color: rgb(102, 102, 102); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 2; \\" action=\\"\\">Good morning!</div><div class=\\"component c-switch c-switch-nostyle leaf movable state-on\\" style=\\"left: 218px; top: 27px; width: 94px; height: 27px; z-index: 0; \\" action=\\"\\"></div></div><div class=\\"component c-plain-row c-plain-row-metal container movable bg-metal in-stack even-in-stack even-in-group last-in-group last-in-stack\\" style=\\"left: 0px; top: 145px; width: 320px; height: 81px; z-index: 0; \\" action=\\"\\"><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 12px; font-size: 25px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 2; \\" action=\\"\\">8:49</div><div class=\\"component c-text c-text-row-metal leaf movable selected\\" style=\\"font-size: 18px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; z-index: 4; left: 62px; top: 18px; width: auto; height: auto; \\" action=\\"\\">AM</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 40px; font-size: 12px; color: rgb(0, 0, 0); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 3; \\" action=\\"\\">Every day</div><div class=\\"component c-text c-text-row-metal leaf movable\\" style=\\"left: 8px; top: 55px; font-size: 12px; color: rgb(102, 102, 102); font-weight: bold; font-style: normal; text-shadow: rgba(255, 255, 255, 0.496094) 0px 1px; width: auto; height: auto; z-index: 1; \\" action=\\"\\">Hey, it's time to get up!</div><div class=\\"component c-switch c-switch-nostyle leaf movable state-off\\" style=\\"left: 218px; top: 27px; width: 94px; height: 27px; z-index: 0; \\" action=\\"\\"></div></div></div>"}]}
        '''
]

(window.Mockko ||= {}).sampleApplications: ( { 'body': body, 'sample': yes } for body in sampleApplicationsJSON )
