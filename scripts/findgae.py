from os import environ, listdir
from os.path import dirname, realpath, join, exists
from sys import stderr, exit

def findgae():
    for d in environ['PATH'].split(':'):
        for f in listdir(d):
            if f == 'dev_appserver.py' or f == 'appcfg.py':
                if exists(join(d, f)):
                    return dirname(realpath(join(d, f)))
    stderr.write('Unable to find Google App Engine SDK')
    exit(1)
