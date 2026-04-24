" vim-supertabpanel : Tetris widget (click controls)

let s:w = 10
let s:h = 16
let s:board = []
let s:piece = {}
let s:score = 0
let s:timer = -1
let s:running = 0
let s:game_over = 0
let s:last_btn = ''

" [[r][c]] offsets per piece, 4 rotations each.
let s:shapes = {
      \ 'I': [[[1,0],[1,1],[1,2],[1,3]],
      \       [[0,2],[1,2],[2,2],[3,2]],
      \       [[2,0],[2,1],[2,2],[2,3]],
      \       [[0,1],[1,1],[2,1],[3,1]]],
      \ 'O': [[[0,1],[0,2],[1,1],[1,2]],
      \       [[0,1],[0,2],[1,1],[1,2]],
      \       [[0,1],[0,2],[1,1],[1,2]],
      \       [[0,1],[0,2],[1,1],[1,2]]],
      \ 'T': [[[0,1],[1,0],[1,1],[1,2]],
      \       [[0,1],[1,1],[1,2],[2,1]],
      \       [[1,0],[1,1],[1,2],[2,1]],
      \       [[0,1],[1,0],[1,1],[2,1]]],
      \ 'L': [[[0,2],[1,0],[1,1],[1,2]],
      \       [[0,1],[1,1],[2,1],[2,2]],
      \       [[1,0],[1,1],[1,2],[2,0]],
      \       [[0,0],[0,1],[1,1],[2,1]]],
      \ 'J': [[[0,0],[1,0],[1,1],[1,2]],
      \       [[0,1],[0,2],[1,1],[2,1]],
      \       [[1,0],[1,1],[1,2],[2,2]],
      \       [[0,1],[1,1],[2,0],[2,1]]],
      \ 'S': [[[0,1],[0,2],[1,0],[1,1]],
      \       [[0,1],[1,1],[1,2],[2,2]],
      \       [[1,1],[1,2],[2,0],[2,1]],
      \       [[0,0],[1,0],[1,1],[2,1]]],
      \ 'Z': [[[0,0],[0,1],[1,1],[1,2]],
      \       [[0,2],[1,1],[1,2],[2,1]],
      \       [[1,0],[1,1],[2,1],[2,2]],
      \       [[0,1],[1,0],[1,1],[2,0]]],
      \ }

let s:names = ['I', 'O', 'T', 'L', 'J', 'S', 'Z']

function! s:setup_colors() abort
  hi default SuperTabPanelTetHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTet      guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTetBlk   guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
  hi default SuperTabPanelTetFill  guifg=#7dcfff guibg=#1a1b26 ctermfg=117 ctermbg=234
  hi default SuperTabPanelTetBtn   guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelTetBtnHit guifg=#1a1b26 guibg=#bb9af7 gui=bold cterm=bold ctermfg=234 ctermbg=141
  hi default SuperTabPanelTetOver  guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
endfunction

function! s:flash_btn(name) abort
  let s:last_btn = a:name
  call timer_start(150, {-> s:clear_btn()})
endfunction

function! s:clear_btn() abort
  let s:last_btn = ''
  redrawtabpanel
endfunction

function! s:bhl(name) abort
  return s:last_btn ==# a:name
        \ ? '%#SuperTabPanelTetBtnHit#'
        \ : '%#SuperTabPanelTetBtn#'
endfunction

function! s:make_board() abort
  let s:board = []
  for _ in range(s:h)
    call add(s:board, repeat([0], s:w))
  endfor
endfunction

function! s:spawn() abort
  let name = s:names[rand() % len(s:names)]
  let s:piece = #{
        \ name: name,
        \ r: 0, c: s:w / 2 - 2,
        \ rot: 0,
        \ }
  if !s:can_place(s:piece)
    let s:game_over = 1
    let s:running = 0
  endif
endfunction

function! s:cells(p) abort
  let out = []
  for off in s:shapes[a:p.name][a:p.rot]
    call add(out, [a:p.r + off[0], a:p.c + off[1]])
  endfor
  return out
endfunction

function! s:can_place(p) abort
  for rc in s:cells(a:p)
    let r = rc[0]
    let c = rc[1]
    if r < 0 || r >= s:h || c < 0 || c >= s:w
      return 0
    endif
    if s:board[r][c] != 0
      return 0
    endif
  endfor
  return 1
