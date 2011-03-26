
require.paths.unshift __dirname + '/lib'
require.paths.unshift __dirname + '/vendor/mongoose'
require.paths.unshift __dirname + '/vendor/socket.io/lib'
require.paths.unshift __dirname

fs           = require 'fs'
path         = require 'path'
redis        = require 'redis'

Function::curry = (args...) ->
  return this if args.length < 1

  __method = this
  return (moreArgs...) ->
    return __method.apply(this, args.concat(moreArgs))


class Environment

  constructor: (config) ->
    @webPort = process.env['WEB_PORT'] || config.web_port || 3000
    @redisHost = process.env['REDIS_HOST'] || config.redis_host || undefined
    @redisPort = process.env['REDIS_PORT'] || config.redis_port || undefined

  init: (callback) ->
    @redis    = redis.createClient(@redisPort, @redisHost)
    @redisSub = redis.createClient(@redisPort, @redisHost)

    @redis.on 'error', (err) ->
      console.log "Redis error: #{err}"

    @redisSub.on 'error', (err) ->
      console.log "Redis error: #{err}"

    return callback(null)

exports.init = (callback) ->
  fs.readFile path.join(__dirname, "/config/app.json"), (err, configJSON) ->
    if err
      console.log "File config/app.json not found.  Try: `cp config/app.json.sample config/app.json`"
      return callback(err)

    config = JSON.parse(configJSON.toString());

    env = new Environment(config)
    env.init (err) ->
      return callback(err) if err
      return callback(null, env)
