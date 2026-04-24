" vim-supertabpanel : Kubernetes pods widget (uses kubectl)
"
" Instance params:
"   all_namespaces : if truthy, pass -A (default 0 = current namespace)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelK8sHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelK8s     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelK8sRun  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelK8sErr  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelK8sWait guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelK8sDone guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(id, ch, msg) abort
  call add(s:instances[a:id].buf, a:msg)
endfunction

function! s:on_done(id, job, status) abort
  let inst = s:instances[a:id]
  let inst.job = v:null
  if a:status != 0 || empty(inst.buf)
    return
  endif
  try
    let data = json_decode(join(inst.buf, ''))
    let inst.pods = []
    for item in data.items
      let phase = get(item.status, 'phase', '?')
      call add(inst.pods, #{
            \ name: item.metadata.name,
            \ ns: item.metadata.namespace,
            \ phase: phase,
            \ })
    endfor
    redrawtabpanel
  catch
  endtry
endfunction

function! s:refresh(id, timer) abort
  if !executable('kubectl')
    return
  endif
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    return
  endif
  let inst.buf = []
  let args = ['kubectl', 'get', 'pods', '-o', 'json']
  if inst.all_namespaces
    call add(args, '-A')
  endif
  let inst.job = job_start(args, #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'raw',
        \ })
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelK8sHead#  ☸ Pods%@'
  if !executable('kubectl')
    return result .. '%#SuperTabPanelK8s#  (kubectl not found)%@'
  endif
  if empty(inst.pods)
    return result .. '%#SuperTabPanelK8s#  (none)%@'
  endif
  for p in inst.pods[:19]
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

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:refresh(a:id, 0)
    let inst.timer = timer_start(10000,
          \ function('s:refresh', [a:id]), #{ repeat: -1 })
  endif
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  if inst.timer != -1
    call timer_stop(inst.timer)
    let inst.timer = -1
  endif
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = v:null
endfunction

function! supertabpanel#widgets#k8s_pods#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_k8s_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ all_namespaces: !!get(a:params, 'all_namespaces', 0),
        \ pods: [],
        \ buf: [],
        \ job: v:null,
        \ timer: -1,
        \ })
  return #{
        \ icon: '☸',
        \ label: 'Pods',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
