
compact = (results) -> result for result in results when result?

exports.map = (list, options) ->
  outstanding = list.length

  if outstanding == 0
    options.then(null, [])
  else
    func = options.each

    results = []
    error   = undefined

    for item in list
      index = results.length
      results.push undefined

      do (index) ->
        func item, (err, newItem) ->
          results[index] = newItem
          error ||= err

          if (outstanding -= 1) == 0
            results = compact(results) if options.compact
            options.then(error, results)

    undefined

exports.chain = (func1, func2, callback) ->
  return (args..., callback) ->
    self = this
    func1.call self, args..., (err) ->
      return callback(err) if err
      func2.call self, args..., (err) ->
        return callback(err) if err
        callback(null)
