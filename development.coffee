app = require './lib/app'
main = require './main'
inspect = require('eyes').inspector(maxLength: 20000)
fs = require('fs')
express = require('express')

# clear console 4465
console.log('.') for i in [0..30]

main.generateScripts 'development', './basic_guide.coffee', (scripts) ->
  http = express.createServer()
  http.configure 'development', ->
    http.use(express.errorHandler(dumpExceptions: true, showStack: true))
  app.configureServer(http, guide, scripts, 'http')
    .listen(8080)

  key = fs.readFileSync('./ssl/key').toString()
  cert = fs.readFileSync('./ssl/cert').toString()
  https = express.createServer(key: key, cert: cert)
  https.configure 'development', ->
    https.use(express.errorHandler(dumpExceptions: true, showStack: true))
  app.configureServer(https, guide, scripts, 'https')
    .listen(8443)
