#!/usr/bin/env coffee

# quick file for testing, run like this:
# ./quick_check.coffee example.js
# ./quick_check.coffee example.html
# ./quick_check.coffee example.js --manual

argv = require('optimist').argv
inspect = require('eyes').inspector(maxLength: 20000)
filename = argv._[0]
if !filename
  useManual = true
else if filename.match(/\.js$/)
  parseJs = true
else if filename.match(/\.html$/)
  parseHtml = true

if argv.manual
  useManual = true

if filename
  fs = require("fs")
  code = fs.readFileSync(filename, 'utf8')
else
  code = """
a.b = c.d = e.f = g.h;
  """

class Handler
  reset: ->
  done: ->
  write: (node) ->
    console.log(node)
  error: ->

unless useManual
  gd = require "./lib/guide"
  esprima = require('./lib/client/esprima')
  guide = new gd.Guide(
    REWRITE_HTML: true
    REWRITE_JS: true
    fs: require('fs')
    host: 'myapp.dev'
    esprima: esprima
    codegen: require('./lib/client/escodegen')
    htmlparser: require('./lib/client/htmlparser2')
    xtnd: require('./lib/xtnd')
    js: require('./lib/js')
    html: require('./lib/html2')
    tester: require('./lib/client/property_tester')
    util: require('./lib/client/util')
    p: () -> inspect(arguments...)
  )
  if parseHtml
    console.log(guide.convertHtml(code))
  else if parseJs
    console.log(guide.convertJs(code))
else
  if parseHtml
    htmlparser = require('./lib/client/htmlparser2')
    handler = new Handler()
    parser = new htmlparser.Parser(handler)
    parser.parseComplete(code)
  else
    js = require('./lib/js')
    esprima = require('./lib/client/esprima')
    codegen = require './lib/client/escodegen'
    r = new js.Rewriter(esprima, codegen)
    r.find('@obj.@method(@args+)')
      .replaceWith "xtnd.methodCall(@obj, @method, this, [@args+])", (binding, node) ->
        if node.name == 'method' && binding.type == 'Identifier'
          {type: 'Literal', value: binding.name}
    console.log(r.convertToJs(code, {newline: '', indent: ''}))
