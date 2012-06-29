`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [
  './Events'
  './Base'
], (Events, Base) ->

  class Model extends Base

    @extend Events

    @records: {}
    @crecords: {}
    @attributes: []

    @configure: (name, attributes...) ->
      @className  = name
      @records    = {}
      @crecords   = {}
      @attributes = attributes if attributes.length
      @attributes and= Array::slice.call(@attributes, 0)
      @attributes or=  []
      @unbind()
      this

    @toString: -> "#{@className}(#{@attributes.join(", ")})"

    @find: (id) ->
      record = @records[id]
      if !record and ("#{id}").match(/c-\d+/)
        return @findCID(id)
      throw new Error('Unknown record') unless record
      record.clone()

    @findCID: (cid) ->
      record = @crecords[cid]
      throw new Error('Unknown record') unless record
      record.clone()

    @exists: (id) ->
      try
        return @find(id)
      catch e
        return false

    @refresh: (values, options = {}) ->
      if options.clear
        @records  = {}
        @crecords = {}

      records = @fromJSON(values)
      records = [records] unless isArray(records)

      for record in records
        record.id           or= record.cid
        @records[record.id]   = record
        @crecords[record.cid] = record

      @trigger('refresh', @cloneArray(records))
      this

    @select: (callback) ->
      result = (record for id, record of @records when callback(record))
      @cloneArray(result)

    @findByAttribute: (name, value) ->
      for id, record of @records
        if record[name] is value
          return record.clone()
      null

    @findAllByAttribute: (name, value) ->
      @select (item) ->
        item[name] is value

    @each: (callback) ->
      for key, value of @records
        callback(value.clone())

    @all: ->
      @cloneArray(@recordsValues())

    @first: ->
      record = @recordsValues()[0]
      record?.clone()

    @last: ->
      values = @recordsValues()
      record = values[values.length - 1]
      record?.clone()

    @count: ->
      @recordsValues().length

    @deleteAll: ->
      for key, value of @records
        delete @records[key]

    @destroyAll: ->
      for key, value of @records
        @records[key].destroy()

    @update: (id, atts, options) ->
      @find(id).updateAttributes(atts, options)

    @create: (atts, options) ->
      record = new @(atts)
      record.save(options)

    @destroy: (id, options) ->
      @find(id).destroy(options)

    @change: (callbackOrParams) ->
      if typeof callbackOrParams is 'function'
        @bind('change', callbackOrParams)
      else
        @trigger('change', callbackOrParams)

    @fetch: (callbackOrParams) ->
      if typeof callbackOrParams is 'function'
        @bind('fetch', callbackOrParams)
      else
        @trigger('fetch', callbackOrParams)

    @toJSON: ->
      @recordsValues()

    @fromJSON: (objects) ->
      return unless objects
      if typeof objects is 'string'
        objects = JSON.parse(objects)
      if isArray(objects)
        (new @(value) for value in objects)
      else
        new @(objects)

    @fromForm: ->
      (new this).fromForm(arguments...)

    # Private

    @recordsValues: ->
      result = []
      for key, value of @records
        result.push(value)
      result

    @cloneArray: (array) ->
      (value.clone() for value in array)

    @idCounter: 0

    @uid: (prefix = '') ->
      uid = prefix + @idCounter++
      uid = @uid(prefix) if @exists(uid)
      uid

    # Instance

    constructor: (atts) ->
      super
      @load atts if atts
      @cid = @constructor.uid('c-')

    isNew: ->
      not @exists()

    isValid: ->
      not @validate()

    validate: ->

    load: (atts) ->
      for key, value of atts
        if typeof @[key] is 'function'
          @[key](value)
        else
          @[key] = value
      this

    attributes: ->
      result = {}
      for key in @constructor.attributes when key of this
        if typeof @[key] is 'function'
          result[key] = @[key]()
        else
          result[key] = @[key]
      result.id = @id if @id
      result

    eql: (rec) ->
      !!(rec and rec.constructor is @constructor and
      (rec.cid is @cid) or (rec.id and rec.id is @id))

    save: (options = {}) ->
      unless options.validate is false
        error = @validate()
        if error
          @trigger('error', error)
          return false

      @trigger('beforeSave', options)
      record = if @isNew() then @create(options) else @update(options)
      @trigger('save', options)
      record

    updateAttribute: (name, value, options) ->
      @[name] = value
      @save(options)

    updateAttributes: (atts, options) ->
      @load(atts)
      @save(options)

    changeID: (id) ->
      records = @constructor.records
      records[id] = records[@id]
      delete records[@id]
      @id = id
      @save()

    destroy: (options = {}) ->
      @trigger('beforeDestroy', options)
      delete @constructor.records[@id]
      delete @constructor.crecords[@cid]
      @destroyed = true
      @trigger('destroy', options)
      @trigger('change', 'destroy', options)
      @unbind()
      this

    dup: (newRecord) ->
      result = new @constructor(@attributes())
      if newRecord is false
        result.cid = @cid
      else
        delete result.id
      result

    clone: ->
      createObject(this)

    reload: ->
      return this if @isNew()
      original = @constructor.find(@id)
      @load(original.attributes())
      original

    toJSON: ->
      @attributes()

    toString: ->
      "<#{@constructor.className} (#{JSON.stringify(this)})>"

    exists: ->
      @id && @id of @constructor.records

    # Private

    update: (options) ->
      @trigger('beforeUpdate', options)
      records = @constructor.records
      records[@id].load @attributes()
      clone = records[@id].clone()
      clone.trigger('update', options)
      clone.trigger('change', 'update', options)
      clone

    create: (options) ->
      @trigger('beforeCreate', options)
      @id          = @cid unless @id

      record       = @dup(false)
      @constructor.records[@id]   = record
      @constructor.crecords[@cid] = record

      clone        = record.clone()
      clone.trigger('create', options)
      clone.trigger('change', 'create', options)
      clone

    bind: (events, callback) ->
      @constructor.bind events, binder = (record) =>
        if record && @eql(record)
          callback.apply(this, arguments)
      @constructor.bind 'unbind', unbinder = (record) =>
        if record && @eql(record)
          @constructor.unbind(events, binder)
          @constructor.unbind('unbind', unbinder)
      binder

    one: (events, callback) ->
      binder = @bind events, =>
        @constructor.unbind(events, binder)
        callback.apply(this, arguments)

    trigger: (args...) ->
      args.splice(1, 0, this)
      @constructor.trigger(args...)

    unbind: ->
      @trigger('unbind')

  Model