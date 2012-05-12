exports.filter = require('./lib/filter')
exports.Guide = require('./lib/guide').Guide
m8 = require('modul8')
pro = require("uglify-js").uglify
jsp = require("uglify-js").parser
coffee = require('coffee-script')
DnsServer = require('./lib/dns_server').DnsServer

compact = (path, cb) ->
  m8(path).register('.coffee', (code,bare) ->
    coffee.compile(code, {bare: bare})
  ).compile (code) ->
    cb(code)

uglify = (code) ->
  ast = jsp.parse(code)
  ast = pro.ast_mangle(ast)
  ast = pro.ast_squeeze(ast)
  pro.gen_code(ast)

exports.generateScripts = (path, callback) ->
  if 'production' == process.env.NODE_ENV
    compact __dirname + '/lib/guide.coffee', (baseCode) ->
      compact path, (customCode) ->
        callback(uglify(baseCode) + uglify(customCode))
  else
    generator = (res) ->
      compact __dirname + '/lib/guide.coffee', (baseCode) ->
        compact path, (customCode) ->
          res.send(baseCode + customCode)
    callback(generator)

exports.dns = (host) ->
  pattern = new RegExp(host)
  server = new DnsServer(
    dnsDomainPattern: pattern
    timeout: (15 * 60)
  )
  console.log('starting dns...')
  server.listen(20561)
