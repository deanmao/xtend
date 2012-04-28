xtnd = exports

_guide = null
_components = /^(https?):\/\/([^\/]*)(.*)$/

parts = (url) ->
  x = (url || '').match(_components) || []
  [x[1], x[2], x[3]]

xtnd.setGuide = (guide) ->
  _guide = guide

toProxiedHost = xtnd.toProxiedHost = (host) ->
  host.replace(/\-/g, '--').replace(/\./g, '-') + '.' + _guide.host

toNormalHost = xtnd.toNormalHost = (proxiedHost) ->
  subdomain = proxiedHost.split('.')[0]
  subdomain.replace(/\-/g, '.').replace(/\.\./g, '-')

xtnd.proxiedUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    [protocol, host, path] = parts(protocol)
  if host
    return protocol + '://' + toProxiedHost(host) + path
  else
    return orig

xtnd.normalUrl = (protocol, host, path) ->
  if 1 == arguments.length
    orig = protocol
    [protocol, host, path] = parts(protocol)
  if host
    return protocol + '://' + toNormalHost(host) + path
  else
    return orig

xtnd.proxiedJS = (code) ->
  _guide.convertJs(code)

xtnd.proxiedHtml = (code) ->
  _guide.convertHtml(code)

xtnd.assign = (obj, property, value) ->

xtnd.appendAssign = (obj, property, value) ->

xtnd.eval = (code) ->

xtnd.methodCall = (name, callee, context) ->

xtnd.ActiveXObject = () ->

