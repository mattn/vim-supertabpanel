" vim-supertabpanel : Asahi News widget

let s:news = []
let s:selected = -1
let s:popup = -1
let s:job = v:null
let s:fetch_buf = []
let s:gen = 0
let s:timer = -1
let s:rss_job = v:null
let s:rss_buf = []

function! s:setup_colors() abort
  hi default SuperTabPanelNewsHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelNews     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
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
  let news = []
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
    let title = ''
    let m = matchlist(chunk, '<title>\s*<!\[CDATA\[\(.\{-}\)\]\]>\s*</title>')
    if empty(m)
      let m = matchlist(chunk, '<title>\(.\{-}\)</title>')
    endif
    if !empty(m)
      let title = s:decode_entities(m[1])
    endif
    if title !=# '' && link !=# ''
      call add(news, {'title': title, 'link': link})
    endif
  endfor
  return news
endfunction

function! s:on_rss_chunk(ch, msg) abort
  call add(s:rss_buf, a:msg)
endfunction

function! s:on_rss_done(job, status) abort
  let s:rss_job = v:null
  if a:status != 0 || empty(s:rss_buf)
    return
  endif
  try
    let s:news = s:parse_rss(join(s:rss_buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#asahinews#fetch(timer) abort
  if !executable('curl')
    return
  endif
  if s:rss_job isnot v:null && job_status(s:rss_job) ==# 'run'
    return
  endif
  let s:rss_buf = []
  let s:rss_job = job_start(
        \ ['curl', '-sL', 'https://www.asahi.com/rss/asahi/newsheadlines.rdf'],
        \ #{
        \   out_cb: function('s:on_rss_chunk'),
        \   exit_cb: function('s:on_rss_done'),
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

function! s:on_chunk(gen, ch, msg) abort
  if a:gen != s:gen
    return
  endif
  call add(s:fetch_buf, a:msg)
endfunction

function! s:on_done(popup_id, gen, title, job, status) abort
  if a:gen != s:gen
    return
  endif
  let s:job = v:null
  if a:popup_id != s:popup || popup_getpos(a:popup_id) == {}
    return
  endif
  let html = a:status == 0 ? join(s:fetch_buf, "\n") : ''
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
  let s:selected = -1
  let s:popup = -1
  redrawtabpanel
endfunction

function! supertabpanel#widgets#asahinews#show_article(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:news)
    return 0
  endif
  let s:selected = idx
  redrawtabpanel
  let item = s:news[idx]
  let loading = [item.title, '', '読み込み中...']
  if s:popup > 0 && popup_getpos(s:popup) != {}
    call popup_settext(s:popup, loading)
  else
    let s:popup = popup_create(loading, #{
          \ border: [],
          \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
          \ maxheight: 30,
          \ padding: [0,1,0,1],
          \ scrollbar: 1,
          \ close: 'click',
          \ filter: function('s:on_popup_filter'),
          \ callback: function('s:on_popup_close'),
          \ highlight: 'SuperTabPanelNews',
          \ borderhighlight: ['SuperTabPanelSep'],
          \ })
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:gen += 1
  let s:fetch_buf = []
  let popup_id = s:popup
  let gen = s:gen
  let s:job = job_start(['curl', '-sL', item.link], #{
        \ out_cb: function('s:on_chunk', [gen]),
        \ exit_cb: function('s:on_done', [popup_id, gen, item.title]),
        \ mode: 'nl',
        \ })
  return 1
endfunction

function! supertabpanel#widgets#asahinews#render() abort
  if len(s:news) == 0
    return '%#SuperTabPanelNewsHead#  📰 News  %#SuperTabPanelNews#fetching...%@'
  endif
  let result = '%#SuperTabPanelNewsHead#  📰 朝日新聞%@'
  let idx = 0
  for item in s:news
    let display = supertabpanel#truncate(item.title, supertabpanel#content_width(5))
    let display = substitute(display, '%', '%%', 'g')
    let mark = idx == s:selected ? '▶ ' : '  '
    let hl = idx == s:selected ? '%#SuperTabPanelNewsHead#' : '%#SuperTabPanelNews#'
    let result ..= '%' .. idx .. '[supertabpanel#widgets#asahinews#show_article]'
          \ .. hl .. mark .. display .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#asahinews#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#asahinews#fetch(0)
    let s:timer = timer_start(600000,
          \ function('supertabpanel#widgets#asahinews#fetch'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#asahinews#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
  if s:rss_job isnot v:null && job_status(s:rss_job) ==# 'run'
    call job_stop(s:rss_job)
  endif
  let s:rss_job = v:null
  if s:popup > 0 && popup_getpos(s:popup) != {}
    call popup_close(s:popup)
  endif
  let s:popup = -1
  let s:selected = -1
endfunction

function! supertabpanel#widgets#asahinews#init() abort
  call s:setup_colors()
  augroup supertabpanel_asahinews_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('asahinews', #{
        \ icon: '📰',
        \ label: 'Asahi News',
        \ render: function('supertabpanel#widgets#asahinews#render'),
        \ on_activate: function('supertabpanel#widgets#asahinews#activate'),
        \ on_deactivate: function('supertabpanel#widgets#asahinews#deactivate'),
        \ })
endfunction
