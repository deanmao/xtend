htmlparser2 = require './parser2'

class HandlerWrapper
  constructor: (handler) ->
    @handler = handler

  oncdatastart: ->
    @cdata = true
    @text = ''

  oncdataend: ->
    @cdata = false
    @handler.write(type: 'cdata', data: @text)

  onopentag: (name, attribs) ->
    @handler.write(type: 'tag', name: name)
    for key, value of attribs
      @handler.write(type: 'attr', name: key, data: value)

  onclosetag: (name, selfclose) ->
    if selfclose
      @handler.write(type: 'tag', name: '/' + name, raw: false)
    else
      @handler.write(type: 'tag', name: '/' + name, raw: true)

  ontext: (data) ->
    if @cdata
      @text = @text + data
    else
      @handler.write(type: 'text', data: data)

  onerror: ->
    console.log 'error'

  onreset: ->
    @handler.reset()

class Parser
  constructor: (handler) ->
    @wrapper = new HandlerWrapper(handler)
    @parser = new htmlparser2.Parser(@wrapper)

  parseComplete: (data) ->
    @parser.parseComplete(data)

  parseChunk: (data) ->
    @parser.parseChunk(data)

exports.Parser = Parser
