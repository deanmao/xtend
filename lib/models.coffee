mongoose = require "mongoose"
Schema = mongoose.Schema

Cookie = new Schema
  domain: { type: String, index: true }
  path: String
  name: String
  value: String
  expires: Date
  secure: Boolean
  httponly: Boolean
  session_id: { type: String, index: true }
  key: { type: String, index: { unique: true } }

Cookie.index({ domain: 1, name: 1, session_id: 1 })

Cookie.virtual('raw').set (cookieStr) ->
  parts = cookieStr.split(/;\s*/)
  for part in parts
    do (part) =>
      if part.match(/^httponly/i)
        @httponly = true
      else if part.match(/^secure/i)
        @secure = true
      else
        x = part.split(/\=/)
        name = x[0]
        value = x[1..-1].join('=')
        if name.match(/domain/i)
          @domain = value
        else if name.match(/expires/i)
          try
            @expires = new Date(value)
          catch e
        else if name.match(/path/i)
          @path = value
        else
          @name = name
          @value = value

Cookie.methods.assignKey = () ->
  @key = "#{@session_id}--#{@domain}--#{@name}"

Cookie.methods.nameValueString = () ->
  "#{@name}=#{@value}"

Cookie.methods.toCookieString = (host) ->
  str = "#{@name}=#{@value}"
  if host != @domain
    str += ";Domain=#{@domain}"
  if @path
    str += ";Path=#{@path}"
  if @secure
    str += ";Secure"
  if @httponly
    str += ";HttpOnly"
  str

Cookie.methods.domainlessCookieString = (guide) ->
  str = "#{@name}=#{@value}"
  if @path
    str += ";Path=#{@path}"
  if @secure
    str += ";Secure"
  if @httponly
    str += ";HttpOnly"
  str

CachedFile = new Schema
  key: { type: String, index: { unique: true } }
  url: String
  type: String
  last_access: Date

exports.CachedFile = mongoose.model('CachedFile', CachedFile)
exports.Cookie = mongoose.model('Cookie', Cookie)
exports.Cookie = mongoose.model('Cookie', Cookie)
