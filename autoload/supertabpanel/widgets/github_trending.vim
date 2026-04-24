" vim-supertabpanel : GitHub trending repos widget (via `gh search`)
"
" Instance params:
"   lang : filter by language (e.g. 'go', 'rust'; default '' = all)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelGtHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelGt     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelGtStar guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
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
    let inst.repos = json_decode(join(inst.buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! s:refresh(id, timer) abort
  if !executable('gh')
    return
  endif
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    return
  endif
  let inst.buf = []
  let since = strftime('%Y-%m-%d', localtime() - 7 * 86400)
  let q = 'created:>' .. since
  if inst.lang !=# ''
    let q ..= ' language:' .. inst.lang
  endif
  let inst.job = job_start(
        \ ['gh', 'search', 'repos', q,
        \  '--sort', 'stars', '--order', 'desc', '--limit', '10',
        \  '--json', 'fullName,stargazersCount,url,description'],
        \ #{
        \   out_cb: function('s:on_chunk', [a:id]),
        \   exit_cb: function('s:on_done', [a:id]),
        \   mode: 'raw',
        \ })
endfunction

" minwid encodes id*1000 + idx.
function! supertabpanel#widgets#github_trending#open(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx >= 0 && idx < len(inst.repos)
    let url = inst.repos[idx].url
    if executable('xdg-open')
      call job_start(['xdg-open', url])
    elseif executable('open')
      call job_start(['open', url])
    endif
  endif
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelGtHead#  🔥 Trending%@'
  if !executable('gh')
    return result .. '%#SuperTabPanelGt#  (gh not found)%@'
  endif
  if empty(inst.repos)
    return result .. '%#SuperTabPanelGt#  fetching...%@'
  endif
  let idx = 0
  for r in inst.repos
    let name = supertabpanel#truncate(r.fullName, supertabpanel#content_width(13))
    let stars = r.stargazersCount
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#github_trending#open]'
          \ .. '%#SuperTabPanelGtStar#  ⭐ ' .. stars .. ' '
          \ .. '%#SuperTabPanelGt#' .. name .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:refresh(a:id, 0)
    let inst.timer = timer_start(1800000,
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

function! supertabpanel#widgets#github_trending#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_gt_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ lang: get(a:params, 'lang', ''),
        \ repos: [],
        \ buf: [],
        \ job: v:null,
        \ timer: -1,
        \ })
  return #{
        \ icon: '🔥',
        \ label: 'Trending',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
