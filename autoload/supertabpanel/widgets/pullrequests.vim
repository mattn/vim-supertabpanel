" vim-supertabpanel : GitHub pull requests widget (uses `gh`)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:prs = []

function! s:setup_colors() abort
  hi default SuperTabPanelPrHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelPr      guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelPrOpen  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelPrDraft guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
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
    let s:prs = json_decode(join(s:buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#pullrequests#refresh(timer) abort
  if !executable('gh')
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(
        \ ['gh', 'pr', 'list', '--json', 'number,title,isDraft,url', '--limit', '10'],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#pullrequests#open(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:prs)
    let url = s:prs[idx].url
    if executable('xdg-open')
      call job_start(['xdg-open', url])
    elseif executable('open')
      call job_start(['open', url])
    endif
  endif
  return 1
endfunction

function! supertabpanel#widgets#pullrequests#render() abort
  let result = '%#SuperTabPanelPrHead#  🔀 Pull Requests%@'
  if !executable('gh')
    return result .. '%#SuperTabPanelPr#  (gh not found)%@'
  endif
  if empty(s:prs)
    return result .. '%#SuperTabPanelPr#  (none)%@'
  endif
  let idx = 0
  for p in s:prs
    let hl = p.isDraft ? '%#SuperTabPanelPrDraft#' : '%#SuperTabPanelPrOpen#'
    let title = supertabpanel#truncate(p.title, supertabpanel#content_width(12))
    let title = substitute(title, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#pullrequests#open]'
          \ .. hl .. '  #' .. p.number .. ' '
          \ .. '%#SuperTabPanelPr#' .. title .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#pullrequests#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#pullrequests#refresh(0)
    let s:timer = timer_start(300000,
          \ function('supertabpanel#widgets#pullrequests#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#pullrequests#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#pullrequests#init() abort
  call s:setup_colors()
  augroup supertabpanel_pr_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('pullrequests', #{
        \ icon: '🔀',
        \ label: 'PRs',
        \ render: function('supertabpanel#widgets#pullrequests#render'),
        \ on_activate: function('supertabpanel#widgets#pullrequests#activate'),
        \ on_deactivate: function('supertabpanel#widgets#pullrequests#deactivate'),
        \ })
endfunction
