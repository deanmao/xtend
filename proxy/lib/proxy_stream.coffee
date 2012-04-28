stream = require('stream')

types =
  BINARY: 1
  JS: 2
  HTML: 3

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
