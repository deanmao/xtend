express = require('express')
inspect = require('eyes').inspector(maxLength: 20000)
fs = require('fs')
xtendme = require './index'
global.XtndGuide = xtendme.Guide
EmptyGuide = require './empty_guide'

console.log('.') for i in [0..30]
key = fs.readFileSync('./ssl/key').toString()
cert = fs.readFileSync('./ssl/cert').toString()
sslOptions = {key: key, cert: cert}

guide = new EmptyGuide
  host: 'myapp.dev'
  fs: fs
  p: () -> inspect(arguments...)

configureServer = (server, guide, scripts, protocol) ->
  server.configure 'development', ->
    server.use(express.errorHandler(dumpExceptions: true, showStack: true))
  server.configure ->
    server.use(express.cookieParser())
    server.use(xtendme.filter(guide: guide, protocol: protocol, scripts: scripts))
    server.use(express.methodOverride())
    server.use(server.router)
  return server

xtendme.generateScripts __dirname + '/empty_guide.coffee', {host: 'myapp.dev'}, (scripts) ->
  http = express.createServer()
  https = express.createServer(sslOptions)
  configureServer(http, guide, scripts, 'http').listen(8080)
  configureServer(https, guide, scripts, 'https').listen(8443)
