# -*- coding: utf-8 -*-
"""
    tipfy
    ~~~~~

    Minimalist WSGI application and utilities.

    :copyright: 2010 by tipfy.org.
    :license: BSD, see LICENSE.txt for more details.
"""
import logging
import os
from wsgiref.handlers import CGIHandler

# Werkzeug swiss knife.
from werkzeug import Local, LocalManager, Request, Response, import_string, \
    escape, cached_property
from werkzeug.exceptions import HTTPException, BadRequest, Unauthorized, \
    Forbidden, NotFound, MethodNotAllowed, NotAcceptable, RequestTimeout, \
    Gone, LengthRequired, PreconditionFailed, RequestEntityTooLarge, \
    RequestURITooLarge, UnsupportedMediaType, InternalServerError, \
    NotImplemented, BadGateway, ServiceUnavailable
from werkzeug.routing import BaseConverter, EndpointPrefix, Map, \
    Rule as WerkzeugRule, RequestRedirect, RuleTemplate, Submount

# Variable store for a single request.
local = Local()
local_manager = LocalManager([local])

# Proxies to the three special variables set on each request.
local.app = local.request = local.response = None
app, request, response = local('app'), local('request'), local('response')

# Allowed request methods.
ALLOWED_METHODS = frozenset(['get', 'post', 'head', 'options', 'put', 'delete',
    'trace'])

# Value to be used for required configurations.
REQUIRED_CONFIG = []

#: Default configuration values for this module. Keys are:
#:   - ``sitename``: Name of the site, used by default in some places. Default
#:     set to `MyApp`.
#:   - ``admin_email``: Administrator e-mail. Default to `None`.
#:   - ``dev``: ``True`` is this is the development server, ``False`` otherwise.
#:     Default is the value of ``os.environ['SERVER_SOFTWARE']``.
#:   - ``app_id``: The application id. Default is the value of
#:     ``os.environ['APPLICATION_ID']``.
#:   - ``version_id``: The current deplyment version id. Default is the value
#:     of ``os.environ['CURRENT_VERSION_ID']``.
#:   - ``apps_installed``: A list of active app modules as a string. Default is
#:     an empty list
#:   - ``apps_entry_points``: URL entry points for the installed apps, in case
#:     their URLs are mounted using base paths.
#:   - ``extensions``: A list of extension modules as strings. A `setup()`
#:     function from each module is called when the WSGI application is
#:     initialized. Extensions can then setup app hooks or perform other
#:     initializations. See `Extensions` in the documentation for a
#:     complete explanation. Default is an empty list.
#:   - ``server_name``: A server name hint, used to calculate current subdomain.
#:     If you plan to use dynamic subdomains, you must define the main domain
#:     here so that the subdomain can be extracted and applied to URL rules..
#:   - ``subdomain``: Force this subdomain to be used instead of extracting
#:     the subdomain from the current url.
#:   - ``url_map``: A ``werkzeug.routing.Map`` with the URL rules defined for
#:     the application. If not set, build one with rules defined in ``urls.py``
#:   - ``wsgi_app_id``: An identifier for this WSGIApplication instance, in
#:     case multiple instances are being used by the same app. This is used
#:     to identify instance specific data such as cached URL rules. Default is
#:    ``main``.
default_config = {
    'sitename': 'MyApp',
    'admin_email': None,
    'dev': os.environ.get('SERVER_SOFTWARE', '').startswith('Dev'),
    'app_id': os.environ.get('APPLICATION_ID', None),
    'version_id': os.environ.get('CURRENT_VERSION_ID', '1'),
    'apps_installed': [],
    'apps_entry_points': {},
    'extensions': [],
    'server_name': None,
    'subdomain': None,
    'url_map': None,
    'wsgi_app_id': 'main',
    # Undocumented for now.
    'url_map_kwargs': {},
}


