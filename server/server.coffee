
require.paths.unshift __dirname + '/lib'
require.paths.unshift __dirname + '/vendor/mongoose'
require.paths.unshift __dirname + '/vendor/socket.io/lib'
require.paths.unshift __dirname

process.on 'uncaughtException', (excp) ->
  console.log(excp)
  console.log(excp.message)
  console.log(excp.stack)

fs           = require 'fs'
sys          = require 'sys'
path         = require 'path'
assert       = require 'assert'
Step         = require 'step'
express      = require 'express'
fugue        = require 'fugue'
paperboy     = require 'paperboy'
io           = require 'socket.io'

app = require 'app'

{ puts } = require 'sys'

config =
  # mongodb_host: process.env['MONGO_NODE_DRIVER_HOST'] || 'localhost'
  # mongodb_port: process.env['MONGO_NODE_DRIVER_PORT'] || mongodb.Connection.DEFAULT_PORT
  web_port:     process.env['WEB_PORT'] || 3000

puts "Listening on port #{config.web_port}."
app.listen(config.web_port)
  # fugue.start(app, config.web_port, null, 2, {verbose : true})
