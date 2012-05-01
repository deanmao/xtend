stream = require('stream')
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
  constructor: (req, res, guide) ->
    @type = BINARY
    @guide = guide
    @res = res
    @req = req
    for own k,v of req.headers
      do (k,v) =>
        req.headers[k] = @visitRequestHeader(k?.toLowerCase(), v)

  _setContentType: (value) ->
    if value?.match(/html/i)
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
    @res.statusCode = resp.statusCode
    @choosePipe()

  visitResponseHeader: (name, value) ->
    switch name
      when 'content-encoding'
        if value?.match(/(gzip|deflate)/i)
          @compressed = true
      when 'location'
        return @guide.xtnd.proxiedUrl(value)
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
        stream = new ContentStream(@req, @res, @type, @guide)
        @pipe(zlib.createGunzip()).pipe(stream)
        stream.pipe(zlib.createGzip()).pipe(@res)
      else
        @res.header('X-Pipe', 'content')
        stream = new ContentStream(@req, @res, @type, @guide)
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
    @guide = guide
    @res = res
    @req = req
    @list = []
    if @type == JS
      @res.header('X-Pipe-Content', 'javascript')
    else if @type == HTML
      @htmlStreamParser = @guide.createHtmlParser()
      @res.header('X-Pipe-Content', 'html')

  write: (chunk, encoding) ->
    if @type == HTML
      # we'll stream the html
      output = @htmlStreamParser(chunk.toString())
      if output != ''
        @emit 'data', output
    else
      @list.push(chunk.toString())

  end: (x) ->
    if @type == JS
      data = @list.join('')
      output = @guide.convertJs(data)
      @emit 'data', output
    @emit 'end'

module.exports = ProxyStream
