class Handler
  constructor: (g, url) ->
    @g = g
    @url = url
    @visitor = g.htmlVisitor
    @output = ''

  reset: ->
    @output = ''

  done: ->

  rewriteJS: (code, options) ->
    try
      @g.esprima.multilineStrings = true
      output = @g.convertJs(code, options)
    catch e
      @g.p(@url)
      throw e
    finally
      @g.esprima.multilineStrings = false
    return output

  append: (str) ->
    @output = @output + '<' + str + '>'

  appendRaw: (str) ->
    @output += str

  visit: (location, name) ->
    data = @visitor?(location, name, @)
    if data
      @appendRaw(data)

  writeTag: (el) ->
    @visit('before', el.name)
    if el.name?.match(/^script$/i)
      @insideScript = true
    if el.name[0] == '/'
      @append(el.name)
      @insideScript = false
    else
      attributes = {}
      for key, value of el.attribs
        do (key, value) =>
          if @g.tester.isHotTagAttribute(el.name, key)
            value2 = @g.xtnd.proxiedUrl(value)
            attributes[key] = value2
          else if @g.tester.isInlineJsAttribute(key)
            value = @g.util.removeHtmlComments(el.raw)
            value = @g.util.decodeChars(value)
            value = '(function(){' + value + '})()'
            data = @rewriteJS(value, {indent: '', newline: ''})
            attributes[key] = data
          else
            attributes[key] = value
      @appendTag(el, attributes)
      @visit('after', el.name)

  appendTag: (el, attributes) ->
    @output = @output + '<' + el.name
    chunks = []
    for key, value of attributes
      do (key, value) =>
        chunks.push(' ')
        chunks.push(key)
        chunks.push('="')
        chunks.push(value)
        chunks.push('" ')
    @output = @output + chunks.join('') + '>'

  writeText: (el) ->
    @visit('inside', el.name)
    if @insideScript
      value = @g.util.removeHtmlComments(el.raw)
      decoded = @g.util.decodeInlineChars(value)
      @appendRaw(@rewriteJS(decoded))
    else
      @appendRaw(el.raw)

  writeComment: (el) ->
    # strip

  writeDirective: (el) ->
    @append(el.raw)

exports.Handler = Handler
