# if typeof(exports) != 'undefined'
#   eyes = require "eyes"
#   p = (x) -> eyes.inspect(x)

traverse = (object, visitor, parent, key) ->
  if visitor.call(null, object, parent, key) == false
    return
  for key,child of object
    do (key, child) =>
      if typeof child == 'object' && child
        traverse(child, visitor, object, key)

class Rewriter
  ruleCache: {}
  rules: []
  constructor: (esprima, codegen) ->
    @esprima = esprima
    @codegen = codegen

  find: (patternStr, checker) ->
    rule = @ruleCache[patternStr]
    unless rule
      rule = new Rule(patternStr, checker, @esprima)
      @rules[@rules.length] = rule
      @ruleCache[patternStr] = rule
    rule

  convert: (js) ->
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
      if node.type == 'Literal' && node.value?.match(namePrefix)
        {name, hole} = fromSpecialName(node.value)
        node.name = name
        node.value = name
        node.hole = hole if hole
        node.fuzzy = true
      else if node.name?.match(namePrefix)
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
      node1.name == node2.name

  sub: () ->
    # create a clone of substitution, replacing fuzzy nodes with values from bindings
    tree = clone(@substitution)
    traverse(tree, (node, parent, key) =>
      if node.fuzzy && parent && key && @bindings[node.name]
        if node.type == 'Literal'
          parent[key].value = @bindings[node.name].name
        else if parent.constructor == Array && node.hole
          i = parseInt(key)
          for item in @bindings[node.name]
            do (item) ->
              parent[i] = item
              i = i + 1
        else
          parent[key] = @bindings[node.name]
    )
    @bindings = null
    tree

  replaceWith: (patternStr) ->
    @substitution = @_process(patternStr)
    @

exports.Rule = Rule
exports.Rewriter = Rewriter
# m = exports.m = (patternStr, jsCode, checker) ->
#   rule = new Rule(patternStr, checker)
#   tree = esprima.parse(jsCode)
#   # p(tree)
#   output = null
#   traverse(tree, (node, parent, key) ->
#     bindings = {}
#     if rule.match(node, bindings, parent, key)
#       output = bindings
#   )
#   return output

# r = exports.r = (patternStr, jsCode, checker) ->
#   writer = new Rewriter()
#   writer.find(patternStr, checker).replaceWith(jsCode)
#   return (code) ->
#     tree = writer.convert(code)
#     # p(esprima.parse(code))
#     # p(tree)
#     codegen.generate(tree)

# z = r("eval(@x+)", "eval(a, b, c, @x)")
# console.log(z("eval(1, 2, 3, 4)"))

# r = new Rewriter()
# rule = r.find("@a.@b = @c").replaceWith("func(@a, @b, '@c')")
# tree = r.convert("w.x.y.z = 2; z.b = 2;")
# p('--------------------------------------------------- done!')
# p(tree)
# p(codegen.generate(tree))

# b = m("@a.asdf = @c", "blah.asdf = 3")
# p("-------------")
# p(b)

# tree = esprima.parse("w.x.y.z = 2").body[0]
# bool = rule.match(tree)
# if bool
#   p("You are CORRECT!")



