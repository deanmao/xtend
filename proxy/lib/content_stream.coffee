stream = require('stream')
fs = require('fs')
models = require('./models')
CachedFile = models.CachedFile
dp = require('eyes').inspector(maxLength: 20000)

BINARY = 1
JS = 2
HTML = 3

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
  constructor: (req, res, type, guide, buffer) ->
    @type = type
    @g = guide
    @res = res
    @req = req
    @list = []
    @buffer = buffer
    if @type == JS
      @res.header('X-Pipe-Content', 'javascript')
    else if @type == HTML
      @htmlStreamParser = @g.createHtmlParser(@req.headers.host + '---' + @req.originalUrl)
      @res.header('X-Pipe-Content', 'html')

  write: (chunk, encoding) ->
    if @type == HTML
      @buffer.pause()
      if @g.DEBUG_OUTPUT_HTML && chunk.length > 0
        unless @debugfile
          url = @req.headers.host + @req.url
          fileIndex = fileIndex + 1
          @debugfile = fs.openSync("./debug/html#{fileIndex}.html", 'w+')
          fs.writeSync(@debugfile, "<!-- #{url} -->")
        fs.writeSync(@debugfile, chunk.toString())
      # we'll stream the html
      output = @htmlStreamParser(chunk.toString())
      if output.length != 0
        @emit 'data', output
      @buffer.resume()
    else
      @list.push(chunk.toString())

  getJs: ->
    data = @list.join('')
    # if function/var is present in string, we assume JS
    # else, we will try to parse it with json and if it fails
    # go back to JS again
    if data.match(/(function|var)/)
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

  updateCachedFile: ->
    CachedFile.update {key: @cacheKey},
                      {$set: prune({
                        name: c.name
                        path: c.path
                        value: c.value
                        domain: c.domain
                        session_id: c.session_id
                        key: c.key
                      })},
                      {upsert: true}, logIfError

  cachedFilePath: ->
    "#{@g.CACHED_FILES_PATH}/#{@cacheKey}.js"

  loadOrSaveJs: ->
    file = @cachedFilePath()
    CachedFile.find(key: @cacheKey, (err, docs) =>
      if docs.length > 0
        # make sure file exists
        fs.readFile file, (err, data) =>
          if err
            console.log 'file not found'
            # if file is not there, just do the usual stuff
            data = @getJs()
            @outputFile(data)
            @emitJs(data)
            @persistCachedKey()
          else
            console.log 'file found'
            @emitJs(data)
            @persistCachedKey()
      else
        console.log 'data not cached'
        data = @getJs()
        @outputFile(data)
        @emitJs(data)
        @persistCachedKey()
    )

  persistCachedKey: ->
    CachedKey.update {key: @cacheKey},
                     {$set: prune({
                       url: @host + @req.url
                       last_access: new Date()
                       key: @cacheKey
                     })},
                     {upsert: true}, logIfError

  outputFile: (data) ->
    fs.open file, 'w+', (err, fd) =>
      unless err
        fs.write fd, data, () =>
          fs.close(fd)

  emitJs: (js) ->
    @emit 'data', js
    @emit 'end'

  end: ->
    if @type == JS
      if true # @g.PRODUCTION
        if !@neverCache && @cacheKey
          @loadOrSaveJs()
        else
          console.log 'not loading from cache', @cacheKey
          @emitJs(@getJs())
      else
        @emitJs(@getJs())
    else
      @emit 'end'
    if @debugfile && @g.DEBUG_OUTPUT_HTML
      fs.closeSync(@debugfile)

module.exports = ContentStream
