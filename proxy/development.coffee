app = require './lib/app'
gd = require('./lib/guide')

app.guide = new gd.Guide(
  REWRITE_HTML: true
  REWRITE_JS: true
  host: 'myapp.dev:3000'
  esprima: require('esprima')
  codegen: require('./lib/client/escodegen')
  htmlparser: require('htmlparser')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  fs: require('fs')
  html: require('./lib/html')
)

app.listen(3000)
