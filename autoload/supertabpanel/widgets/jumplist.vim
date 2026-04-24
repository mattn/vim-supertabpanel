" vim-supertabpanel : jumplist widget

function! s:setup_colors() abort
  hi default SuperTabPanelJlHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelJl     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

let s:snapshot = []
let s:snapshot_cur = 0

function! s:refresh() abort
  let jl = getjumplist()
  let s:snapshot = jl[0]
  let s:snapshot_cur = jl[1]
endfunction

function! supertabpanel#widgets#jumplist#jump(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:snapshot)
    return 0
  endif
  call supertabpanel#flash('jumplist', idx)
  let diff = idx - s:snapshot_cur
  if diff < 0
    execute 'normal! ' .. (-diff) .. "\<C-O>"
  elseif diff > 0
    execute 'normal! ' .. diff .. "\<C-I>"
  endif
  return 1
endfunction

function! supertabpanel#widgets#jumplist#render() abort
  call s:refresh()
  let result = '%#SuperTabPanelJlHead#  ↔ Jumplist%@'
  if empty(s:snapshot)
    return result .. '%#SuperTabPanelJl#  (empty)%@'
  endif
  let start = max([0, len(s:snapshot) - 15])
  let idx = start
  for j in s:snapshot[start:]
    let name = fnamemodify(bufname(j.bufnr), ':t')
    if name ==# '' | let name = '[No Name]' | endif
    let name = supertabpanel#truncate(name, supertabpanel#content_width(10))
    let name = substitute(name, '%', '%%', 'g')
    let hl = supertabpanel#flash_hl('jumplist', idx, '%#SuperTabPanelJl#')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#jumplist#jump]'
          \ .. hl .. '  ' .. name .. ':' .. j.lnum .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#jumplist#init() abort
  call s:setup_colors()
  augroup supertabpanel_jl_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('jumplist', #{
        \ icon: '↔',
        \ label: 'Jumps',
        \ render: function('supertabpanel#widgets#jumplist#render'),
        \ })
endfunction
