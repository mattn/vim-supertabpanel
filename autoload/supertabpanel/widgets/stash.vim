" vim-supertabpanel : git stash list widget

let s:stashes = []
let s:job = v:null
let s:buf = []

function! s:setup_colors() abort
  hi default SuperTabPanelStashHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelStashIdx  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelStash     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  let s:stashes = []
  if a:status != 0
    redrawtabpanel
    return
  endif
  for chunk in s:buf
    for l in split(chunk, "\n")
      let p = split(l, '||', 1)
      if len(p) >= 2
        call add(s:stashes, #{ name: p[0], desc: p[1] })
      endif
    endfor
  endfor
  redrawtabpanel
endfunction

function! s:refresh() abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(
        \ ['git', 'stash', 'list', '--pretty=format:%gd||%s'],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \   err_io: 'null',
        \ })
endfunction

function! supertabpanel#widgets#stash#apply(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:stashes)
    return 0
  endif
  let name = s:stashes[idx].name
  silent call system('git stash apply ' .. shellescape(name))
  call s:refresh()
  return 1
endfunction

function! supertabpanel#widgets#stash#render() abort
  let result = '%#SuperTabPanelStashHead#  📦 Stash%@'
  if empty(s:stashes)
    return result .. '%#SuperTabPanelStash#  (empty)%@'
  endif
  let idx = 0
  for s in s:stashes[:9]
    let desc = supertabpanel#truncate(s.desc, supertabpanel#content_width(15))
    let desc = substitute(desc, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#stash#apply]'
          \ .. '%#SuperTabPanelStashIdx#  ' .. s.name .. ' '
          \ .. '%#SuperTabPanelStash#' .. desc .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#stash#activate() abort
  call s:refresh()
  augroup supertabpanel_stash
    autocmd!
    autocmd BufWritePost * call s:refresh()
  augroup END
endfunction

function! supertabpanel#widgets#stash#deactivate() abort
  augroup supertabpanel_stash
    autocmd!
  augroup END
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#stash#init() abort
  call s:setup_colors()
  augroup supertabpanel_stash_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('stash', #{
        \ icon: '📦',
        \ label: 'Stash',
        \ render: function('supertabpanel#widgets#stash#render'),
        \ on_activate: function('supertabpanel#widgets#stash#activate'),
        \ on_deactivate: function('supertabpanel#widgets#stash#deactivate'),
        \ })
endfunction
