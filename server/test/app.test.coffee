
vows   = require 'vows'
assert = require 'assert'
app    = require './../lib/app'

vows.describe('Mockko').addBatch
  'Apps list':

    topic: 10

    'should be equal to 10': (topic) ->
      assert.equal topic, 10
.export(module)
