app = require './lib/app'
main = require './main'
express = require('express')
fs = require('fs')
RedditGuide = require('./reddit_guide')

guide = new RedditGuide
  PRODUCTION: true
  host: 'xtendthis.com'
  p: () -> return

main.generateScripts 'production', './reddit_guide.coffee', (scriptSource) ->
  http = express.createServer()
  http.configure 'production', ->
    http.use(express.errorHandler(dumpExceptions: false, showStack: false))
  app.configureServer(http, guide, scriptSource, 'http')
    .listen(8080)

  key = fs.readFileSync('/home/prod/ssl/xtendthis.key').toString()
  ca = fs.readFileSync('/home/prod/ssl/xtendthis.ca-bundle').toString()
  cert = fs.readFileSync('/home/prod/ssl/xtendthis.crt').toString()
  https = express.createServer(key: key, cert: cert, ca: ca)
  https.configure 'production', ->
    https.use(express.errorHandler(dumpExceptions: false, showStack: false))
  app.configureServer(https, guide, scriptSource, 'https')
    .listen(8443)
