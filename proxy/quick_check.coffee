#!/usr/bin/env coffee

js = require('./lib/js')

code = """
a.b.c.d.e.f.g.h.i.j = [1,2,3,4,5]
"""

esprima = require 'esprima'
codegen = require 'escodegen'
r = new js.Rewriter(esprima, codegen)

r1 = r.find('@x.@prop = [@z+]')
  .replaceWith("xtnd.assign(@x, '@prop', [@z+])")
r1.name = 'abc'

console.log(r.convertToJs(code))
