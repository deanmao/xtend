express = require('express')
request = require('request')
coffee = require('coffee-script')
m8 = require('modul8')
ProxyStream = require('./proxy_stream')
eyes = require "eyes"
p = (x) -> eyes.inspect(x)

app = module.exports = express.createServer()

# clear console
console.log('.') for i in [0..30]

# FYI: this must be set to a new guide instance before
# runtime
app.guide = null

app.configure ->
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(app.router)

app.configure 'development', ->
  app.use(express.errorHandler(dumpExceptions: true, showStack: true))

sendScripts = (res) ->
  m8('./lib/browser.coffee').register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    res.setHeader('Content-Type', 'application/x-javascript')
    res.send(code)

app.get '/x_t_n_d/:name', (req, res) ->
  name = req.params.name
  if name == 'scripts'
    sendScripts(res)
  else
    res.send('')

app.all '*', (req, res) ->
  try
    xtnd = app.guide.xtnd
    # TODO: we shouldn't be using the host header, but it's okay for now.
    # -- there are cases when we don't have any headers
    url = xtnd.normalUrl('http', req.headers.host, req.originalUrl)
    req.headers.host = xtnd.toNormalHost(req.headers.host)
    stream = new ProxyStream(req, res, app.guide)
    request(
      url: url
      method: req.method
      followRedirect: false
      body: req.param.body
      headers: req.headers
      jar: false # TODO
      pipefilter: (resp, dest) ->
        for own k,v of resp.headers
          do (k,v) ->
            val = stream.visitResponseHeader(k?.toLowerCase(), v)
            if val
              res.header(k, val)
            else
              res.removeHeader(k)
        res.statusCode = resp.statusCode
        stream.choosePipe()
    ).pipe(stream)
  catch error
    console.log(error)

