eyes = require "eyes"
exports.js = require "../lib/js"
exports.assert = require "assert"
exports.vows = require "vows"
exports.p = (x) -> eyes.inspect(x)
exports.esprima = require 'esprima'
exports.codegen = require '../lib/client/escodegen'
