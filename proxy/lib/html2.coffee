# if typeof(exports) != 'undefined'
#   eyes = require "eyes"
#   p = (x) -> eyes.inspect(x)

_tags = exports.LOCATION_TAGS = {
  a: 'href'
  img: 'src'
  script: 'src'
  link: 'href'
  input: 'action'
  iframe: 'src'
  frame: 'src'
  area: 'href'
  base: 'href'
}

_jsAttributes = exports.JS_ATTRIBUTES = {}
_attrs = """
onblur onchange onclick ondblclick onfocus onkeydown onkeypress onkeyup onload
onmousedown onmousemove onmouseout onmouseover onmouseup onreset onselect onsubmit
onunload onabort onactivate onafterprint onafterupdate onbeforeactivate
onbeforecopy onbeforecut onbeforedeactivate onbeforeeditfocus onbeforepaste
onbeforeprint onbeforeunload onbeforeupdate onbounce oncontextmenu oncontrolselect
oncopy oncut ondataavailable ondatasetchanged ondeactivate ondrag ondragend
ondragenter ondragleave ondragover ondragstart ondrop onerror onerrorupdate
onfilterchange onfinish onfocusin onfocusout onhelp onlayoutcomplete onlosecapture
onmouseenter onmouseleave onmousewheel onmove onmoveend onmovestart onpaste
onpropertychange onreadystatechanged onresize onresizeend onresizestart onrowenter
onrowexit onrowsdelete onrowsinserted onscroll onselectionchange onstart onstop
ontimeerror
"""
_attrs.replace /\w+/g, (x) ->
  _jsAttributes[x] = true

encodeChars = exports.encodeChars = (str) ->
  i = str.length
  aRet = []
  while i--
    iC = str[i].charCodeAt()
    if iC < 65 || iC > 127 || (iC>90 && iC<97)
      aRet[i] = '&#'+iC+';'
    else
      aRet[i] = str[i]
  return aRet.join('')

decodeChars = (str) ->
  decodeInlineChars(str).replace /&(\w+);/g, (s, code) ->
    switch code
      when 'amp' then '&'
      when 'quot' then '"'
      when 'lt' then '<'
      when 'gt' then '>'
      else s

decodeInlineChars = (str) ->
  hack = str.indexOf('<!--')
  if hack > -1 && hack < 20
    str = str.replace('<!--', '').replace('-->', '')
  str.replace /&#0?0?(\d+);/g, (s, code) ->
    String.fromCharCode(parseInt(code))

class Handler
  constructor: (guide, url) ->
    @guide = guide
    @url = url
    @visitor = guide.htmlVisitor
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
      @guide.esprima.multilineStrings = true
      output = @guide.convertJs(code, options)
    catch e
      @guide.p(@url)
      throw e
    finally
      @guide.esprima.multilineStrings = false
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
            decoded = decodeInlineChars(el.data)
            @appendText(@rewriteJS(decoded))
          else
            @appendText('')
        else
          @appendText(el.data)
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
        if _tags[@tagName] == attrib
          value2 = @guide.xtnd.proxiedUrl(value)
          if @tagName.match(/script/i)
            value2 = value2 + @guide.FORCE_SCRIPT_SUFFIX
          @appendAttr(attrib, value2)
        else if _jsAttributes[attrib.toLowerCase()]
          if value
            value2 = '(function(){' + decodeChars(value) + '})()'
            @appendAttr(attrib, @rewriteJS(value2, {newline: '', indent: ''}))
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
