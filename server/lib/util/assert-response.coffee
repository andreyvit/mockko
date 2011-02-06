
assert = require 'assert'
http   = require 'http'

nextServerPort = 5555  # for test servers

# assert.response ported from expresso
exports.assertResponse = assertResponse = (server, options) ->
  { url, method, data, headers, timeout,
    status, body, resheaders, callback, message } = options

  # Check that the server is ready or defer
  unless server.fd
    server.__deferred = [] unless '__deferred' of server
    server.__deferred.push [server, options]

    unless server.__started
      server.__port = (nextServerPort += 1)
      server.listen server.__port, '127.0.0.1', ->
        if server.__deferred
          process.nextTick ->
            assertResponse.apply(null, args) for args in server.__deferred
      server.__started = true;
    return

  # defaults
  callback ||= (->)
  message    = if message then "#{message}. " else message
  method   ||= 'GET'
  timeout  ||= 0
  headers  ||= {}

  server.__pending = (server.__pending || 0) + 1

  client = (server.client ||= http.createClient(server.__port))

  request = client.request method, url, headers

  if timeout
    timer = setTimeout(->
      server.close() if (server.__pending -= 1) == 0
      assert.fail "#{message}Request timed out after #{requestTimeout} ms."
    , timeout)

  request.write data if data

  request.addListener 'response', (response) ->
    response.body = ''
    response.setEncoding 'utf8'
    response.addListener 'data', (chunk) -> response.body += chunk

    response.addListener 'end', ->
      server.close() if (server.__pending -= 1) == 0
      clearTimeout(timer) if timer

      if body?
          ok = (if body instanceof RegExp then body.test(response.body) else body == response.body)
          assert.ok ok, """
                        #{message}Invalid response body.
                            Expected: #{sys.inspect(res.body)}
                            Got: #{sys.inspect(response.body)}
                        """

      if status?
        assert.equal response.statusCode, status,
          """
          #{message}Invalid response status code.
              Expected: #{status}
              Got: #{response.statusCode}
          """

      if resheaders
        for name, expected of resheaders
          actual = response.headers[name.toLowerCase()]
          eql = (if expected instanceof RegExp then expected.test(actual) else expected == actual)
          assert.ok eql,  """
                          #{message}Invalid response header #{name}.
                              Expected: #{sys.inspect(expected)}
                              Got: #{sys.inspect(actual)}
                          """
      callback response

  request.end()
