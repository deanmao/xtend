xtnd = exports

_guide = null
_threeComponents = /^(https?):\/\/([^\/]*)(.*)$/
_twoComponents = /^\/\/([^\/]*)(.*)$/

_p = () -> console.log(arguments...)

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

xtnd.setGuide = (guide) ->
  _guide = guide

toProxiedHost = xtnd.toProxiedHost = (host) ->
  host.replace(/\-/g, '--').replace(/\./g, '-').replace(/:/g, '--p--') + '.' + _guide.host

toNormalHost = xtnd.toNormalHost = (proxiedHost) ->
  subdomain = proxiedHost.split('.')[0]
  subdomain.replace(/\-\-p\-\-/g, ':').replace(/\-/g, '.').replace(/\.\./g, '-')


proxiedUrl = xtnd.proxiedUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    unless orig
      return orig
    if _guide.isProxyUrl(orig)
      return orig # the url is already a proxy url
    [protocol, host, path] = threeParts(orig)
    unless protocol
      [host, path] = twoParts(orig)
  if host
    if protocol
      return protocol + '://' + toProxiedHost(host) + path
    else
      return '//' + toProxiedHost(host) + path
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

isWindow = (x) -> x?.setTimeout && x.setInterval && x.history
isDocument = (x) -> x?.constructor == window.document.constructor
isLocation = (x) -> x?.constructor == window.location.constructor
isHtmlElement = (x) -> x?.nodeName && x.nodeType
isXMLHttpRequest = (x) -> x?.constructor == XMLHttpRequest

xtnd.log = () ->
  console.log(arguments...)

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
          el.href = proxiedUrl(el.href)
          if el.target
            el.target = ''
          return el.href
        el = el.parentNode

xtnd.assign = (obj, property, value, operation) ->
  try
    if operation == 'add'
      value = obj[property] + value
     if _guide.PASSTHROUGH
       return (obj[property] = value)
    if obj == null
      return null
    else if isDocument(obj)
      if property?.match(/cookie/i)
        console.log('setting document.cookie with', value)
        obj[property] = value # TODO
      else if property?.match(/domain/i)
        obj[property] = toProxiedHost(document.domain)
      else if property?.match(/url/i)
        obj[property] = value
      else if property?.match(/location/i)
        obj[property] = proxiedUrl(value)
      else
        obj[property] = value
    else if isHtmlElement(obj)
      if isOneOf('src href action', property)
        obj[property] = proxiedUrl(value)
      else if isOneOf('innerhtml', property)
        x = document.createElement('div')
        x.innerHTML = value
        value = xtnd.proxiedHtml(x.innerHTML)
        obj[property] = value
      else
        obj[property] = value
    else if isWindow(obj) && isOneOf('location, url, href', property)
      obj[property] = proxiedUrl(value)
    else if isLocation(obj) && isOneOf('location, url, href', property)
      obj[property] = proxiedUrl(value)
    else
      obj[property] = value
  catch error
    _guide.p(error)

xtnd.eval = (code) ->
  if _guide.PASSTHROUGH
    code
  else
    xtnd.proxiedJS(code)

if typeof(window) != 'undefined'
  _open = XMLHttpRequest.prototype.open
  window.XMLHttpRequest.prototype.open = (method, url, async, user, pass) ->
    url = proxiedUrl(url) + _guide.XHR_SUFFIX
    _open.apply(this, [method, url, async, user, pass])
  _replace = document.location.replace
  document.location.replace = (url) ->
    _replace.apply(document.location, [proxiedUrl(url)])


traverseNode = (node, parent) ->
  children = node.children
  if children
    for child in children
      do (child) ->
        name = child.nodeName
        attr = _guide.tester.getHotTagAttribute(name)
        if attr && _guide.tester.isHotTagAttribute(name, attr)
          value = child.getAttribute(attr)
          child.setAttribute(attr, proxiedUrl(value))
        traverseNode(child, node)

xtnd.methodCall = (obj, name, caller, args) ->
  caller = obj
  if _guide.PASSTHROUGH
    return obj[name].apply(obj, args)
  # if name == 'addEventListener'
  #   if typeof(args[1]) == 'function'
  #     eventName = args[0]
  #     orig = args[1]
  #     mylistener = (evt) ->
  #       console.log eventName, evt
  #       orig(evt)
  #     args[1] = mylistener
  #   obj[name].apply(caller, args)
  if isLocation(obj) && isOneOf('replace', name)
    obj[name].apply(caller, [proxiedUrl(args[0])])
  else if isDocument(obj) && isOneOf('write writeln appendchild', name)
    xtnd.documentWriteHtmlParser ?= _guide.createHtmlParser()
    if name == 'writeln'
      document.writeln(xtnd.documentWriteHtmlParser(args[0]))
    else if name == 'write'
      document.write(xtnd.documentWriteHtmlParser(args[0]))
    else if name == 'appendchild'
      document.appendChild(args[0])
  if isXMLHttpRequest(obj)
    if name == 'open'
      [method, url, async, user, pass] = args
      obj.open(method, proxiedUrl(url), async, user, pass)
    else
      obj[name].apply(caller, args)
  else if isHtmlElement(obj) && isOneOf('setattribute getattribute appendchild', name)
    attrib = args[0]
    if name == 'setAttribute'
      if isOneOf('src href action', attrib)
        obj.setAttribute(attrib, proxiedUrl(args[1]))
      else
        obj[name].apply(caller, args)
    else if name == 'getAttribute'
      if isOneOf('src href action', attrib)
        obj.getAttribute(attrib, normalUrl(args[1]))
      else
        obj[name].apply(caller, args)
    else if name == 'appendChild'
      traverseNode(args[0])
      obj[name].apply(caller, args)
    else
      obj[name].apply(caller, args)
  else if obj.location && isOneOf('postmessage', name)
    obj.postMessage(args[0], proxiedUrl(args[1]))
  else
    obj[name].apply(caller, args)

xtnd.ActiveXObject = () ->
xtnd.ActiveXObject.prototype = (server, typeName, location) ->
  new ActiveXObject(proxiedUrl(server), typeName, location)

