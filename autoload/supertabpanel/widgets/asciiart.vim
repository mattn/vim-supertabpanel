" vim-supertabpanel : random ASCII art widget
"
" Instance params:
"   arts : list of art frames.  Each frame is a list of lines.

let s:instances = []
let s:colors_ready = 0

function! s:default_arts() abort
  return [
        \ ['   /\_/\ ', '  ( o.o )', '   > ^ < '],
        \ ['  (\_/) ', '  (•_•) ', '  />🥕  '],
        \ ['  ʕ •ᴥ•ʔ', ],
        \ ['   _,_   ', '  (o.o)  ', '  (___)  ', '   " "   '],
        \ [' (◕‿◕) ', ],
        \ ['  /\ /\ ', ' |  o o|', '  \ ~ / ', '   \_/  '],
        \ ['  ┏(・o・)┛ ♪ '],
        \ ['  (っ◔◡◔)っ ♥ '],
        \ ]
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelAaHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelAa     guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
endfunction

function! s:rotate(id, timer) abort
  let inst = s:instances[a:id]
  if empty(inst.arts)
    return
  endif
  let inst.current = (inst.current + 1) % len(inst.arts)
  redrawtabpanel
endfunction

function! supertabpanel#widgets#asciiart#next(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  call s:rotate(id, 0)
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelAaHead#  🎨 Art%@'
  if empty(inst.arts)
    return result
  endif
  for l in inst.arts[inst.current]
    let l = substitute(l, '%', '%%', 'g')
    let result ..= '%' .. a:id .. '[supertabpanel#widgets#asciiart#next]'
          \ .. '%#SuperTabPanelAa#  ' .. l .. '%[]%@'
  endfor
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    let inst.timer = timer_start(10000,
          \ function('s:rotate', [a:id]), #{ repeat: -1 })
  endif
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  if inst.timer != -1
    call timer_stop(inst.timer)
    let inst.timer = -1
  endif
endfunction

function! supertabpanel#widgets#asciiart#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_aa_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ arts: get(a:params, 'arts', s:default_arts()),
        \ current: 0,
        \ timer: -1,
        \ })
  return #{
        \ icon: '🎨',
        \ label: 'ASCII Art',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
