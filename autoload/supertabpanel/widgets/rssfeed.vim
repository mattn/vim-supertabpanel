" vim-supertabpanel : generic RSS/RDF feed widget
"
" Instance params:
"   name : display name shown in the header (required)
"   url  : feed URL (required)
"   icon : header icon (default '📰')
"   max  : maximum number of items to display (default 0 = all)
"   content_selector : when fetching an article, narrow the HTML to this
"     element before extracting paragraphs.  Accepts CSS-ish selectors:
"       'tag'   — e.g. 'article', 'main'
"       '#foo'  — any tag with id="foo"
"       '.bar'  — any tag whose class list contains 'bar'
"     When unset, the widget tries <article> then <main> automatically.

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelRssHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelRss     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:decode_entities(s) abort
  let s = a:s
  " Numeric character references — handle these first so e.g. &#38; (=&)
  " doesn't get misinterpreted as the start of a named entity.
  let s = substitute(s, '&#x\(\x\+\);',
        \ '\=nr2char(str2nr(submatch(1), 16))', 'g')
  let s = substitute(s, '&#\(\d\+\);',
        \ '\=nr2char(str2nr(submatch(1)))', 'g')
  let s = substitute(s, '&lt;', '<', 'g')
  let s = substitute(s, '&gt;', '>', 'g')
  let s = substitute(s, '&quot;', '"', 'g')
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

" Strip noise tags globally.
function! s:strip_noise(html) abort
  let html = a:html
  for t in ['script', 'style', 'noscript', 'iframe', 'svg',
        \    'nav', 'header', 'footer', 'aside', 'form']
    let html = substitute(html,
          \ '<' .. t .. '\%(\s\_[^>]*\)\?>\_.\{-}</' .. t .. '\_[^>]*>',
          \ '', 'g')
  endfor
  return html
endfunction

" Scan forward from start_inner until the matching close tag, counting
" nested opens/closes.  Returns [inner_start, inner_end] byte offsets or
" [-1, -1] if no balanced close is found.
function! s:balanced_inner(html, opening_end, tag) abort
  let pat = '\c<\(/\?\)' .. a:tag .. '\%(\s[^>]*\|/\?\)\?>'
  let depth = 1
  let i = a:opening_end
  while 1
    let m = match(a:html, pat, i)
    if m < 0
      return [-1, -1]
    endif
    let end = matchend(a:html, pat, i)
    let is_close = (a:html[m + 1] ==# '/')
    if is_close
      let depth -= 1
      if depth == 0
        return [a:opening_end, m]
      endif
    else
      let depth += 1
    endif
    let i = end
  endwhile
endfunction

" Extract content matching selector.  Returns '' on no match.
function! s:extract_selector(html, selector) abort
  if a:selector ==# ''
    return ''
  endif
  if a:selector[0] ==# '#'
    let id = a:selector[1:]
    let pat = '\c<\(\w\+\)\%(\s[^>]*\)\?\<id\s*=\s*["'']' .. id .. '["''][^>]*>'
  elseif a:selector[0] ==# '.'
    let cls = a:selector[1:]
    let pat = '\c<\(\w\+\)\%(\s[^>]*\)\?\<class\s*=\s*["''][^"'']*\<' .. cls
          \ .. '\>[^"'']*["''][^>]*>'
  else
    let pat = '\c<\(' .. a:selector .. '\)\%(\s[^>]*\)\?>'
  endif
  let open = match(a:html, pat)
  if open < 0
    return ''
  endif
  let open_end = matchend(a:html, pat)
  let tag = matchlist(a:html, pat)[1]
  let range = s:balanced_inner(a:html, open_end, tag)
  if range[0] < 0
    " Fallback: non-greedy up to first matching close, good enough for
    " rarely-nested tags like <article>/<main>.
    let inner = matchstr(a:html[open_end :],
          \ '\_.\{-}\ze<\/' .. tag .. '\_[^>]*>')
    return inner
  endif
  return a:html[range[0] : range[1] - 1]
endfunction

" Pull the article body out of the page.  First tries the instance's
" content_selector param, then <article>, then <main>.  Returns the
" narrowed HTML, or the whole thing if nothing matched.
function! s:narrow_body(html, selector) abort
  let html = s:strip_noise(a:html)
  for sel in [a:selector, 'article', 'main']
    if sel ==# ''
      continue
    endif
    let inner = s:extract_selector(html, sel)
    if inner !=# ''
      return inner
    endif
  endfor
  return html
endfunction

function! s:decode_html_entities(s) abort
  let s = a:s
  let s = substitute(s, '&nbsp;', ' ', 'g')
  let s = substitute(s, '&lt;', '<', 'g')
  let s = substitute(s, '&gt;', '>', 'g')
  let s = substitute(s, '&quot;', '"', 'g')
  let s = substitute(s, '&#39;', "'", 'g')
  let s = substitute(s, '&amp;', '\&', 'g')
  return s
endfunction

" Collect <p> inner text blocks, one line per paragraph.  Returns [] if
" nothing substantive found.
function! s:extract_paragraphs(html) abort
  let lines = []
  let rest = a:html
  while 1
    let m = matchstrpos(rest, '<p\%(\s\_[^>]*\)\?>\zs\_.\{-}\ze</p\_[^>]*>')
    if m[1] < 0
      break
    endif
    let inner = m[0]
    let inner = substitute(inner, '<br\s*/\?>', '\n', 'g')
    let inner = substitute(inner, '<[^>]*>', '', 'g')
    let inner = s:decode_html_entities(inner)
    for l in split(inner, '\n')
      let l = substitute(l, '^\s\+\|\s\+$', '', 'g')
      if strchars(l) >= 15
        call add(lines, l)
      endif
    endfor
    let rest = rest[m[2] :]
  endwhile
  return lines
endfunction

function! s:parse_article(title, selector, html) abort
  let lines = [a:title, '']
  if a:html ==# ''
    call add(lines, '(記事の取得に失敗しました)')
  else
    let body = s:narrow_body(a:html, a:selector)
    let paragraphs = s:extract_paragraphs(body)
    if len(paragraphs) >= 2
      call extend(lines, paragraphs)
    else
      " Fall back to plain strip-all of the (narrowed) body.
      let text = body
      let text = substitute(text, '<br\s*/\?>', '\n', 'g')
      let text = substitute(text, '<\/\?p\(\s[^>]*\)\?>', '\n', 'g')
      let text = substitute(text, '<[^>]*>', '', 'g')
      let text = s:decode_html_entities(text)
      let text = substitute(text, '\r', '', 'g')
      for l in split(text, '\n')
        let l = substitute(l, '^\s\+\|\s\+$', '', 'g')
        if l !=# ''
          call add(lines, l)
        endif
      endfor
    endif
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
  call popup_settext(a:popup_id,
        \ s:parse_article(a:title, inst.content_selector, html))
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
        \ content_selector: get(a:params, 'content_selector', ''),
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
