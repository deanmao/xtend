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

app.configure('development', ->
  app.use(express.errorHandler(dumpExceptions: true, showStack: true))
)

app.get('/x_t_n_d/:name', (req, res) ->
  name = req.params.name
  if name == 'scripts'
    m8('./lib/browser.coffee').register('.coffee', (code,bare) ->
      coffee.compile(code, {bare: bare})
    ).compile( (code) ->
      res.setHeader('Content-Type', 'application/x-javascript')
      res.send(code)
    )
  else
    res.send('')
)

app.all('*', (req, res) ->
  url = app.guide.xtnd.normalUrl('http', req.headers.host, req.originalUrl)
  req.headers.host = app.guide.xtnd.toNormalHost(req.headers.host)
  stream = new ProxyStream(req, res, app.guide)
  request({
    url: url
    method: req.method
    headers: req.headers
    pipefilter: (resp, dest) ->
      for own k,v of resp.headers
        do (k,v) ->
          stream.visitHeader(k, v, dest)
  }).pipe(stream)
)

