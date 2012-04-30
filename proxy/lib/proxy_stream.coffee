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

  visitResponseHeader: (name, value) ->
    switch name
      when 'content-encoding'
        if value?.match(/(gzip|deflate)/i)
          @compressed = true
      when 'content-type'
        @_setContentType(value)
    return value

  visitRequestHeader: (name, value) ->
    switch name
      when 'content-encoding'
        if value?.match(/gzip/)
          @compressed = true
          return ''
      when 'accept'
        @_setContentType(value)
    return value

  choosePipe: ->
    if @type == JS || @type == HTML
      if @compressed
        # if the stream came in compressed, we'll send it back out
        # compressed
        stream = new ContentStream(@req, @res, @type, @guide)
        @pipe(zlib.createGunzip()).pipe(stream)
        stream.pipe(zlib.createGzip()).pipe(@res)
      else
        stream = new ContentStream(@req, @res, @type, @guide)
        @pipe(stream)
        stream.pipe(@res)
    else
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

  write: (chunk, encoding) ->
    @list.push(chunk.toString())
    # @buf.push(chunk)
    # @emit 'data', chunk.toString()
    # @emit 'data', chunk

  end: (x) ->
    data = @list.join('')
    if @type == HTML
      @emit 'data', @guide.convertHtml(data)
    else if @type == JS
      @emit 'data', @guide.convertJs(data)
    else
      @emit 'data', data
    @emit 'end'

module.exports = ProxyStream
