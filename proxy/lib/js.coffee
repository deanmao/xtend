# if typeof(exports) != 'undefined'
#   eyes = require "eyes"
#   p = (x) -> eyes.inspect(x)

traverse = exports.traverse = (object, visitor, parent, key) ->
  if visitor.call(null, object, parent, key) == false
    return
  for key,child of object
    do (key, child) =>
      if typeof child == 'object' && child
        traverse(child, visitor, object, key)

class Rewriter
  constructor: (esprima, codegen, guide) ->
    @esprima = esprima
    @codegen = codegen
    @guide = guide
    @ruleCache = {}
    @rules = []

  find: (patternStr, checker) ->
    rule = @ruleCache[patternStr]
    unless rule
      rule = new Rule(patternStr, checker, @esprima)
      @rules[@rules.length] = rule
      @ruleCache[patternStr] = rule
    rule

  convert: (js) ->
    if @guide?.JS_DEBUG
      root = @esprima.parse(js, {loc: true})
    else
      root = @esprima.parse(js)
    traverse(root, (node, parent, key) =>
      matchingRule = null
      for rule in @rules
        do (rule) =>
          unless matchingRule
            bindings = {}
            if rule.match(node, bindings, parent, key)
              matchingRule = rule
              matchingRule.bindings = bindings
      if matchingRule
        parent[key] = matchingRule.sub()
        return false
      else
        return true
    )
    root

  convertToJs: (js) ->
    @codegen.generate(@convert(js))

namePrefix = 'xtend_pattern__'
Hole =
  Optional: 'optional'
  OneOrMore: 'one_or_more'
  Multiple: 'multiple'

toSpecialName = (str) ->
  parts = str.match(/@(\w+)([\+\*\?]?)/)
  name = parts[1]
  holeSym  = parts[2]
  hole = ''
  if holeSym
    if holeSym == '?'
      hole = Hole.Optional
    else if holeSym == '+'
      hole = Hole.OneOrMore
    else if holeSym == '*'
      hole = Hole.Multiple
    namePrefix+name+'__'+hole
  else
    namePrefix+name

fromSpecialName = (str) ->
  if str && str.match(namePrefix)
    val = str.replace(namePrefix, '')
    hole = val.match(/__(optional|one_or_more|multiple)$/)?[1]
    if hole
      name = val.replace('__'+hole, '')
    else
      name = val
    return {name: name, hole: hole}
  else
    return null

clone = (obj) ->
  JSON.parse(JSON.stringify(obj))

class Rule
  constructor: (patternStr, checker, esprima) ->
    @esprima = esprima
    @detect = @_process(patternStr)
    @checker = checker

  _process: (js) ->
    js = js.replace(/@\w+[\+\*\?]?/g, toSpecialName)
    tree = @esprima.parse(js)
    traverse(tree, (node, parent, key) =>
      if node.name?.match(namePrefix)
        {name, hole} = fromSpecialName(node.name)
        node.name = name
        node.hole = hole if hole
        node.fuzzy = true
    )
    tree.body[0]

  # returns true if we don't have rule matching function, or if the matching
  # function returns true
  check: (name, node, bindings) ->
    if !@checker || @checker(name, node)
      bindings[name] = node
      return true
    else
      return false

  # node = current tree node in the source
  # bindings = name to node mappings
  # parent = parent of the node
  # key = parent[key] == node
  # nodeBP = node blueprint from the rule descriptor
  match: (node, bindings, parent, key, nodeBP) ->
    nodeBP = @detect unless nodeBP
    if nodeBP.constructor == Array && nodeBP[0]?.fuzzy && nodeBP[0]?.hole
      return @check(nodeBP[0].name, node, bindings)
    else if nodeBP.fuzzy && !nodeBP.hole
      return @check(nodeBP.name, node, bindings)
    else if @equals(node, nodeBP)
      isMatching = true
      for key,child of node
        do (key, child) =>
          if typeof(child) == 'object' && child != null && nodeBP[key]
            isMatching = isMatching && @match(child, bindings, parent, key, nodeBP[key])
      return isMatching
    else
      return false

  equals: (node1, node2) ->
    node1.type == node2.type &&
      node1.value == node2.value &&
      node1.computed == node2.computed &&
      node1.prefix == node2.prefix &&
      node1.operator == node2.operator &&
      node1.kind == node2.kind &&
      node1.name == node2.name

  # bindingConversion should return null if it doesn't want to convert
  # anything
  _convertBinding: (binding, node) ->
    @bindingConversion?(binding, node) || binding

  sub: () ->
    # create a clone of substitution, replacing fuzzy nodes with values from bindings
    tree = clone(@substitution)
    traverse(tree, (node, parent, key) =>
      binding = @bindings[node.name]
      if node.fuzzy && parent && key && binding
        if parent.constructor == Array && node.hole
          i = parseInt(key)
          for item in binding
            do (item) =>
              parent[i] = @_convertBinding(item, node)
              i = i + 1
        else
          parent[key] = @_convertBinding(binding, node)
    )
    @bindings = null
    tree

  replaceWith: (patternStr, bindingConversion) ->
    @substitution = @_process(patternStr)
    @bindingConversion = bindingConversion
    @

exports.Rule = Rule
exports.Rewriter = Rewriter
