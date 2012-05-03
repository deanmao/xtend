gd = require('./guide')
htmlparser = require('./client/htmlparser')
esprima = require('./client/esprima')
codegen = require('./client/escodegen')
xtnd = require('./xtnd')
js = require('./js')
html = require('./html')
tester = require('./client/property_tester')
util = require('./client/util')

guide = new gd.Guide(
  host: 'myapp.dev'
  esprima: esprima
  codegen: codegen
  htmlparser: htmlparser
  tester: tester
  xtnd: xtnd
  js: js
  html: html
  util: util
)

window.xtnd = guide.xtnd
