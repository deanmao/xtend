if typeof(window) != 'undefined'
  Guide = window.__xtnd_guide
else
  Guide = global.XtndGuide

class EmptyGuide extends Guide
  PRODUCTION: false

if typeof(window) != 'undefined'
  guide = new EmptyGuide(host: 'myapp.dev')
  window.xtnd = guide.xtnd
else
  module.exports = EmptyGuide

