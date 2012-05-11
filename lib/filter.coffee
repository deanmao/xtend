request = require('request')
ProxyStream = require('./proxy_stream')
BufferStream = require('bufferstream')

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
  protocol = options.protocol
  xtnd = guide.xtnd
  returnVal = (req, res, next) ->
    originalUrl = req.originalUrl
    if req.url.match(/^\/x_t_n_d/)
      next()
    else
      buffer = new BufferStream()
      req.pipe(buffer)
      buffer.pause()
      isScript = false
      skip = false
      if originalUrl.indexOf(guide.FORCE_SCRIPT_SUFFIX) != -1
        originalUrl = originalUrl.replace(forceScriptSuffixRegExp, '')
        isScript = true
      if req.headers['x-xtnd-xhr']
        skip = true
      url = xtnd.normalUrl(protocol, req.headers.host, originalUrl)
      host = xtnd.toNormalHost(req.headers.host)
      if guide.isProxyUrl(host)
        res.send('')
        return
      req.headers.host = host
      stream = new ProxyStream(req, res, guide, isScript, protocol, skip, url)
      stream.process =>
        remoteReq = request(
          url: url
          method: req.method
          followRedirect: false
          headers: stream.requestHeaders
          jar: false
          pipefilter: (resp, dest) -> stream.pipefilter(resp, dest)
        )
        res.setHeader('X-Original-Url', host + req.originalUrl)
        remoteReq.pause()
        remoteReq.pipe(stream)
        buffer.on 'data', (chunk) ->
          remoteReq.write(chunk)
          console.log(chunk.toString())
        buffer.on 'end', ->
          remoteReq.end()
        remoteReq.resume()
        buffer.resume()
