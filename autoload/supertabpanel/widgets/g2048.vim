" vim-supertabpanel : 2048 game widget

let s:board = []
let s:score = 0
let s:size = 4
let s:last_btn = ''

function! s:setup_colors() abort
  hi default SuperTabPanelG2Head  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelG2      guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
  hi default SuperTabPanelG2T2    guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelG2T4    guifg=#7aa2f7 guibg=#1a1b26 ctermfg=111 ctermbg=234
  hi default SuperTabPanelG2T8    guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelG2T16   guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelG2T32   guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelG2Btn   guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelG2BtnHit guifg=#1a1b26 guibg=#bb9af7 gui=bold cterm=bold ctermfg=234 ctermbg=141
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
        \ ? '%#SuperTabPanelG2BtnHit#'
        \ : '%#SuperTabPanelG2Btn#'
endfunction

function! s:empty_cells() abort
  let cells = []
  for r in range(s:size)
    for c in range(s:size)
      if s:board[r][c] == 0
        call add(cells, [r, c])
      endif
    endfor
  endfor
  return cells
endfunction

function! s:add_random() abort
  let cells = s:empty_cells()
  if empty(cells)
    return
  endif
  let p = cells[rand() % len(cells)]
  let s:board[p[0]][p[1]] = (rand() % 10 == 0) ? 4 : 2
endfunction

function! s:reset() abort
  let s:board = []
  for _ in range(s:size)
    call add(s:board, repeat([0], s:size))
  endfor
  let s:score = 0
  call s:add_random()
  call s:add_random()
endfunction

function! s:slide_row(row) abort
  let vals = filter(copy(a:row), 'v:val != 0')
  let out = []
  let i = 0
  while i < len(vals)
    if i + 1 < len(vals) && vals[i] == vals[i + 1]
      call add(out, vals[i] * 2)
      let s:score += vals[i] * 2
      let i += 2
    else
      call add(out, vals[i])
      let i += 1
    endif
  endwhile
  while len(out) < s:size
    call add(out, 0)
  endwhile
  return out
endfunction

function! s:move(dir) abort
  let changed = 0
  if a:dir ==# 'L'
    for r in range(s:size)
      let new_row = s:slide_row(s:board[r])
      if new_row != s:board[r]
        let s:board[r] = new_row
        let changed = 1
      endif
    endfor
  elseif a:dir ==# 'R'
    for r in range(s:size)
      let new_row = reverse(s:slide_row(reverse(copy(s:board[r]))))
      if new_row != s:board[r]
        let s:board[r] = new_row
        let changed = 1
      endif
    endfor
  elseif a:dir ==# 'U'
    for c in range(s:size)
      let col = map(range(s:size), 's:board[v:val][c]')
      let new_col = s:slide_row(col)
      for r in range(s:size)
        if s:board[r][c] != new_col[r]
          let s:board[r][c] = new_col[r]
          let changed = 1
        endif
      endfor
    endfor
  elseif a:dir ==# 'D'
    for c in range(s:size)
      let col = map(range(s:size), 's:board[v:val][c]')
      let new_col = reverse(s:slide_row(reverse(col)))
      for r in range(s:size)
        if s:board[r][c] != new_col[r]
          let s:board[r][c] = new_col[r]
          let changed = 1
        endif
      endfor
    endfor
  endif
  if changed
    call s:add_random()
  endif
  redrawtabpanel
endfunction

function! supertabpanel#widgets#g2048#up(info) abort
  call s:flash_btn('up')
  call s:move('U') | return 1
endfunction
function! supertabpanel#widgets#g2048#down(info) abort
  call s:flash_btn('down')
  call s:move('D') | return 1
endfunction
function! supertabpanel#widgets#g2048#left(info) abort
  call s:flash_btn('left')
  call s:move('L') | return 1
endfunction
function! supertabpanel#widgets#g2048#right(info) abort
  call s:flash_btn('right')
  call s:move('R') | return 1
endfunction
function! supertabpanel#widgets#g2048#reset(info) abort
  call s:flash_btn('reset')
  call s:reset()
  redrawtabpanel
  return 1
endfunction

function! s:tile_hl(v) abort
  if a:v == 0   | return '%#SuperTabPanelG2#'   | endif
  if a:v <= 2   | return '%#SuperTabPanelG2T2#' | endif
  if a:v <= 4   | return '%#SuperTabPanelG2T4#' | endif
  if a:v <= 8   | return '%#SuperTabPanelG2T8#' | endif
  if a:v <= 16  | return '%#SuperTabPanelG2T16#' | endif
  return '%#SuperTabPanelG2T32#'
endfunction

function! supertabpanel#widgets#g2048#render() abort
  let result = '%#SuperTabPanelG2Head#  🟦 2048  ' .. s:score .. '%@'
  for r in range(s:size)
    let line = '  '
    for c in range(s:size)
      let v = s:board[r][c]
      let cell = v == 0 ? '   .' : printf('%4d', v)
      let line ..= s:tile_hl(v) .. cell
    endfor
    let result ..= line .. '%@'
  endfor
  let result ..= '%#SuperTabPanelG2#  '
  let result ..= '%0[supertabpanel#widgets#g2048#up]' .. s:bhl('up') .. ' ↑ %[]'
  let result ..= '%0[supertabpanel#widgets#g2048#down]' .. s:bhl('down') .. ' ↓ %[]'
  let result ..= '%0[supertabpanel#widgets#g2048#left]' .. s:bhl('left') .. ' ← %[]'
  let result ..= '%0[supertabpanel#widgets#g2048#right]' .. s:bhl('right') .. ' → %[]'
  let result ..= '%0[supertabpanel#widgets#g2048#reset]' .. s:bhl('reset') .. ' ⟲ %[]%@'
  return result
endfunction

function! supertabpanel#widgets#g2048#init() abort
  call s:setup_colors()
  augroup supertabpanel_g2_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call s:reset()
  call supertabpanel#register('g2048', #{
        \ icon: '🟦',
        \ label: '2048',
        \ render: function('supertabpanel#widgets#g2048#render'),
        \ })
endfunction
