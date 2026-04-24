" vim-supertabpanel : registers widget

let s:preview_cache = {}

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

" keytrans() sanitizes embedded keycodes to plain text like <Esc>, which
" both reads better and keeps control bytes out of the tabpanel format
" string (otherwise redraws during rotation animation are expensive).
" Undo keytrans' expansion of plain whitespace — we only care about
" special keys, not every literal space/tab becoming '<Space>'/<Tab>.
" The cache holds the untruncated sanitized form so panel width changes
" stay correct on the next render.
function! s:preview_of(val) abort
  let cached = get(s:preview_cache, a:val, v:null)
  if cached is v:null
    let p = keytrans(a:val)
    let p = substitute(p, '<Space>', ' ', 'g')
    let p = substitute(p, '<Tab>',   ' ', 'g')
    let p = substitute(p, '<NL>',    '⏎', 'g')
    let cached = p
    let s:preview_cache[a:val] = cached
  endif
  let p = supertabpanel#truncate(cached, supertabpanel#content_width(5))
  return substitute(p, '%', '%%', 'g')
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
    let result ..= '%' .. idx .. '[supertabpanel#widgets#registers#paste]'
          \ .. '%#SuperTabPanelRegName#  "' .. r .. ' '
          \ .. '%#SuperTabPanelReg#' .. s:preview_of(val) .. '%[]%@'
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
