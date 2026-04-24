" vim-supertabpanel : registers widget

function! s:setup_colors() abort
  hi default SuperTabPanelRegHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelRegName guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelReg     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

let s:regs = ['"', '*', '+', '-', '0', '1', '2', '3', '4', '5',
      \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']

function! supertabpanel#widgets#registers#paste(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:regs)
    return 0
  endif
  let r = s:regs[idx]
  execute 'normal! "' .. r .. 'p'
  return 1
endfunction

function! supertabpanel#widgets#registers#render() abort
  let result = '%#SuperTabPanelRegHead#  📋 Registers%@'
  let idx = 0
  for r in s:regs
    let val = getreg(r)
    if val ==# ''
      let idx += 1
      continue
    endif
    let val = substitute(val, '\n', ' ', 'g')
    let val = substitute(val, '\t', ' ', 'g')
    let val = substitute(val, '%', '%%', 'g')
    if strdisplaywidth(val) > 22
      let val = strcharpart(val, 0, 20) .. '..'
    endif
    let result ..= '%' .. idx .. '[supertabpanel#widgets#registers#paste]'
          \ .. '%#SuperTabPanelRegName#  "' .. r .. ' '
          \ .. '%#SuperTabPanelReg#' .. val .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#registers#init() abort
  call s:setup_colors()
  augroup supertabpanel_reg_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('registers', #{
        \ icon: '📋',
        \ label: 'Registers',
        \ render: function('supertabpanel#widgets#registers#render'),
        \ })
endfunction