class RequestHandler(object):
    """Base request handler. Implements the minimal interface required by
    :class:`WSGIApplication`: the ``dispatch()`` method.
    """
    #: A list of classes or callables that return a middleware object. A
    #: middleware can implement two methods that are called before and after
    #: the current request method is executed in the handler:
    #: ``pre_dispatch(handler)`` and ``post_dispatch(handler, response)``.
    #: They are useful to initialize features and post-process the response in
    #: a per handler basis.
    middleware = []

    def dispatch(self, action, *args, **kwargs):
        """Executes a handler method. This method is called by the
        WSGIApplication and must always return a response object.

        :param action:
            The method to be executed.
        :param kwargs:
            The arguments from the matched route.
        :return:
            A ``werkzeug.Response`` object.
        """
        method = getattr(self, action, None)
        if method is None:
            raise MethodNotAllowed()

        if not self.middleware:
            # No middleware defined; simply execute the requested method.
            return method(*args, **kwargs)

        # Initialize every middleware.
        middleware = [m() for m in self.middleware]

        # Run pre_dispatch() hook on every middleware that implements it.
        for m in middleware:
            if getattr(m, 'pre_dispatch', None):
                response = m.pre_dispatch(self)
                if response is not None:
                    break
        else:
            # Execute the requested method.
            response = method(*args, **kwargs)

        # Run post_dispatch() hook on every middleware that implements it.
        for m in middleware:
            if getattr(m, 'post_dispatch', None):
                res = m.post_dispatch(self, response)
                if res is not None:
                    return res

        # Done!
        return response


class WSGIApplication(object):
    #: Default class for requests.
    request_class = Request
    #: Default class for responses.
    response_class = Response

    def __init__(self, config=None):
        """Initializes the application.

        :param config:
            Dictionary with configuration for the application modules.
        """
        # Set an accessor to this instance.
        local.app = self

        # Load default config and update with values for this instance.
        self.config = Config(config)
        self.config.setdefault(__name__, default_config)

        # Set the url rules.
        self.url_map = self.config.get(__name__, 'url_map')
        if not self.url_map:
            self.url_map = self.get_url_map()

        # Cache for loaded handler classes.
        self.handlers = {}

        # Set the hook handler.
        self.hooks = HookHandler()

        # Setup extensions.
        for module in self.config.get(__name__, 'extensions', []):
            import_string(module + ':setup')(self)

    def __call__(self, environ, start_response):
        """Called by WSGI when a request comes in."""
        # Apply pre-init-request hooks.
        for request in self.hooks.iter('pre_init_request', self, environ):
            if request is not None:
                break
        else:
            request = self.request_class(environ)

        # Set local variables for a single request.
        local.app = self
        local.request = request
        local.response = self.response_class()

        # Bind url map to the current request location.
        self.url_adapter = self.url_map.bind_to_environ(environ,
            server_name=self.config.get(__name__, 'server_name', None),
            subdomain=self.config.get(__name__, 'subdomain', None))

        self.rule = self.rule_args = None

        try:
            # Apply pre-match-url hooks.
            for res in self.hooks.iter('pre_match_url', self, request):
                if res is not None:
                    self.rule, self.rule_args = res
                    break
            else:
                # Check requested method.
                method = request.method.lower()
                if method not in ALLOWED_METHODS:
                    raise MethodNotAllowed()

                # Match the path against registered rules.
                self.rule, self.rule_args = self.url_adapter.match(request.path,
                    return_rule=True)

            # Apply pre-dispatch hooks.
            for response in self.hooks.iter('pre_dispatch_handler', self,
                request):
                if response is not None:
                    break
            else:
                # Import handler set in matched rule.
                if self.rule.handler not in self.handlers:
                    self.handlers[self.rule.handler] = import_string(
                        self.rule.handler)

                # Instantiate handler and dispatch request method.
                response = self.handlers[self.rule.handler]().dispatch(method,
                    **self.rule_args)

            # Apply post-dispatch hooks.
            for res in self.hooks.iter('post_dispatch_handler', self, request,
                response):
                if res is not None:
                    response = res
                    break

        except RequestRedirect, e:
            # Execute redirects raised by the routing system or the application.
            response = e
        except Exception, e:
            # Handle http and uncaught exceptions. This will apply exception
            # hooks if they are set.
            response = handle_exception(self, request, e)

        # Apply pre-end-request hooks.
        for r in self.hooks.iter('pre_end_request', self, request, response):
            if r is not None:
                response = r
                break

        # Call the response object as a WSGI application.
        return response(environ, start_response)

    def get_url_map(self):
        """Returns ``werkzeug.routing.Map`` with the URL rules defined for the
        application. Rules are cached in production; the cache is automatically
        renewed on each deployment.

        :return:
            A ``werkzeug.routing.Map`` instance.
        """
        from google.appengine.api import memcache
        config = self.config.get(__name__)
        key = 'wsgi_app.rules.%s.%s' % (config.get('wsgi_app_id'),
            config.get('version_id'))
        rules = memcache.get(key)
        if not rules or config.get('dev'):
            rules = import_string('urls:get_rules')()
            try:
                memcache.set(key, rules)
            except:
                logging.info('Failed to save wsgi_app.rules to memcache.')

        return Map(rules, **config.get('url_map_kwargs'))


