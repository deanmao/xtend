express = require('express')
request = require('request')
coffee = require('coffee-script')
m8 = require('modul8')
ProxyStream = require('./proxy_stream')
eyes = require "eyes"
p = (x) -> eyes.inspect(x)
require('long-stack-traces')
fs = require('fs')

# clear console 4465
console.log('.') for i in [0..30]

# FYI: this must be set to a new guide instance before
# runtime
_guide = null
exports.setGuide = (x) ->
  _guide = x

sendScripts = (res) ->
  m8('./lib/browser.coffee').register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    res.setHeader('Content-Type', 'application/x-javascript')
    res.send(code)

configureServer = (app, protocol) ->
  app.configure ->
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(app.router)

  app.configure 'development', ->
    app.use(express.errorHandler(dumpExceptions: true, showStack: true))

  # deny robots from scraping anything
  app.get '/robots.txt', (req, res) ->
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.send("User-agent: *\nDisallow: /\n")

  app.get '/x_t_n_d/:name', (req, res) ->
    name = req.params.name
    if name == 'scripts'
      sendScripts(res)
    else
      res.send('')

  # For now, don't do any try/catch statements so that all errors
  # will bubble up to the top so we can see :-)
  app.all '*', (req, res) ->
    xtnd = _guide.xtnd
    # TODO: we shouldn't be using the host header, but it's okay for now.
    # -- there are cases when we don't have any headers
    originalUrl = req.originalUrl
    isScript = false
    if originalUrl.indexOf(_guide.FORCE_SCRIPT_SUFFIX) != -1
      originalUrl = originalUrl.replace(_guide.FORCE_SCRIPT_SUFFIX, '')
      isScript = true
    url = xtnd.normalUrl(protocol, req.headers.host, originalUrl)
    req.headers.host = xtnd.toNormalHost(req.headers.host)
    stream = new ProxyStream(req, res, _guide)
    request(
      url: url
      method: req.method
      followRedirect: false
      body: req.param.body
      headers: req.headers
      jar: false # TODO
      pipefilter: (resp, dest) -> stream.pipefilter(resp, dest)
    ).pipe(stream)

  return app

exports.http = configureServer(express.createServer(), 'http')
key = fs.readFileSync('./ssl/key').toString()
cert = fs.readFileSync('./ssl/cert').toString()
exports.https = configureServer(express.createServer(key: key, cert: cert), 'https')
