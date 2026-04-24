" vim-supertabpanel : test runner widget
"
" Instance params:
"   cmd     : shell command to run the tests (required; '' means "not
"             configured")
"   on_save : if truthy, re-run after every :w (default 0)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelTsHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTs     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTsOk   guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
  hi default SuperTabPanelTsFail guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelTsRun  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelTsBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(id, ch, msg) abort
  call add(s:instances[a:id].buf, a:msg)
endfunction

function! s:on_done(id, job, status) abort
  let inst = s:instances[a:id]
  let inst.job = v:null
  let inst.status = a:status == 0 ? 'pass' : 'fail'
  let inst.last_output = join(inst.buf, "\n")
  redrawtabpanel
endfunction

function! s:run(id) abort
  let inst = s:instances[a:id]
  if inst.cmd ==# ''
    echohl WarningMsg
    echom 'tests: no cmd configured'
    echohl None
    return 0
  endif
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.status = 'running'
  let inst.buf = []
  let inst.job = job_start(['sh', '-c', inst.cmd], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ err_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'nl',
        \ })
  redrawtabpanel
  return 1
endfunction

" minwid encodes id*10 + action (0=run, 1=show)
function! supertabpanel#widgets#tests#click(info) abort
  let code = a:info.minwid
  let id = code / 10
  let action = code % 10
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if action == 0
    return s:run(id)
  elseif action == 1
    if inst.last_output ==# ''
      return 0
    endif
    call popup_create(split(inst.last_output, "\n"), #{
          \ title: ' Test output ',
          \ border: [], padding: [0, 1, 0, 1],
          \ maxwidth: 100, maxheight: 30,
          \ scrollbar: 1, close: 'click',
          \ })
    return 1
  endif
  return 0
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelTsHead#  🧪 Tests%@'
  if inst.cmd ==# ''
    let result ..= '%#SuperTabPanelTs#  (not configured)%@'
    return result
  endif
  if inst.status ==# 'idle'
    let result ..= '%#SuperTabPanelTs#  (not run yet)%@'
  elseif inst.status ==# 'running'
    let result ..= '%#SuperTabPanelTsRun#  ⏳ running...%@'
  elseif inst.status ==# 'pass'
    let result ..= '%' .. (a:id * 10 + 1) .. '[supertabpanel#widgets#tests#click]'
          \ .. '%#SuperTabPanelTsOk#  ✔ passed%[]%@'
  else
    let result ..= '%' .. (a:id * 10 + 1) .. '[supertabpanel#widgets#tests#click]'
          \ .. '%#SuperTabPanelTsFail#  ✘ failed%[]%@'
  endif
  let result ..= '%' .. (a:id * 10 + 0) .. '[supertabpanel#widgets#tests#click]'
        \ .. '%#SuperTabPanelTsBtn#  ▶ run%[]%@'
  return result
endfunction

function! s:run_autocmd(id) abort
  call s:run(a:id)
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.on_save
    let group = 'supertabpanel_tests_' .. a:id
    execute 'augroup ' .. group
      autocmd!
      execute 'autocmd BufWritePost * call <SID>run_autocmd(' .. a:id .. ')'
    augroup END
  endif
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  let group = 'supertabpanel_tests_' .. a:id
  execute 'augroup ' .. group
    autocmd!
  augroup END
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = v:null
endfunction

function! supertabpanel#widgets#tests#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_ts_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ cmd: get(a:params, 'cmd', ''),
        \ on_save: !!get(a:params, 'on_save', 0),
        \ status: 'idle',
        \ last_output: '',
        \ buf: [],
        \ job: v:null,
        \ })
  return #{
        \ icon: '🧪',
        \ label: 'Tests',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
