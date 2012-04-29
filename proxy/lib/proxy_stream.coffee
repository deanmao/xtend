stream = require('stream')

types =
  BINARY: 1
  JS: 2
  HTML: 3

# we buffer up all the data if it's html or js, then send
# all that data to the client.  I guess if we're
# sophisticated, we could rewrite & stream the html on
# every closing bracket.
#
# we don't manipulate binary content right now, we just
# pass it along to the response object immediately
class ProxyStream extends stream.Stream
  writeable: true
  constructor: (req, res, guide) ->
    @type = types.BINARY
    @guide = guide
    @res = res
    @req = req
    @buf = ''
    @on 'data', (data) =>
      @buf += data
    for own k,v of req.headers
      do (k, v) =>
        if k?.toLowerCase() == 'accept' && v?.match(/html/)
          @type = types.HTML

  visitHeader: (k, v, res) ->
    if k.toLowerCase() == 'content-type'
      if v?.match(/html/i)
        @type = types.HTML
      else if v?.match(/javascript/i)
        @type = types.JS

  write: (chunk) ->
    if @type == types.BINARY
      @res.write(chunk)
    else
      @emit 'data', chunk

  end: (chunk) ->
    if chunk
      @write(chunk)
    if @type == types.HTML
      @guide.p(@buf)
      @res.write(@guide.convertHtml(@buf))
    else if @type == types.JS
      @res.write(@guide.convertJs(@buf))
    @res.end()
    @emit('end')
    @guide.p('end!!')

module.exports = ProxyStream
