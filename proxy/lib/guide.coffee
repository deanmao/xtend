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
  PASSTHROUGH: true
  JS_DEBUG: true
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

    # r.find('@x.@method(@args+)', checkHotMethod)
    #   .replaceWith("xtnd.methodCall(@x, @method, this, [@args+])", (binding, node) ->
    #     if node.name == 'method' && binding.type == 'Identifier'
    #       {type: 'Literal', value: binding.name}
    #   )
    # r.find('eval(@x)')
    #   .replaceWith('xtnd.eval(@x)')
    # r.find('window.eval(@x)')
    #   .replaceWith('xtnd.eval(@x)')

    # worry about IE later
    # r.find('new ActiveXObject(@x)')
    #   .replaceWith('new xtnd.ActiveXObject(@x)')

  convertJs: (code) ->
    if @REWRITE_JS
      try
        @jsRewriter.convertToJs(code)
      catch e
        if @JS_DEBUG && @fs
          prettyCode = @codegen.generate(@esprima.parse(code))
          @fs.writeFileSync('error_output.js', prettyCode)
          try
            @jsRewriter.convertToJs(prettyCode)
          catch ee
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
