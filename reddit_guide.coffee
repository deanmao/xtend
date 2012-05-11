gd = require('./lib/guide')

class RedditGuide extends gd.Guide
  toProxiedHost: (host, context) ->
    if context
      tag = context.tag?.toLowerCase()
      if 'script' == tag || 'link' == tag
        super(host, context)
      else if host?.match(/reddit/)
        super(host, context)
      else
        host
    else
      super(host, context)

  toNormalHost: (proxiedHost) ->
    if proxiedHost == @host
      return 'www.reddit.com'
    else
      super(proxiedHost)

if typeof(window) != 'undefined'
  guide = new RedditGuide(host: 'myapp.dev')
  window.xtnd = guide.xtnd
else
  module.exports = RedditGuide
