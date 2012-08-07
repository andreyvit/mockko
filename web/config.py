# -*- coding: utf-8 -*-
"""
    config
    ~~~~~~

    Configuration settings.

    :copyright: 2009 by tipfy.org.
    :license: BSD, see LICENSE for more details.
"""
config = {}

# Configurations for the 'tipfy' module.
config['tipfy'] = {
    'apps_installed': [
        'makeapp',
    ],
    'extensions': [
        'tipfy.ext.debugger',
        'tipfy.ext.i18n',
        # 'tipfy.ext.user',
    ],
    # 'server_name': ('make-app.local:8888' if os.environ.get('SERVER_SOFTWARE', '').startswith('Dev') else 'make-app.com'),
    # 'url_map_kwargs': { 'default_subdomain': 'www'},
}

config['tipfy.ext.auth'] = {
    'user_model': 'models:Account',
}

config['tipfy.ext.i18n'] = {
    'locale_request_lookup': [('cookies', 'tipfy.locale')],
}
