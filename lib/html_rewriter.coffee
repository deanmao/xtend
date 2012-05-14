htmlparser = require './client/htmlparser2'

class HtmlRewriter
  constructor: (options) ->
    visitor = (location, name, context, url) =>
      @htmlVisitor(location, name, context, url)
    @htmlHandler = new options.Handler(options.url, visitor, options.guide)
    @parser = new htmlparser.Parser(@htmlHandler)

  convertHtml: (code) ->
    @htmlHandler.reset()
    @parser.parseComplete(code)
    @htmlHandler.getOutput()

  htmlVisitor: (location, name, context, url) ->
    # nothing


