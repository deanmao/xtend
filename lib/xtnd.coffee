xtnd = exports

_guide = null
_threeComponents = /^(https?)?:?\/\/([^\/]*)(.*)$/
_twoComponents = /^\/\/([^\/]*)(.*)$/

listToHash = (str) ->
  hash = {}
  str.replace /\w+/g, (x) ->
    hash[x.toLowerCase()] = true
  hash

isOneOf = (list, property) ->
  isOneOf.matchers ?= {}
  matcher = isOneOf.matchers[list]
  unless matcher
    isOneOf.matchers[list] = listToHash(list)
    matcher = isOneOf.matchers[list]
  property && matcher[property.toLowerCase()]

threeParts = (url) ->
  x = (url || '').match(_threeComponents) || []
  [x[1], x[2], x[3]]

twoParts = (url) ->
  x = (url || '').match(_twoComponents) || []
  [x[1], x[2]]

toProxiedHost = xtnd.toProxiedHost = (host, context) ->
  _guide.toProxiedHost(host, context)

toNormalHost = xtnd.toNormalHost = (proxiedHost) ->
  _guide.toNormalHost(proxiedHost)

proxiedUrl = xtnd.proxiedUrl = (orig, context) ->
  if _guide.isProxyUrl(orig)
    return orig # the url is already a proxy url
  [protocol, host, path] = threeParts(orig)
  if host
    if protocol
      return protocol + '://' + toProxiedHost(host, context) + path
    else
      return '//' + toProxiedHost(host, context) + path
  else
    return orig

normalUrl = xtnd.normalUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    unless orig
      return orig
    unless _guide.isProxyUrl(orig)
      return orig
    [protocol, host, path] = threeParts(orig)
    unless protocol
      [host, path] = twoParts(orig)
  if host
    if protocol
      return protocol + '://' + toNormalHost(host) + path
    else
      return '//' + toNormalHost(host) + path
  else
    return orig

xtnd.proxiedJS = (code) -> _guide.convertJs(code)
xtnd.proxiedHtml = (code) -> _guide.convertHtml(code)
xtnd.setGuide = (guide) -> _guide = guide
xtnd.getGuide = () -> _guide
xtnd.log = () -> console.log(arguments...)

isWindow = (x) -> x?.setTimeout && x.setInterval && x.history
isDocument = (x) -> x?.constructor == window.document.constructor
isLocation = (x) -> x?.constructor == window.location.constructor
isHtmlElement = (x) -> x?.nodeName && x.nodeType
isXMLHttpRequest = (x) -> x?.constructor == XMLHttpRequest

checkClickListener = () ->
  unless xtnd.addedClickListener
    xtnd.addedClickListener = true
    document.addEventListener 'click', (event) ->
      e = event || window.event
      el = e.target || e.srcElement
      if el.nodeType == 3
        el = target.parentNode
      while el
        if el.tagName == 'A' || el.nodeName == 'A'
          el.href = proxiedUrl(el.href, {tag: el.tagName})
          if el.target
            el.target = ''
          return el.href
        el = el.parentNode

xtnd.getOriginal = (obj, property) ->
  value = obj[property]
  try
    if _guide.PASSTHROUGH
      return value
    if value == null || property == null
      return value
    else if isDocument(obj)
      switch property.toLowerCase()
        when 'domain'
          host = toNormalHost(document.location.host)
          parts = host.split('.')
          return parts[parts.length - 2] + '.' + parts[parts.length - 1]
        when 'location'
          return normalUrl(document.location)
        else
          value
    else
      value
  catch error
    _guide.p(error)
    return value

