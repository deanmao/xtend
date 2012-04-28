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
  constructor: (config) ->
    xtnd.setGuide(@)
    for key, value of config
      do (key, value) =>
        @[key] = value
    r = @jsRewriter = new @js.Rewriter()
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
    r.find('@x.@prop = @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x[@prop] = @z')
      .replaceWith("xtnd.assign(@x, '@prop', @z)")
    r.find('@x.@prop += @z')
      .replaceWith("xtnd.appendAssign(@x, '@prop', @z)")
    r.find('@x[@prop] += @z')
      .replaceWith("xtnd.appendAssign(@x, '@prop', @z)")
    r.find('@x.@method(@args+)', checkHotMethod)
      .replaceWith("xtnd.methodCall('@method', @x, this, @args)")
    r.find('eval(@x)')
      .replaceWith('xtnd.eval(@x)')
    r.find('window.eval(@x)')
      .replaceWith('xtnd.eval(@x)')
    r.find('new ActiveXObject(@x)')
      .replaceWith('new xtnd.ActiveXObject(@x)')

  xtnd: ->
    xtnd

  js: (code) ->
    @jsRewriter.convertToJs(code)

  html: (code) ->
    handler = new @html.Handler(@xtnd)
    parser = new @htmlparser.Parser(handler)
    parser.parseComplete(code)
    handler.output

exports.Guide = Guide
