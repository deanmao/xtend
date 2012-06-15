if typeof(window) != 'undefined'
  Guide = window.__xtnd_guide
else
  Guide = global.XtndGuide

class EmptyGuide extends Guide
  PRODUCTION: false
  DEBUG_REQ_HEADERS: true
  DEBUG_RES_HEADERS: true

if typeof(window) != 'undefined'
  options = require('data::options')
  guide = new EmptyGuide(options)
  window.xtnd = guide.xtnd
else
  module.exports = EmptyGuide

