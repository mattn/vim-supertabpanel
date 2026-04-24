" vim-supertabpanel : GitHub trending repos widget (via `gh search`)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:repos = []
let s:language = get(g:, 'supertabpanel_trending_lang', '')

function! s:setup_colors() abort
  hi default SuperTabPanelGtHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelGt     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelGtStar guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
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
    let s:repos = json_decode(join(s:buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#github_trending#refresh(timer) abort
  if !executable('gh')
    return
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  " Repositories created within last 7 days, sorted by stars.
  let since = strftime('%Y-%m-%d', localtime() - 7 * 86400)
  let q = 'created:>' .. since
  if s:language !=# ''
    let q ..= ' language:' .. s:language
  endif
  let s:job = job_start(
        \ ['gh', 'search', 'repos', q,
        \  '--sort', 'stars', '--order', 'desc', '--limit', '10',
        \  '--json', 'fullName,stargazersCount,url,description'],
        \ #{
        \   out_cb: function('s:on_chunk'),
        \   exit_cb: function('s:on_done'),
        \   mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#github_trending#open(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:repos)
    let url = s:repos[idx].url
    if executable('xdg-open')
      call job_start(['xdg-open', url])
    elseif executable('open')
      call job_start(['open', url])
    endif
  endif
  return 1
endfunction

function! supertabpanel#widgets#github_trending#render() abort
  let result = '%#SuperTabPanelGtHead#  🔥 Trending%@'
  if !executable('gh')
    return result .. '%#SuperTabPanelGt#  (gh not found)%@'
  endif
  if empty(s:repos)
    return result .. '%#SuperTabPanelGt#  fetching...%@'
  endif
  let idx = 0
  for r in s:repos
    let name = supertabpanel#truncate(r.fullName, supertabpanel#content_width(13))
    let stars = r.stargazersCount
    let result ..= '%' .. idx .. '[supertabpanel#widgets#github_trending#open]'
          \ .. '%#SuperTabPanelGtStar#  ⭐ ' .. stars .. ' '
          \ .. '%#SuperTabPanelGt#' .. name .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#github_trending#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#github_trending#refresh(0)
    let s:timer = timer_start(1800000,
          \ function('supertabpanel#widgets#github_trending#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#github_trending#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#github_trending#init() abort
  call s:setup_colors()
  augroup supertabpanel_gt_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('github_trending', #{
        \ icon: '🔥',
        \ label: 'Trending',
        \ render: function('supertabpanel#widgets#github_trending#render'),
        \ on_activate: function('supertabpanel#widgets#github_trending#activate'),
        \ on_deactivate: function('supertabpanel#widgets#github_trending#deactivate'),
        \ })
endfunction