class Config(dict):
    """A simple configuration dictionary keyed by module name. This is a
    dictionary of dictionaries. It requires all values to be dictionaries
    and applies updates and default values to the inner dictionaries instead of
    the first level one.
    """
    def __init__(self, value=None):
        if value is not None:
            assert isinstance(value, dict)
            for module in value.keys():
                self.update(module, value[module])

    def __setitem__(self, key, value):
        """Sets a configuration for a module, requiring it to be a dictionary.
        """
        assert isinstance(value, dict)
        super(Config, self).__setitem__(key, value)

    def update(self, module, value):
        """Updates the configuration dictionary for a module.

        >>> cfg = Config({'tipfy.ext.i18n': {'locale': 'pt_BR'})
        >>> cfg.get('tipfy.ext.i18n', 'locale')
        pt_BR
        >>> cfg.get('tipfy.ext.i18n', 'foo')
        None
        >>> cfg.update('tipfy.ext.i18n', {'locale': 'en_US', 'foo': 'bar'})
        >>> cfg.get('tipfy.ext.i18n', 'locale')
        en_US
        >>> cfg.get('tipfy.ext.i18n', 'foo')
        bar

        :param module:
            The module to update the configuration, e.g.: 'tipfy.ext.i18n'.
        :param value:
            A dictionary of configurations for the module.
        :return:
            None.
        """
        assert isinstance(value, dict)
        if module not in self:
            self[module] = {}

        self[module].update(value)

    def setdefault(self, module, value):
        """Sets a default configuration dictionary for a module.

        >>> cfg = Config({'tipfy.ext.i18n': {'locale': 'pt_BR'})
        >>> cfg.get('tipfy.ext.i18n', 'locale')
        pt_BR
        >>> cfg.get('tipfy.ext.i18n', 'foo')
        None
        >>> cfg.setdefault('tipfy.ext.i18n', {'locale': 'en_US', 'foo': 'bar'})
        >>> cfg.get('tipfy.ext.i18n', 'locale')
        pt_BR
        >>> cfg.get('tipfy.ext.i18n', 'foo')
        bar

        :param module:
            The module to set default configuration, e.g.: 'tipfy.ext.i18n'.
        :param value:
            A dictionary of configurations for the module.
        :return:
            None.
        """
        assert isinstance(value, dict)
        if module not in self:
            self[module] = {}

        for key in value.keys():
            self[module].setdefault(key, value[key])

    def get(self, module, key=None, default=None):
        """Returns a configuration value for given key in a given module.

        >>> cfg = Config({'tipfy.ext.i18n': {'locale': 'pt_BR'})
        >>> cfg.get('tipfy.ext.i18n')
        {'locale': 'pt_BR'}
        >>> cfg.get('tipfy.ext.i18n', 'locale')
        pt_BR
        >>> cfg.get('tipfy.ext.i18n', 'invalid-key')
        None
        >>> cfg.get('tipfy.ext.i18n', 'invalid-key', 'default-value')
        default-value

        :param module:
            The module to get a configuration from, e.g.: 'tipfy.ext.i18n'.
        :param key:
            The key from the module configuration.
        :param default:
            A default value to return in case the configuration for the
            module/key is not set.
        :return:
            The configuration value.
        """
        if module not in self:
            return default

        if key is None:
            return self[module]
        elif key not in self[module]:
            return default

        return self[module][key]


