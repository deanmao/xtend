class Guide
  REWRITE_HTML: true
  REWRITE_JS: true
  PASSTHROUGH: false
  PRODUCTION: false
  CACHED_FILES_PATH: './cached'
  FORCE_SCRIPT_SUFFIX: '__XTND_SCRIPT'
  INTERNAL_URL_PREFIX: '/___xtnd'
  htmlparser: require('./client/htmlparser2')
  esprima: require('./client/esprima')
  codegen: require('./client/escodegen')
  tester: require('./client/property_tester')
  util: require('./client/util')
  xtnd: require('./xtnd')
  js: require('./js')
  html: require('./html2')
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
    convertPropertyToLiteral = (binding, node, allBindings) ->
      if node.name == 'propx'
        propBinding = allBindings['prop']
        if propBinding.type == 'Identifier'
          return {type: 'Literal', value: propBinding.name}
        else
          return {type: 'Literal', value: propBinding.value}

    assignmentMatcher = (name, node) =>
      if name == 'rhs'
        if node.type == 'FunctionExpression'
          return false
        else if node.type == 'Literal' && typeof(node.value) != 'string'
          return false
      else if name == 'prop'
        if node.type == 'Identifier'
          if @tester.isHotProperty(node.name)
            return true
          else
            return false
        else if node.type == 'Literal'
          if typeof(node.value) == 'string'
            if @tester.isSpecial(node.value)
              return true
            else
              return false
          else
            return false
        else
          return false
      return true

    r.find('@obj.@prop = @rhs', {useExpression: true}, assignmentMatcher)
      .replaceWith("@obj.@prop = xtnd.get(@obj, @propx, @rhs)", convertPropertyToLiteral)

    r.find('@obj[@prop] = @rhs', {useExpression: true}, assignmentMatcher)
      .replaceWith("@obj[@prop] = xtnd.get(@obj, @propx, @rhs)", convertPropertyToLiteral)

    r.find('@obj.@prop += @rhs', {useExpression: true}, assignmentMatcher)
      .replaceWith("@obj.@prop += xtnd.get(@obj, @propx, @rhs)", convertPropertyToLiteral)

    r.find('@obj[@prop] += @rhs', {useExpression: true}, assignmentMatcher)
      .replaceWith("@obj[@prop] += xtnd.get(@obj, @propx, @rhs)", convertPropertyToLiteral)

    checkHotMethod = (name, node) =>
      if name == 'method' && node.type == 'Identifier' && !@tester.isHotMethod(node.name)
        return false
      return true

    r.find('@obj.@method(@args+)', checkHotMethod)
      .replaceWith "xtnd.methodCall(@obj, @method, this, [@args+])", (binding, node) ->
        if node.name == 'method' && binding.type == 'Identifier'
          {type: 'Literal', value: binding.name}

    r.find('eval(@x)')
      .replaceWith('eval(xtnd.eval(@x))')

    if @DEBUG_REWRITTEN_JS
      r.find('try { @stmts+ } catch (@e) { @cstmts+ }', (name, node) ->
        if name == 'cstmts' && node.length == 0
          return false
        return true
      ).replaceWith('try { @stmts+ } catch (@e) { console.log(@e); {@cstmts+} }')

    r.find('new ActiveXObject(@x+)')
      .replaceWith('new xtnd.ActiveXObject(@x+)')

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

  toProxiedHost: (host, context) ->
    host.replace(/\-/g, '--').replace(/\./g, '-').replace(/:/g, '--p--') + '.' + @host

  toNormalHost: (proxiedHost) ->
    subdomain = proxiedHost.split('.')[0]
    subdomain.replace(/\-\-p\-\-/g, ':').replace(/\-/g, '.').replace(/\.\./g, '-')

  makeSafe: (code) ->
    "(function(){try{" + code + "}catch(e){xtnd.log('xtnd inline js error', e)}})()"

  isProxyUrl: (url) ->
    url.indexOf(@host) != -1

  convertHtml: (code) ->
    if @REWRITE_HTML
      @htmlHandler.reset()
      @parser.parseComplete(code)
      @htmlHandler.getOutput()
    else
      code

  isBrowser: ->
    typeof(window) != 'undefined'

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
      '<script src="'+@INTERNAL_URL_PREFIX+'/xtnd_scripts.js"></script>'
    else if name == 'head' && location == 'after' && !context.insertedSpecialJS
      context.insertedSpecialJS = true
      '<script src="'+@INTERNAL_URL_PREFIX+'/xtnd_scripts.js"></script>'
    else if name == 'body' && location == 'after' && !context.insertedSpecialJS
      context.insertedSpecialJS = true
      '<script src="'+@INTERNAL_URL_PREFIX+'/xtnd_scripts.js"></script>'

  log: () ->
    @p(arguments...)

  p: () ->
    # default to disable debug print

exports.Guide = Guide
