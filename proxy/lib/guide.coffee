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

checkHotMethod = (name, node) ->
  if name == 'method' && node.type == 'Identifier'
    if mHot(node.value)
      return false
  return true

skipNumericProperties = (name, node) ->
  if name == 'prop' && node.name == undefined && node.type == 'Literal'
    return false
  return true

skipRhsFunctionExpressions = (name, node) ->
  if name == 'rhs' && node.type == 'FunctionExpression'
    return false
  return true

convertPropertyToLiteral = (binding, node) ->
  if node.name == 'prop'
    if binding.type == 'Identifier'
      {type: 'Literal', value: binding.name}

class Guide
  REWRITE_HTML: true
  REWRITE_JS: true
  PASSTHROUGH: false
  JS_DEBUG: true
  FORCE_SCRIPT_SUFFIX: '__XTND_SCRIPT.js'
  constructor: (config) ->
    # ------------- copy over config into instance variables
    for own key, value of config
      do (key, value) =>
        @[key] = value
    # ------------- html init:
    @htmlHandler = new @html.Handler(@)
    @parser = new @htmlparser.Parser(@htmlHandler)
    # ------------- js init:
    r = @jsRewriter = new @js.Rewriter(@esprima, @codegen, @)
    @xtnd.setGuide(@)
    # ------------- create js rewrite rules

    # assignment, but skip function assignments like: a[x] = function(){}
    r.find('@obj.@prop = @rhs', skipRhsFunctionExpressions)
      .replaceWith("xtnd.assign(@obj, @prop, @rhs)", convertPropertyToLiteral)

    # object field accessor assignment, but skip numeric fields like: obj[3]
    r.find('@obj[@prop] = @rhs', skipNumericProperties)
      .replaceWith("xtnd.assign(@obj, @prop, @rhs)")

    r.find('@obj.@prop += @rhs')
      .replaceWith("xtnd.assign(@obj, @prop, @rhs, 'add')", convertPropertyToLiteral)

    r.find('@obj[@prop] += @rhs', skipNumericProperties)
      .replaceWith("xtnd.assign(@obj, @prop, @rhs, 'add')", convertPropertyToLiteral)

    # TODO FIXME:
    r.find('@obj.@method(@args+)', checkHotMethod)
      .replaceWith "xtnd.methodCall(@obj, @method, this, [@args+])", (binding, node) ->
        if node.name == 'method' && binding.type == 'Identifier'
          {type: 'Literal', value: binding.name}

    r.find('eval(@x)')
      .replaceWith('eval(xtnd.eval(@x))')

    # worry about IE later
    # r.find('new ActiveXObject(@x)')
    #   .replaceWith('new xtnd.ActiveXObject(@x)')

  convertJs: (code, options) ->
    if @REWRITE_JS
      try
        @jsRewriter.convertToJs(code, options)
      catch e
        if @JS_DEBUG && @fs
          try
            prettyCode = @codegen.generate(@esprima.parse(code))
            @fs.writeFileSync('error_output.js', prettyCode)
            return @jsRewriter.convertToJs(prettyCode, options)
          catch ee
            @p?(code)
            @p?(options)
            @p?(ee.stmt)
            throw ee
        else
          # not sure if we should throw error here or silently fail
          # and just return the original code
          throw e
    else
      code

  convertHtml: (code) ->
    if @REWRITE_HTML
      @htmlHandler.reset()
      @parser.parseComplete(code)
      @htmlHandler.output
    else
      code

  # This one is primarly for doing chunked content, to be used later
  # when we want to handle the html streams in chunks instead of one big
  # block.
  createHtmlParser: (url)->
    if @REWRITE_HTML
      handler = new @html.Handler(@, url)
      parser = new @htmlparser.Parser(handler)
      asdf = (chunk) ->
        handler.reset()
        parser.parseChunk(chunk)
        handler.output
    else
      asdf = (chunk) ->
        chunk

  htmlVisitor: (location, name, context) ->
    # ------------- append our special script after head tag
    if name == 'script' && location == 'before' && !context.insertedSpecialJS
      context.insertedSpecialJS = true
      '<script src="/x_t_n_d/scripts"></script>'
    else if name == 'head' && location == 'after' && !context.insertedSpecialJS
      context.insertedSpecialJS = true
      '<script src="/x_t_n_d/scripts"></script>'

  p: () ->
    # default to disable debug print

exports.Guide = Guide
