
require.paths.unshift __dirname + '/lib'
require.paths.unshift __dirname + '/vendor/mongoose'
require.paths.unshift __dirname + '/vendor/socket.io/lib'
require.paths.unshift __dirname


require('import').import require('redis').createClient(), (err) ->
  if err
    console.log "Error: #{err.message}"
  else
    console.log "Done."
