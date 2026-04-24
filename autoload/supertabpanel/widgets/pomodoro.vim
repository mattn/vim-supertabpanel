" vim-supertabpanel : pomodoro timer widget

let s:timer = -1
let s:remaining = 25 * 60
let s:running = 0
let s:work_sec = 25 * 60
let s:break_sec = 5 * 60
let s:mode = 'work'

function! s:setup_colors() abort
  hi default SuperTabPanelPomoHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelPomoTime  guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelPomoBtn   guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelPomoBreak guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
endfunction

function! s:tick(timer) abort
  if !s:running
    return
  endif
  let s:remaining -= 1
  if s:remaining <= 0
    let s:running = 0
    call timer_stop(s:timer)
    let s:timer = -1
    if executable('paplay')
      silent call system('paplay /usr/share/sounds/freedesktop/stereo/complete.oga &')
    endif
    echo s:mode ==# 'work' ? '🍅 Break time!' : '🍅 Back to work!'
    let s:mode = s:mode ==# 'work' ? 'break' : 'work'
    let s:remaining = s:mode ==# 'work' ? s:work_sec : s:break_sec
  endif
  redrawtabpanel
endfunction

function! supertabpanel#widgets#pomodoro#start(info) abort
  if !s:running
    let s:running = 1
    if s:timer == -1
      let s:timer = timer_start(1000,
            \ function('s:tick'), #{ repeat: -1 })
    endif
  else
    let s:running = 0
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#pomodoro#reset(info) abort
  let s:running = 0
  let s:mode = 'work'
  let s:remaining = s:work_sec
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#pomodoro#render() abort
  let mm = s:remaining / 60
  let ss = s:remaining % 60
  let time = printf('%02d:%02d', mm, ss)
  let mode_icon = s:mode ==# 'work' ? '🍅' : '☕'
  let mode_hl = s:mode ==# 'work' ? '%#SuperTabPanelPomoTime#' : '%#SuperTabPanelPomoBreak#'
  let btn = s:running ? ' ⏸ pause' : ' ▶ start'
  let result = '%#SuperTabPanelPomoHead#  ' .. mode_icon .. ' Pomodoro%@'
  let result ..= mode_hl .. '      ' .. time .. '%@'
  let result ..= '%0[supertabpanel#widgets#pomodoro#start]'
        \ .. '%#SuperTabPanelPomoBtn#  ' .. btn .. '%[]%@'
  let result ..= '%0[supertabpanel#widgets#pomodoro#reset]'
        \ .. '%#SuperTabPanelPomoBtn#  ⟲ reset%[]%@'
  return result
endfunction

function! supertabpanel#widgets#pomodoro#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  let s:running = 0
endfunction

function! supertabpanel#widgets#pomodoro#init() abort
  call s:setup_colors()
  augroup supertabpanel_pomo_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('pomodoro', #{
        \ icon: '🍅',
        \ label: 'Pomodoro',
        \ render: function('supertabpanel#widgets#pomodoro#render'),
        \ on_deactivate: function('supertabpanel#widgets#pomodoro#deactivate'),
        \ })
endfunction
