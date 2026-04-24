" vim-supertabpanel : test runner widget
"
" Configure g:supertabpanel_test_cmd and g:supertabpanel_test_on_save.

let s:job = v:null
let s:buf = []
let s:status = 'idle'
let s:last_output = ''

function! s:setup_colors() abort
  hi default SuperTabPanelTsHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTs     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTsOk   guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
  hi default SuperTabPanelTsFail guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelTsRun  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelTsBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  let s:status = a:status == 0 ? 'pass' : 'fail'
  let s:last_output = join(s:buf, "\n")
  redrawtabpanel
endfunction

function! supertabpanel#widgets#tests#run(info) abort
  let cmd = get(g:, 'supertabpanel_test_cmd', '')
  if cmd ==# ''
    echohl WarningMsg
    echom 'Set g:supertabpanel_test_cmd (e.g. "go test ./...")'
    echohl None
    return 0
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:status = 'running'
  let s:buf = []
  let s:job = job_start(['sh', '-c', cmd], #{
        \ out_cb: function('s:on_chunk'),
        \ err_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'nl',
        \ })
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#tests#show(info) abort
  if s:last_output ==# ''
    return 0
  endif
  call popup_create(split(s:last_output, "\n"), #{
        \ title: ' Test output ',
        \ border: [], padding: [0, 1, 0, 1],
        \ maxwidth: 100, maxheight: 30,
        \ scrollbar: 1, close: 'click',
        \ })
  return 1
endfunction

function! supertabpanel#widgets#tests#render() abort
  let result = '%#SuperTabPanelTsHead#  🧪 Tests%@'
  let cmd = get(g:, 'supertabpanel_test_cmd', '')
  if cmd ==# ''
    let result ..= '%#SuperTabPanelTs#  (not configured)%@'
    return result
  endif
  if s:status ==# 'idle'
    let result ..= '%#SuperTabPanelTs#  (not run yet)%@'
  elseif s:status ==# 'running'
    let result ..= '%#SuperTabPanelTsRun#  ⏳ running...%@'
  elseif s:status ==# 'pass'
    let result ..= '%0[supertabpanel#widgets#tests#show]'
          \ .. '%#SuperTabPanelTsOk#  ✔ passed%[]%@'
  else
    let result ..= '%0[supertabpanel#widgets#tests#show]'
          \ .. '%#SuperTabPanelTsFail#  ✘ failed%[]%@'
  endif
  let result ..= '%0[supertabpanel#widgets#tests#run]'
        \ .. '%#SuperTabPanelTsBtn#  ▶ run%[]%@'
  return result
endfunction

function! supertabpanel#widgets#tests#activate() abort
  if get(g:, 'supertabpanel_test_on_save', 0)
    augroup supertabpanel_tests
      autocmd!
      autocmd BufWritePost * call supertabpanel#widgets#tests#run({})
    augroup END
  endif
endfunction

function! supertabpanel#widgets#tests#deactivate() abort
  augroup supertabpanel_tests
    autocmd!
  augroup END
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#tests#init() abort
  call s:setup_colors()
  augroup supertabpanel_ts_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('tests', #{
        \ icon: '🧪',
        \ label: 'Tests',
        \ render: function('supertabpanel#widgets#tests#render'),
        \ on_activate: function('supertabpanel#widgets#tests#activate'),
        \ on_deactivate: function('supertabpanel#widgets#tests#deactivate'),
        \ })
endfunction
