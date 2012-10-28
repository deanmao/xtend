models = require('./models')
Cookie = models.Cookie
dp = require('eyes').inspector(maxLength: 20000)

logIfError = (err, docs) =>
  if err
    dp err

prune = (hash) ->
  for own k,v of hash
    do (k,v) ->
      unless v
        delete hash[k]
  hash

class CookieHandler
  constructor: (sessionId, cookies, proxy) ->
    @sessionId = sessionId
    @requestCookies = cookies
    @proxy = proxy

  processRequest: (cb) ->
    @setRequestCookies =>
      cb()

  processResponse: (cookies) ->
    if cookies
      @setResponseCookies(cookies)

  setRequestCookies: (next) ->
    host = @proxy.host
    rawCookies = []
    parts = host.split('.')
    domain = parts[1..-1].join('.')
    Cookie.find({}).where('session_id', @sessionId)
      .where('domain').in([domain, host, '.'+domain])
      .run (err, docs) =>
        if docs
          for cookie in docs
            do (cookie) =>
              unless cookie?.name?.match(/^xtnd/)
                val = cookie.nameValueString()
                rawCookies.push(val)
              delete @requestCookies[cookie.name]
        for own name, value of @requestCookies
          do (name, value) =>
            unless name?.match(/^xtnd/)
              c = new Cookie(session_id: @sessionId, domain: host, name: name, path: '/', value: value)
              c.assignKey()
              Cookie.update {key: c.key},
                            {$set: prune({
                              name: c.name
                              path: c.path
                              value: c.value
                              domain: c.domain
                              session_id: c.session_id
                              key: c.key
                            })},
                            {upsert: true}, logIfError
              rawCookies.push(c.nameValueString())
        @proxy.setRequestCookies(rawCookies.join('; '))
        next()

  setResponseCookies: (cookies) ->
    if cookies
      @responseCookies = []
      cookieStrings = []
      @saveCookies(cookies)
      host = @proxy.host
      for cookie in @responseCookies
        do (cookie) =>
          cookieStrings.push(cookie.domainlessCookieString())
      @proxy.setResponseCookies(cookieStrings)

  saveCookies: (cookies) ->
    for cookieStr in cookies
      do (cookieStr) =>
        c = new Cookie()
        c.set('raw', cookieStr)
        c.session_id = @sessionId
        unless c.domain
          c.domain = @proxy.host
        c.assignKey()
        if c.expires && c.expires.getTime() < Date.now()
          # cookie is set to be deleted
          Cookie.find(key: c.key).remove()
        else
          @responseCookies.push(c)
          Cookie.update {key: c.key},
                        {$set: prune({
                          name: c.name
                          value: c.value
                          domain: c.domain
                          secure: c.secure
                          httponly: c.httponly
                          path: c.path
                          key: c.key
                          session_id: @sessionId
                        })},
                        {upsert: true}, logIfError

module.exports = CookieHandler
