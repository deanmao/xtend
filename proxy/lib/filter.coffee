request = require('request')
ProxyStream = require('./proxy_stream')

module.exports = (options) ->
  guide = options.guide
  protocol = options.protocol
  xtnd = guide.xtnd
  returnVal = (req, res, next) ->
    originalUrl = req.originalUrl
    if req.url.match(/^\/x_t_n_d/)
      next()
    else
      isScript = false
      if originalUrl.indexOf(guide.FORCE_SCRIPT_SUFFIX) != -1
        originalUrl = originalUrl.replace(guide.FORCE_SCRIPT_SUFFIX, '')
        isScript = true
      url = xtnd.normalUrl(protocol, req.headers.host, originalUrl)
      req.headers.host = xtnd.toNormalHost(req.headers.host)
      stream = new ProxyStream(req, res, guide, isScript, protocol)
      remoteReq = request(
        url: url
        method: req.method
        followRedirect: false
        headers: req.headers
        jar: false
        pipefilter: (resp, dest) -> stream.pipefilter(resp, dest)
      ).pipe(stream)
      req.on 'data', (chunk) ->
        remoteReq.emit 'data', chunk
      req.on 'end', ->
        remoteReq.emit 'end'
