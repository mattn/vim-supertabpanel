" vim-supertabpanel : recent (MRU) files widget

let s:cached = []

function! s:setup_colors() abort
  hi default SuperTabPanelRecentHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelRecent     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:refresh() abort
  let s:cached = filter(copy(v:oldfiles), 'filereadable(v:val)')[:14]
endfunction

function! supertabpanel#widgets#recent#open(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:cached)
    call supertabpanel#flash('recent', idx)
    execute 'edit ' .. fnameescape(s:cached[idx])
  endif
  return 1
endfunction

function! supertabpanel#widgets#recent#render() abort
  let result = '%#SuperTabPanelRecentHead#  🕑 Recent%@'
  let idx = 0
  for f in s:cached
    let name = fnamemodify(f, ':t')
    let name = supertabpanel#truncate(name, supertabpanel#content_width(4))
    let name = substitute(name, '%', '%%', 'g')
    let hl = supertabpanel#flash_hl('recent', idx, '%#SuperTabPanelRecent#')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#recent#open]'
          \ .. hl .. '  ' .. name .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#recent#activate() abort
  call s:refresh()
  augroup supertabpanel_recent
    autocmd!
    autocmd BufReadPost,BufWritePost * call s:refresh()
  augroup END
endfunction

function! supertabpanel#widgets#recent#deactivate() abort
  augroup supertabpanel_recent
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#recent#init() abort
  call s:setup_colors()
  augroup supertabpanel_recent_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('recent', #{
        \ icon: '🕑',
        \ label: 'Recent',
        \ render: function('supertabpanel#widgets#recent#render'),
        \ on_activate: function('supertabpanel#widgets#recent#activate'),
        \ on_deactivate: function('supertabpanel#widgets#recent#deactivate'),
        \ })
endfunction
