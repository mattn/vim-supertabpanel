" vim-supertabpanel : macros widget (replay registers a-z)

function! s:setup_colors() abort
  hi default SuperTabPanelMacHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelMacName guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelMac     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! supertabpanel#widgets#macros#play(info) abort
  let idx = a:info.minwid
  let name = nr2char(char2nr('a') + idx)
  execute 'normal! @' .. name
  return 1
endfunction

function! supertabpanel#widgets#macros#render() abort
  let result = '%#SuperTabPanelMacHead#  🎬 Macros%@'
  let any = 0
  for i in range(26)
    let name = nr2char(char2nr('a') + i)
    let val = getreg(name)
    if val ==# ''
      continue
    endif
    let any = 1
    let preview = substitute(val, '\n', '⏎', 'g')
    let preview = substitute(preview, '\t', '⇥', 'g')
    let preview = supertabpanel#truncate(preview, supertabpanel#content_width(12))
    let preview = substitute(preview, '%', '%%', 'g')
    let result ..= '%' .. i .. '[supertabpanel#widgets#macros#play]'
          \ .. '%#SuperTabPanelMacName#  @' .. name .. ' '
          \ .. '%#SuperTabPanelMac#' .. preview .. '%[]%@'
  endfor
  if !any
    let result ..= '%#SuperTabPanelMac#  (no recorded macros)%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#macros#init() abort
  call s:setup_colors()
  augroup supertabpanel_mac_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('macros', #{
        \ icon: '🎬',
        \ label: 'Macros',
        \ render: function('supertabpanel#widgets#macros#render'),
        \ })
endfunction
