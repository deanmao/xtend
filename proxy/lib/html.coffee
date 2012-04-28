if typeof(exports) != 'undefined'
  eyes = require "eyes"
  p = (x) -> eyes.inspect(x)

_tags = exports.LOCATION_TAGS = {
  a: 'href'
  img: 'src'
  script: 'src'
  link: 'src'
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

class Handler
  constructor: (guide) ->
    @guide = guide

  output: ''
  reset: ->

  done: ->

  rewriteJS: (code) ->
    @guide.js(code)

  append: (str) ->
    @output = @output + '<' + str + '>'

  appendRaw: (str) ->
    @output = @output + str

  writeTag: (el) ->
    if el.name?.match(/script/i)
      @insideScript = true
    if el.name[0] == '/'
      @append(el.name)
      @insideScript = false
    else
      attributes = {}
      matchingAttrib = _tags[el.name]
      for key, value of el.attribs
        do (key, value) =>
          if matchingAttrib == key
            value2 = @guide.xtnd.proxiedUrl(value)
            attributes[key] = value2
          else if _jsAttributes[key]
            attributes[key] = @rewriteJS(value)
          else
            attributes[key] = value
      @appendTag(el, attributes)

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
    if @insideScript
      @appendRaw(@rewriteJS(el.raw))
    else
      @appendRaw(el.raw)

  writeComment: (el) ->
    # strip

  writeDirective: (el) ->
    @append(el.raw)

exports.Handler = Handler

# handler = new Handler()
# parser = new htmlparser.Parser(handler)
# parser.parseChunk("<html><SCRIPT>blah</script>")
# console.log(handler.output)

# html = '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'
# request('http://news.ycombinator.com', (err, req, body) ->
#   handler = new Handler()
#   parser = new htmlparser.Parser(handler)
#   parser.parseComplete(body)
#   # console.log(body)
# )

