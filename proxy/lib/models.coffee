mongoose = require "mongoose"
Schema = mongoose.Schema
ObjectId = Schema.ObjectId

User = new Schema()

Cookie = new Schema
  domain: String
  path: String
  name: String
  value: String
  expiration: Date
  secure: Boolean
  httponly: Boolean
  user_id: ObjectId

Cookie.methods.toCookieString = (host, currentCookies) ->
  if currentCookies?[@name] && currentCookies[@name] != @value
    @value = currentCookies[@name]
    @save()
  str = "#{@name}=#{encodeURIComponent(@value)}"
  if host != @domain
    str += ";Domain=.#{@domain}"
  if @path
    str += ";Path=#{@path}"
  if @secure
    str += ";Secure"
  if @httponly
    str += ";HttpOnly"
  delete currentCookies[@name]
  str

Cookie.methods.domainlessCookieString = (guide) ->
  str = "#{@name}=#{encodeURIComponent(@value)}"
  if @path
    str += ";Path=#{@path}"
  if @secure
    str += ";Secure"
  if @httponly
    str += ";HttpOnly"
  str

# PREF=ID=f5cc013be6b38a59:FF=0:TM=1336232997:LM=1336232997:S=vRT-pAsGrZHU1UyE;
#        expires=Mon, 05-May-2014 15:49:57 GMT; path=/; domain=.google-com.myapp.dev;
Cookie.virtual('rawstring').set (rawString) ->
  # parse the cookie and set values

exports.User = mongoose.model('User', User)
exports.Cookie = mongoose.model('Cookie', Cookie)
mongoose.connect('mongodb://localhost/xtnd')

