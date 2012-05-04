request = require('request')
ProxyStream = require('./proxy_stream')

# This is a connect module that performs the remote request if the url
# is not an "internal" url.
#
# Internal urls begin with a path like: /x_t_n_d
#
# All other requests have their data stream & headers sent to the remote
# server, after being slightly modified.
module.exports = (options) ->
  guide = options.guide
  forceScriptSuffixRegExp = new RegExp(guide.FORCE_SCRIPT_SUFFIX, 'g')
  xhrSuffixRegExp = new RegExp(guide.XHR_SUFFIX, 'g')
  protocol = options.protocol
  xtnd = guide.xtnd
  returnVal = (req, res, next) ->
    originalUrl = req.originalUrl
    if req.url.match(/^\/x_t_n_d/)
      next()
    else
      isScript = false
      skip = false
      if originalUrl.indexOf(guide.FORCE_SCRIPT_SUFFIX) != -1
        originalUrl = originalUrl.replace(forceScriptSuffixRegExp, '')
        isScript = true
      if originalUrl.indexOf(guide.XHR_SUFFIX) != -1
        originalUrl = originalUrl.replace(xhrSuffixRegExp, '')
        skip = true
      url = xtnd.normalUrl(protocol, req.headers.host, originalUrl)
      host = xtnd.toNormalHost(req.headers.host)
      if guide.isProxyUrl(host)
        res.send('')
        return
      req.headers.host = host
      stream = new ProxyStream(req, res, guide, isScript, protocol, skip)
      remoteReq = request(
        url: url
        method: req.method
        followRedirect: false
        headers: req.headers
        jar: false
        pipefilter: (resp, dest) -> stream.pipefilter(resp, dest)
      )
      remoteReq.pause()
      remoteReq.pipe(stream)
      req.on 'data', (chunk) ->
        remoteReq.write(chunk)
      req.on 'end', ->
        remoteReq.end()
      remoteReq.resume()