class LazyCallable(object):
    """A lazy callable used by :class:`HookHandler`: hooks are set as a string
    and only imported when used.
    """
    def __init__(self, hook_spec):
        """Builds the lazy callable.

        :param hook_spec:
            The callable that will handle the event, as a string. It will be
            imported only when the callable is used.
        """
        self.hook_spec = hook_spec
        self.hook = None

    def __call__(self, *args, **kwargs):
        """Executes the event callable, importing it if it is not imported yet.

        :param args:
            Positional arguments to be passed to the callable.
        :param kwargs:
            Keyword arguments to be passed to the callable.
        :return:
            The value returned by the callable.
        """
        if self.hook is None:
            self.hook = import_string(self.hook_spec)

        return self.hook(*args, **kwargs)


class HookHandler(object):
    def __init__(self, hooks=None):
        """Initializes the application hook handler.

        :param hooks:
            A dictionary with event names as keys and a list of hook specs
            as values.
        """
        self.hooks = hooks or {}

    def add(self, name, hook, pos=None):
        """Adds a hook to a given application event.

        :param name:
            The event name to be added (a string).
        :param hook:
            The callable that is executed when the event occurs. Can be either
            a callable or a string to be lazily imported.
        :param pos:
            Position to insert the hook in the hook list. If not set, the hook
            is appended to the list.
        :return:
            ``None``.
        """
        if not callable(hook):
            hook = LazyCallable(hook)

        event = self.hooks.setdefault(name, [])
        if pos is None:
            event.append(hook)
        else:
            event.insert(pos, hook)

    def add_multi(self, spec):
        """Adds multiple hook to multiple application events.

        :param spec:
            A dictionary with event names as keys and a list of hooks as values.
            Hooks can be a callable or a string to be lazily imported.
        :return:
            ``None``.
        """
        for name in spec.keys():
            for hook in spec[name]:
                self.add(name, hook)

    def iter(self, name, *args, **kwargs):
        """Call all hooks for a given application event. This is a generator.

        :param name:
            The event name (a string).
        :param args:
            Positional arguments to be passed to the subscribers.
        :param kwargs:
            Keyword arguments to be passed to the subscribers.
        :yield:
            The result of the hook calls.
        """
        for hook in self.hooks.get(name, []):
            yield hook(*args, **kwargs)

    def call(self, name, *args, **kwargs):
        """Call all hooks for a given application event. This uses :meth:`iter`
        and returns a list with all results.

        :param name:
            The event name (a string).
        :param args:
            Positional arguments to be passed to the hooks.
        :param kwargs:
            Keyword arguments to be passed to the hooks.
        :return:
            A list with all results from the hook calls.
        """
        return [res for res in self.iter(name, *args, **kwargs)]

    def get(self, name, default=None):
        """Returns the list of hooks added to a given event.

        :param name:
            The event name to get related hooks.
        :param default:
            The default value to return in case the event doesn't have hooks.
        :return:
            A list of hooks.
        """
        return self.hooks.get(name, default)


