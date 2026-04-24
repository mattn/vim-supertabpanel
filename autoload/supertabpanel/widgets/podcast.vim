" vim-supertabpanel : podcast widget (RSS feed, plays episodes via ffplay)

" Feeds can be configured either as a list of {name, url} dicts:
"   let g:supertabpanel_podcast_feeds = [
"         \ #{ name: 'Show A', url: '...' },
"         \ #{ name: 'Show B', url: '...' },
"         \ ]
" or as a single URL in g:supertabpanel_podcast_feed (kept for compat).
let s:feeds = get(g:, 'supertabpanel_podcast_feeds', [])
if empty(s:feeds)
  let s:feeds = [#{ name: '', url: get(g:, 'supertabpanel_podcast_feed',
        \ 'https://feeds.megaphone.fm/TFM9640066968') }]
endif
let s:current_feed = 0
let s:episodes = []
let s:channel_title = ''
let s:fetch_buf = []
let s:fetch_job = v:null
let s:play_job = v:null
let s:current = -1
let s:timer = -1

function! s:setup_colors() abort
  hi default SuperTabPanelPcHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelPc     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelPcPlay guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
endfunction

function! s:decode_entities(s) abort
  let s = a:s
  let s = substitute(s, '&lt;', '<', 'g')
  let s = substitute(s, '&gt;', '>', 'g')
  let s = substitute(s, '&quot;', '"', 'g')
  let s = substitute(s, '&#39;', "'", 'g')
  let s = substitute(s, '&apos;', "'", 'g')
  let s = substitute(s, '&amp;', '\&', 'g')
  return s
endfunction

function! s:parse_feed(xml) abort
  let episodes = []
  let items = split(a:xml, '<item\>')
  let header = items[0]
  let channel = ''
  let ct = matchlist(header, '<title>\s*<!\[CDATA\[\(.\{-}\)\]\]>\s*</title>')
  if empty(ct)
    let ct = matchlist(header, '<title>\(.\{-}\)</title>')
  endif
  if !empty(ct)
    let channel = s:decode_entities(ct[1])
  endif
  let s:channel_title = channel
  for chunk in items[1:]
    let end = stridx(chunk, '</item>')
    if end >= 0
      let chunk = chunk[: end - 1]
    endif
    let title = ''
    let m = matchlist(chunk, '<title>\s*<!\[CDATA\[\(.\{-}\)\]\]>\s*</title>')
    if empty(m)
      let m = matchlist(chunk, '<title>\(.\{-}\)</title>')
    endif
    if !empty(m)
      let title = s:decode_entities(m[1])
    endif
    let url = ''
    let u = matchlist(chunk, '<enclosure\_[^>]*\<url="\([^"]\+\)"')
    if !empty(u)
      let url = s:decode_entities(u[1])
    endif
    if title !=# '' && url !=# ''
      call add(episodes, #{ title: title, url: url })
    endif
  endfor
  return episodes
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:fetch_buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:fetch_job = v:null
  if a:status != 0
    return
  endif
  try
    let s:episodes = s:parse_feed(join(s:fetch_buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! s:fetch(timer) abort
  if !executable('curl')
    return
  endif
  if s:fetch_job isnot v:null && job_status(s:fetch_job) ==# 'run'
    call job_stop(s:fetch_job)
  endif
  let s:fetch_buf = []
  let s:fetch_job = job_start(['curl', '-sL', s:feeds[s:current_feed].url], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#podcast#cycle_feed(info) abort
  if len(s:feeds) <= 1
    return 0
  endif
  call s:stop()
  let s:current_feed = (s:current_feed + 1) % len(s:feeds)
  let s:episodes = []
  let s:channel_title = ''
  call s:fetch(0)
  redrawtabpanel
  return 1
endfunction

function! s:stop() abort
  if s:play_job isnot v:null && job_status(s:play_job) ==# 'run'
    call job_stop(s:play_job)
  endif
  let s:play_job = v:null
  let s:current = -1
endfunction

function! supertabpanel#widgets#podcast#play(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:episodes)
    return 0
  endif
  if !executable('ffplay')
    echohl WarningMsg | echom 'ffplay not found' | echohl None
    return 0
  endif
  call s:stop()
  let s:current = idx
  let s:play_job = job_start(['ffplay', '-nodisp', '-loglevel', 'quiet',
        \ '-autoexit', s:episodes[idx].url])
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#podcast#stop(info) abort
  call s:stop()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#podcast#render() abort
  let name = s:feeds[s:current_feed].name
  if name ==# ''
    let name = s:channel_title !=# '' ? s:channel_title : 'Podcast'
  endif
  let multi = len(s:feeds) > 1
  let label = supertabpanel#truncate(name, supertabpanel#content_width(multi ? 8 : 6))
  let label = substitute(label, '%', '%%', 'g')
  let result = ''
  if multi
    let result ..= '%0[supertabpanel#widgets#podcast#cycle_feed]'
          \ .. '%#SuperTabPanelPcHead#  🎙 ' .. label .. ' ⇄ %[]%@'
  else
    let result ..= '%#SuperTabPanelPcHead#  🎙 ' .. label .. '%@'
  endif
  if empty(s:episodes)
    return result .. '%#SuperTabPanelPc#  fetching...%@'
  endif
  let idx = 0
  for e in s:episodes[:9]
    let playing = (idx == s:current)
    let hl = playing ? '%#SuperTabPanelPcPlay#' : '%#SuperTabPanelPc#'
    let icon = playing ? '▶' : ' '
    let title = supertabpanel#truncate(e.title, supertabpanel#content_width(7))
    let title = substitute(title, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#podcast#play]'
          \ .. hl .. ' ' .. icon .. ' ' .. title .. '%[]%@'
    let idx += 1
  endfor
  if s:current >= 0
    let result ..= '%0[supertabpanel#widgets#podcast#stop]'
          \ .. '%#SuperTabPanelPc#  ⏹ stop%[]%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#podcast#activate() abort
  if s:timer == -1
    call s:fetch(0)
    let s:timer = timer_start(3600000,
          \ function('s:fetch'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#podcast#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  call s:stop()
  if s:fetch_job isnot v:null && job_status(s:fetch_job) ==# 'run'
    call job_stop(s:fetch_job)
  endif
  let s:fetch_job = v:null
endfunction

function! supertabpanel#widgets#podcast#init() abort
  call s:setup_colors()
  augroup supertabpanel_pc_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('podcast', #{
        \ icon: '🎙',
        \ label: 'Podcast',
        \ render: function('supertabpanel#widgets#podcast#render'),
        \ on_activate: function('supertabpanel#widgets#podcast#activate'),
        \ on_deactivate: function('supertabpanel#widgets#podcast#deactivate'),
        \ })
endfunction
