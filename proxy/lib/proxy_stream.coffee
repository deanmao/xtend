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
  constructor: (req, res, guide, isScript, protocol, skip) ->
    @g = guide
    @type = BINARY
    @skip = skip
    @protocol = protocol
    @host = req.headers.host
    @isScript = isScript
    if @isScript
      @type = JS
    @proxiedHost = @g.xtnd.toProxiedHost(@host)
    @res = res
    @req = req
    for own k,v of req.headers
      do (k,v) =>
        req.headers[k] = @visitRequestHeader(k?.toLowerCase(), v)
    if @g.DEBUG_REQ_HEADERS
      console.log('Request headers --------->>>')
      p(req.headers)

  _setContentType: (value) ->
    unless @skip
      if value?.match(/html/i)
        @type = HTML
      else if @isScript || value?.match(/javascript/i)
        @type = JS

  pipefilter: (resp, dest) ->
    if @g.DEBUG_RES_HEADERS
      console.log('Unmodified Response headers <<<---------')
      p(resp.headers)
    for own k,v of resp.headers
      do (k,v) =>
        val = @visitResponseHeader(k, v)
        if val
          @res.setHeader(k, val)
        else
          @res.removeHeader(k)
    @res.statusCode = resp.statusCode
    cookies = resp.headers['set-cookie']
    newCookies = []
    if cookies
      for cookie in cookies
        do (cookie) =>
          newCookies.push(cookie.replace /domain=([\w\.]+);?/i, (x, host) =>
            host = @g.xtnd.toProxiedHost(host)
            if host[0] == '-'
              host = host.replace(/^\-/, '.')
            'domain=' + host + ';'
          )
      @res.removeHeader('set-cookie')
      # TODO: save cookies here
      @res.setHeader('set-cookie', newCookies)
    if @g.DEBUG_RES_HEADERS
      console.log('Response headers <<<---------')
      p(@res._headers)
    @choosePipe()

  visitResponseHeader: (name, value) ->
    lowered = name.toLowerCase()
    switch lowered
      when 'content-encoding'
        if value?.match(/(gzip|deflate)/i)
          @compressed = true
      when 'location'
        return @g.xtnd.proxiedUrl(value)
      when 'access-control-allow-origin'
        return @g.xtnd.proxiedUrl(value)
      when 'content-type'
        @_setContentType(value)
        if @type == JS || @type == HTML
          @res.removeHeader('content-length')
      when 'x-frame-options'
        return null
      when 'content-length'
        if @type == JS || @type == HTML
          return null
    return value

  visitRequestHeader: (name, value) ->
    switch name
      when 'origin'
        return @g.xtnd.normalUrl(value)
      when 'referer'
        return @g.xtnd.normalUrl(value)
      when 'cookies'
        # set cookies here
        return value
    return value

  choosePipe: ->
    if @type == JS || @type == HTML
      if @compressed
        # if the stream came in compressed, we'll send it back out
        # compressed
        @res.setHeader('X-Pipe', 'compressed')
        stream = new ContentStream(@req, @res, @type, @g)
        @pipe(zlib.createGunzip()).pipe(stream)
        stream.pipe(zlib.createGzip()).pipe(@res)
      else
        @res.setHeader('X-Pipe', 'content')
        stream = new ContentStream(@req, @res, @type, @g)
        @pipe(stream)
        stream.pipe(@res)
    else
      @res.setHeader('X-Pipe', 'passthrough')
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
          try
            output = @g.convertJs(data)
            @emit 'data', output
          catch ee
            console.log('bad js:')
            console.log(data)
            @emit 'data', data
    @emit 'end'

module.exports = ProxyStream
