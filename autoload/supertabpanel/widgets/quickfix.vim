" vim-supertabpanel : quickfix widget

function! s:setup_colors() abort
  hi default SuperTabPanelQfHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelQf     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelQfErr  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelQfWarn guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
endfunction

function! supertabpanel#widgets#quickfix#jump(info) abort
  let idx = a:info.minwid
  if idx >= 0
    execute (idx + 1) .. 'cc'
  endif
  return 1
endfunction

function! supertabpanel#widgets#quickfix#render() abort
  let list = getqflist()
  let result = '%#SuperTabPanelQfHead#  ⚠ Quickfix (' .. len(list) .. ')%@'
  if empty(list)
    return result .. '%#SuperTabPanelQf#  (empty)%@'
  endif
  let idx = 0
  for q in list[:14]
    let file = fnamemodify(bufname(q.bufnr), ':t')
    if file ==# '' | let file = '?' | endif
    let text = substitute(q.text, '^\s\+\|\s\+$', '', 'g')
    let txt = supertabpanel#truncate(file .. ':' .. q.lnum .. ' ' .. text, supertabpanel#content_width(6))
    let txt = substitute(txt, '%', '%%', 'g')
    let hl = '%#SuperTabPanelQf#'
    if q.type ==# 'E' || q.type ==# 'e'
      let hl = '%#SuperTabPanelQfErr#'
    elseif q.type ==# 'W' || q.type ==# 'w'
      let hl = '%#SuperTabPanelQfWarn#'
    endif
    let result ..= '%' .. idx .. '[supertabpanel#widgets#quickfix#jump]'
          \ .. hl .. '  ' .. txt .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#quickfix#activate() abort
  augroup supertabpanel_qf
    autocmd!
    autocmd QuickFixCmdPost * if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#quickfix#deactivate() abort
  augroup supertabpanel_qf
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#quickfix#init() abort
  call s:setup_colors()
  augroup supertabpanel_qf_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('quickfix', #{
        \ icon: '⚠',
        \ label: 'Quickfix',
        \ render: function('supertabpanel#widgets#quickfix#render'),
        \ on_activate: function('supertabpanel#widgets#quickfix#activate'),
        \ on_deactivate: function('supertabpanel#widgets#quickfix#deactivate'),
        \ })
endfunction
