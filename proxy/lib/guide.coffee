# private methods & variables:
listToHash = (str) ->
  hash = {}
  str.replace /\w+/g, (x) ->
    hash[x.toLowerCase()] = true
  hash

pHot = (prop) ->
  pHot.list ?= listToHash """
    location url href cookie domain src innerhtml host hostname history documenturi
    baseuri port referrer parent top opener window parentwindow action
  """
  prop && pHot.list[prop.toLowerCase()]

mHot = (prop) ->
  mHot.list ?= listToHash 'setattribute write writeln getattribute open setrequestheader'
  prop && mHot.list[prop.toLowerCase()]

rHot = (prop) ->
  rHot.list ?= listToHash 'location top parent'
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
    skipNumericProperties = (name, node) ->
      if name == 'prop' && node.name == undefined
        return false
      return true
    # ------------- create js rewrite rules
    r.find('@x.@prop = @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x[@prop] = @z', skipNumericProperties)
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x.@prop += @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z, 'add')")
    r.find('@x[@prop] += @z', skipNumericProperties)
      .replaceWith("xtnd.assign(@x, '@prop', @z, 'add')")
    r.find('@x.@method(@args+)', checkHotMethod)
      .replaceWith("xtnd.methodCall(@x, '@method', this, [@args+])")
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
