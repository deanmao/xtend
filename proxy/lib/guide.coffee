# private methods & variables:
_hotReferences = {}
for x in ["location", "top", "parent"]
  do (x) ->
    _hotReferences[x.toLowerCase()] = true

_hotMethods = {}
for x in ["setAttribute", "write", "writeln", "getAttribute", "open", "setRequestHeader"]
  do (x) ->
    _hotMethods[x.toLowerCase()] = true

_hotProperties = {}
for x in ["location", "URL", "href", "cookie", "domain", "src", "innerHTML",
   "host", "hostname", "history", "documentURI", "baseURI", "port",
   "referrer", "parent", "top", "opener", "window", "parentWindow",
   "action"]
   do (x) ->
     _hotProperties[x.toLowerCase()] = true

pHot = (prop) ->
  prop && _hotProperties[prop.toLowerCase()]

mHot = (prop) ->
  prop && _hotMethods[prop.toLowerCase()]

rHot = (prop) ->
  prop && _hotReferences[prop.toLowerCase()]

class Guide
  REWRITE_HTML: true
  REWRITE_JS: true
  constructor: (config) ->
    # ------------- copy over config into instance variables
    for own key, value of config
      do (key, value) =>
        @[key] = value
    # ------------- html init:
    @htmlHandler = new @html.Handler(@)
    @htmlParser = new @htmlparser.Parser(@htmlHandler)
    # ------------- js init:
    r = @jsRewriter = new @js.Rewriter(@esprima, @codegen)
    @xtnd.setGuide(@)
    checkHotPropertyLiteral = (name, node) ->
      if name == 'prop' && node.type == 'Literal'
        if !pHot(node.value)
          return false
      return true
    checkHotMethod = (name, node) ->
      if name == 'method' && node.type == 'Identifier'
        if !mHot(node.value)
          return false
      return true
    # ------------- create js rewrite rules
    r.find('@x.@prop = @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x[@prop] = @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x.@prop += @z')
      .replaceWith("xtnd.appendAssign(@x, '@prop', @z)")
    r.find('@x[@prop] += @z')
      .replaceWith("xtnd.appendAssign(@x, '@prop', @z)")
    r.find('@x.@method(@args+)', checkHotMethod)
      .replaceWith("xtnd.methodCall('@method', @x, this, @args+)")
    r.find('eval(@x)')
      .replaceWith('xtnd.eval(@x)')
    r.find('window.eval(@x)')
      .replaceWith('xtnd.eval(@x)')
    r.find('new ActiveXObject(@x)')
      .replaceWith('new xtnd.ActiveXObject(@x)')

  convertJs: (code) ->
    if @REWRITE_JS
      if @fs
        @p(code)
        @fs.writeFileSync('data.js', code)
      @jsRewriter.convertToJs(code)
    else
      code

  convertHtml: (code) ->
    if @REWRITE_HTML
      @htmlHandler.reset()
      @htmlParser.parseComplete(code)
      @htmlHandler.output
    else
      code

  createHtmlParser: ->
    handler = new @html.Handler(@)
    parser = new @htmlparser.Parser(handler)
    asdf = (chunk, isDone) ->
      if isDone
        parser.done()
      else
        parser.parseChunk(chunk)
        handler.reset()
      handler.output

  htmlVisitor: (location, name) ->
    # ------------- append our special script after head tag
    if name == 'head' && location == 'after'
        '<script src="/x_t_n_d/scripts"></script>'

  p: () ->
    # default to disable debug print

exports.Guide = Guide
