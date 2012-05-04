class Handler
  constructor: (guide, url) ->
    @g = guide
    @url = url
    @visitor = @g.htmlVisitor
    @output = ''
    @closeStartTag = false
    @counts = {}

  reset: ->
    @output = ''

  done: ->

  error: (err) ->
    console.log(err)

  rewriteJS: (code, options) ->
    try
      @g.esprima.multilineStrings = true
      output = @g.convertJs(code, options)
    catch e
      @g.p?(@url)
      unless @g.isBrowser()
        throw e
    finally
      @g.esprima.multilineStrings = false
    return output

  visit: (location, name) ->
    data = @visitor?(location, name, @)
    if data
      @appendRaw(data)

  error: (err) ->
    console.log(err)

  write: (el) ->
    switch el.type
      when 'text'
        @appendCloseStartTag()
        @visit('inside', @tagName)
        if @insideScript
          if el.data
            try
              value = @g.util.removeHtmlComments(el.data)
              value = @g.util.decodeInlineChars(value)
              value = @rewriteJS(value)
              # value = @g.util.simpleEncode(value)
              # TODO HACK:
              value = value.replace(/<\//g, '<\\/')
              # value = @g.makeSafe(value)
              @appendText('\n\n'+value+'\n\n')
            catch e
              # sometimes script tags contain non-js such as
              # backbone view templates
              @appendText(el.data)
          else
            @appendText('')
        else
          @appendText(el.data)
      when 'comment'
        @appendCloseStartTag()
        @appendRaw('\n<!--\n'+el.data+'\n-->\n')
      when 'tag'
        if el.name[0] == '/'
          @insideScript = false
          @appendEndTag(el)
        else
          if el.name?.match(/^script$/i)
            @insideScript = true
            @tagName = el.name
          else
            @tagName = el.name
          @appendCloseStartTag()
          @visit('before', @tagName)
          @appendStartTag(el)
      when 'attr'
        attrib = el.name
        value = el.data
        if @g.tester.isHotTagAttribute(@tagName, attrib)
          value2 = @g.xtnd.proxiedUrl(value)
          if @tagName.match(/script/i)
            value2 = value2 + @g.FORCE_SCRIPT_SUFFIX
          @appendAttr(attrib, value2)
        else if @g.tester.isInlineJsAttribute(attrib)
          if value
            value = @g.util.removeHtmlComments(value)
            value = '(function(){' + @g.util.decodeChars(value) + '})()'
            value = @rewriteJS(value, {newline: '', indent: ''})
            # value = @g.util.simpleEncode(value)
            @appendAttr(attrib, value)
          else
            @appendAttr(attrib, '')
        else
          @appendAttr(attrib, value)
      when 'cdata'
        @appendRaw('<![CDATA[' + el.data+ ']]>')
      when 'doctype'
        @appendRaw('<!DOCTYPE' + el.data + '>')

  appendAttr: (name, value) ->
    @output += ' ' + name + '="' + (value || '') + '"'

  appendStartTag: (el) ->
    @closeStartTag = true
    @output += '<' + el.name

  appendEndTag: (el) ->
    @appendCloseStartTag()
    @output += '<' + el.name + '>'

  appendRaw: (str) ->
    @output += str

  appendText: (str) ->
    @appendCloseStartTag()
    if str
      @output += str

  appendCloseStartTag: ->
    if @closeStartTag
      @output += '>'
      @visit('after', @tagName)
    @closeStartTag = false

exports.Handler = Handler
