" vim-supertabpanel : tags widget (current buffer's ctags)

let s:tags = []
let s:buf = -1

function! s:setup_colors() abort
  hi default SuperTabPanelTgHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTg     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTgKind guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:refresh() abort
  let s:buf = bufnr('%')
  let file = expand('%:p')
  if file ==# '' || !filereadable(file)
    let s:tags = []
    return
  endif
  if !executable('ctags')
    return
  endif
  " -x produces a plain tabular listing.
  silent let out = systemlist('ctags -f - --sort=no ' .. shellescape(file) .. ' 2>/dev/null')
  let s:tags = []
  for l in out
    let parts = split(l, '\t')
    if len(parts) >= 4
      let name = parts[0]
      let kind = parts[3]
      " Extract pattern/lnum.
      let lnum = 0
      let m = matchstr(l, 'line:\zs\d\+')
      if m !=# ''
        let lnum = str2nr(m)
      endif
      call add(s:tags, #{ name: name, kind: kind, lnum: lnum })
    endif
  endfor
endfunction

function! supertabpanel#widgets#tags#jump(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:tags)
    let lnum = s:tags[idx].lnum
    if lnum > 0
      execute lnum
    else
      execute 'tag ' .. s:tags[idx].name
    endif
  endif
  return 1
endfunction

function! supertabpanel#widgets#tags#render() abort
  if bufnr('%') != s:buf
    call s:refresh()
  endif
  let result = '%#SuperTabPanelTgHead#  🏷 Tags%@'
  if !executable('ctags')
    return result .. '%#SuperTabPanelTg#  (ctags not found)%@'
  endif
  if empty(s:tags)
    return result .. '%#SuperTabPanelTg#  (none)%@'
  endif
  let idx = 0
  for t in s:tags[:29]
    let name = supertabpanel#truncate(t.name, supertabpanel#content_width(12))
    let result ..= '%' .. idx .. '[supertabpanel#widgets#tags#jump]'
          \ .. '%#SuperTabPanelTgKind#  ' .. t.kind[0] .. ' '
          \ .. '%#SuperTabPanelTg#' .. name .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#tags#activate() abort
  call s:refresh()
  augroup supertabpanel_tg
    autocmd!
    autocmd BufWritePost,BufEnter * call s:refresh()
          \ | if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#tags#deactivate() abort
  augroup supertabpanel_tg
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#tags#init() abort
  call s:setup_colors()
  augroup supertabpanel_tg_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('tags', #{
        \ icon: '🏷',
        \ label: 'Tags',
        \ render: function('supertabpanel#widgets#tags#render'),
        \ on_activate: function('supertabpanel#widgets#tags#activate'),
        \ on_deactivate: function('supertabpanel#widgets#tags#deactivate'),
        \ })
endfunction
