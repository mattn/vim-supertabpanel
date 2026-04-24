" vim-supertabpanel : docker containers widget

let s:timer = -1
let s:containers = []

function! s:setup_colors() abort
  hi default SuperTabPanelDockerHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelDockerRun  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelDockerOff  guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
endfunction

function! s:refresh(timer) abort
  if !executable('docker')
    return
  endif
  silent let out = systemlist("docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.State}}' 2>/dev/null")
  if v:shell_error != 0
    return
  endif
  let s:containers = []
  for l in out
    let p = split(l, '\t', 1)
    if len(p) >= 3
      call add(s:containers, #{ id: p[0], name: p[1], state: p[2] })
    endif
  endfor
  redrawtabpanel
endfunction

function! supertabpanel#widgets#docker#toggle(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:containers)
    return 0
  endif
  let c = s:containers[idx]
  let cmd = c.state ==# 'running' ? 'stop' : 'start'
  silent call system('docker ' .. cmd .. ' ' .. shellescape(c.id))
  call s:refresh(0)
  return 1
endfunction

function! supertabpanel#widgets#docker#render() abort
  let result = '%#SuperTabPanelDockerHead#  🐋 Docker%@'
  if !executable('docker')
    return result .. '%#SuperTabPanelDockerOff#  (docker not found)%@'
  endif
  if empty(s:containers)
    return result .. '%#SuperTabPanelDockerOff#  (no containers)%@'
  endif
  let idx = 0
  for c in s:containers
    let running = c.state ==# 'running'
    let icon = running ? '▶' : '■'
    let hl = running ? '%#SuperTabPanelDockerRun#' : '%#SuperTabPanelDockerOff#'
    let name = supertabpanel#truncate(c.name, supertabpanel#content_width(8))
    let result ..= '%' .. idx .. '[supertabpanel#widgets#docker#toggle]'
          \ .. hl .. '  ' .. icon .. ' ' .. name .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#docker#activate() abort
  if s:timer == -1
    call s:refresh(0)
    let s:timer = timer_start(10000,
          \ function('s:refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#docker#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#docker#init() abort
  call s:setup_colors()
  augroup supertabpanel_docker_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('docker', #{
        \ icon: '🐋',
        \ label: 'Docker',
        \ render: function('supertabpanel#widgets#docker#render'),
        \ on_activate: function('supertabpanel#widgets#docker#activate'),
        \ on_deactivate: function('supertabpanel#widgets#docker#deactivate'),
        \ })
endfunction
