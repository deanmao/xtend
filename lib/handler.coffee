class Handler
  constructor: (url, visitor) ->
    @url = url
    @visitor = visitor
    @output = ''
    @closeStartTag = false
    @counts = {}
    @scriptData = ''

  reset: ->
    @output = ''

  done: ->

  error: (err) ->
    console.log('handler err')
    console.log(err)

  visit: (location, name) ->
    data = @visitor?(location, name, @, @url)
    if data
      @appendRaw(data)

  error: (err) ->
    console.log('handler err 2')
    console.log(err)

  getOutput: () ->
    @appendCloseStartTag()
    @output

  visitScriptBlock: (data) ->
    return ''

  visitHtmlAttribute: () ->
    return ''

  visitScriptAttribute: (data) ->
    return ''

  shouldVisitHtmlAttribute: (nodeName, attrib) ->
    true

  write: (el) ->
    switch el.type
      when 'text'
        @appendCloseStartTag()
        @visit('inside', @tagName)
        if @insideScript
          if el.data
            @scriptData = @scriptData + el.data
          else
            @appendText('')
        else
          @appendText(el.data)
      when 'comment'
        @appendCloseStartTag()
        @appendRaw('\n<!--\n'+el.data+'\n-->\n')
      when 'tag'
        if el.name?.match(/^\/script$/i)
          try
            value = @visitScriptBlock(@scriptData)
            @appendText('\n\n'+value+'\n\n')
          catch e
            # sometimes script tags contain non-js such as
            # backbone view templates
            @appendText(@scriptData)
          finally
            @scriptData = ''
        if el.name[0] == '/'
          @insideScript = false
          if el.raw
            @appendEndTag(el)
          else
            @appendSelfCloseTag(el)
        else
          if el.name?.match(/^script$/i)
            @insideScript = true
          @appendCloseStartTag()
          @visit('before', el.name)
          @appendStartTag(el)
          @tagName = el.name
      when 'attr'
        attrib = el.name
        value = el.data
        if @insideScript && attrib == 'type' && !value.match(/javascript/i)
          @insideScript = false
        if @shouldVisitHtmlAttribute(@tagName, attrib)
          @appendAttr(attrib, @visitHtmlAttribute(@tagName, attrib, value) )
        else if @shouldVisitScriptAttribute(@tagName, attrib)
          if value
            @appendAttr(attrib, @visitScriptAttribute(value))
          else
            @appendAttr(attrib, '')
        else
          @appendAttr(attrib, value)
      when 'cdata'
        @appendRaw('<![CDATA[' + el.data+ ']]>')
      when 'doctype'
        @appendRaw('<!DOCTYPE' + el.data + '>\n')

  appendAttr: (name, value) ->
    @output += ' ' + name + '="' + (value || '') + '"'

  appendStartTag: (el) ->
    @closeStartTag = true
    @output += '<' + el.name

  appendSelfCloseTag: (el) ->
    @output += ' /'
    @appendCloseStartTag()

  appendEndTag: (el) ->
    @appendCloseStartTag()
    @visit('end', el.name.slice(1))
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
