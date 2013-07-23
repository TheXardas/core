define [
  'cord!Collection'
  'cord!Model'
  'cord!utils/Defer'
  'cord!utils/Future'
  'postal'
  'underscore'
  'cord!Console'
], (Collection, Model, Defer, Future, postal, _, _console) ->

  class Context

    constructor: (arg1, arg2) ->
      @[':internal'] = {}
      @[':internal'].version = 0
      if typeof arg1 is 'object'
        for key, value of arg1
          @[key] = value
      else
        @id = arg1
        if arg2
          for key, value of arg2
            @[key] = value
            @_initDeferredDebug(key)


    owner: (owner) ->
      if owner
        Object.defineProperty @, "_owner",
          value: owner
          writable: true
          enumerable: false
      @_owner


    set: (args...) ->
      triggerChange = false
      if args.length == 0
        throw "Invalid number of arguments! Should be 1 or 2."
      else if args.length == 1
        pairs = args[0]
        if typeof pairs is 'object'
          for key, value of pairs
            if @setSingle key, value
              triggerChange = true
        else
          throw "Invalid argument! Single argument must be key-value pair (object)."
      else if @setSingle args[0], args[1]
        triggerChange = true

      if triggerChange
        Defer.nextTick =>
          postal.publish "widget.#{ @id }.someChange", {}


    setSingle: (name, newValue, callbackPromise) ->
      ###
      Sets single context param's value
      @param String name param name
      @param Any newValue param value
      @param (optional)Future callbackPromise promise to support setWithCallback() method functionality
      @return Boolean true if the change event was triggered (the value was changed)
      ###
      if newValue != undefined
        if @[name] == ':deferred'
          # if the current value special :deferred than event should be triggered even if the new value is null
          triggerChange = (newValue != ':deferred')
        else
          oldValue = @[name]
          if oldValue == null
            # null needs special check because null == null in javascript isn't true
            triggerChange = (newValue != null)
          else
            triggerChange = (newValue != oldValue)
      else
        triggerChange = false

#      _console.log "setSingle -> #{ name } = #{ newValue } (oldValue = #{ @[name] }) trigger = #{ triggerChange } -> #{ (new Date).getTime() }"

      # never change value to 'undefined' (don't mix up with 'null' value)
      @[name] = newValue if newValue != undefined

      if triggerChange
        callbackPromise.fork() if callbackPromise
        curVersion = ++@[':internal'].version
        if @[':internal'].stash
          cursor = _.uniqueId()
          @[':internal'].stash.push
            id: @id
            name: name
            newValue: newValue
            oldValue: oldValue
            cursor: cursor
            version: curVersion
        Defer.nextTick =>
          _console.log "publish widget.#{ @id }.change.#{ name }" if global.config.debug.widget
          postal.publish "widget.#{ @id }.change.#{ name }",
            name: name
            value: newValue
            oldValue: oldValue
            callbackPromise: callbackPromise
            cursor: cursor
            version: curVersion
          callbackPromise.resolve() if callbackPromise

      @_initDeferredDebug(name)

      triggerChange


    setDeferred: (args...) ->
      for name in args
        @setSingle(name, ':deferred')


    isDeferred: (name) ->
      @[name] is ':deferred'


    isEmpty: (name) ->
      (not @[name]?) or @isDeferred(name)


    setWithFeedback: (name, value) ->
      ###
      Sets the context param's value as usual but injects future to the event data and returns it.
      By default if event handlers doesn't support injected callback promise, the future will be completed immediately
       after calling all event handlers. But some event handlers can support the promise and defer their completion
       depending of some of their async activity.
      @param String name param name
      @param Any value param value
      @return Future
      ###
      callbackPromise = new Future
      @setSingle(name, value, callbackPromise)
      callbackPromise


    stashEvents: ->
      @[':internal'].stash = []


    replayStashedEvents: ->
      ###
      Re-triggers stashed context-change events.
      Stashing is needed after Widget::setParams() is already processed but browserInit() still didn't executed,
       so child widget's and behaviour will miss context changing which ocasionally happens during that time.
      @browser-only
      ###
      if @[':internal'].stash and @[':internal'].stash.length
        Defer.nextTick =>
          for ev in @[':internal'].stash
            postal.publish "widget.#{ ev.id }.change.#{ ev.name }",
              name: ev.name
              value: ev.newValue
              oldValue: ev.oldValue
              cursor: ev.cursor
              version: ev.version
              stashed: true
          @[':internal'].stash = null


    getVersion: ->
      @[':internal'].version


    toJSON: ->
      result = {}
      for key, value of this
        if value instanceof Collection
          result[key] = value.serializeLink()
        else if value instanceof Model
          result[key] = value.serializeLink()
        else if key != ':internal'
          result[key] = value
      result


    @fromJSON: (obj, ioc, callback) ->
      promise = new Future
      for key, value of obj
        do (key, value) ->
          if Collection.isSerializedLink(value)
            promise.fork()
            Collection.unserializeLink value, ioc, (collection) ->
              obj[key] = collection
              promise.resolve()
          else if Model.isSerializedLink(value)
            promise.fork()
            Model.unserializeLink value, ioc, (model) ->
              obj[key] = model
              promise.resolve()
          else
            obj[key] = value

      promise.done =>
        callback(new this(obj))


    _initDeferredDebug: (name) ->
      if @[name] == ':deferred'
        setTimeout =>
          _console.error '### Deferred timeout', name, @id, @_owner?.constructor.name  if @[name] == ':deferred'
        , 10000

