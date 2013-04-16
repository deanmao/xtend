exports.filter = require('./lib/filter')
exports.Guide = require('./lib/guide').Guide
m8 = require('modul8')
pro = require("uglify-js").uglify
jsp = require("uglify-js").parser
coffee = require('coffee-script')
DnsServer = require('./lib/dns_server').DnsServer

exports.Handler = require('./lib/handler').Handler
exports.BasicHandler = require('./lib/basic_handler').BasicHandler
exports.HtmlRewriter = require('./lib/html_rewriter').HtmlRewriter
exports.JsRewriter = require('./lib/js_rewriter').JsRewriter

compact = (filepath, options, cb) ->
  m8(filepath).data().add('options', options).register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    cb(code)

uglify = (code) ->
  ast = jsp.parse(code)
  ast = pro.ast_mangle(ast)
  ast = pro.ast_squeeze(ast)
  pro.gen_code(ast)

exports.generateScripts = (filepath, options, callback) ->
  if 'production' == process.env.NODE_ENV
    compact __dirname + '/lib/guide.coffee', {}, (baseCode) ->
      compact filepath, options, (customCode) ->
        callback(uglify(baseCode + customCode))
  else
    generator = (res) ->
      compact __dirname + '/lib/guide.coffee', {}, (baseCode) ->
        compact filepath, options, (customCode) ->
          res.send(baseCode + '\n' + customCode)
    callback(generator)

exports.dns = (host) ->
  pattern = new RegExp(host)
  server = new DnsServer(
    dnsDomainPattern: pattern
    timeout: (15 * 60)
  )
  console.log('starting dns...')
  server.listen(20561)
