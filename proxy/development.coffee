app = require './lib/app'
gd = require('./lib/guide')

app.setGuide(new gd.Guide(
  host: 'myapp.dev:3000'
  esprima: require('esprima')
  codegen: require('escodegen')
  htmlparser: require('htmlparser')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  html: require('./lib/html')
))

app.listen(3000)