xtnd.get = (obj, property, value) ->
  try
    if _guide.PASSTHROUGH
      return value
    if value == null || property == null
      return value
    else if isDocument(obj)
      switch property.toLowerCase()
        when 'domain'
          return _guide.host
          # return document.domain
          # toProxiedHost(value)
        when 'location'
          proxiedUrl(value, {object: obj, property: property})
        when 'cookie'
          # TODO
          value
        else
          value
    else if isHtmlElement(obj)
      if isOneOf('src href action', property)
        proxiedUrl(value, {object: obj, property: property})
      else if isOneOf('innerhtml', property)
        x = document.createElement('div')
        x.innerHTML = value.replace(/asdffoo/g, '</')
        value = xtnd.proxiedHtml(x.innerHTML)
        value
      else
        value
    else if isWindow(obj) && isOneOf('location, url, href', property)
      proxiedUrl(value, {object: obj, property: property})
    else if isLocation(obj) && isOneOf('location, url, href', property)
      proxiedUrl(value, {object: obj, property: property})
    else
      value
  catch error
    _guide.p(error)
    return value

xtnd.eval = (code) ->
  if _guide.PASSTHROUGH
    code
  else
    xtnd.proxiedJS(code)

if typeof(window) != 'undefined'
  _open = XMLHttpRequest.prototype.open
  window.XMLHttpRequest.prototype.open = (method, url, async, user, pass) ->
    url = proxiedUrl(url, {type: 'xhr'})
    out = _open.apply(this, [method, url, async, user, pass])
    this.setRequestHeader("x-xtnd-xhr", "yep")
    return out

traverseNode = (node, parent) ->
  children = node.children
  if children
    for child in children
      do (child) ->
        name = child.nodeName
        attr = _guide.tester.getHotTagAttribute(name)
        if attr && _guide.tester.isHotTagAttribute(name, attr)
          value = child.getAttribute(attr)
          child.setAttribute(attr, proxiedUrl(value, {tag: child.nodeName}))
        # if name.match(/^script/i) <--------- TODO:  Do we actually need this?
        #   value = _guide.util.removeHtmlComments(child.innerText)
        #   value = _guide.util.decodeInlineChars(value)
        #   value = xtnd.proxiedJS(value)
        #   value = value.replace(/<\//g, '<\\/')
        #   child.innerText = value
        traverseNode(child, node)

xtnd.methodCall = (obj, name, caller, args) ->
  caller = obj
  if _guide.PASSTHROUGH
    return obj[name].apply(obj, args)
  if isLocation(obj) && isOneOf('replace', name)
    return obj[name].apply(caller, [proxiedUrl(args[0], {object: obj, property: name})])
  else if isDocument(obj) && isOneOf('write writeln appendchild', name)
    xtnd.documentWriteHtmlParser ?= _guide.createHtmlParser()
    value = args[0]
    if name == 'writeln'
      value = value.replace(/asdffoo/g, '</')
      return document.writeln(_guide.convertCompleteHtml(value))
    else if name == 'write'
      value = value.replace(/asdffoo/g, '</')
      return document.write(_guide.convertCompleteHtml(value))
    else if name == 'appendchild'
      traverseNode(value)
      document.appendChild(value)
  if isXMLHttpRequest(obj)
    if name == 'open'
      [method, url, async, user, pass] = args
      return obj.open(method, proxiedUrl(url, {type: 'xhr'}), async, user, pass)
    else
      return obj[name].apply(caller, args)
  else if isHtmlElement(obj) && isOneOf('setattribute getattribute appendchild', name)
    attrib = args[0]
    if name == 'setAttribute'
      if isOneOf('src href action', attrib)
        return obj.setAttribute(attrib, proxiedUrl(args[1], {object: obj, property: attrib}))
      else
        return obj[name].apply(caller, args)
    else if name == 'getAttribute'
      if isOneOf('src href action', attrib)
        return obj.getAttribute(attrib, normalUrl(args[1], {object: obj, property: attrib}))
      else
        return obj[name].apply(caller, args)
    else if name == 'appendChild'
      traverseNode(args[0])
      return obj[name].apply(caller, args)
    else
      return obj[name].apply(caller, args)
  else if obj.location && isOneOf('postmessage', name)
    return obj.postMessage(args[0], proxiedUrl(args[1], {type: 'postmessage'}))
  else
    return obj[name].apply(caller, args)

xtnd.ActiveXObject = () ->
xtnd.ActiveXObject.prototype = (server, typeName, location) ->
  new ActiveXObject(proxiedUrl(server, {type: 'xhr'}), typeName, location)

