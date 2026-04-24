" vim-supertabpanel : build (:make) status widget

let s:last_errors = 0
let s:last_warns = 0
let s:last_status = 'idle'

function! s:setup_colors() abort
  hi default SuperTabPanelBdHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelBd      guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelBdOk    guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelBdErr   guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelBdBtn   guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:count() abort
  let s:last_errors = 0
  let s:last_warns = 0
  for q in getqflist()
    if q.type ==? 'E' || (q.type ==? '' && q.valid)
      let s:last_errors += 1
    elseif q.type ==? 'W'
      let s:last_warns += 1
    endif
  endfor
  if s:last_errors > 0
    let s:last_status = 'failed'
  elseif s:last_warns > 0
    let s:last_status = 'warnings'
  else
    let s:last_status = 'ok'
  endif
endfunction

function! supertabpanel#widgets#build#run(info) abort
  silent! make!
  call s:count()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#build#open_qf(info) abort
  copen
  return 1
endfunction

function! supertabpanel#widgets#build#render() abort
  let result = '%#SuperTabPanelBdHead#  🔨 Build%@'
  if s:last_status ==# 'idle'
    let result ..= '%#SuperTabPanelBd#  (not run yet)%@'
  elseif s:last_status ==# 'ok'
    let result ..= '%0[supertabpanel#widgets#build#open_qf]'
          \ .. '%#SuperTabPanelBdOk#  ✔ success%[]%@'
  else
    let msg = '✘ ' .. s:last_errors .. ' errors'
    if s:last_warns > 0
      let msg ..= ', ' .. s:last_warns .. ' warnings'
    endif
    let result ..= '%0[supertabpanel#widgets#build#open_qf]'
          \ .. '%#SuperTabPanelBdErr#  ' .. msg .. '%[]%@'
  endif
  let result ..= '%0[supertabpanel#widgets#build#run]'
        \ .. '%#SuperTabPanelBdBtn#  ▶ :make%[]%@'
  return result
endfunction

function! supertabpanel#widgets#build#activate() abort
  augroup supertabpanel_build
    autocmd!
    autocmd QuickFixCmdPost make call s:count() | call s:maybe_redraw()
  augroup END
endfunction

function! s:maybe_redraw() abort
  if &showtabpanel | redrawtabpanel | endif
endfunction

function! supertabpanel#widgets#build#deactivate() abort
  augroup supertabpanel_build
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#build#init() abort
  call s:setup_colors()
  augroup supertabpanel_bd_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('build', #{
        \ icon: '🔨',
        \ label: 'Build',
        \ render: function('supertabpanel#widgets#build#render'),
        \ on_activate: function('supertabpanel#widgets#build#activate'),
        \ on_deactivate: function('supertabpanel#widgets#build#deactivate'),
        \ })
endfunction
