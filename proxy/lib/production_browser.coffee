gd = require('./guide')
htmlparser = require('./client/htmlparser2')
esprima = require('./client/esprima')
codegen = require('./client/escodegen')
xtnd = require('./xtnd')
js = require('./js')
html = require('./html2')
tester = require('./client/property_tester')
util = require('./client/util')

guide = new gd.Guide(
  host: 'xtendthis.com'
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
