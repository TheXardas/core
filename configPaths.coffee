`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [],  ->
  paths:

    'cordWidget':     './bundles/cord/core/Widget'
    'cordBehaviour':  './bundles/cord/core/Behaviour'
    'pathBundles':    './bundles'

    #plugins
    'text':         './vendor/requirejs/plugins/text'
    'use':          './vendor/requirejs/plugins/use'
    'cord-helper':  './bundles/cord/core/requirejs/cord-helper'
    'cord':         './bundles/cord/core/requirejs/cord'
    'cord-w':       './bundles/cord/core/requirejs/cord-w'
    'cord-t':       './bundles/cord/core/requirejs/cord-t'