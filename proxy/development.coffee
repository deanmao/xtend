app = require './lib/app'
gd = require('./lib/guide')
inspect = require('eyes').inspector(maxLength: 20000)

app.guide = new gd.Guide(
  REWRITE_HTML: true
  REWRITE_JS: true
  host: 'myapp.dev:3000'
  esprima: require('./lib/client/esprima')
  codegen: require('./lib/client/escodegen')
  htmlparser: require('./lib/client/htmlparser')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  fs: require('fs')
  html: require('./lib/html')
  p: () -> inspect(arguments...)
)

app.listen(3000)
