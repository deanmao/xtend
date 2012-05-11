app = require './lib/app'
inspect = require('eyes').inspector(maxLength: 20000)
m8 = require('modul8')
fs = require('fs')
coffee = require('coffee-script')
express = require('express')
mongoose = require('mongoose')
RedditGuide = require('./reddit_guide')

mongoose.connect('mongodb://localhost/xtnd')

guide = new RedditGuide
  host: 'myapp.dev'
  fs: fs
  p: () -> inspect(arguments...)

# clear console 4465
console.log('.') for i in [0..30]

scripts = (res) ->
  m8('./reddit_guide.coffee').register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    res.send(code)

http = express.createServer()
http.configure 'development', ->
  http.use(express.errorHandler(dumpExceptions: true, showStack: true))
app.configureServer(http, guide, scripts, 'http')
  .listen(8000)

key = fs.readFileSync('./ssl/key').toString()
cert = fs.readFileSync('./ssl/cert').toString()
https = express.createServer(key: key, cert: cert)
https.configure 'development', ->
  https.use(express.errorHandler(dumpExceptions: true, showStack: true))
app.configureServer(https, guide, scripts, 'https')
  .listen(8443)