endfunction

function! s:lock() abort
  for rc in s:cells(s:piece)
    let s:board[rc[0]][rc[1]] = 1
  endfor
  " Clear full rows.
  let cleared = 0
  let r = s:h - 1
  while r >= 0
    if index(s:board[r], 0) < 0
      call remove(s:board, r)
      call insert(s:board, repeat([0], s:w), 0)
      let cleared += 1
    else
      let r -= 1
    endif
  endwhile
  let s:score += cleared * 100
  call s:spawn()
endfunction

function! s:try_move(dr, dc) abort
  let p = copy(s:piece)
  let p.r += a:dr
  let p.c += a:dc
  if s:can_place(p)
    let s:piece = p
    return 1
  endif
  return 0
endfunction

function! s:tick(timer) abort
  if !s:running
    return
  endif
  if !s:try_move(1, 0)
    call s:lock()
  endif
  redrawtabpanel
endfunction

function! supertabpanel#widgets#tetris#left(info) abort
  if !s:running | return 0 | endif
  call s:flash_btn('left')
  call s:try_move(0, -1)
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tetris#right(info) abort
  if !s:running | return 0 | endif
  call s:flash_btn('right')
  call s:try_move(0, 1)
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tetris#down(info) abort
  if !s:running | return 0 | endif
  call s:flash_btn('down')
  if !s:try_move(1, 0)
    call s:lock()
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tetris#rotate(info) abort
  if !s:running | return 0 | endif
  call s:flash_btn('rotate')
  let p = copy(s:piece)
  let p.rot = (p.rot + 1) % 4
  if s:can_place(p)
    let s:piece = p
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tetris#start(info) abort
  call s:flash_btn('start')
  if s:game_over || empty(s:piece)
    call s:make_board()
    let s:score = 0
    let s:game_over = 0
    call s:spawn()
  endif
  let s:running = !s:running
  if s:running && s:timer == -1
    let s:timer = timer_start(500, function('s:tick'), #{ repeat: -1 })
  endif
  if !s:running && s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tetris#render() abort
  let result = '%#SuperTabPanelTetHead#  🎮 Tetris  ' .. s:score .. '%@'
  if s:game_over
    let result ..= '%#SuperTabPanelTetOver#    GAME OVER%@'
  endif
  let overlay = {}
  if !empty(s:piece) && !s:game_over
    for rc in s:cells(s:piece)
      let overlay[rc[0] . '_' . rc[1]] = 1
    endfor
  endif
  for r in range(s:h)
    let line = '%#SuperTabPanelTet#  '
    for c in range(s:w)
      let key = r . '_' . c
      if has_key(overlay, key)
        let line ..= '%#SuperTabPanelTetFill#██'
      elseif s:board[r][c] == 1
        let line ..= '%#SuperTabPanelTetBlk#██'
      else
        let line ..= '%#SuperTabPanelTet#··'
      endif
    endfor
    let result ..= line .. '%@'
  endfor
  let btn = s:running ? '⏸' : (s:game_over ? '⟲' : '▶')
  let result ..= '%#SuperTabPanelTet#  '
  let result ..= '%0[supertabpanel#widgets#tetris#start]' .. s:bhl('start') .. ' ' .. btn .. ' ' .. '%[]'
  let result ..= '%0[supertabpanel#widgets#tetris#left]' .. s:bhl('left') .. ' ← ' .. '%[]'
  let result ..= '%0[supertabpanel#widgets#tetris#rotate]' .. s:bhl('rotate') .. ' ↻ ' .. '%[]'
  let result ..= '%0[supertabpanel#widgets#tetris#right]' .. s:bhl('right') .. ' → ' .. '%[]'
  let result ..= '%0[supertabpanel#widgets#tetris#down]' .. s:bhl('down') .. ' ↓ ' .. '%[]%@'
  return result
endfunction

function! supertabpanel#widgets#tetris#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  let s:running = 0
endfunction

function! supertabpanel#widgets#tetris#init() abort
  call s:setup_colors()
  augroup supertabpanel_tet_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call s:make_board()
  call supertabpanel#register('tetris', #{
        \ icon: '🎮',
        \ label: 'Tetris',
        \ render: function('supertabpanel#widgets#tetris#render'),
        \ on_deactivate: function('supertabpanel#widgets#tetris#deactivate'),
        \ })
endfunction
