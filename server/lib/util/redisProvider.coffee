redis = require 'redis'

# A middleware that provides a Redis connection for each request.
#
# The created instance of Redis is available as 'propName' property
# on the request:
#
#     app.use redisProvider('redis')
#
#     app.get '/', (req, res) ->
#       req.redis.incr 'requests', (err, value) ->
#         throw err if err
#         res.send "We've got #{value} visits!"
#
exports = module.exports = (propName = 'redis', configureClient = (->)) ->

  createConfiguredRedisClient = ->
    client = redis.createClient()
    configureClient client
    return client

  return (req, res, next) ->

    # Holds the created Redis instance
    client = null

    # obj.redis creates the redis client lazily
    Object.defineProperty req, propName, get: ->
        client ||= createConfiguredRedisClient()

    prevEnd = res.end
    res.end = (args...) ->
      if client
        client.end()
        client = null
      prevEnd(args...)

    next()
