" vim-supertabpanel : generic RSS/RDF feed widget
"
" Instance params:
"   name : display name shown in the header (required)
"   url  : feed URL (required)
"   icon : header icon (default '📰')
"   max  : maximum number of items to display (default 0 = all)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelRssHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelRss     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
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

function! s:parse_rss(xml) abort
  let out = []
  let items = split(a:xml, '<item\>')
  for chunk in items[1:]
    let end = stridx(chunk, '</item>')
    if end >= 0
      let chunk = chunk[: end - 1]
    endif
    let link = ''
    let la = matchlist(chunk, 'rdf:about="\([^"]\+\)"')
    if !empty(la)
      let link = la[1]
    endif
    if link ==# ''
      let lm = matchlist(chunk, '<link>\s*\(.\{-}\)\s*</link>')
      if !empty(lm)
        let link = s:decode_entities(lm[1])
      endif
    endif
    let title = ''
    let m = matchlist(chunk, '<title>\s*<!\[CDATA\[\(.\{-}\)\]\]>\s*</title>')
    if empty(m)
      let m = matchlist(chunk, '<title>\(.\{-}\)</title>')
    endif
    if !empty(m)
      let title = s:decode_entities(m[1])
    endif
    if title !=# '' && link !=# ''
      call add(out, #{ title: title, link: link })
    endif
  endfor
  return out
endfunction

function! s:on_rss_chunk(id, ch, msg) abort
  call add(s:instances[a:id].rss_buf, a:msg)
endfunction

function! s:on_rss_done(id, job, status) abort
  let inst = s:instances[a:id]
  let inst.rss_job = v:null
  if a:status != 0 || empty(inst.rss_buf)
    return
  endif
  try
    let inst.items = s:parse_rss(join(inst.rss_buf, ''))
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
  if inst.rss_job isnot v:null && job_status(inst.rss_job) ==# 'run'
    return
  endif
  let inst.rss_buf = []
  let inst.rss_job = job_start(
        \ ['curl', '-sL', inst.url],
        \ #{
        \   out_cb: function('s:on_rss_chunk', [a:id]),
        \   exit_cb: function('s:on_rss_done', [a:id]),
        \   mode: 'raw',
        \   err_io: 'null',
        \ })
endfunction

function! s:parse_article(title, html) abort
  let lines = [a:title, '']
  if a:html ==# ''
    call add(lines, '(記事の取得に失敗しました)')
  else
    let text = a:html
    let text = substitute(text, '<script\_.\{-}</script>', '', 'g')
    let text = substitute(text, '<style\_.\{-}</style>', '', 'g')
    let text = substitute(text, '<br\s*/\?>', '\n', 'g')
    let text = substitute(text, '<\/\?p\(\s[^>]*\)\?>', '\n', 'g')
    let text = substitute(text, '<[^>]*>', '', 'g')
    let text = substitute(text, '&amp;', '\&', 'g')
    let text = substitute(text, '&lt;', '<', 'g')
    let text = substitute(text, '&gt;', '>', 'g')
    let text = substitute(text, '&quot;', '"', 'g')
    let text = substitute(text, '&#39;', "'", 'g')
    let text = substitute(text, '&nbsp;', ' ', 'g')
    let text = substitute(text, '\r', '', 'g')
    for l in split(text, '\n')
      let l = substitute(l, '^\s\+\|\s\+$', '', 'g')
      if l !=# ''
        call add(lines, l)
      endif
    endfor
  endif
  if len(lines) > 40
    let lines = lines[:39] + ['', '...']
  endif
  return lines
endfunction

function! s:on_chunk(id, gen, ch, msg) abort
  let inst = s:instances[a:id]
  if a:gen != inst.gen
    return
  endif
  call add(inst.fetch_buf, a:msg)
endfunction

function! s:on_done(id, popup_id, gen, title, job, status) abort
  let inst = s:instances[a:id]
  if a:gen != inst.gen
    return
  endif
  let inst.job = v:null
  if a:popup_id != inst.popup || popup_getpos(a:popup_id) == {}
    return
  endif
  let html = a:status == 0 ? join(inst.fetch_buf, "\n") : ''
  call popup_settext(a:popup_id, s:parse_article(a:title, html))
endfunction

