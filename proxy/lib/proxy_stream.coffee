stream = require('stream')
request = require('request')
inspect = require('eyes').inspector(maxLength: 20000)
zlib = require 'zlib'
p = () -> inspect(arguments...)

BINARY = 1
JS = 2
HTML = 3

# we buffer up all the data if it's html or js, then send
# all that data to the client.  I guess if we're
# sophisticated, we could rewrite & stream the html on
# every closing bracket.
#
# we don't manipulate binary content right now, we just
# pass it along to the response object immediately
class ProxyStream extends stream.Stream
  writable: true
  constructor: (req, res, guide, isScript, protocol, host) ->
    @type = BINARY
    @protocol = protocol
    @host = host
    @isScript = isScript
    if @isScript
      @type = JS
    @g = guide
    @proxiedHost = @g.xtnd.toProxiedHost(@host)
    @res = res
    @req = req
    for own k,v of req.headers
      do (k,v) =>
        req.headers[k] = @visitRequestHeader(k?.toLowerCase(), v)
    @_processRequestCookies()
    # @_processRequestBody()

  # _processRequestBody: () ->
  #   @body = ''
  #   if @req.body
  #     bodyParts = []
  #     for k,v of @req.body
  #       do (k,v) ->
  #         bodyParts.push(k + '=' + encodeURIComponent(v))
  #     @body = bodyParts.join('&')

  _processRequestCookies: () ->
    @jar = request.jar()
    cookies = @req.headers['cookie']
    if cookies
      cookies = cookies.split(';')
      for cookie in cookies
        do (cookie) =>
          @jar.add(request.cookie(cookie))

  _processResponseCookies: (cookies) ->
    if cookies
      for cookie in cookies
        do (cookie) =>
          c = cookie.split(';')[0]
          parts = c.split('=')
          @res.cookie(parts[0], parts[1])

  _setContentType: (value) ->
    if @isScript || value?.match(/html/i)
      @type = HTML
    else if value?.match(/javascript/i)
      @type = JS

  pipefilter: (resp, dest) ->
    for own k,v of resp.headers
      do (k,v) =>
        val = @visitResponseHeader(k?.toLowerCase(), v)
        if val
          @res.setHeader(k, val)
        else
          @res.removeHeader(k)
    # @res.setHeader('Access-Control-Allow-Origin', @protocol+'://*.myapp.dev')
    # @res.setHeader('Access-Control-Allow-Credentials', 'true')
    @res.statusCode = resp.statusCode
    @_processResponseCookies(resp.headers['set-cookie'])
    @choosePipe()

  visitResponseHeader: (name, value) ->
    switch name
      when 'content-encoding'
        if value?.match(/(gzip|deflate)/i)
          @compressed = true
      when 'location'
        return @g.xtnd.proxiedUrl(value)
      when 'content-type'
        @_setContentType(value)
        if @type == JS || @type == HTML
          @res.removeHeader('content-length')
      when 'content-length'
        if @type == JS || @type == HTML
          return null
    return value

  visitRequestHeader: (name, value) ->
    switch name
      when 'cookie'
        # do stuff to cookies here
        return value
    return value

  choosePipe: ->
    if @type == JS || @type == HTML
      if @compressed
        # if the stream came in compressed, we'll send it back out
        # compressed
        @res.header('X-Pipe', 'compressed')
        stream = new ContentStream(@req, @res, @type, @g)
        @pipe(zlib.createGunzip()).pipe(stream)
        stream.pipe(zlib.createGzip()).pipe(@res)
      else
        @res.header('X-Pipe', 'content')
        stream = new ContentStream(@req, @res, @type, @g)
        @pipe(stream)
        stream.pipe(@res)
    else
      @res.header('X-Pipe', 'passthrough')
      @pipe(@res)

  write: (chunk, encoding) ->
    @emit 'data', chunk

  end: ->
    @emit 'end'

class ContentStream extends stream.Stream
  writable: true
  constructor: (req, res, type, guide) ->
    @type = type
    @g = guide
    @res = res
    @req = req
    @list = []
    if @type == JS
      @res.header('X-Pipe-Content', 'javascript')
    else if @type == HTML
      @htmlStreamParser = @g.createHtmlParser(@req.headers.host + '---' + @req.originalUrl)
      @res.header('X-Pipe-Content', 'html')

  write: (chunk, encoding) ->
    if @type == HTML
      # we'll stream the html
      output = @htmlStreamParser(chunk.toString())
      if output.length != 0
        @emit 'data', output
    else
      @list.push(chunk.toString())

  end: (x) ->
    if @type == JS
      data = @list.join('')
      # if function/var is present in string, we assume JS
      # else, we will try to parse it with json and if it fails
      # go back to JS again
      if data.match(/(function|var)/)
        output = @g.convertJs(data)
        @emit 'data', output
      else
        try
          JSON.parse(data)
          @emit 'data', data
        catch e
          output = @g.convertJs(data)
          @emit 'data', output
    @emit 'end'

module.exports = ProxyStream
