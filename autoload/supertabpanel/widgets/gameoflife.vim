" vim-supertabpanel : Conway's Game of Life widget

let s:w = 14
let s:h = 10
let s:grid = []
let s:timer = -1
let s:running = 0
let s:last_btn = ''

function! s:setup_colors() abort
  hi default SuperTabPanelGlHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelGl     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelGlLive guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelGlBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelGlBtnHit guifg=#1a1b26 guibg=#bb9af7 gui=bold cterm=bold ctermfg=234 ctermbg=141
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
        \ ? '%#SuperTabPanelGlBtnHit#'
        \ : '%#SuperTabPanelGlBtn#'
endfunction

function! s:make_grid() abort
  let s:grid = []
  for _ in range(s:h)
    call add(s:grid, repeat([0], s:w))
  endfor
endfunction

function! s:seed() abort
  call s:make_grid()
  " glider
  let s:grid[1][2] = 1
  let s:grid[2][3] = 1
  let s:grid[3][1] = 1
  let s:grid[3][2] = 1
  let s:grid[3][3] = 1
endfunction

function! s:step() abort
  let new = []
  for _ in range(s:h)
    call add(new, repeat([0], s:w))
  endfor
  for y in range(s:h)
    for x in range(s:w)
      let n = 0
      for dy in [-1, 0, 1]
        for dx in [-1, 0, 1]
          if dx == 0 && dy == 0 | continue | endif
          let yy = (y + dy + s:h) % s:h
          let xx = (x + dx + s:w) % s:w
          let n += s:grid[yy][xx]
        endfor
      endfor
      if s:grid[y][x] == 1 && (n == 2 || n == 3)
        let new[y][x] = 1
      elseif s:grid[y][x] == 0 && n == 3
        let new[y][x] = 1
      endif
    endfor
  endfor
  let s:grid = new
endfunction

function! s:tick(timer) abort
  if !s:running
    return
  endif
  call s:step()
  redrawtabpanel
endfunction

function! supertabpanel#widgets#gameoflife#toggle_cell(info) abort
  let idx = a:info.minwid
  let y = idx / s:w
  let x = idx % s:w
  if y >= 0 && y < s:h && x >= 0 && x < s:w
    let s:grid[y][x] = s:grid[y][x] == 1 ? 0 : 1
    redrawtabpanel
  endif
  return 1
endfunction

function! supertabpanel#widgets#gameoflife#play(info) abort
  call s:flash_btn('play')
  let s:running = !s:running
  if s:running && s:timer == -1
    let s:timer = timer_start(400,
          \ function('s:tick'), #{ repeat: -1 })
  endif
  if !s:running && s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#gameoflife#step(info) abort
  call s:flash_btn('step')
  call s:step()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#gameoflife#reset(info) abort
  call s:flash_btn('reset')
  call s:seed()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#gameoflife#render() abort
  let result = '%#SuperTabPanelGlHead#  🧬 Life%@'
  let idx = 0
  for y in range(s:h)
    let line = '%#SuperTabPanelGl#  '
    for x in range(s:w)
      let cell = s:grid[y][x]
      let char = cell == 1 ? '██' : '··'
      let hl = cell == 1 ? '%#SuperTabPanelGlLive#' : '%#SuperTabPanelGl#'
      let line ..= '%' .. idx .. '[supertabpanel#widgets#gameoflife#toggle_cell]'
            \ .. hl .. char .. '%[]'
      let idx += 1
    endfor
    let result ..= line .. '%@'
  endfor
  let btn = s:running ? ' ⏸ pause' : ' ▶ play'
  let result ..= '%#SuperTabPanelGl#  '
  let result ..= '%0[supertabpanel#widgets#gameoflife#play]' .. s:bhl('play') .. btn .. '%[]'
  let result ..= '%0[supertabpanel#widgets#gameoflife#step]' .. s:bhl('step') .. ' ⏭ step%[]'
  let result ..= '%0[supertabpanel#widgets#gameoflife#reset]' .. s:bhl('reset') .. ' ⟲ reset%[]%@'
  return result
endfunction

function! supertabpanel#widgets#gameoflife#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  let s:running = 0
endfunction

function! supertabpanel#widgets#gameoflife#init() abort
  call s:setup_colors()
  augroup supertabpanel_gl_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call s:seed()
  call supertabpanel#register('gameoflife', #{
        \ icon: '🧬',
        \ label: 'Life',
        \ render: function('supertabpanel#widgets#gameoflife#render'),
        \ on_deactivate: function('supertabpanel#widgets#gameoflife#deactivate'),
        \ })
endfunction
