steps_to_show = 4

# GAME STATE
name = 'foo' #prompt "Your name?"
board = []
players = {}
prev_choices = {}


# DRAWING
cell_list = []
cell_table = []
create_board = ->
  cell_list = []
  cell_table = []
  $('#board').empty()
  y = 0
  for row in board
    tr = $('<tr>')
      .appendTo '#board'

    brow = []
    cell_table.push brow

    x = 0
    for cell in row
      td = $('<td>')
        .appendTo(tr)
        .text(get(board, x, y))
        .css
          opacity: '0.5'

      td[0].x = x
      td[0].y = y

      brow.push td[0]
      cell_list.push td[0]
      x++

    y++

  register_clicks()

mice = {}
draw_mouse = (id, x, y) ->
  return
  mouse = mice[id] ||= $('<div>').appendTo( 'body' )
  mouse.css
    width: '8px'
    height: '8px'
    position: 'absolute'
    background: 'white'
    top: "#{y - 4}px"
    left: "#{x - 4}px"

update_players = ->
  $('#players').empty()
  for id, player of players
    tr = $('<tr>').appendTo '#players'
    $('<td>').text( player.name ).appendTo tr
    $('<td>').text( player.score ).appendTo tr

get = (arr, x, y) ->
  arr[y][x] || ""

update_board = ->
  for cell in cell_list
    $(@).text get(board, cell.x, cell.y)

update_visibility = (cards) ->
  opacity = 1.0
  for card in cards
    cell = get cell_table, card.x, card.y
    $(cell).css
      opacity: opacity

    opacity -= 1/steps_to_show
    opacity = 0 if opacity < 0


# NETWORKING
socket = null
reconnect = ->
  socket = io.connect window.location.href

  socket.on 'connect', ->
    socket.emit 'register'
      name: name

  socket.on 'board', (msg) ->
    create = board.length == 0
    board = msg
    create_board() if create
    # update_board()

  socket.on 'mouse', (msg) ->
    draw_mouse msg.id, msg.x, msg.y

  socket.on 'players', (msg) ->
    players = msg
    update_players()

  socket.on 'choose', (msg) ->
    prev = (prev_choices[msg.id] ||= [])
    prev.unshift msg
    update_visibility prev
    prev.pop if prev.length > steps_to_show

reconnect()


# INPUT
last_mouse = new Date().getTime()
document.onmousemove = (e) ->
  return
  return unless socket?
  now = new Date().getTime()
  return if now - last_mouse < 30
  last_mouse = now
  socket.emit 'mouse'
    x: e.clientX + window.scrollX
    y: e.clientY + window.scrollY
  true

register_clicks = ->
  for cell in cell_list
    cell.onclick = ->
      socket.emit 'choose'
        x: @x
        y: @y
