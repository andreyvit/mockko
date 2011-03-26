#! /usr/bin/env coffee

environment = require('../environment')

async = require('util/async')

K =
  account:
    body: (id) -> "acc::#{id}"
    by: (prop, value) -> "acc:#{prop}:#{value}"

upgradeAccount = (env, account, callback) ->
  email = account.email
  email = email.replace(/^me@/, '')
  email = email.replace(/@.*$/, '') if email.replace(/@.*$/, '').length >= 6
  subdomain = email.replace(/[^a-zA-Z0-9]+/g, '-')
  console.log "#{account.email} -> #{subdomain}"

  [prevSubdomain, account.subdomain] = [account.subdomain, subdomain]

  multi = env.redis.multi()
  multi.del K.account.by('subdomain', prevSubdomain) if prevSubdomain
  multi.set K.account.by('subdomain', account.subdomain), account.id if account.subdomain
  multi.set K.account.body(account.id), JSON.stringify(account)
  multi.exec (err, replies) ->
    return callback(err) if err
    return callback(null)

upgradeAccountJSON = (env, accountJSON, callback) ->
  account = JSON.parse(accountJSON)

  if account.email
    return upgradeAccount(env, account, callback)
  else
    console.log "Account #{account.id} (#{account.oldKey}) has no email."
    return callback(null)

fillInSubdomains = (env, callback) ->
  env.redis.keys 'acc::*', (err, keys) ->
    return callback(err) if err
    env.redis.mget keys, (err, values) ->
      async.map values,
        each: upgradeAccountJSON.curry(env)
        then: callback

environment.init (err, env) ->
  throw err if err
  fillInSubdomains env, (err) ->
    throw err if err

    console.log "OK"