function! s:on_popup_filter(id, key) abort
  if a:key ==# 'j' || a:key ==# "\<Down>"
    call win_execute(a:id, "normal! \<C-E>")
    return 1
  endif
  if a:key ==# 'k' || a:key ==# "\<Up>"
    call win_execute(a:id, "normal! \<C-Y>")
    return 1
  endif
  if a:key ==# 'q'
    call popup_close(a:id)
    return 1
  endif
  return 0
endfunction

function! s:on_popup_close(id, result) abort
  for inst in s:instances
    if inst.popup == a:id
      let inst.selected = -1
      let inst.popup = -1
      redrawtabpanel
      return
    endif
  endfor
endfunction

" Click dispatcher: minwid encodes id * 1000 + idx.
function! supertabpanel#widgets#rssfeed#click(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx < 0 || idx >= len(inst.items)
    return 0
  endif
  " Only one rssfeed popup is allowed at a time — if another instance is
  " showing one, close it and clear its selection so the old highlight
  " doesn't linger after we switch to this feed.
  for other in s:instances
    if other.id != id && other.popup > 0 && popup_getpos(other.popup) != {}
      call popup_close(other.popup)
    endif
  endfor
  let inst.selected = idx
  redrawtabpanel
  let item = inst.items[idx]
  let loading = [item.title, '', '読み込み中...']
  if inst.popup > 0 && popup_getpos(inst.popup) != {}
    call popup_settext(inst.popup, loading)
  else
    let inst.popup = popup_create(loading, #{
          \ border: [],
          \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
          \ maxheight: 30,
          \ padding: [0,1,0,1],
          \ scrollbar: 1,
          \ close: 'click',
          \ filter: function('s:on_popup_filter'),
          \ callback: function('s:on_popup_close'),
          \ highlight: 'SuperTabPanelRss',
          \ borderhighlight: ['SuperTabPanelSep'],
          \ })
  endif
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.gen += 1
  let inst.fetch_buf = []
  let popup_id = inst.popup
  let gen = inst.gen
  let inst.job = job_start(['curl', '-sL', item.link], #{
        \ out_cb: function('s:on_chunk', [id, gen]),
        \ exit_cb: function('s:on_done', [id, popup_id, gen, item.title]),
        \ mode: 'nl',
        \ })
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let header = '%#SuperTabPanelRssHead#  ' .. inst.icon .. ' ' .. inst.name
  if len(inst.items) == 0
    return header .. '  %#SuperTabPanelRss#fetching...%@'
  endif
  let result = header .. '%@'
  let items = inst.max > 0 ? inst.items[: inst.max - 1] : inst.items
  let idx = 0
  for item in items
    let display = supertabpanel#truncate(item.title, supertabpanel#content_width(5))
    let display = substitute(display, '%', '%%', 'g')
    let mark = idx == inst.selected ? '▶ ' : '  '
    let hl = idx == inst.selected ? '%#SuperTabPanelRssHead#' : '%#SuperTabPanelRss#'
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#rssfeed#click]'
          \ .. hl .. mark .. display .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:fetch(a:id, 0)
    let inst.timer = timer_start(600000,
          \ function('s:fetch', [a:id]), #{ repeat: -1 })
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
  if inst.rss_job isnot v:null && job_status(inst.rss_job) ==# 'run'
    call job_stop(inst.rss_job)
  endif
  let inst.rss_job = v:null
  if inst.popup > 0 && popup_getpos(inst.popup) != {}
    call popup_close(inst.popup)
  endif
  let inst.popup = -1
  let inst.selected = -1
endfunction

function! supertabpanel#widgets#rssfeed#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_rssfeed_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  let inst = #{
        \ id: id,
        \ name: get(a:params, 'name', 'RSS'),
        \ url: get(a:params, 'url', ''),
        \ icon: get(a:params, 'icon', '📰'),
        \ max: get(a:params, 'max', 0),
        \ items: [],
        \ selected: -1,
        \ popup: -1,
        \ job: v:null,
        \ fetch_buf: [],
        \ gen: 0,
        \ timer: -1,
        \ rss_job: v:null,
        \ rss_buf: [],
        \ }
  call add(s:instances, inst)
  return #{
        \ icon: inst.icon,
        \ label: inst.name,
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
