stream = require('stream')
btools = require('buffertools')
fs = require('fs')
models = require('./models')
CachedFile = models.CachedFile
dp = require('eyes').inspector(maxLength: 20000)

BINARY = 1
JS = 2
HTML = 3
IMAGE = 4

fileIndex = 0

logIfError = (err, docs) =>
  if err
    dp err

prune = (hash) ->
  for own k,v of hash
    do (k,v) ->
      unless v
        delete hash[k]
  hash

class ContentStream extends stream.Stream
  writable: true
  constructor: (req, res, type, guide, buffer, proxyStream) ->
    @type = type
    @g = guide
    @res = res
    @req = req
    @proxyStream = proxyStream
    @content = new Buffer('')
    @buffer = buffer
    @parseChunkCalls = 0
    @ended = false
    fileIndex = fileIndex + 1
    @endedCount = 0
    if @type == JS
      @res.header('X-Pipe-Content', 'javascript')
    else if @type == HTML
      @htmlStreamParser = @g.createHtmlParser(@req.headers.host + '---' + @req.originalUrl)
      @res.header('X-Pipe-Content', 'html')

  emitEnd: ->
    if @type == HTML && @htmlStreamParser.async
      if 0 == @parseChunkCalls && @ended
        clearTimeout(@timeout)
        @emit 'end'
      else
        @endedCount = @endedCount + 1
        clearTimeout(@timeout)
        @timeout = setTimeout( =>
          if @endedCount < 15
            @emitEnd()
          else
            console.log 'async chunk timeout, there is a problem with ', @req.originalUrl
            @emit 'end'
        , 1000)
    else
      @emit 'end'

  writeDebugChunkFile: (chunk) ->
    @chunkIndex = @chunkIndex || 0
    @chunkIndex = @chunkIndex + 1
    file = fs.openSync("./debug/html_#{fileIndex}_chunk_#{@chunkIndex}.html", 'w+')
    fs.writeSync(file, chunk.toString())

  write: (chunk, encoding) ->
    if @type == HTML
      # @buffer.pause()
      if @g.DEBUG_OUTPUT_HTML && chunk.length > 0
        unless @debugfile
          url = @req.headers.host + @req.url
          fileIndex = fileIndex + 1
          @debugfile = fs.openSync("./debug/html#{fileIndex}.html", 'w+')
          fs.writeSync(@debugfile, "<!-- #{url} -->")
        fs.writeSync(@debugfile, chunk.toString())
      # we'll stream the html
      if @g.BUFFER_WHOLE_HTML
        @content = btools.concat(@content, chunk)
      else
        if chunk
          chunkString = chunk.toString()
          if @htmlStreamParser.async
            @parseChunkCalls = @parseChunkCalls + 1
            @htmlStreamParser(chunkString, (output) =>
              @parseChunkCalls = @parseChunkCalls - 1
              if output.length != 0
                @emit 'data', output
              @emitEnd()
            )
          else
            output = @htmlStreamParser(chunkString)
            if output.length != 0
              @emit 'data', output
      # @buffer.resume()
    else
      @content = btools.concat(@content, chunk)

  getJs: ->
    data = @content.toString()
    # if function/var is present in string, we assume JS
    # else, we will try to parse it with json and if it fails
    # go back to JS again
    if data.match(/(function)/)
      try
        output = @g.convertJs(data)
        return output
      catch e
        console.log('bad json:')
        console.log(data)
        return data
    else
      try
        JSON.parse(data)
        return data
      catch e
        try
          output = @g.convertJs(data)
          return output
        catch ee
          console.log('bad js:')
          console.log(data)
          return data

  cachedFilePath: ->
    "#{@g.CACHED_FILES_PATH}/#{@proxyStream.cacheKey}.js"

  loadOrSaveJs: ->
    CachedFile.find(key: @proxyStream.cacheKey, (err, docs) =>
      if docs.length > 0
        # make sure file exists
        fs.readFile @cachedFilePath(), (err, data) =>
          if err
            @createFileAndEmit()
          else
            @emitJs(data)
            @persistCachedFile()
      else
        @createFileAndEmit()
    )

  createFileAndEmit: ->
    data = @getJs()
    @outputFile(data)
    @emitJs(data)

  persistCachedFile: ->
    CachedFile.update {key: @proxyStream.cacheKey},
                      {$set: prune({
                        url: @proxyStream.host + @req.url
                        last_access: new Date()
                        type: 'js'
                        key: @proxyStream.cacheKey
                      })},
                      {upsert: true}, logIfError

  outputFile: (data) ->
    fs.writeFile @cachedFilePath(), data, (err) =>
      unless err
        @persistCachedFile()

  emitJs: (js) ->
    @emit 'data', js
    @emit 'end'

  end: ->
    @ended = true
    if @type == JS
      if @g.PRODUCTION
        if !@proxyStream.neverCache && @proxyStream.cacheKey
          @loadOrSaveJs()
        else
          @emitJs(@getJs())
      else
        @emitJs(@getJs())
    else
      if @g.BUFFER_WHOLE_HTML
        # this is where we can run tidy on the content
        if @content.toString().length == 0
          @emitEnd()
        else if @htmlStreamParser.async
          @htmlStreamParser(@content.toString(), (output) =>
            if output.length != 0
              @emit 'data', output
            @emitEnd()
          )
        else
          output = @htmlStreamParser(@content.toString())
          if output.length != 0
            @emit 'data', output
          @emit 'end'
      else
        @emitEnd()
    if @debugfile && @g.DEBUG_OUTPUT_HTML
      fs.closeSync(@debugfile)

module.exports = ContentStream
