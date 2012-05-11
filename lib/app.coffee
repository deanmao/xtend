express = require('express')
filter = require('./filter')
connect = require('connect')
Session = require('connect-mongodb')

lastModifiedString = new Date().toString()
exports.configureServer = (app, guide, scripts, protocol) ->
  app.configure ->
    app.use(express.cookieParser())
    app.use(
      express.session(
        key: 'xtnd.sid'
        cookie:
          domain: '.'+guide.host
        secret: 'you have to go there'
        store: new Session(url: 'mongodb://localhost/xtnd')
      )
    )
    app.use(filter(guide: guide, protocol: protocol))
    app.use(express.methodOverride())
    app.use(app.router)

  # deny robots from scraping anything
  app.get '/robots.txt', (req, res) ->
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.send("User-agent: *\nDisallow: /\n")

  app.get '/x_t_n_d/:name', (req, res) ->
    name = req.params.name
    if name == 'scripts'
      res.setHeader('Content-Type', 'text/javascript; charset=UTF-8')
      res.setHeader('Last-Modified', lastModifiedString)
      if typeof(scripts) == 'function'
        scripts(res)
      else
        res.send(scripts)
    else
      res.send('')
  return app

