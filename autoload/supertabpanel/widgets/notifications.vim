" vim-supertabpanel : GitHub notifications widget (uses `gh`)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:items = []

function! s:setup_colors() abort
  hi default SuperTabPanelNfHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelNf     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelNfUnr  guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
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
    let s:items = json_decode(join(s:buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#notifications#refresh(timer) abort
  if !executable('gh')
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(
        \ ['gh', 'api', 'notifications', '--paginate=false'],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#notifications#open(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:items)
    let url = s:items[idx].subject.url
    " Convert API URL to HTML URL.
    let url = substitute(url, 'api.github.com/repos', 'github.com', '')
    let url = substitute(url, '/pulls/', '/pull/', '')
    if executable('xdg-open')
      call job_start(['xdg-open', url])
    elseif executable('open')
      call job_start(['open', url])
    endif
  endif
  return 1
endfunction

function! supertabpanel#widgets#notifications#render() abort
  let result = '%#SuperTabPanelNfHead#  🔔 Notifications%@'
  if !executable('gh')
    return result .. '%#SuperTabPanelNf#  (gh not found)%@'
  endif
  if empty(s:items)
    return result .. '%#SuperTabPanelNf#  (no unread)%@'
  endif
  let idx = 0
  for n in s:items[:9]
    let repo = get(n.repository, 'full_name', '')
    let repo = fnamemodify(repo, ':t')
    let title = get(n.subject, 'title', '')
    let text = supertabpanel#truncate(repo .. ' ' .. title, supertabpanel#content_width(5))
    let text = substitute(text, '%', '%%', 'g')
    let hl = n.unread ? '%#SuperTabPanelNfUnr#' : '%#SuperTabPanelNf#'
    let result ..= '%' .. idx .. '[supertabpanel#widgets#notifications#open]'
          \ .. hl .. '  ' .. text .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#notifications#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#notifications#refresh(0)
    let s:timer = timer_start(300000,
          \ function('supertabpanel#widgets#notifications#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#notifications#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#notifications#init() abort
  call s:setup_colors()
  augroup supertabpanel_nf_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('notifications', #{
        \ icon: '🔔',
        \ label: 'Notifications',
        \ render: function('supertabpanel#widgets#notifications#render'),
        \ on_activate: function('supertabpanel#widgets#notifications#activate'),
        \ on_deactivate: function('supertabpanel#widgets#notifications#deactivate'),
        \ })
endfunction
