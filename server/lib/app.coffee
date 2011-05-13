
fs           = require 'fs'
sys          = require 'sys'
path         = require 'path'
assert       = require 'assert'
Step         = require 'step'
express      = require 'express'
fugue        = require 'fugue'
paperboy     = require 'paperboy'
io           = require 'socket.io'
async        = require 'util/async'

{ inspect }  = require 'util'

# db = new mongodb.Db 'mockko', new mongodb.Server(config.mongodb_host, config.mongodb_port, {}), {}
app = module.exports = express.createServer()

subdomainHandler = (staticDir) ->
  staticItems = fs.readdirSync(staticDir)

  return (req, res, next) ->
    return next() unless req.headers.host

    host = req.headers.host.split(':')[0]
    first = req.url.split('/')[1]
    console.log "req.url == '#{req.url}'"
    console.log "first == '#{first}'"
    console.log "first in staticItems == #{first in staticItems}"
    if host.match(/^www\.|^mockko\./) && !(first in staticItems)
      req.url = "/www#{req.url}"
      req.subdomain = 'www'
    else
      req.subdomain = host.split('.')[0]
    console.log "req.url == '#{req.url}'"

    next()

redisProvider = (req, res, next) ->
  req.redis = app.set('redis')
  next()

app.configure ->
  app.use express.logger(format: ':method :url')
  app.use express.methodOverride()
  app.use express.bodyParser()
  app.use subdomainHandler(__dirname + '/../public')
  app.use redisProvider
  app.use express.static(__dirname + '/../public')
  app.use app.router
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
  console.log "authenticate() got a request, subdomain == #{req.subdomain}"
  if req.subdomain == 'www'
    next()
  else
    redis = req.redis
    redis.get "acc:subdomain:#{req.subdomain}", (err, accountId) ->
      console.log "returned from Redis"
      return next(err) if err

      if accountId
        redis.get "acc::#{accountId}", (err, accountJSON) ->
          return next(err) if err
          return next(new Error("Account not found for ID #{accountId}")) unless accountJSON

          req.account = JSON.parse(accountJSON)
          next()
      else
        res.send "Sorry, account '#{req.subdomain}' does not exist.", 404

app.get '/www/', (req, res) ->
  res.render 'marketing-index',
    layout: 'marketing'

app.get '/', authenticate, (req, res) ->
  res.render 'designer', layout: false
  # res.send "Hello, #{req.account.fullName} &lt;#{req.account.email}&gt;!"

app.get '/user/', authenticate, (req, res) ->
  res.sendJSON
    'logout_url':      '/'  # FIXME: users.create_logout_url(url_for('home'))
    'profile-created': req.account.profileCreated
    'newsletter':      req.account.newsletter
    'full-name':       req.account.fullName

app.post '/user/', authenticate, (req, res) ->
  res.redirect "/"

app.get '/apps/', authenticate, (req, res, next) ->
  req.redis.keys "a::*", (err, keys) ->
    return next(err) if err

    async.map keys,
      each: (key, callback) ->
        return callback(null) if key.match(/:body$/)
        req.redis.get key, (err, appJSON) ->
          return callback(err) if err

          console.log "appJSON = #{inspect(appJSON)}"
          a = JSON.parse(appJSON)
          console.log "app = #{inspect(a)}"
          callback(null, a)

      then: (err, apps) ->
        return next(err) if err

        apps = (a for a in apps when a)
        console.log "apps = #{inspect(apps.slice(0, 10))}"

        result = {}
        results = []
        for creator, appsForCreator of apps.groupBy('creator')
          continue if !creator
          r = result[creator] =
            apps: appsForCreator
            creator: creator
            # 'full_name': acc.full_name or '',
            # 'email': acc.user.email(),
            # 'created_at': time.mktime(acc.created_at.timetuple()),
          results.push r
          break

        console.log "results = #{inspect(results)}"

        async.map results,
          each: (r, callback) ->
            console.log "creator = #{r.creator}"
            req.redis.get "acc::#{r.creator}", (err, accountJSON) ->
              return callback(err) if err
              console.log "creator = #{r.creator}"
              console.log "json = #{accountJSON}"
              account = JSON.parse(accountJSON)
              console.log "account = #{account}"

              r.full_name  = account.fullName
              r.email      = account.email
              r.created_at = account.created

              callback(null)

          then: (err) ->
            return next(err) if err

            res.sendJSON result

app.get /\/R(\d+)/, authenticate, (req, res) ->
  res.send "run app #{req.params[0]}"

app.post '/apps/:app_id', authenticate, (req, res) ->
  res.send "saved app #{req.params.app_id}"

app.del '/apps/:app_id', authenticate, (req, res) ->
  res.send "deleted app #{req.params.app_id}"

# get all groups
app.get '/images/', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# get group
app.get '/images/:group_id', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# save image
app.post '/images/:group_id', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# get image
app.get '/images/:group_id/:image_name', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# delete image
app.del '/images/:group_id/:image_name', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# statistics
app.get '/status/', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

# more statistics
app.get '/stats/apps.xml', authenticate, (req, res) ->
  res.send "[1, 2, 3]"

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
  console.log "WebSocket #{client.sessionId} connected"
  client.send buffer: _buffer
  client.broadcast announcement: client.sessionId + ' connected'

  client.on 'message', (message) ->
    console.log "WebSocket #{client.sessionId} message"
    msg = message: [client.sessionId, message]
    _buffer.push msg
    if _buffer.length > 15
      _buffer.shift()
    client.broadcast msg

  client.on 'disconnect', ->
    console.log "WebSocket #{client.sessionId} disconnected"
    client.broadcast announcement: client.sessionId + ' disconnected'
