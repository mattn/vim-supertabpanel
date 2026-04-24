" vim-supertabpanel : random ASCII art widget

let s:timer = -1
let s:current = 0
let s:arts = get(g:, 'supertabpanel_asciiart', [
      \ ['   /\_/\ ', '  ( o.o )', '   > ^ < '],
      \ ['  (\_/) ', '  (•_•) ', '  />🥕  '],
      \ ['  ʕ •ᴥ•ʔ', ],
      \ ['   _,_   ', '  (o.o)  ', '  (___)  ', '   " "   '],
      \ [' (◕‿◕) ', ],
      \ ['  /\ /\ ', ' |  o o|', '  \ ~ / ', '   \_/  '],
      \ ['  ┏(・o・)┛ ♪ '],
      \ ['  (っ◔◡◔)っ ♥ '],
      \ ])

function! s:setup_colors() abort
  hi default SuperTabPanelAaHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelAa     guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
endfunction

function! s:rotate(timer) abort
  if empty(s:arts)
    return
  endif
  let s:current = (s:current + 1) % len(s:arts)
  redrawtabpanel
endfunction

function! supertabpanel#widgets#asciiart#next(info) abort
  call s:rotate(0)
  return 1
endfunction

function! supertabpanel#widgets#asciiart#render() abort
  let result = '%#SuperTabPanelAaHead#  🎨 Art%@'
  if empty(s:arts)
    return result
  endif
  for l in s:arts[s:current]
    let l = substitute(l, '%', '%%', 'g')
    let result ..= '%0[supertabpanel#widgets#asciiart#next]'
          \ .. '%#SuperTabPanelAa#  ' .. l .. '%[]%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#asciiart#activate() abort
  if s:timer == -1
    let s:timer = timer_start(10000,
          \ function('s:rotate'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#asciiart#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#asciiart#init() abort
  call s:setup_colors()
  augroup supertabpanel_aa_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('asciiart', #{
        \ icon: '🎨',
        \ label: 'ASCII Art',
        \ render: function('supertabpanel#widgets#asciiart#render'),
        \ on_activate: function('supertabpanel#widgets#asciiart#activate'),
        \ on_deactivate: function('supertabpanel#widgets#asciiart#deactivate'),
        \ })
endfunction