class Rule(WerkzeugRule):
    """Extends Werkzeug routing to support a handler definition for each Rule.
    Handler is a :class:`RequestHandler` module and class specification, and
    endpoint is a friendly name used to build URL's. For example:

    .. code-block:: python

       Rule('/users', endpoint='user-list', handler='my_app:UsersHandler')

    Access to the URL ``/users`` loads ``UsersHandler`` class from ``my_app``
    module. To generate an URL to that page, use :func:`url_for`:

    .. code-block:: python

       url = url_for('user-list')

    """
    def __init__(self, *args, **kwargs):
        self.handler = kwargs.pop('handler', kwargs.get('endpoint', None))
        WerkzeugRule.__init__(self, *args, **kwargs)

    def empty(self):
        """Returns an unbound copy of this rule. This can be useful if you
        want to reuse an already bound URL for another map.
        """
        defaults = None
        if self.defaults is not None:
            defaults = dict(self.defaults)
        return Rule(self.rule, defaults, self.subdomain, self.methods,
                    self.build_only, self.endpoint, self.strict_slashes,
                    self.redirect_to, handler=self.handler)


# Extra URL rule converter from
# http://groups.google.com/group/pocoo-libs/browse_thread/thread/ff5a3fddee12a955/
class RegexConverter(BaseConverter):
    """Matches a regular expression::

       Rule('/<regex(".*$"):name>')
    """
    def __init__(self, map, *items):
        BaseConverter.__init__(self, map)
        self.regex = items[0]
Map.default_converters = dict(Map.default_converters)
Map.default_converters['regex'] = RegexConverter


class PatchedCGIHandler(CGIHandler):
    """``wsgiref.handlers.CGIHandler`` holds ``os.environ`` when imported. This
    class overrides this behaviour. Thanks to Kay framework for this patch.
    """
    def __init__(self):
        self.os_environ = {}
        CGIHandler.__init__(self)


def make_wsgi_app(config):
    """Returns a instance of :class:`WSGIApplication`.

    :param config:
        A dictionary of configuration values.
    :return:
        A :class:`WSGIApplication` instance.
    """
    return WSGIApplication(config)


def run_wsgi_app(app):
    """Executes the application, optionally wrapping it by hooks.

    :param app:
        A :class:`WSGIApplication` instance.
    :return:
        ``None``.
    """
    # Fix issue #772.
    if app.config.get(__name__, 'dev'):
        fix_sys_path()

    # Apply pre-run hooks.
    for res in app.hooks.iter('pre_run_app', app):
        if res is not None:
            app = res

    # Wrap app by local_manager so that local is cleaned after each request.
    PatchedCGIHandler().run(local_manager.make_middleware(app))


def handle_exception(app, request, e):
    """Handles HTTPException or uncaught exceptions raised by the WSGI
    application, optionally applying exception hooks.

    :param app:
        The :class:`WSGIApplication` instance.
    :param e:
        The catched exception.
    :return:
        A ``werkzeug.Response`` object, if the exception is not raised.
    """
    for response in app.hooks.iter('pre_handle_exception', app, request, e):
        if response:
            return response

    if app.config.get(__name__, 'dev'):
        raise

    logging.exception(e)

    if isinstance(e, HTTPException):
        return e

    return InternalServerError()


def url_for(endpoint, full=False, method=None, **kwargs):
    """Builds and returns an URL for a named :class:`Rule`.

    :param endpoint:
        The rule endpoint.
    :param full:
        If True, builds an absolute URL. Otherwise, builds a relative one.
    :param method:
        The rule request method, in case there are different rules
        for different request methods.
    :param kwargs:
        Keyword arguments to build the URL.
    :return:
        An absolute or relative URL.
    """
    return local.app.url_adapter.build(endpoint, force_external=full,
        method=method, values=kwargs)


