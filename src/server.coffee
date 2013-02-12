http = require 'http'
url = require 'url'
fs = require 'fs'
io = require 'socket.io'
sys = require 'sys'

send404 = (res) ->
  res.writeHead(404)
  res.write('404')
  res.end()
  res

server = http.createServer (req,res) ->
  path = url.parse(req.url).pathname
  console.log( path )
  path = '/index.html' if path == '/'
  fs.readFile "#{__dirname}/../public/" + path, (err,data) ->
    return send404 res if err
    ext = path.substr path.lastIndexOf( "." ) + 1
    content_type = switch ext
      when 'js' then 'text/javascript'
      when 'css' then 'text/css'
      when 'html' then 'text/html'
      else
        console.log "Unknown content type: #{ext}"
        'application/octet-stream'
    res.writeHead 200
      'Content-Type': content_type
    res.write data, 'utf8'
    res.end()

server.listen 3000

console.log "Server running on http://localhost:3000"

io = io.listen(server)
io.set 'log level', 2

shuffle = (arr) ->
  for i in [(arr.length-1)...0] by -1
    j = Math.floor Math.random() * (i+1)
    temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp

size = 10
board = []
reset_board = ->
  choices = [1..10]
  cards = []
  while cards.length < size * size
    cards = cards.concat(choices)
  shuffle cards
  board = []
  for y in [0...size]
    row = []
    board.push row
    for x in [0...size]
      row.push cards.shift()
  board.remaining = size*size

do reset_board

get = (x, y) ->
  board[y][x]

set = (x, y, val) ->
  board[y][x] = val

players = {}
clients = {}

broadcast_to_others = (source, type, data) ->
  for id, client of clients
    continue if source.id == id
    try
      client.emit type, data
    catch err
      console.log "Couldn't emit #{type}: #{err}"

broadcast = (type, data) ->
  for id, client of clients
    try
      client.emit type, data
    catch err
      console.log "Couldn't emit #{type}: #{err}"

# The server only needs to echo messages, except it will keep score to avoid
# race conditions

io.sockets.on 'connection', (client) ->
  player =
    id: client.id
    name: "Anonymous"
    score: 0

  client.on 'register', (msg) ->
    player.name = msg.name
    players[client.id] = player
    clients[client.id] = client
    broadcast 'players', players
    client.emit 'board', board

  client.on 'mouse', (msg) ->
    broadcast 'mouse'
      id: client.id
      x: msg.x
      y: msg.y

  last_move = null
  client.on 'choose', (msg) ->
    cur = get(msg.x, msg.y)
    prev = get(last_move.x, last_move.y) if last_move

    if cur? && prev? && !(msg.x == last_move.x && msg.y == last_move.y) && cur == prev
      player.score += cur
      set(msg.x, msg.y, null)
      set(last_move.x, last_move.y, null)
      board.remaining -= 2

      if board.remaining == 0
        do reset_board

      broadcast 'board', board
      broadcast 'players', players

    last_move = msg

    broadcast 'choose'
      id: client.id
      x: msg.x
      y: msg.y

  client.on 'error', ->
    console.log "error"

  client.on 'disconnect', ->
    console.log "disconnect"
    delete players[client.id]
    delete clients[client.id]
    broadcast 'players', players
