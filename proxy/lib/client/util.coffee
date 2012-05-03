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

  decodeChars: (str) ->
    util.decodeInlineChars(str).replace /&(\w+);/g, (s, code) ->
      switch code
        when 'amp' then '&'
        when 'quot' then '"'
        when 'lt' then '<'
        when 'gt' then '>'
        else s

  decodeInlineChars: (str) ->
    hack = str.indexOf('<!--')
    if hack > -1 && hack < 20
      str = str.replace('<!--', '').replace('-->', '')
    str.replace /&#0?0?(\d+);/g, (s, code) ->
      String.fromCharCode(parseInt(code))
}