def redirect(location, code=302):
    """Return a response object (a WSGI application) that, if called,
    redirects the client to the target location.  Supported codes are 301,
    302, 303, 305, and 307.  300 is not supported because it's not a real
    redirect and 304 because it's the answer for a request with a request
    with defined If-Modified-Since headers.

    :param location:
        The location the response should redirect to.
    :param code:
        The redirect status code.
    :return:
        A ``werkzeug.Response`` object with headers set for redirection.
    """
    response = getattr(local, 'response', None)
    if response is None:
        response = Response()

    assert code in (301, 302, 303, 305, 307), 'invalid code'
    response.data = \
        '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">\n' \
        '<title>Redirecting...</title>\n' \
        '<h1>Redirecting...</h1>\n' \
        '<p>You should be redirected automatically to target URL: ' \
        '<a href="%s">%s</a>.  If not click the link.' % \
        ((escape(location),) * 2)
    response.status_code = code
    response.headers['Location'] = location
    return response


def redirect_to(endpoint, method=None, code=302, **kwargs):
    """Convenience function mixing :func:`redirect` and :func:`url_for`:
    redirects the client to a URL built using a named :class:`Rule`.

    :param endpoint:
        The rule endpoint.
    :param method:
        The rule request method, in case there are different rules
        for different request methods.
    :param code:
        The redirect status code.
    :param kwargs:
        Keyword arguments to build the URL.
    :return:
        A ``werkzeug.Response`` object with headers set for redirection.
    """
    return redirect(url_for(endpoint, full=True, method=method, **kwargs),
        code=code)


def render_json_response(obj):
    """Renders a JSON response, automatically encoding `obj` to JSON.

    :param obj:
        An object to be serialized to JSON, normally a dictionary.
    :return:
        A ``werkzeug.Response`` object with `obj` converted to JSON in the body
        and mimetype set to ``application/json``.
    """
    response = getattr(local, 'response', None)
    if response is None:
        response = Response()

    from django.utils import simplejson
    response.data = simplejson.dumps(obj)
    response.mimetype = 'application/json'
    return response


_DEFAULT_CONFIG = []
def get_config(module, key=None, default=_DEFAULT_CONFIG):
    """Returns a configuration value for a module. If it is not already set,
    it will load a ``default_config`` variable from the given module, update the
    app config with those default values and return the value for the given key.
    If the key is still not available, it'll return the given default value.

    If a default value is not provided, the configuration is considered
    required and an exception is raised if it is not set.

    Every `Tipfy`_ module that allows some kind of configuration sets a
    ``default_config`` global variable that is loaded by this function, cached
    and used in case the requested configuration was not defined by the user.

    :param module:
        The configured module.
    :param key:
        The config key.
    :param default:
        The default value to be returned in case the key is not set.
    :return:
        A configuration value.
    """
    value = local.app.config.get(module, key, default)
    if value is REQUIRED_CONFIG:
        raise ValueError('Module %s requires the config key "%s" to be set.' %
            (module, key))
    elif value is _DEFAULT_CONFIG:
        # Update app config. If import fails or the default_config attribute
        # doesn't exist, an exception will be raised.
        local.app.config.setdefault(module, import_string(module +
            ':default_config'))
        return get_config(module, key, REQUIRED_CONFIG)

    return value


def normalize_callable(spec):
    """Many `Tipfy`_ configurations expect a callable or optionally a string
    with a callable definition to be lazily imported. This function normalizes
    those definitions, importing the callable if necessary.

    :param spec:
        A callable or a string with a callable definition to be imported.
    :return:
        A callable.
    """
    if isinstance(spec, basestring):
        spec = import_string(spec)

    if not callable(spec):
        raise ValueError('%s is not a callable.' % str(spec))

    return spec


ultimate_sys_path = None
def fix_sys_path():
    """A fix for issue 772. We must keep this here until it is fixed in the dev
    server.

    See: http://code.google.com/p/googleappengine/issues/detail?id=772
    """
    global ultimate_sys_path
    import sys
    if ultimate_sys_path is None:
        ultimate_sys_path = list(sys.path)
    else:
        if sys.path != ultimate_sys_path:
            sys.path[:] = ultimate_sys_path


# Old imports.