var parser = require('./Parser.js'),
    domhandler = require('./domhandler.js'),
    // feedhandler = require('./FeedHandler.js'),
    tokenizer = require('./Tokenizer.js'),
    elementtype = require('./domelementtype.js'),
    stream = require('./Stream.js'),
    writablestream = require('./WritableStream.js'),
    proxyhandler = require('./ProxyHandler.js'),
    domutils = require('./domutils.js'),
    collectinghandler = require('./CollectingHandler.js');

function defineProp(name, value){
  delete module.exports[name];
  module.exports[name] = value;
  return value;
}

module.exports = {
  get Parser(){
    return defineProp("Parser", parser);
  },
  get DomHandler(){
    return defineProp("DomHandler", domhandler);
  },
  // get FeedHandler(){
  //   return defineProp("FeedHandler", feedhandler);
  // },
  get Tokenizer(){
    return defineProp("Tokenizer", tokenizer);
  },
  get ElementType(){
    return defineProp("ElementType", elementtype);
  },
  get Stream(){
    return defineProp("Stream", stream);
  },
  get WritableStream(){
    return defineProp("WritableStream", writablestream);
  },
  get ProxyHandler(){
    return defineProp("ProxyHandler", proxyhandler);
  },
  get DomUtils(){
    return defineProp("DomUtils", domutils);
  },
  get CollectingHandler(){
    return defineProp("CollectingHandler", collectinghandler);
  },
  // For legacy support
  get DefaultHandler(){
    return defineProp("DefaultHandler", this.DomHandler);
  },
  get RssHandler(){
    return defineProp("RssHandler", this.FeedHandler);
  },
  createDomStream: function(cb, options, elementCb){
    var handler = new module.exports.DomHandler(cb, options, elementCb);
    return new module.exports.Parser(handler, options);
  },
  // List of all events that the parser emits
  EVENTS: { /* Format: eventname: number of arguments */
    attribute: 2,
    cdatastart: 0,
    cdataend: 0,
    text: 1,
    processinginstruction: 2,
    comment: 1,
    commentend: 0,
    closetag: 1,
    opentag: 2,
    opentagname: 1,
    error: 1,
    end: 0
  }
};
