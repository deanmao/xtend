util = module.exports = {
  encodeChars: (str) ->
    i = str.length
    aRet = []
    while i--
      iC = str[i].charCodeAt()
      if iC < 65 || iC > 127 || (iC>90 && iC<97)
        aRet[i] = '&#'+iC+';'
      else
        aRet[i] = str[i]
    return aRet.join('')

  simpleEncode: (str) ->
    str.replace(/</g, '&lt;').replace(/>/g, '&gt;')

  decodeChars: (str) ->
    util.decodeInlineChars(str).replace /&(\w+);/g, (s, code) ->
      switch code
        when 'amp' then '&'
        when 'quot' then '"'
        when 'lt' then '<'
        when 'gt' then '>'
        else s

  decodeInlineChars: (str) ->
    str.replace /&#0?0?(\d+);/g, (s, code) ->
      String.fromCharCode(parseInt(code))

  removeHtmlComments: (str) ->
    str.replace(/<!\-\-/g, '').replace(/\-\->/g, '')
}
