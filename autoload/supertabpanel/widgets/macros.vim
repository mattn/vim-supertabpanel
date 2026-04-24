" vim-supertabpanel : macros widget (replay registers a-z)

let s:preview_cache = {}

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

" Build the display preview for a raw register value.  keytrans() turns
" embedded keycodes (e.g. <80>ku) into plain text like <Up>; this both
" makes the preview readable and keeps control bytes out of the tabpanel
" format string, which otherwise slows down animation redraws badly.
" Undo keytrans' expansion of plain whitespace so literal spaces/tabs
" don't bloat the preview into multiple cells each.  The cache holds the
" untruncated sanitized form, so panel width changes apply on the next
" render instead of re-using a stale truncation.
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
  let p = supertabpanel#truncate(cached, supertabpanel#content_width(12))
  return substitute(p, '%', '%%', 'g')
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
    let result ..= '%' .. i .. '[supertabpanel#widgets#macros#play]'
          \ .. '%#SuperTabPanelMacName#  @' .. name .. ' '
          \ .. '%#SuperTabPanelMac#' .. s:preview_of(val) .. '%[]%@'
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
