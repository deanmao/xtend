#!/usr/bin/env coffee

js = require('./lib/js')

code = """
function byId(id) {
  return document.getElementById(id);
}

function vote(node) {
  var v = node.id.split(/_/);   // {'up', '123'}
  var item = v[1];

  // hide arrows
  byId('up_'   + item).style.visibility = 'hidden';
  byId('down_' + item).style.visibility = 'hidden';

  // ping server
  var ping = new Image();
  ping.src = node.href;

  return false; // cancel browser nav
}
"""

esprima = require 'esprima'
codegen = require 'escodegen'
r = new js.Rewriter(esprima, codegen)

r1 = r.find('@x.@prop = @z')
  .replaceWith("xtnd.assign(@x, '@prop', @z)")
r1.name = 'abc'

r2 = r.find('blah(@x)')
  .replaceWith("xtnd")
r2.name = 'def'

console.log(r.convertToJs(code))
