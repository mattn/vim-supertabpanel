" vim-supertabpanel : Kubernetes pods widget (uses kubectl)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:pods = []

function! s:setup_colors() abort
  hi default SuperTabPanelK8sHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelK8s     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelK8sRun  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelK8sErr  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelK8sWait guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelK8sDone guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0 || empty(s:buf)
    return
  endif
  try
    let data = json_decode(join(s:buf, ''))
    let s:pods = []
    for item in data.items
      let phase = get(item.status, 'phase', '?')
      call add(s:pods, #{
            \ name: item.metadata.name,
            \ ns: item.metadata.namespace,
            \ phase: phase,
            \ })
    endfor
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#k8s_pods#refresh(timer) abort
  if !executable('kubectl')
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let args = ['kubectl', 'get', 'pods', '-o', 'json']
  if !get(g:, 'supertabpanel_k8s_all_namespaces', 0)
    " default namespace only
  else
    call add(args, '-A')
  endif
  let s:job = job_start(args, #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#k8s_pods#render() abort
  let result = '%#SuperTabPanelK8sHead#  ☸ Pods%@'
  if !executable('kubectl')
    return result .. '%#SuperTabPanelK8s#  (kubectl not found)%@'
  endif
  if empty(s:pods)
    return result .. '%#SuperTabPanelK8s#  (none)%@'
  endif
  for p in s:pods[:19]
    if p.phase ==# 'Running'
      let hl = '%#SuperTabPanelK8sRun#'
      let icon = '●'
    elseif p.phase ==# 'Succeeded'
      let hl = '%#SuperTabPanelK8sDone#'
      let icon = '✓'
    elseif p.phase ==# 'Failed' || p.phase ==# 'Unknown'
      let hl = '%#SuperTabPanelK8sErr#'
      let icon = '✘'
    else
      let hl = '%#SuperTabPanelK8sWait#'
      let icon = '○'
    endif
    let name = supertabpanel#truncate(p.name, supertabpanel#content_width(8))
    let result ..= hl .. '  ' .. icon .. ' ' .. name .. '%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#k8s_pods#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#k8s_pods#refresh(0)
    let s:timer = timer_start(10000,
          \ function('supertabpanel#widgets#k8s_pods#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#k8s_pods#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#k8s_pods#init() abort
  call s:setup_colors()
  augroup supertabpanel_k8s_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('k8s_pods', #{
        \ icon: '☸',
        \ label: 'Pods',
        \ render: function('supertabpanel#widgets#k8s_pods#render'),
        \ on_activate: function('supertabpanel#widgets#k8s_pods#activate'),
        \ on_deactivate: function('supertabpanel#widgets#k8s_pods#deactivate'),
        \ })
endfunction
