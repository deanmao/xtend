app = require './lib/app'
gd = require('./lib/guide')
m8 = require('modul8')
coffee = require('coffee-script')
express = require('express')
mongoose = require('mongoose')
fs = require('fs')
RedditGuide = require('./reddit_guide')

pro = require("uglify-js").uglify
jsp = require("uglify-js").parser

mongoose.connect('mongodb://localhost/xtnd')

guide = new RedditGuide
  PRODUCTION: true
  host: 'xtendthis.com'
  p: () -> return

scriptSource = null
m8('./reddit_guide.coffee').register('.coffee', (code,bare) ->
  coffee.compile(code, {bare: bare})
).compile (code) ->
  ast = jsp.parse(code)
  ast = pro.ast_mangle(ast)
  ast = pro.ast_squeeze(ast)
  scriptSource = pro.gen_code(ast)

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
