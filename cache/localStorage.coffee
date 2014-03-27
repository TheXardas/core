define [
  'cord!utils/Future'
  'localforage'
  'cord!utils/sha1'
], (Future, localForage, sha1) ->

  class LocalStorage

    saveCollectionInfo: (repoName, collectionName, ttl, info) ->
      ###
      Saves only collections meta-information
      ###
      key = "cl:#{ repoName }:#{ sha1(collectionName) }"
      if ttl?
        @_registerTtl(key + ':info', ttl)
        @_registerTtl(key, ttl)
      @_set(key + ':info', info)


    saveCollection: (repoName, collectionName, modelIds) ->
      ###
      Saves list of model ids for the collection.
      ###
      @_set("cl:#{ repoName }:#{ sha1(collectionName) }", modelIds)


    invalidateCollection: (repoName, collectionName) ->
      ###
      Removes collection from cache
      ###
      key = "cl:#{ repoName }:#{ sha1(collectionName) }"
      @_removeItem key
      @_removeItem(key + ':info')


    invalidateAllCollectionsWithField: (repoName, fieldName) ->
      ###
      Clear cache for collections of particular repo, which contains the fieldName
      ###
      @_invalidateAllCollectionsWithField repoName, fieldName


    getCollectionInfo: (repoName, collectionName) ->
      ###
      Returns meta-information of the collection, previously saved in the local storage.
      ###
      @_get("cl:#{ repoName }:#{ sha1(collectionName) }:info")


    getCollection: (repoName, collectionName) ->
      ###
      Returns list of model ids of the collection, previously saved in the local storage.
      ###
      @_get("cl:#{ repoName }:#{ sha1(collectionName) }")


    getItem: (key) ->
      ###
      getItem wrapper
      ###
      @_get key


    setItem: (key, value) ->
      ###
      setItem wrapper
      ###
      @_set key, value


    removeItem: (key) ->
      ###
      removeItem wrapper
      ###
      @_removeItem key


    clear: ->
      ###
      Clear local storage
      ###
      localForage.clear()


    _removeItem: (key) ->
      result = Future.single('localStorage::_removeItem')
      try
        localForage.removeItem key, ->
          result.resolve()
      catch e
        result.reject(e)
      result


    _set: (key, value) ->
      ###
      Key-value set proxy for the local storage with serialization and garbage collection fired when not enough space.
      Garbage collection is base on the TTL params, passed when saving values.
      ###
      result = Future.single("localStorage::_set #{key}")
      try
        localForage.setItem key, value, ->
          result.resolve()
      catch e
        if e.code == DOMException.QUOTA_EXCEEDED_ERR or e.name.toLowerCase().indexOf('quota') != -1
          @_gc(value.length)
          try
            localForage.setItem key, value, ->
              result.resolve()
          catch e
            _console.error "localStorage::_set(#{ key }) failed!", value, e
            result.reject(e)
        else
          result.reject(e)
      result


    _get: (key) ->
      ###
      Future-powered proxy key-value get method.
      ###
      result = Future.single("localStorage::_get #{key}")
      localForage.getItem key, (value) ->
        if value?
          result.resolve(value)
        else
          result.reject("Key '#{ key }' doesn't exists in the local storage!")
      result


    _registerTtl: (key, ttl) ->
      ###
      Saves TTL for the given key to be able to make right decisions during GC
      ###
      localForage.getItem 'models:ttl-info', (ttlInfo) =>
        ttlInfo = {} if ttlInfo == null
        ttlInfo[key] = (new Date).getTime() + ttl

        @_set('models:ttl-info', ttlInfo)


    _gc: (needLength) ->
      ###
      Garbage collector.
      If needLength argument is given, than it tries to free just enought space, if not - all expired items are removed.
      @param (optional) needLength amount of memory needed
      ###
      localForage.getItem 'models:ttl-info', (ttlInfo) =>
        if needLength
          needLength = parseInt(needLength) * 2
        else
          needLength = 0
        orderedTtlInfo = []
        for k, v of ttlInfo
          orderedTtlInfo.push [k, v]
        orderedTtlInfo = _.sortBy orderedTtlInfo, (x) -> x[1]

        if needLength
          while needLength > 0 and orderedTtlInfo.length
            item = orderedTtlInfo.shift()
            localForage.getItem item[0], (val) ->
              if val?
                needLength -= val.length
                localForage.removeItem(item[0])
              delete ttlInfo[item[0]]
        else
          currentTime = (new Date).getTime()
          for item in orderedTtlInfo
            if item[1] < currentTime
              localForage.removeItem(item[0])
              delete ttlInfo[item[0]]
            else
              break

        @_set('models:ttl-info', ttlInfo)


    _invalidateAllCollectionsWithField: (repoName, fieldName) ->
      promise = new Future(1, "localStorage::_invalidateAllCollectionsWithField #{repoName} #{fieldName} promise")

      localForage.length (length) =>
        for index in [1..length-1]
          promise.fork()

          localForage.key index, (key) =>
            if key.slice(-5) == ':info' && key.indexOf(repoName) >= 0
              if !fieldName
                localForage.removeItem key
                localForage.removeItem(key.slice(0, key.length - 5))
              else
                localForage.getItem key, (value) =>
                  if !value.fields || (fieldName in value.fields)
                    localForage.removeItem key
                    localForage.removeItem(key.slice(0, key.length - 5))

            promise.resolve()

        promise.resolve()

      promise


    _invalidateAllCollections: (repoName) ->
      promise = new Future(1, "localStorage::_invalidateAllCollections #{repoName} promise")

      localForage.length (length) =>
        for index in [1..length-1]
          promise.fork()

          localForage.key index, (key) =>
            if key.indexOf(repoName) >= 0
              localForage.removeItem key
              localForage.removeItem(key.slice(0, key.length - 5))

            promise.resolve()

        promise.resolve()

      promise


  new LocalStorage
