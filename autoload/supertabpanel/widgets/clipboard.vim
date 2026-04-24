" vim-supertabpanel : clipboard / yank history widget

let s:history = []
let s:max = 10

function! s:setup_colors() abort
  hi default SuperTabPanelClipHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelClip     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! supertabpanel#widgets#clipboard#record() abort
  let txt = getreg('"')
  if txt ==# ''
    return
  endif
  call filter(s:history, 'v:val !=# txt')
  call insert(s:history, txt, 0)
  if len(s:history) > s:max
    let s:history = s:history[:s:max - 1]
  endif
  if &showtabpanel
    redrawtabpanel
  endif
endfunction

function! supertabpanel#widgets#clipboard#paste(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:history)
    call setreg('"', s:history[idx])
    execute 'normal! ""p'
  endif
  return 1
endfunction

function! supertabpanel#widgets#clipboard#render() abort
  let result = '%#SuperTabPanelClipHead#  📋 Clipboard%@'
  if empty(s:history)
    return result .. '%#SuperTabPanelClip#  (empty)%@'
  endif
  let idx = 0
  for t in s:history
    let preview = substitute(t, '\n', '⏎', 'g')
    let preview = substitute(preview, '\t', '⇥', 'g')
    let preview = supertabpanel#truncate(preview, supertabpanel#content_width(6))
    let preview = substitute(preview, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#clipboard#paste]'
          \ .. '%#SuperTabPanelClip#  ' .. preview .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#clipboard#activate() abort
  augroup supertabpanel_clipboard
    autocmd!
    autocmd TextYankPost * call supertabpanel#widgets#clipboard#record()
  augroup END
endfunction

function! supertabpanel#widgets#clipboard#deactivate() abort
  augroup supertabpanel_clipboard
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#clipboard#init() abort
  call s:setup_colors()
  augroup supertabpanel_clip_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('clipboard', #{
        \ icon: '📋',
        \ label: 'Clipboard',
        \ render: function('supertabpanel#widgets#clipboard#render'),
        \ on_activate: function('supertabpanel#widgets#clipboard#activate'),
        \ on_deactivate: function('supertabpanel#widgets#clipboard#deactivate'),
        \ })
endfunction
