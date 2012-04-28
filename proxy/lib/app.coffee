express = require('express')
request = require('request')

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
    # send one giant js with everything needed
    res.send('asdf  33')
)

app.all('*', (req, res) ->
  url = guide.xtnd.normalUrl('http', req.headers.host, req.originalUrl)
  headers = {}
  for own k,v of req.headers
    do (k,v) ->
      headers[k] = v
  headers.host = guide.xtnd.toNormalHost(req.headers.host)
  request({
    url: url
    method: req.method
    headers: headers
  }, (err, resp, body) ->
    for own k,v of resp.headers
      do (k,v) ->
        res.setHeader(k, v)
    res.status(resp.statusCode)
    # check content type and covert js/html, or just send body if neither
    res.send(body)
  )
)

