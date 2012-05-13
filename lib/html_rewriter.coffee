htmlparser = require './client/htmlparser2'
html = require './html2'

class HtmlRewriter
  esprima: require './client/esprima'
  util: require './util'

  constructor: (options) ->
  @htmlHandler = new html.Handler(@)
  @parser = new htmlparser.Parser(@htmlHandler)

  convertHtml: (code) ->
    @htmlHandler.reset()
    @parser.parseComplete(code)
    @htmlHandler.getOutput()

  htmlVisitor: (location, name, context, url) ->
