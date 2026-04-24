" vim-supertabpanel : podcast widget (RSS feed, plays episodes via ffplay)
"
" Instance params:
"   name : display name shown in the header.  If omitted, the feed's
"          <channel><title> is used once fetched.
"   url  : feed URL (required)
"   icon : header icon (default '🎙')

let s:instances = []
let s:colors_ready = 0

" Global play state — only one episode plays at a time across all instances.
let s:play_job = v:null
let s:play_inst = -1
let s:play_idx = -1

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
  let out = #{ channel: '', episodes: [] }
  let items = split(a:xml, '<item\>')
  let header = items[0]
  let ct = matchlist(header, '<title>\s*<!\[CDATA\[\(.\{-}\)\]\]>\s*</title>')
  if empty(ct)
    let ct = matchlist(header, '<title>\(.\{-}\)</title>')
  endif
  if !empty(ct)
    let out.channel = s:decode_entities(ct[1])
  endif
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
      call add(out.episodes, #{ title: title, url: url })
    endif
  endfor
  return out
endfunction

function! s:on_chunk(id, ch, msg) abort
  call add(s:instances[a:id].fetch_buf, a:msg)
endfunction

function! s:on_done(id, job, status) abort
  let inst = s:instances[a:id]
  let inst.fetch_job = v:null
  if a:status != 0
    return
  endif
  try
    let parsed = s:parse_feed(join(inst.fetch_buf, ''))
    let inst.channel_title = parsed.channel
    let inst.episodes = parsed.episodes
    redrawtabpanel
  catch
  endtry
endfunction

function! s:fetch(id, timer) abort
  if !executable('curl')
    return
  endif
  let inst = s:instances[a:id]
  if inst.url ==# ''
    return
  endif
  if inst.fetch_job isnot v:null && job_status(inst.fetch_job) ==# 'run'
    call job_stop(inst.fetch_job)
  endif
  let inst.fetch_buf = []
  let inst.fetch_job = job_start(['curl', '-sL', inst.url], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'raw',
        \ })
endfunction

function! s:stop_play() abort
  if s:play_job isnot v:null && job_status(s:play_job) ==# 'run'
    call job_stop(s:play_job)
  endif
  let s:play_job = v:null
  let s:play_inst = -1
  let s:play_idx = -1
endfunction

" minwid encodes id * 1000 + idx.
function! supertabpanel#widgets#podcast#play(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx < 0 || idx >= len(inst.episodes)
    return 0
  endif
  if !executable('ffplay')
    echohl WarningMsg | echom 'ffplay not found' | echohl None
    return 0
  endif
  call s:stop_play()
  let s:play_inst = id
  let s:play_idx = idx
  let s:play_job = job_start(['ffplay', '-nodisp', '-loglevel', 'quiet',
        \ '-autoexit', inst.episodes[idx].url])
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#podcast#stop(info) abort
  call s:stop_play()
  redrawtabpanel
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let name = inst.name
  if name ==# ''
    let name = inst.channel_title !=# '' ? inst.channel_title : 'Podcast'
  endif
  let label = supertabpanel#truncate(name, supertabpanel#content_width(6))
  let label = substitute(label, '%', '%%', 'g')
  let result = '%#SuperTabPanelPcHead#  ' .. inst.icon .. ' ' .. label .. '%@'
  if empty(inst.episodes)
    return result .. '%#SuperTabPanelPc#  fetching...%@'
  endif
  let idx = 0
  for e in inst.episodes[:9]
    let playing = (s:play_inst == a:id && s:play_idx == idx)
    let hl = playing ? '%#SuperTabPanelPcPlay#' : '%#SuperTabPanelPc#'
    let icon = playing ? '▶' : ' '
    let title = supertabpanel#truncate(e.title, supertabpanel#content_width(7))
    let title = substitute(title, '%', '%%', 'g')
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#podcast#play]'
          \ .. hl .. ' ' .. icon .. ' ' .. title .. '%[]%@'
    let idx += 1
  endfor
  if s:play_inst == a:id
    let result ..= '%0[supertabpanel#widgets#podcast#stop]'
          \ .. '%#SuperTabPanelPc#  ⏹ stop%[]%@'
  endif
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:fetch(a:id, 0)
    let inst.timer = timer_start(3600000,
          \ function('s:fetch', [a:id]), #{ repeat: -1 })
  endif
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  if inst.timer != -1
    call timer_stop(inst.timer)
    let inst.timer = -1
  endif
  if s:play_inst == a:id
    call s:stop_play()
  endif
  if inst.fetch_job isnot v:null && job_status(inst.fetch_job) ==# 'run'
    call job_stop(inst.fetch_job)
  endif
  let inst.fetch_job = v:null
endfunction

function! supertabpanel#widgets#podcast#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_podcast_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  let inst = #{
        \ id: id,
        \ name: get(a:params, 'name', ''),
        \ url: get(a:params, 'url', ''),
        \ icon: get(a:params, 'icon', '🎙'),
        \ channel_title: '',
        \ episodes: [],
        \ fetch_buf: [],
        \ fetch_job: v:null,
        \ timer: -1,
        \ }
  call add(s:instances, inst)
  return #{
        \ icon: inst.icon,
        \ label: inst.name !=# '' ? inst.name : 'Podcast',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
