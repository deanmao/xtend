{ vows, assert } = require("./helpers")
gd = require('../lib/guide')

# Gravatar[this.notify_stack[key][a]](key.substr(1));

guide = new gd.Guide(
  REWRITE_HTML: true
  REWRITE_JS: true
  host: 'myapp.dev:3000'
  esprima: require('esprima')
  codegen: require('../lib/client/escodegen')
  htmlparser: require('htmlparser')
  xtnd: require('../lib/xtnd')
  js: require('../lib/js')
  html: require('../lib/html')
)

vows.describe('guide validators').addBatch
  'funny code':
    topic: ->
      guide.convertJs('Gravatar[this.notify_stack[key][a]](key.substr(1));')
    'should work': (output) ->
      assert.equal output, ''

.export(module)
