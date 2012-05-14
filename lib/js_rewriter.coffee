esprima = require('./client/esprima')
codegen = require('./client/escodegen')
js = require('./js')

class JsRewriter
  constructor: (guide) ->
    @jsRewriter = new js.Rewriter(esprima, codegen, guide)

  addRule: ->
    @jsRewriter

  convert: (code, options) ->
    @jsRewriter.convertToJs(code, options)

exports.JsRewriter = JsRewriter
