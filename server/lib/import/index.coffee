
async = require 'util/async'
model = require 'model/model'

client = require('./appengine-rest-client').createClient("andreyvit-playground.mockkodesigner.appspot.com", 'bcbpaddbnoedmqqazw')

Account = model.defineModel('Account', prefix: 'acc')
  .property('oldKey', unique: yes)
  .property('email', unique: yes)
  .property('fullName')
  .property('created')
  .property('updated')
  .property('newsletter')
  .property('profileCreated')

App = model.defineModel('App', prefix: 'a')
  .property('oldKey', unique: yes)
  .property('name')
  .property('creator')  # id
  .property('created')
  .property('updated')
  .property('body', standalone: yes, storage: model.storage.stringValue)

ImageGroup = model.defineModel('ImageGroup', prefix: 'ig')
  .property('oldKey', unique: yes)
  .property('name')
  .property('priority')
  .property('owner')

Image = model.defineModel('Image', prefix: 'i')
  .property('oldKey', unique: yes)
  .property('account')
  .property('group')
  .property('priority')
  .property('file_name')
  .property('created')
  .property('updated')
  .property('width')
  .property('height')
  .property('mime_type')
  .property('digest')

importAccount = (redis, old, callback) ->
  Account.byOldKey redis, old._key, (err, instance) ->
    return callback(err) if err

    instance = new Account { oldKey: old._key } unless instance?

    instance.email           = old.email
    instance.fullName        = old.full_name
    instance.newsletter      = old.newsletter
    instance.profileCreated  = old.profile_created
    instance.created         = old.created_at
    instance.updated         = old.updated_at

    instance.save redis, callback

importApp = (redis, old, callback) ->
  App.byOldKey redis, old._key, (err, instance) ->
    return callback(err) if err

    Account.byOldKey redis, old.created_by, (err, ownerAccount) ->
      return callback(err) if err

      instance = new App { oldKey: old._key } unless instance?

      instance.name    = old.name
      instance.creator = ownerAccount?.id
      instance.created = old.created_at
      instance.updated = old.updated_at
      instance.body    = old.body

      instance.save redis, ['body'], callback

importImageGroup = (redis, old, callback) ->
  ImageGroup.byOldKey redis, old._key, (err, instance) ->
    return callback(err) if err

    Account.byOldKey redis, old.owner, (err, ownerAccount) ->
      return callback(err) if err

      instance = new ImageGroup { oldKey: old._key } unless instance?

      instance.name     = old.name
      instance.owner    = ownerAccount?.id
      instance.priority = old.priority

      instance.save redis, [], callback

importImage = (redis, old, callback) ->
  Image.byOldKey redis, old._key, (err, instance) ->
    return callback(err) if err

    Account.byOldKey redis, old.account, (err, ownerAccount) ->
      return callback(err) if err

      ImageGroup.byOldKey redis, old.group, (err, group) ->
        return callback(err) if err

        instance = new Image { oldKey: old._key } unless instance?

        instance.owner    = ownerAccount?.id
        instance.group    = group?.id
        instance.created  = old.created_at
        instance.updated  = old.updated_at

        for key in ['priority', 'file_name', 'width', 'height', 'mime_type', 'digest']
          instance[key] = old[key]

        instance.save redis, [], callback

importItems = (redis, kind, func, callback) ->
  console.log "Loading #{kind}s from App Engine..."
  client.query kind, { _limit: 10000 }, (err, items) ->
    return callback(err) if err
    console.log "Number of #{kind}s: #{items.length}"

    async.map items,
      each: (item, cb) -> func(redis, item, cb)
      then: (err) ->
        return callback(err) if err
        callback(null)

exports.import = (redis, callback) ->
  importItems redis, 'Account', importAccount, (err) ->
    return callback(err) if err

    importItems redis, 'App', importApp, (err) ->
      return callback(err) if err

      importItems redis, 'ImageGroup', importImageGroup, (err) ->
        return callback(err) if err

        importItems redis, 'Image', importImage, (err) ->
          return callback(err) if err

          callback(null)
