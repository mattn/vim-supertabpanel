" vim-supertabpanel : git diff hunks widget

let s:hunks = []
let s:job = v:null
let s:buf = []

function! s:setup_colors() abort
  hi default SuperTabPanelDiffHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelDiffAdd  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelDiffDel  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelDiffMod  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelDiff     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  let s:hunks = []
  if a:status != 0
    redrawtabpanel
    return
  endif
  for chunk in s:buf
    for l in split(chunk, "\n")
      let m = matchlist(l, '^@@ -\(\d\+\)\%(,\(\d\+\)\)\? +\(\d\+\)\%(,\(\d\+\)\)\?')
      if !empty(m)
        let del = m[2] ==# '' ? 1 : str2nr(m[2])
        let add = m[4] ==# '' ? 1 : str2nr(m[4])
        let new_start = str2nr(m[3])
        if del == 0
          let kind = 'add'
        elseif add == 0
          let kind = 'del'
        else
          let kind = 'mod'
        endif
        call add(s:hunks, #{
              \ lnum: new_start,
              \ add: add, del: del, kind: kind,
              \ })
      endif
    endfor
  endfor
  redrawtabpanel
endfunction

function! s:refresh() abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let file = expand('%:p')
  if file ==# '' || !filereadable(file)
    let s:hunks = []
    return
  endif
  let dir = fnamemodify(file, ':h')
  let s:buf = []
  let s:job = job_start(
        \ ['git', '-C', dir, 'diff', '--no-color', '-U0', '--', file],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \   err_io: 'null',
        \ })
endfunction

function! supertabpanel#widgets#diff#jump(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:hunks)
    execute s:hunks[idx].lnum
  endif
  return 1
endfunction

function! supertabpanel#widgets#diff#render() abort
  let result = '%#SuperTabPanelDiffHead#   Diff%@'
  if empty(s:hunks)
    return result .. '%#SuperTabPanelDiff#  (clean)%@'
  endif
  let idx = 0
  for h in s:hunks
    if h.kind ==# 'add'
      let hl = '%#SuperTabPanelDiffAdd#'
      let icon = '+'
      let label = '+' .. h.add
    elseif h.kind ==# 'del'
      let hl = '%#SuperTabPanelDiffDel#'
      let icon = '-'
      let label = '-' .. h.del
    else
      let hl = '%#SuperTabPanelDiffMod#'
      let icon = '~'
      let label = '±' .. (h.add + h.del)
    endif
    let result ..= '%' .. idx .. '[supertabpanel#widgets#diff#jump]'
          \ .. hl .. ' ' .. icon .. ' L' .. h.lnum .. '  ' .. label .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#diff#activate() abort
  call s:refresh()
  augroup supertabpanel_diff
    autocmd!
    autocmd BufWritePost,BufEnter * call s:refresh()
  augroup END
endfunction

function! supertabpanel#widgets#diff#deactivate() abort
  augroup supertabpanel_diff
    autocmd!
  augroup END
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#diff#init() abort
  call s:setup_colors()
  augroup supertabpanel_diff_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('diff', #{
        \ icon: '',
        \ label: 'Diff',
        \ render: function('supertabpanel#widgets#diff#render'),
        \ on_activate: function('supertabpanel#widgets#diff#activate'),
        \ on_deactivate: function('supertabpanel#widgets#diff#deactivate'),
        \ })
endfunction
