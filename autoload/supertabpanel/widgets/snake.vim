" vim-supertabpanel : Snake game widget

let s:w = 14
let s:h = 10
let s:snake = []
let s:dir = [0, 1]
let s:food = [0, 0]
let s:score = 0
let s:running = 0
let s:game_over = 0
let s:timer = -1
let s:last_btn = ''

function! s:setup_colors() abort
  hi default SuperTabPanelSnHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelSn     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelSnBody guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelSnFood guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelSnBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelSnBtnHit guifg=#1a1b26 guibg=#bb9af7 gui=bold cterm=bold ctermfg=234 ctermbg=141
  hi default SuperTabPanelSnOver guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
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
        \ ? '%#SuperTabPanelSnBtnHit#'
        \ : '%#SuperTabPanelSnBtn#'
endfunction

function! s:place_food() abort
  while 1
    let s:food = [rand() % s:h, rand() % s:w]
    if index(s:snake, s:food) < 0
      return
    endif
  endwhile
endfunction

function! s:reset() abort
  let s:snake = [[s:h / 2, s:w / 2]]
  let s:dir = [0, 1]
  let s:score = 0
  let s:game_over = 0
  call s:place_food()
endfunction

function! s:tick(timer) abort
  if !s:running || s:game_over
    return
  endif
  let head = s:snake[0]
  let new_head = [head[0] + s:dir[0], head[1] + s:dir[1]]
  if new_head[0] < 0 || new_head[0] >= s:h
        \ || new_head[1] < 0 || new_head[1] >= s:w
        \ || index(s:snake, new_head) >= 0
    let s:game_over = 1
    let s:running = 0
    redrawtabpanel
    return
  endif
  call insert(s:snake, new_head, 0)
  if new_head == s:food
    let s:score += 10
    call s:place_food()
  else
    call remove(s:snake, -1)
  endif
  redrawtabpanel
endfunction

function! supertabpanel#widgets#snake#up(info) abort
  call s:flash_btn('up')
  if s:dir[0] == 0
    let s:dir = [-1, 0]
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#snake#down(info) abort
  call s:flash_btn('down')
  if s:dir[0] == 0
    let s:dir = [1, 0]
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#snake#left(info) abort
  call s:flash_btn('left')
  if s:dir[1] == 0
    let s:dir = [0, -1]
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#snake#right(info) abort
  call s:flash_btn('right')
  if s:dir[1] == 0
    let s:dir = [0, 1]
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#snake#start(info) abort
  call s:flash_btn('start')
  if s:game_over || empty(s:snake)
    call s:reset()
  endif
  let s:running = !s:running
  if s:running && s:timer == -1
    let s:timer = timer_start(200, function('s:tick'), #{ repeat: -1 })
  endif
  if !s:running && s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#snake#render() abort
  let result = '%#SuperTabPanelSnHead#  🐍 Snake  ' .. s:score .. '%@'
  if s:game_over
    let result ..= '%#SuperTabPanelSnOver#    GAME OVER%@'
  endif
  let body = {}
  for p in s:snake
    let body[p[0] . '_' . p[1]] = 1
  endfor
  for r in range(s:h)
    let line = '%#SuperTabPanelSn#  '
    for c in range(s:w)
      let key = r . '_' . c
      if has_key(body, key)
        let line ..= '%#SuperTabPanelSnBody#██'
      elseif [r, c] == s:food
        let line ..= '%#SuperTabPanelSnFood# ●'
      else
        let line ..= '%#SuperTabPanelSn#··'
      endif
    endfor
    let result ..= line .. '%@'
  endfor
  let btn = s:running ? '⏸' : (s:game_over ? '⟲' : '▶')
  let result ..= '%#SuperTabPanelSn#  '
  let result ..= '%0[supertabpanel#widgets#snake#start]' .. s:bhl('start') .. ' ' .. btn .. ' ' .. '%[]'
  let result ..= '%0[supertabpanel#widgets#snake#up]' .. s:bhl('up') .. ' ↑ %[]'
  let result ..= '%0[supertabpanel#widgets#snake#down]' .. s:bhl('down') .. ' ↓ %[]'
  let result ..= '%0[supertabpanel#widgets#snake#left]' .. s:bhl('left') .. ' ← %[]'
  let result ..= '%0[supertabpanel#widgets#snake#right]' .. s:bhl('right') .. ' → %[]%@'
  return result
endfunction

function! supertabpanel#widgets#snake#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  let s:running = 0
endfunction

function! supertabpanel#widgets#snake#init() abort
  call s:setup_colors()
  augroup supertabpanel_sn_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call s:reset()
  call supertabpanel#register('snake', #{
        \ icon: '🐍',
        \ label: 'Snake',
        \ render: function('supertabpanel#widgets#snake#render'),
        \ on_deactivate: function('supertabpanel#widgets#snake#deactivate'),
        \ })
endfunction
