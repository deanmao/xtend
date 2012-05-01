xtnd = exports

_guide = null
_components = /^(https?):\/\/([^\/]*)(.*)$/

listToHash = (str) ->
  hash = {}
  str.replace /\w+/g, (x) ->
    hash[x.toLowerCase()] = true
  hash

isOneOf = (list, property) ->
  matcher = isOneOf.matchers[list]
  unless matcher
    isOneOf.matchers[list] = listToHash(list)
    matcher = isOneOf.matchers[list]
  property && matcher[property.toLowerCase()]

parts = (url) ->
  x = (url || '').match(_components) || []
  [x[1], x[2], x[3]]

xtnd.setGuide = (guide) ->
  xtnd._guide = guide
  _guide = guide

# 4465
toProxiedHost = xtnd.toProxiedHost = (host) ->
  host.replace(/\-/g, '--').replace(/\./g, '-') + '.' + _guide.host

toNormalHost = xtnd.toNormalHost = (proxiedHost) ->
  subdomain = proxiedHost.split('.')[0]
  subdomain.replace(/\-/g, '.').replace(/\.\./g, '-')

proxiedUrl = xtnd.proxiedUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    [protocol, host, path] = parts(protocol)
  if host
    return protocol + '://' + toProxiedHost(host) + path
  else
    return orig

normalUrl = xtnd.normalUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    [protocol, host, path] = parts(protocol)
  if host
    return protocol + '://' + toNormalHost(host) + path
  else
    return orig

xtnd.proxiedJS = (code) -> _guide.convertJs(code)
xtnd.proxiedHtml = (code) -> _guide.convertHtml(code)

isLocation = (x) -> x && x.constructor == window.location.constructor
isDocument = (x) -> x && x.constructor == window.document.constructor
isWindow = (x) -> x && x.constructor == window.constructor
isHtmlElement = (x) -> x?.nodeName && x?.nodeType
isXMLHttpRequest = (x) -> x && x.constructor == XMLHttpRequest

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
        obj[property] = xtnd.proxiedHtml(value)
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

xtnd.methodCall = (obj, name, caller, args) ->
  if _guide.PASSTHROUGH
    return obj[name].apply(obj, args)
  if isDocument(obj) && isOneOf('write writeln', name)
    # TODO: handle document.write here...
    if name == 'writeln'
      document.writeln(args[0])
    else
      document.write(args[0])
  if isXMLHttpRequest(obj)
    if name == 'open'
      [method, url, async, user, pass] = args
      obj.setRequestHeader('X-Xtnd-XHR', url)
      obj.open(method, proxiedUrl(url), async, user, pass)
    else
      obj[name].apply(caller, args)
  else if isHtmlElement(obj) && isOneOf('setattribute getattribute', name)
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
    else
      obj[name].apply(caller, args)
  else
    obj[name].apply(caller, args)

