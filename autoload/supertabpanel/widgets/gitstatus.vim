" vim-supertabpanel : git status widget

let s:timer = -1
let s:branch = ''
let s:ahead = 0
let s:behind = 0
let s:staged = 0
let s:unstaged = 0
let s:untracked = 0
let s:job = v:null
let s:buf = []

function! s:setup_colors() abort
  hi default SuperTabPanelGitHead     guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelGitBranch   guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelGitStaged   guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelGitUnstaged guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelGitUntrack  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelGitAhead    guifg=#7dcfff guibg=#1a1b26 ctermfg=117 ctermbg=234
  hi default SuperTabPanelGitBehind   guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0
    let s:branch = ''
    redrawtabpanel
    return
  endif
  let s:branch = ''
  let s:ahead = 0
  let s:behind = 0
  let s:staged = 0
  let s:unstaged = 0
  let s:untracked = 0
  for chunk in s:buf
    for l in split(chunk, "\n")
      if l =~# '^# branch.head'
        let s:branch = matchstr(l, '^# branch\.head \zs.*')
      elseif l =~# '^# branch.ab'
        let m = matchlist(l, '^# branch\.ab +\(\d\+\) -\(\d\+\)')
        if !empty(m)
          let s:ahead = str2nr(m[1])
          let s:behind = str2nr(m[2])
        endif
      elseif l =~# '^? '
        let s:untracked += 1
      elseif l =~# '^[12u] '
        let code = l[2:3]
        if code[0] !=# '.' | let s:staged += 1 | endif
        if code[1] !=# '.' | let s:unstaged += 1 | endif
      endif
    endfor
  endfor
  redrawtabpanel
endfunction

function! s:refresh(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(
        \ ['git', '-C', getcwd(), 'status', '--porcelain=v2', '--branch'],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \   err_io: 'null',
        \ })
endfunction

function! supertabpanel#widgets#gitstatus#open_status(info) abort
  if exists(':Git')
    execute 'Git'
  else
    execute '!git status'
  endif
  return 1
endfunction

function! supertabpanel#widgets#gitstatus#render() abort
  let result = '%#SuperTabPanelGitHead#   Git%@'
  if s:branch ==# ''
    return result .. '%#SuperTabPanelGitUntrack#  (not a repo)%@'
  endif
  let result ..= '%0[supertabpanel#widgets#gitstatus#open_status]'
        \ .. '%#SuperTabPanelGitBranch#   ' .. s:branch .. '%[]%@'
  let parts = []
  if s:ahead > 0
    call add(parts, '%#SuperTabPanelGitAhead#↑' .. s:ahead)
  endif
  if s:behind > 0
    call add(parts, '%#SuperTabPanelGitBehind#↓' .. s:behind)
  endif
  if s:staged > 0
    call add(parts, '%#SuperTabPanelGitStaged#+' .. s:staged)
  endif
  if s:unstaged > 0
    call add(parts, '%#SuperTabPanelGitUnstaged#~' .. s:unstaged)
  endif
  if s:untracked > 0
    call add(parts, '%#SuperTabPanelGitUntrack#?' .. s:untracked)
  endif
  if !empty(parts)
    let result ..= '  ' .. join(parts, ' ') .. '%@'
  else
    let result ..= '  %#SuperTabPanelGitStaged# clean%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#gitstatus#activate() abort
  if s:timer == -1
    call s:refresh(0)
    let s:timer = timer_start(5000,
          \ function('s:refresh'), #{ repeat: -1 })
  endif
  augroup supertabpanel_gitstatus
    autocmd!
    autocmd BufWritePost * call s:refresh(0)
  augroup END
endfunction

function! supertabpanel#widgets#gitstatus#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  augroup supertabpanel_gitstatus
    autocmd!
  augroup END
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#gitstatus#init() abort
  call s:setup_colors()
  augroup supertabpanel_gitstatus_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('gitstatus', #{
        \ icon: '',
        \ label: 'Git',
        \ render: function('supertabpanel#widgets#gitstatus#render'),
        \ on_activate: function('supertabpanel#widgets#gitstatus#activate'),
        \ on_deactivate: function('supertabpanel#widgets#gitstatus#deactivate'),
        \ })
endfunction
