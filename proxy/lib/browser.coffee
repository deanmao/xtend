gd = require('./guide')

guide = new gd.Guide(
  host: 'myapp.dev:3000'
  esprima: require('./client/esprima')
  codegen: require('./client/escodegen')
  htmlparser: require('./client/htmlparser')
  xtnd: require('./xtnd')
  js: require('./js')
  html: require('./html')
)

window.xtnd = guide.xtnd
