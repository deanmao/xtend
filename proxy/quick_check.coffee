#!/usr/bin/env coffee

# quick file for testing, run like this:
# ./quick_check.coffee example.js
# ./quick_check.coffee example.html
# ./quick_check.coffee example.js --manual

argv = require('optimist').argv
filename = argv._[0]
if filename.match(/\.js$/)
  parseJs = true
else if filename.match(/\.html$/)
  parseHtml = true

if argv.manual
  useManual = true

console.log('using '+filename)
fs = require("fs")
code = fs.readFileSync(filename, 'utf8')

unless useManual
  gd = require "./lib/guide"
  inspect = require('eyes').inspector(maxLength: 20000)
  guide = new gd.Guide(
    REWRITE_HTML: true
    REWRITE_JS: true
    fs: require('fs')
    host: 'myapp.dev:3000'
    esprima: require('esprima')
    codegen: require('escodegen')
    htmlparser: require('htmlparser')
    xtnd: require('./lib/xtnd')
    js: require('./lib/js')
    html: require('./lib/html')
    p: () -> inspect(arguments...)
  )
  if parseHtml
    console.log(guide.convertHtml(code))
  else if parseJs
    console.log(guide.convertJs(code))
else
  js = require('./lib/js')
  esprima = require 'esprima'
  codegen = require 'escodegen'
  r = new js.Rewriter(esprima, codegen)
  # r1 = r.find('@x.@prop = [@z+]')
  #   .replaceWith("xtnd.assign(@x, '@prop', [@z+])")
  # r1.name = 'abc'
  console.log(r.convertToJs(code))

