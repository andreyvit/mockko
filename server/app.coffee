
require.paths.unshift __dirname + '/lib'
require.paths.unshift __dirname + '/vendor/mongoose'
require.paths.unshift __dirname + '/vendor/socket.io/lib'
require.paths.unshift __dirname

process.on 'uncaughtException', (excp) ->
  console.log(excp.message)
  console.log(excp.stack)

{ puts } = require 'sys'

fs           = require 'fs'
assert       = require 'assert'
Step         = require 'step'
express      = require 'express'
fugue        = require 'fugue'
mongodb      = require 'mongodb'
io           = require 'socket.io'
{ Mongoose } = require 'mongoose'

config =
    mongodb_host: process.env['MONGO_NODE_DRIVER_HOST'] || 'localhost'
    mongodb_port: process.env['MONGO_NODE_DRIVER_PORT'] || mongodb.Connection.DEFAULT_PORT
    web_port:     process.env['WEB_PORT'] || 3000

db = new mongodb.Db 'mockko', new mongodb.Server(config.mongodb_host, config.mongodb_port, {}), {}
app = express.createServer()

app.configure ->
    app.use express.logger(format: ':method :url')
    app.use express.methodOverride()
    app.use express.bodyDecoder()
    app.use app.router
    app.use express.staticProvider(__dirname + '/public')
    app.set 'view engine', 'jade'

app.configure 'development', ->
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))

app.configure 'production', ->
    app.use(express.errorHandler())

socket = io.listen(app)

newMockko = (db, app, socket) ->

    _users = null
    _apps  = null

    _buffer = []

    # private methods

    setupRoutes = ->

        app.get '/', (req, res) ->
            _users.insert { created: +new Date() }, ->
                res.render 'index'
                    locals:
                        title: "Foo"

        app.get '/users/:id', (req, res) ->
            res.send "user id xx #{req.params.id}"

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

    # initialization

    setupRoutes()

    # public methods

    initialize: (callback) ->
        Step(
            ->
                db.createCollection 'users', this.parallel()
                db.createCollection 'apps', this.parallel()
            (err) ->
                db.collection 'users', this.parallel()
                db.collection 'apps',  this.parallel()
            (err, users, apps) ->
                _users = users
                _apps  = apps
                callback()
        )

mockko = newMockko(db, app, socket)

db.open ->
    mockko.initialize ->
        puts "Listening on port #{config.web_port}."
        app.listen(config.web_port)
        # fugue.start(app, config.web_port, null, 2, {verbose : true})
