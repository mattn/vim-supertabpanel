" vim-supertabpanel : Hacker News top widget

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:stories = []
let s:pending_ids = []
let s:pending_jobs = {}
let s:opened = -1
let s:opened_timer = -1

function! s:setup_colors() abort
  hi default SuperTabPanelHnHead  guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelHn      guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelHnScore guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelHnOpen  guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
endfunction

function! s:on_ids_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_ids_done(job, status) abort
  let s:job = v:null
  if a:status != 0 || empty(s:buf)
    return
  endif
  try
    let ids = json_decode(join(s:buf, ''))
    let s:pending_ids = ids[:9]
    let s:stories = []
    let s:pending_jobs = {}
    for id in s:pending_ids
      let s:pending_jobs[id] = job_start(
            \ ['curl', '-sL', 'https://hacker-news.firebaseio.com/v0/item/' .. id .. '.json'],
            \ #{
            \   out_cb: function('s:on_story_chunk', [id]),
            \   exit_cb: function('s:on_story_done', [id]),
            \   mode: 'raw',
            \ })
      let s:pending_jobs[id . '_buf'] = []
    endfor
  catch
  endtry
endfunction

function! s:on_story_chunk(id, ch, msg) abort
  if has_key(s:pending_jobs, a:id . '_buf')
    call add(s:pending_jobs[a:id . '_buf'], a:msg)
  endif
endfunction

function! s:on_story_done(id, job, status) abort
  if !has_key(s:pending_jobs, a:id . '_buf')
    return
  endif
  let buf = s:pending_jobs[a:id . '_buf']
  unlet s:pending_jobs[a:id . '_buf']
  unlet s:pending_jobs[a:id]
  if a:status == 0 && !empty(buf)
    try
      let story = json_decode(join(buf, ''))
      call add(s:stories, story)
    catch
    endtry
  endif
  if empty(s:pending_jobs)
    call sort(s:stories,
          \ {a, b -> index(s:pending_ids, b.id) - index(s:pending_ids, a.id)})
    let s:stories = reverse(s:stories)
    redrawtabpanel
  endif
endfunction

function! supertabpanel#widgets#hackernews#fetch(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(
        \ ['curl', '-sL', 'https://hacker-news.firebaseio.com/v0/topstories.json'],
        \ #{
        \   out_cb: function('s:on_ids_chunk'),
        \   exit_cb: function('s:on_ids_done'),
        \   mode: 'raw',
        \ })
endfunction

function! s:clear_opened(timer) abort
  let s:opened = -1
  let s:opened_timer = -1
  redrawtabpanel
endfunction

function! supertabpanel#widgets#hackernews#open(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:stories)
    let s = s:stories[idx]
    let url = get(s, 'url', '')
    if url ==# ''
      let url = 'https://news.ycombinator.com/item?id=' .. s.id
    endif
    if executable('xdg-open')
      call job_start(['xdg-open', url])
    elseif executable('open')
      call job_start(['open', url])
    endif
    let s:opened = idx
    if s:opened_timer != -1
      call timer_stop(s:opened_timer)
    endif
    let s:opened_timer = timer_start(800, function('s:clear_opened'))
    redrawtabpanel
  endif
  return 1
endfunction

function! supertabpanel#widgets#hackernews#render() abort
  let result = '%#SuperTabPanelHnHead#  🧡 Hacker News%@'
  if empty(s:stories)
    return result .. '%#SuperTabPanelHn#  fetching...%@'
  endif
  let idx = 0
  for s in s:stories
    let title = supertabpanel#truncate(get(s, 'title', ''), supertabpanel#content_width(9))
    let title = substitute(title, '%', '%%', 'g')
    let score = get(s, 'score', 0)
    let opened = (idx == s:opened)
    let mark = opened ? '▸' : ' '
    let score_hl = opened ? '%#SuperTabPanelHnOpen#' : '%#SuperTabPanelHnScore#'
    let title_hl = opened ? '%#SuperTabPanelHnOpen#' : '%#SuperTabPanelHn#'
    let result ..= '%' .. idx .. '[supertabpanel#widgets#hackernews#open]'
          \ .. score_hl .. ' ' .. mark .. ' ' .. score .. ' '
          \ .. title_hl .. title .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#hackernews#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#hackernews#fetch(0)
    let s:timer = timer_start(600000,
          \ function('supertabpanel#widgets#hackernews#fetch'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#hackernews#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:opened_timer != -1
    call timer_stop(s:opened_timer)
    let s:opened_timer = -1
  endif
  let s:opened = -1
endfunction

function! supertabpanel#widgets#hackernews#init() abort
  call s:setup_colors()
  augroup supertabpanel_hn_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('hackernews', #{
        \ icon: '🧡',
        \ label: 'Hacker News',
        \ render: function('supertabpanel#widgets#hackernews#render'),
        \ on_activate: function('supertabpanel#widgets#hackernews#activate'),
        \ on_deactivate: function('supertabpanel#widgets#hackernews#deactivate'),
        \ })
endfunction
