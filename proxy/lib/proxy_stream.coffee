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
  constructor: (res, guide) ->
    @guide = guide
    @res = res
    @buf = ''
    @on 'data', (data) =>
      @buf += data
    @writable = true

  setHeader: (k, v) ->
    if k.toLowerCase() == 'content-type'
      if v?.match(/html/i)
        @type = types.HTML
      else if v?.match(/javascript/i)
        @type = types.JS
      else
        @type = types.BINARY

  write: (chunk) ->
    if @type == types.BINARY
      @res.write(chunk)
    else
      @emit 'data', chunk

  end: (chunk) ->
    if chunk
      @write(chunk)
    if @type == types.HTML
      @res.write(@guide.convertHtml(@buf))
    else if @type == types.JS
      @res.write(@guide.convertJs(@buf))
    @res.end()
    @emit('end')

module.exports = ProxyStream
