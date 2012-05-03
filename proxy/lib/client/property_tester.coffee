_tag_attribute_pairs = {
  embed: 'src'
  a: 'href'
  img: 'src'
  script: 'src'
  link: 'href'
  form: 'action'
  input: 'src'
  iframe: 'src'
  frame: 'src'
  area: 'href'
  base: 'href'
}
_js_attributes = """
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
_hot_properties = """
location url href cookie domain src innerhtml host hostname history documenturi
baseuri port referrer parent top opener window parentwindow action
"""
_hot_methods = 'setattribute write writeln getattribute open setrequestheader'
_window_attributes = 'location, url, href'
_dom_location_attributes = 'src href action'
_hot_references = 'location top parent'


listToHash = (str) ->
  hash = {}
  str.replace /\w+/g, (x) ->
    hash[x.toLowerCase()] = true
  hash

generateTester = (list) ->
  hash = listToHash(list)
  checker = (prop) ->
    prop && hash[prop.toLowerCase]

testers = module.exports =
  isInlineJsAttribute: generateTester(_js_attributes)
  isHotMethod: generateTester(_hot_methods)
  isHotReference: generateTester(_hot_references)
  isHotProperty: generateTester(_hot_properties)
  isHotTagAttribute: (tagName, attribName) ->
    _tag_attribute_pairs[tagName] == attribName
  isDomLocationAttribute: generateTester(_dom_location_attributes)
  isWindowAttribute: generateTester(_window_attributes)

