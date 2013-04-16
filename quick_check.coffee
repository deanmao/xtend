#!/usr/bin/env coffee

# quick file for testing, run like this:
# ./quick_check.coffee example.js
# ./quick_check.coffee example.html
# ./quick_check.coffee example.js --manual

argv = require('optimist').argv
inspect = require('eyes').inspector(maxLength: 300000)
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
<h1>something</h1>
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
    BUFFER_WHOLE_HTML: true
    # htmlparser: require('hubbub')
    htmlparser: require('./lib/client/parser2_wrapper')
    fs: require('fs')
    host: 'myapp.dev'
    esprima: esprima
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
    tester = require './lib/client/property_tester'
    esprima.parse(code)
    # convertPropertyToLiteral = (binding, node) ->
    #   if node.name == 'prop'
    #     if binding.type == 'Identifier'
    #       {type: 'Literal', value: binding.name}
    # r = new js.Rewriter(esprima, codegen)
    # rule = r.find('try { @stmts+ } catch (@e) { @cstmts+ }', (name, node) ->
    #   if name == 'cstmts' && node.length == 0
    #     return false
    #   return true
    # ).replaceWith('try { @stmts+ } catch (@e) { console.log(@e); {@cstmts+} }')
    # inspect rule.detect
    # console.log(r.convertToJs(code))
