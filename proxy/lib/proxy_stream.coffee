stream = require('stream')
BufferList = require('bufferlist').BufferList
eyes = require 'eyes'
p = () -> eyes.inspect(arguments...)
gunzip = require './compress'

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
    @buf = new BufferList()
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
        if value?.match(/gzip/)
          @compressed = true
          return ''
      when 'content-type'
        @_setContentType(value)
    return value

  visitRequestHeader: (name, value) ->
    switch name
      when 'accept-encoding'
        return null
      when 'user-agent'
        return null
      when 'content-encoding'
        if value?.match(/gzip/)
          @compressed = true
          return ''
      when 'accept'
        @_setContentType(value)
    return value

  write: (chunk, encoding) ->
    if @type == BINARY
      @emit 'data', chunk
    else
      @buf.push(chunk)
      true

  bufferString: (cb) ->
    buffer = @buf.take(@buf.length)
    if @compressed
      gunzip buffer, (err, data) ->
        if err
          console.log(err)
          cb('')
        else
          cb(data)
    else
      cb(buffer)

  end: ->
    if @type == HTML
      @bufferString (data) =>
        # @emit 'data', new Buffer(@guide.convertHtml(html))
        @emit 'data', data
        @emit 'end'
    else if @type == JS
      @bufferString (data) =>
        # @emit 'data', new Buffer(@guide.convertJs(js))
        @emit 'data', data
        @emit 'end'
    else
      @emit 'end'

module.exports = ProxyStream
