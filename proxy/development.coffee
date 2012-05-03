app = require './lib/app'
gd = require('./lib/guide')
inspect = require('eyes').inspector(maxLength: 20000)

app.setGuide(new gd.Guide(
  REWRITE_HTML: true
  REWRITE_JS: true
  host: 'myapp.dev'
  esprima: require('./lib/client/esprima')
  codegen: require('./lib/client/escodegen')
  htmlparser: require('./lib/client/htmlparser2')
  xtnd: require('./lib/xtnd')
  js: require('./lib/js')
  fs: require('fs')
  html: require('./lib/html2')
  tester: require('./lib/client/property_tester')
  util: require('./lib/client/util')
  p: () -> inspect(arguments...)
))

app.http.listen(3000)
app.https.listen(3443)
