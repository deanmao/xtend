gd = require('./guide')
htmlparser = require('./client/htmlparser')
esprima = require('./client/esprima')
codegen = require('./client/escodegen')
xtnd = require('./xtnd')
js = require('./js')
html = require('./html')

guide = new gd.Guide(
  host: 'myapp.dev:3000'
  esprima: esprima
  codegen: codegen
  htmlparser: htmlparser
  xtnd: xtnd
  js: js
  html: html
)

window.xtnd = guide.xtnd
window.xtnd_assign = guide.xtnd.assign
