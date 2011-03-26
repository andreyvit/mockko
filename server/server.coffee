
environment  = require './environment'

fs           = require 'fs'
sys          = require 'sys'
path         = require 'path'
assert       = require 'assert'
Step         = require 'step'
express      = require 'express'
fugue        = require 'fugue'
paperboy     = require 'paperboy'
io           = require 'socket.io'

app          = require('app')

process.on 'uncaughtException', (excp) ->
  console.log(excp)
  console.log(excp.message)
  console.log(excp.stack)

environment.init (err, env) ->
  if err
    console.log "Initialization failed: #{err}"
    console.log "#{err.message}"
    console.log "#{err.stack}"
  else
    app.set('redis', env.redis)
    app.listen(env.webPort)
    console.log "Listening on port #{env.webPort}."
