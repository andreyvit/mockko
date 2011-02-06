querystring = require 'querystring'
http        = require 'http'

exports.createClient = (host, apikey) ->

  [host, port] = host.split(':')
  port ||= 80

  request = (kind, action, params, callback) ->
    options =
      host: host
      port: port
      path: "/rest/#{apikey}/#{kind}/#{action}?#{querystring.stringify(params)}"

    req = http.get options, (res) ->
      if res.statusCode != 200
        return callback(new Error("Server returned code #{res.statusCode}"))

      res.setEncoding 'utf8'

      body = ''
      res.on 'data', (chunk) ->
        body += chunk
      res.on 'end', ->
        callback(null, JSON.parse(body))

    req.on 'error', (err) ->
      callback(err)

  query: (kind,       params, callback) -> request(kind, '', params, callback)
  get:   (kind, attr, params, callback) -> request(kind, attr, params, callback)

