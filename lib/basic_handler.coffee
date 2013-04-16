Handler = require('./handler').Handler
util = require('./client/util')
tester = require('./client/property_tester')

class BasicHandler extends Handler
  constructor: (url, visitor, guide) ->
    super(url, visitor)
    @g = guide

  rewriteJS: (code, options) ->
    try
      @g.esprima.multilineStrings = true
      output = @g.convertJs(code, options)
    catch e
      # bad js from basic handler
      output = code
      console.log 'WARNING: Bad inline js', e, code
    finally
      @g.esprima.multilineStrings = false
    return output

  visitScriptBlock: (data) ->
    value = util.removeHtmlComments(data)
    value = util.decodeInlineChars(value)
    value = @rewriteJS(value, {
      nodeVisitor: (node) ->
        # asdffoo hack:
        if node.type == 'Literal' && typeof(node.value) == 'string'
          node.value = node.value.replace(/<\//g, "&#160;&#8239;")
    })
    return value

  shouldVisitHtmlAttribute: (nodeName, attrib) ->
    return tester.isHotTagAttribute(nodeName, attrib)

  shouldVisitScriptAttribute: (nodeName, attrib) ->
    return tester.isInlineJsAttribute(attrib)

  visitScriptAttribute: (data) ->
    value = util.removeHtmlComments(data)
    value = util.decodeChars(value)
    value = '(function(){' + value + '})()'
    value = @rewriteJS(value, {newline: '', indent: ''})
    value = value.replace(/\}\(\)\);$/, '').replace(/^\(function \(\) \{/, '')
    return value

  visitHtmlAttribute: (nodeName, attrib, value) ->
    if value
      value2 = @g.xtnd.proxiedUrl(value, {tag: nodeName})
      if nodeName.match(/^script/i)
        value2 = value2 + @g.FORCE_SCRIPT_SUFFIX
      return value2
    else
      return value

exports.BasicHandler = BasicHandler
