express = require('express')
filter = require('./filter')

exports.configureServer = (app, guide, scripts, protocol) ->
  app.configure ->
    app.use(express.cookieParser())
    app.use(filter(guide: guide, protocol: protocol, scripts: scripts))
    app.use(express.methodOverride())
    app.use(app.router)

  return app

