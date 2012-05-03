# private methods & variables:
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
  # DEBUG_REQ_HEADERS: true
  # DEBUG_RES_HEADERS: true
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
    r.find('@obj.@prop = @rhs', (name, node) =>
      if name == 'rhs' && node.type == 'FunctionExpression'
        return false
      if name == 'prop' && node.type == 'Identifier' && !@tester.isHotProperty(node.name)
        return false
      return true
    ).replaceWith("xtnd.assign(@obj, @prop, @rhs)", convertPropertyToLiteral)

    # object field accessor assignment, but skip numeric fields like: obj[3]
    r.find('@obj[@prop] = @rhs', skipNumericProperties)
      .replaceWith("xtnd.assign(@obj, @prop, @rhs)")

    r.find('@obj.@prop += @rhs')
      .replaceWith("xtnd.assign(@obj, @prop, @rhs, 'add')", convertPropertyToLiteral)

    r.find('@obj[@prop] += @rhs', skipNumericProperties)
      .replaceWith("xtnd.assign(@obj, @prop, @rhs, 'add')", convertPropertyToLiteral)

    checkHotMethod = (name, node) =>
      if name == 'method' && node.type == 'Identifier' && !@tester.isHotMethod(node.value)
        return false
      return true

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
            @p?('bad js for Guide.convertJs:')
            @p?(code)
            if ee?.stmt
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

  log: () ->
    @p(arguments...)

  p: () ->
    # default to disable debug print

exports.Guide = Guide
