express = require('express')
filter = require('./filter')

exports.configureServer = (app, guide, scripts, protocol) ->
  app.configure ->
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
      if typeof(scripts) == 'function'
        scripts(res)
      else
        res.send(scripts)
    else
      res.send('')
  return app

