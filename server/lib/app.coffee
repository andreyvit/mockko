
fs           = require 'fs'
sys          = require 'sys'
path         = require 'path'
assert       = require 'assert'
Step         = require 'step'
express      = require 'express'
fugue        = require 'fugue'
paperboy     = require 'paperboy'
io           = require 'socket.io'

{ puts } = require 'sys'

# db = new mongodb.Db 'mockko', new mongodb.Server(config.mongodb_host, config.mongodb_port, {}), {}
app = exports.app = express.createServer()

configureRedisClient = (redis) ->
  redis.on 'error', (err) ->
    console.log "Redis error: #{err}"

subdomainHandler = ->

  return (req, res, next) ->
    return next() unless req.headers.host

    host = req.headers.host.split(':')[0]
    if host.match /^www\.|^mockko\./
      req.url = "/www#{req.url}"
      req.subdomain = 'www'
    else
      req.subdomain = host.split('.')[0]

    next()

app.configure ->
  app.use express.logger(format: ':method :url')
  app.use express.methodOverride()
  app.use express.bodyDecoder()
  app.use require('util/redisProvider')('redis', configureRedisClient)
  app.use subdomainHandler()
  app.use app.router
  app.use express.staticProvider(__dirname + '/public')
  app.set 'view engine', 'jade'

app.configure 'development', ->
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))

app.configure 'production', ->
  app.use(express.errorHandler())

socket = io.listen(app)

PROJECT_ROOT = path.dirname(__filename)
MOCKUPS_ROOT = path.join(path.dirname(__filename), 'mockups')

_users = null
_apps  = null

_buffer = []

log = (statCode, url, ip, err) ->
  sys.log "#{statCode} - #{url} - #{ip} - #{err || 'ok'}"
#
# function loadUser(req, res, next) {
#     // You would fetch your user from the db
#     var user = users[req.params.id];
#     if (user) {
#         req.user = user;
#         next();
#     } else {
#         next(new Error('Failed to load user ' + req.params.id));
#     }
# }

authenticate = (req, res, next) ->
  puts "authenticate() got a request, subdomain == #{req.subdomain}"
  if req.subdomain == 'www'
    next()
  else
    puts "asking Redis"
    r = req.redis
    console.log "1, r.get = #{r.get}"
    r.get "acc:subdomain:#{req.subdomain}", (err, accountId) ->
      puts "returned from Redis"
      return next(err) if err

      if accountId
        req.accountId = accountId
        next()
      else
        res.send "Sorry, this account does not exist.", 404

app.get '/www/', authenticate, (req, res) ->
  res.send "Hello!"
  # res.render 'index'
  #   locals:
  #     title: "Foo"
  # _users.insert { created: +new Date() }, ->
  #   res.render 'index'
  #     locals:
  #       title: "Foo"

app.get '/', authenticate, (req, res) ->
  _users.insert { created: +new Date() }, ->
    res.render 'index'
      locals:
        title: "Foo"

app.get '/users/:id', (req, res) ->
  res.send "user id xx #{req.params.id}"

app.get '/mockups/*', (req, res) ->
  req.url = req.url.replace('/mockups', '')
  paperboy
    .deliver(MOCKUPS_ROOT, req, res)
    .before ->
      sys.log "Received Request"
    .after (statCode) ->
      log statCode, req.url, req.ip
    .error (statCode, msg) ->
      res.writeHead statCode, 'Content-Type': 'text/plain'
      res.end "Error: #{statCode}"
      log statCode, req.url, req.ip, msg
    .otherwise (err) ->
      res.writeHead 404, 'Content-Type': 'text/plain'
      res.end "Error 404: File not found"
      log 404, req.url, req.ip, err

socket.on 'connection', (client) ->
  puts "WebSocket #{client.sessionId} connected"
  client.send buffer: _buffer
  client.broadcast announcement: client.sessionId + ' connected'

  client.on 'message', (message) ->
    puts "WebSocket #{client.sessionId} message"
    msg = message: [client.sessionId, message]
    _buffer.push msg
    if _buffer.length > 15
      _buffer.shift()
    client.broadcast msg

  client.on 'disconnect', ->
    puts "WebSocket #{client.sessionId} disconnected"
    client.broadcast announcement: client.sessionId + ' disconnected'
