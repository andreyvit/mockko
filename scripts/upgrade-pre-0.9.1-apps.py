import sys, json
sys.path.append('.')
from makeapp.models import App

def update_img(gid, component):
    print '>' + component['type']
    if 'image' in component:
        imgdata = component['image']
        print json.dumps(imgdata)
        if 'kind' in imgdata:
            if imgdata['kind'] == 'custom':
                imgdata['group'] = gid
            elif imgdata['kind'] == 'stock':
                if imgdata['group'] == 'glyphish/icons':
                    imgdata['group'] = 'glyphish-icons'
                if imgdata['group'] == 'glyphish/mini-icons':
                    imgdata['group'] = 'glyphish-mini-icons'
            del imgdata['kind']
        if 'group' not in imgdata:
            imgdata['group'] = gid
        print json.dumps(imgdata)

    if 'children' in component:
        for child in component['children']:
            update_img(gid, child)

    print "<"

def update_app(app):
    aid = str(app.key().id())
    print 'App %s' % aid

    body = json.loads(app.body)

    gid = app.created_by.imagegroup_set.get().key().id()

    for screen in body["screens"]:
        update_img(gid, screen["rootComponent"])


    f = open(aid, 'w')
    json.dump(body, f)
    f.close()

    app.body = json.dumps(body)
    app.put()

def update_all():
    for app in App.all():
        update_app(app)

if __name__ == '__main__':
    update_all()
