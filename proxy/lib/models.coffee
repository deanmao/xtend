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
  http: Boolean
  user_id: ObjectId

exports.User = mongoose.model('User', User)
exports.Cookie = mongoose.model('Cookie', Cookie)
mongoose.connect('mongodb://localhost/xtnd')

