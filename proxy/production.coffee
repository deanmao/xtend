app = require './lib/app'
gd = require('./lib/guide')
m8 = require('modul8')
coffee = require('coffee-script')
express = require('express')
mongoose = require('mongoose')
fs = require('fs')

pro = require("uglify-js").uglify
jsp = require("uglify-js").parser

mongoose.connect('mongodb://localhost/xtnd')

guide = new gd.Guide(
  PRODUCTION: true
  host: 'xtendthis.com'
  esprima: require('./lib/client/esprima')
  codegen: require('./lib/client/escodegen')
  htmlparser: require('./lib/client/htmlparser2')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  html: require('./lib/html2')
  tester: require('./lib/client/property_tester')
  util: require('./lib/client/util')
  p: () -> return
)

scriptSource = null
m8('./lib/production_browser.coffee').register('.coffee', (code,bare) ->
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
