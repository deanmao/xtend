stream = require('stream')
zlib = require 'zlib'
crypto = require 'crypto'
ContentStream = require('./content_stream')
CookieHandler = require('./cookie_handler')
BufferStream = require('bufferstream')
dp = require('eyes').inspector(maxLength: 20000)

BINARY = 1
JS = 2
HTML = 3
IMAGE = 4

sha1 = (str) ->
  sum = crypto.createHash('sha1')
  sum.update(str)
  sum.digest('hex')

# we buffer up all the data if it's html or js, then send
# all that data to the client.  I guess if we're
# sophisticated, we could rewrite & stream the html on
# every closing bracket.
#
# we don't manipulate binary content right now, we just
# pass it along to the response object immediately
class ProxyStream extends stream.Stream
  writable: true
  constructor: (req, res, guide, isScript, protocol, skip, normalUrl) ->
    @done = false
    @g = guide
    @type = BINARY
    @skip = skip
    @normalUrl = normalUrl
    @protocol = protocol
    @host = req.headers.host
    @isScript = isScript
    if @isScript
      @type = JS
    @proxiedHost = @g.xtnd.toProxiedHost(@host)
    @res = res
    @req = req

  _setContentType: (value) ->
    unless @skip
      if value?.match(/html/i)
        @type = HTML
      else if @isScript || value?.match(/javascript/i)
        @type = JS
      else if value?.match(/image/)
        @type = IMAGE

  setSessionId: (id) ->
    @sessionId = id
    @req.session.sessionId = id

  setRequestCookies: (cookieString) ->
    if cookieString
      @requestHeaders['cookie'] = cookieString
    else
      delete @requestHeaders['cookie']


  setResponseCookies: (cookies) ->
    # if cookies?.length > 0
      # dp "using these cookies in client response for #{@host}"
      # dp cookies
      # @res.setHeader('set-cookie', cookies)

  process: (next) ->
    @requestHeaders = {}
    for own k,v of @req.headers
      do (k,v) =>
        val = @visitRequestHeader(k?.toLowerCase(), v)
        if val
          @requestHeaders[k] = val
    @cook = new CookieHandler(@req.session.id, @req.cookies, @)
    @cook.processRequest =>
      if @g.DEBUG_REQ_HEADERS
        console.log('Request headers --------->>>')
        dp(@requestHeaders)
      next()

  pipefilter: (resp, dest) ->
    if @g.DEBUG_RES_HEADERS
      console.log('Unmodified Response headers <<<---------')
      dp(resp.headers)
    for own k,v of resp.headers
      do (k,v) =>
        val = @visitResponseHeader(k, v)
        if val
          @res.setHeader(k, val)
        else
          @res.removeHeader(k)
    @res.statusCode = resp.statusCode
    @res.removeHeader('set-cookie')
    @cook.processResponse(resp.headers['set-cookie'])
    if @g.DEBUG_RES_HEADERS
      console.log('Response headers <<<---------')
      dp(@res._headers)
    @choosePipe()

  visitResponseHeader: (name, value) ->
    lowered = name.toLowerCase()
    switch lowered
      when 'cache-control'
        if value?.match(/no\-cache/i)
          @neverCache = true
      when 'pragma'
        if value?.match(/no\-cache/i)
          @neverCache = true
      when 'etag'
        @alwaysCache = true
        @cacheKey = sha1("#{@host}#{value}")
        @res.setHeader('X-Pipe-Cache-Key', @cacheKey)
      when 'last-modified'
        if !@neverCache && !@cacheKey
          @cacheKey = sha1("#{@host}#{@req.url}#{value}")
          @res.setHeader('X-Pipe-Cache-Key', @cacheKey)
      when 'content-encoding'
        if value?.match(/(gzip|deflate)/i)
          @compressed = true
      when 'location'
        return @g.xtnd.proxiedUrl(value, {header: name})
      when 'access-control-allow-origin'
        return @g.xtnd.proxiedUrl(value, {header: name})
      when 'content-type'
        @_setContentType(value)
        if @type && @type != BINARY
          @res.removeHeader('content-length')
      when 'x-frame-options'
        return null
      when 'content-length'
        if @type == JS || @type == HTML
          return null
    return value

  visitRequestHeader: (name, value) ->
    switch name
      when 'connection'
        return 'close'
      when 'origin'
        return @g.xtnd.normalUrl(value)
      when 'referer'
        return @g.xtnd.normalUrl(value)
    return value

  choosePipe: ->
    if @type == JS || @type == HTML
      if @compressed
        # if the stream came in compressed, we'll send it back out
        # compressed
        @res.setHeader('X-Pipe', 'compressed')
        buffer = new BufferStream()
        stream = new ContentStream(@req, @res, @type, @g, buffer, @)
        @pipe(zlib.createGunzip()).pipe(buffer)
        buffer.pipe(stream)
        stream.pipe(zlib.createGzip()).pipe(@res)
      else
        @res.setHeader('X-Pipe', 'content')
        buffer = new BufferStream()
        stream = new ContentStream(@req, @res, @type, @g, buffer, @)
        @pipe(buffer)
        buffer.pipe(stream)
        stream.pipe(@res)
    else
      if @cacheKey && @type == IMAGE
        # we should just redirect to the real image here instead, or redirect to a cdn image
        @res.setHeader('X-Pipe', 'redirect')
        @res.setHeader('X-Pipe-Content', 'image')
        @res.setHeader('Location', @normalUrl)
        """
          content-length accept-ranges etag expires last-modified
        """.replace /[\w\-]+/g, (name) =>
          @res.removeHeader(name)
        @res.statusCode = 301
        @res.send('')
        @done = true
      else
        @res.setHeader('X-Pipe', 'passthrough')
        @pipe(@res)

  write: (chunk, encoding) ->
    unless @done
      @emit 'data', chunk

  end: ->
    unless @done
      @emit 'end'

module.exports = ProxyStream
