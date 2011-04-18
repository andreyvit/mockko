
async = require 'util/async'

capitalize = (str) -> str.substr(0, 1).toUpperCase() + str.substr(1)

storage = exports.storage =
  jsonMap:
    load: (key, properties, db, callback) ->
      db.get key, (err, value) =>
        return callback(err) if err
        return callback(null, null) if value == null
        callback null, JSON.parse(value)

    save: (key, properties, attributes, db, multi, callback) ->
      multi.set key, JSON.stringify(attributes)
      callback(null)

  jsonValue:
    load: (key, properties, db, callback) ->
      db.get key, (err, value) =>
        return callback(err) if err

        obj = {}
        obj[properties[0].key] = (if value then JSON.parse(value) else undefined)

        callback null, obj

    save: (key, properties, attributes, db, multi, callback) ->
      multi.set key, JSON.stringify(attributes[properties[0].key])
      callback(null)

  stringValue:
    load: (key, properties, db, callback) ->
      db.get key, (err, value) =>
        return callback(err) if err

        obj = {}
        obj[properties[0].key] = value

        callback null, obj

    save: (key, properties, attributes, db, multi, callback) ->
      value = attributes[properties[0].key]
      if value
        multi.set key, value
      else
        multi.del key
      callback(null)

class Property

  constructor: (@key, options) ->
    @unique = options.unique || no
    @group  = options.group || 'default'

class Group

  constructor: (@model, @name, @storage) ->
    @properties = []

  add: (property) ->
    @properties.push property

  keyForId: (id) -> @model.__dataKey(id, @name)

  attributes: (instance) ->
    attributes = {}
    for property in @properties
      attributes[property.key] = instance[property.key]
    attributes

  isAssigned: (instance) ->
    for property in @properties
      if instance.hasOwnProperty(property.key)
        return yes
    return no

  save: (instance, db, multi, callback) ->
    @storage.save @keyForId(instance.id), @properties, @attributes(instance), db, multi, callback

  load: (instance, db, callback) ->
    @storage.load @keyForId(instance.id), @properties, db, (err, attributes) ->
      return callback(err) if err
      if attributes?
        instance.setAttributes attributes
      if @name == 'default'
        instance.existing = attributes?
      callback(null)


exports.defineModel = (name, options) ->

  class DasModel

    constructor: (attributes = {}) ->
      @_original = {}
      @existing = no
      @setAttributes attributes

    attributes: (options={}) ->
      group = options.group || 'default'

      result = {}
      for k, property of @constructor.__properties when property.group is group
        result[k] = @[k]
      result

    setAttributes: (attributes, options={}) ->
      for k, v of attributes
        throw "Invalid #{name} attribute: #{k}" unless @constructor.isValidKey(k)
        @[k] = v
        @_original[k] = v unless k of @_original
      attributes

    serialize: ->
      JSON.stringify(@attributes())

    assignId: (db, callback) ->
      if @id
        callback(null)
      else
        db.incr @constructor.__nextKey, (err, result) =>
          return callback(err) if err

          @id = parseInt(result)
          callback(null)

    load: (db, groups, callback) ->
      async.map ['default'].concat(groups),
        each: (group, cb) =>
          @constructor.__groups[group].load @, db, cb
        then: (err) =>
          @afterLoad (err) =>
            return callback(err) if err
            callback(null, @)

    save: (db, groups, callback) ->
      unless callback?
        callback = groups
        groups = (group for group, groupObj of @constructor.__groups when groupObj.isAssigned(@))

      @assignId db, (err) =>
        return callback(err) if err

        # db.watch dataKey, (err) =>
        #   return callback(err) if err
        do =>
          @constructor.byId db, @id, groups, (err, latest) =>
            return callback(err) if err

            multi = db.multi()

            if @constructor.__indexes.length > 0
              for k in @constructor.__indexes
                if !latest.existing || latest[k] != this[k]
                  multi.del @constructor.__indexKey(k, latest[k]) if latest
                  multi.set @constructor.__indexKey(k, this[k]), @id

            async.map ['default'].concat(groups),
              each: (group, cb) =>
                @constructor.__groups[group].save @, db, multi, cb
              then: (err) =>
                return callback(err) if err

                @onSave db, multi, (err) =>
                  return callback(err) if err

                  multi.exec (err, replies) =>
                    callback(err)

    afterLoad: (callback) ->
      callback(null)

    onSave: (db, multi, callback) ->
      callback(null)

  DasModel.__prefix = options.prefix || name
  DasModel.__groups = {}
  DasModel.__properties = {}
  DasModel.__indexes = []

  DasModel.__nextKey  = "#{DasModel.__prefix}:next"
  DasModel.__indexKey = (key, value) -> "#{@__prefix}:#{key}:#{value}"
  DasModel.__dataKey  = (id, group) -> "#{@__prefix}::#{id}" + (if group == 'default' then '' else ":#{group}")

  DasModel.isValidKey = (key) -> key of @__properties

  DasModel.uniqueIndex = (key) ->
    @__indexes.push key
    @["by#{capitalize(key)}"] = (db, value, callback) ->
      db.get @__indexKey(key, value), (err, value) =>
        return callback(err) if err
        return callback(null, null) if value == null
        @byId(db, value, callback)
    @

  DasModel.property = (key, options={}) ->
    if options.standalone
      options.group = key
      @group(key, options.storage || storage.jsonValue)

    property = new Property(key, options)

    @__properties[key] = property

    @__groups[property.group].add(property)

    @uniqueIndex(key) if property.unique

    @

  DasModel.group = (name, storage) ->
    @__groups[name] = new Group(@, name, storage)
    @

  DasModel.group('default', storage.jsonMap).property('id')

  for hook in ['afterLoad', 'onSave']
    DasModel[hook] = (func) ->
      @::[hook] = async.chain(@::[hook], func)
      @

  DasModel.byId = (db, id, groups, callback) ->
    unless callback?
      callback = groups
      groups = []

    new DasModel(id: id).load db, groups, callback

  DasModel
