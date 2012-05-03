app = require './lib/app'
gd = require('./lib/guide')
inspect = require('eyes').inspector(maxLength: 20000)
m8 = require('modul8')
fs = require('fs')
require('long-stack-traces')
coffee = require('coffee-script')
express = require('express')

guide = new gd.Guide(
  REWRITE_HTML: true
  REWRITE_JS: true
  # DEBUG_HEADERS: true
  host: 'myapp.dev'
  esprima: require('./lib/client/esprima')
  codegen: require('./lib/client/escodegen')
  htmlparser: require('./lib/client/htmlparser2')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  fs: fs
  html: require('./lib/html2')
  tester: require('./lib/client/property_tester')
  util: require('./lib/client/util')
  p: () -> inspect(arguments...)
)

# clear console 4465
console.log('.') for i in [0..30]

scripts = (res) ->
  m8('./lib/browser.coffee').register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    res.setHeader('Content-Type', 'application/x-javascript')
    res.send(code)

http = express.createServer()
http.configure 'development', ->
  http.use(express.errorHandler(dumpExceptions: true, showStack: true))
app.configureServer(http, guide, scripts, 'http')
  .listen(3000)

key = fs.readFileSync('./ssl/key').toString()
cert = fs.readFileSync('./ssl/cert').toString()
https = express.createServer(key: key, cert: cert)
https.configure 'development', ->
  https.use(express.errorHandler(dumpExceptions: true, showStack: true))
app.configureServer(https, guide, scripts, 'https')
  .listen(3443)
