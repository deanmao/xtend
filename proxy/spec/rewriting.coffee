{ vows, assert, js, p } = require("./helpers")

vows.describe('js matching rules').addBatch
  # 'doing an exact match for assignment':
  #   topic: ->
  #     js.m('@a.@b = @c', 'blah.asdf = 3')
  #   'should match bindings': (bindings) ->
  #     assert.equal bindings.a.name, 'blah'
  #     assert.equal bindings.b.name, 'asdf'
  #     assert.equal bindings.c.value, 3

  # 'doing an exact unequal match':
  #   topic: ->
  #     js.m('@a.not_asdf = @c', 'blah.asdf = 3')
  #   'should not match bindings': (bindings) ->
  #     assert.equal bindings, null

  # 'doing an exact equal match with strings':
  #   topic: ->
  #     js.m('@a.something = "blah"', 'blah.something = "blah"')
  #   'should match bindings': (bindings) ->
  #     assert.equal bindings.a.name, 'blah'

  # 'match on object':
  #   topic: ->
  #     js.m('{@a: @b}', '{blah: 3}')
  #   'matching': (bindings) ->
  #     assert.equal bindings.a.name, 'blah'
  #     assert.equal bindings.b.value, 3

  # 'match on object with specific property':
  #   topic: ->
  #     js.m('{food: @a}', '{blah: 3, food: "apple"}')
  #   'matching': (bindings) ->
  #     assert.equal bindings.a.value, "apple"

  # 'match on object +':
  #   topic: ->
  #     js.m('asdf(@a+)', 'asdf(1, "abc", 200)')
  #   'matching': (bindings) ->
  #     assert.ok bindings.a
  #     assert.equal bindings.a.length, 3
  #     assert.equal bindings.a[0].value, 1
  #     assert.equal bindings.a[1].value, 'abc'
  #     assert.equal bindings.a[2].value, 200

  # 'match on object no plus':
  #   topic: ->
  #     js.m('asdf(@a)', 'asdf(1, "abc", 200)')
  #   'matching': (bindings) ->
  #     assert.ok bindings.a
  #     assert.equal bindings.a.value, 1

  # 'only match if the object property is cookie':
  #   topic: ->
  #     js.m('@a.@b = @c', 'blah.asdf = 3', (name, node) ->
  #       if name == 'b' && node.name != 'cookie'
  #         return false
  #       return true
  #     )
  #   'should not match bindings': (bindings) ->
  #     assert.equal bindings, null

  # 'only match if the object property is location':
  #   topic: ->
  #     js.m('@a.@b = @c', 'blah.location = 3', (name, node) ->
  #       if name == 'b' && node.name != 'location'
  #         return false
  #       return true
  #     )
  #   'should match bindings': (bindings) ->
  #     assert.equal bindings.b.name, 'location'

  # 'basic replacements':
  #   topic: ->
  #     js.r("@a.@b = @c", "assignment( @a, @b, @c )")
  #   'should work': (convert) ->
  #     assert.equal convert('window.location = 3;'), 'assignment(window, location, 3);'
  #     assert.equal convert("window.location = 'google.com';"), "assignment(window, location, 'google.com');"
  #     assert.equal convert("a.b= function(){};"), "assignment(a, b, function () {\n});"

  'converting into bound type':
    topic: ->
      js.r("method(@a.@b)", "method2( @a, '@b' )")
    'should work': (convert) ->
      assert.equal convert('method(window.location)'), "method2(window, 'location');"
      assert.equal convert('something(window.location)'), "something(window.location);"

.export(module)
