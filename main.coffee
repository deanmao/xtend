exports.filter = require('./lib/filter')
exports.Guide = require('./lib/guide').Guide
m8 = require('modul8')
pro = require("uglify-js").uglify
jsp = require("uglify-js").parser
coffee = require('coffee-script')

exports.generateScripts = (mode, path, callback) ->
  if mode == 'production'
    m8(path).register('.coffee', (code,bare) ->
      coffee.compile(code, {bare: bare})
    ).compile (code) ->
      ast = jsp.parse(code)
      ast = pro.ast_mangle(ast)
      ast = pro.ast_squeeze(ast)
      scriptSource = pro.gen_code(ast)
      callback(scriptSource)
  else
    scripts = (res) ->
      m8(path).register('.coffee', (code,bare) ->
        coffee.compile(code, {bare: bare})
      ).compile (code) ->
        res.send(code)
    callback(scripts)
