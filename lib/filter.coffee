request = require('request')
express = require('express')
mongoose = require('mongoose')
ProxyStream = require('./proxy_stream')
BufferStream = require('bufferstream')
Session = require('connect-mongodb')

# This is a connect module that performs the remote request if the url
# is not an "internal" url.
#
# Internal urls begin with a path like: /___xtnd
#
# All other requests have their data stream & headers sent to the remote
# server, after being slightly modified.
module.exports = (options) ->
  guide = options.guide
  forceScriptSuffixRegExp = new RegExp(guide.FORCE_SCRIPT_SUFFIX, 'g')
  lastModifiedString = new Date().toString()
  protocol = options.protocol
  xtnd = guide.xtnd
  scripts = options.scripts
  cookieKey = options.cookieKey || 'xtnd.sid'
  cookieSecret = options.cookieSecret || 'blah blah you have to go there'
  mongoUrl = options.mongoUrl || 'mongodb://localhost/xtnd'
  mongoose.connect(mongoUrl)
  sessionFunc = express.session(
    key: cookieKey
    cookie:
      domain: '.'+guide.host
    secret: cookieSecret
    store: new Session(url: mongoUrl)
  )
  returnVal = (req, res, next) ->
    sessionFunc req, res, ->
      originalUrl = req.originalUrl
      if req.url.indexOf(guide.INTERNAL_URL_PREFIX) != -1
        if req.url.match(/xtnd_scripts.js/)
          res.setHeader('Content-Type', 'text/javascript; charset=UTF-8')
          res.setHeader('Last-Modified', lastModifiedString)
          if typeof(scripts) == 'function'
            scripts(res)
          else
            res.send(scripts)
        else
          next()
      else if req.url == '/robots.txt'
        res.setHeader('Content-Type', 'text/plain; charset=utf-8')
        res.send("User-agent: *\nDisallow: /\n")
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
