express = require('express')
request = require('request')
coffee = require('coffee-script')
m8 = require('modul8')
ProxyStream = require('./proxy_stream')

app = module.exports = express.createServer()

guide = null
app.setGuide = (x) ->
  guide = x

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
      res.setHeader('content-type', 'application/javascript')
      res.send(code)
    )
)

app.all('*', (req, res) ->
  url = guide.xtnd.normalUrl('http', req.headers.host, req.originalUrl)
  headers = {}
  for own k,v of req.headers
    do (k,v) ->
      headers[k] = v
  headers.host = guide.xtnd.toNormalHost(req.headers.host)
  options = {headers: {}, type: 'binary'}
  stream = new ProxyStream(res, guide)
  request({
    url: url
    method: req.method
    headers: headers
    pipefilter: (resp, dest) ->
      for own k,v of resp.headers
        do (k,v) ->
          stream.setHeader(k, v)
  }).pipe(stream)
)

