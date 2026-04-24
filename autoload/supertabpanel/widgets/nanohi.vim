" vim-supertabpanel : 今日は何の日 widget (pulls from ja.wikipedia.org)
"
" Instance params:
"   section : 'holidays' (default — 記念日・年中行事)
"             'events'   — できごと
"             'births'   — 誕生日
"             'deaths'   — 忌日
"   name    : header label (default derives from section)
"   icon    : header icon (default '📅')
"   max     : maximum items to display (default 0 = all)
"
" Clicking the header opens today's Wikipedia page in the default browser.

let s:instances = []
let s:colors_ready = 0

let s:SECTIONS = #{
      \ holidays: #{ hdr: '記念日・年中行事', name: '今日は何の日' },
      \ events:   #{ hdr: 'できごと',         name: '今日のできごと' },
      \ births:   #{ hdr: '誕生日',           name: '今日生まれ' },
      \ deaths:   #{ hdr: '忌日',             name: '今日亡くなった' },
      \ }

function! s:setup_colors() abort
  hi default SuperTabPanelNhHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelNh     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:decode_entities(s) abort
  let s = a:s
  let s = substitute(s, '&lt;', '<', 'g')
  let s = substitute(s, '&gt;', '>', 'g')
  let s = substitute(s, '&quot;', '"', 'g')
  let s = substitute(s, '&#39;', "'", 'g')
  let s = substitute(s, '&nbsp;', ' ', 'g')
  let s = substitute(s, '&amp;', '\&', 'g')
  return s
endfunction

function! s:today_url() abort
  let m = str2nr(strftime('%m'))
  let d = str2nr(strftime('%d'))
  " 月 = U+6708 → %E6%9C%88,  日 = U+65E5 → %E6%97%A5
  return 'https://ja.wikipedia.org/wiki/' .. m .. '%E6%9C%88' .. d .. '%E6%97%A5'
endfunction

function! s:today_key() abort
  return strftime('%Y%m%d')
endfunction

function! s:parse(id, html) abort
  let inst = s:instances[a:id]
  let spec = get(s:SECTIONS, inst.section, s:SECTIONS.holidays)
  let hdr = spec.hdr
  let html = substitute(a:html, '<script\_.\{-}</script>', '', 'g')
  let html = substitute(html, '<style\_.\{-}</style>', '', 'g')
  " Narrow to this section (between its <h2> and the next <h2>).
  let sec = matchstr(html,
        \ '<h2 id="' .. hdr .. '"[^>]*>\zs\_.\{-}\ze<h2')
  if sec ==# ''
    return []
  endif
  let items = []
  let rest = sec
  while 1
    let m = matchstrpos(rest, '<li\%(\s[^>]*\)\?>\zs\_.\{-}\ze</li>')
    if m[1] < 0
      break
    endif
    let inner = m[0]
    let inner = substitute(inner, '<ul\_[^>]*>\_.\{-}</ul>', '', 'g')
    let inner = substitute(inner, '<[^>]*>', '', 'g')
    let inner = s:decode_entities(inner)
    let inner = substitute(inner, '\_s\+', ' ', 'g')
    let inner = trim(inner)
    if strchars(inner) >= 2
      call add(items, inner)
    endif
    let rest = rest[m[2] :]
  endwhile
  return items
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
    let inst.items = s:parse(a:id, join(inst.buf, ''))
    let inst.fetched_key = s:today_key()
    redrawtabpanel
  catch
  endtry
endfunction

function! s:fetch(id, timer) abort
  if !executable('curl')
    return
  endif
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    return
  endif
  let inst.buf = []
  let inst.job = job_start(['curl', '-sL', s:today_url()], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'raw',
        \ err_io: 'null',
        \ })
endfunction

function! supertabpanel#widgets#nanohi#open(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let url = s:today_url()
  if executable('xdg-open')
    call job_start(['xdg-open', url])
  elseif executable('open')
    call job_start(['open', url])
  endif
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let header = '%#SuperTabPanelNhHead#  ' .. inst.icon .. ' ' .. inst.name
  let result = '%' .. a:id .. '[supertabpanel#widgets#nanohi#open]'
        \ .. header .. '%[]%@'
  if empty(inst.items)
    return result .. '%#SuperTabPanelNh#  fetching...%@'
  endif
  let items = inst.max > 0 ? inst.items[: inst.max - 1] : inst.items
  for item in items
    let text = supertabpanel#truncate(item, supertabpanel#content_width(6))
    let text = substitute(text, '%', '%%', 'g')
    let result ..= '%#SuperTabPanelNh#  • ' .. text .. '%@'
  endfor
  return result
endfunction

function! s:tick(id, timer) abort
  let inst = s:instances[a:id]
  if inst.fetched_key !=# s:today_key()
    call s:fetch(a:id, 0)
  endif
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if empty(inst.items) || inst.fetched_key !=# s:today_key()
    call s:fetch(a:id, 0)
  endif
  if inst.timer == -1
    " Hourly date-rollover check so Vim left open past midnight
    " refetches the new day's list.
    let inst.timer = timer_start(3600000,
          \ function('s:tick', [a:id]), #{ repeat: -1 })
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

function! supertabpanel#widgets#nanohi#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_nh_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let section = get(a:params, 'section', 'holidays')
  let spec = get(s:SECTIONS, section, s:SECTIONS.holidays)
  let id = len(s:instances)
  let name = get(a:params, 'name', spec.name)
  let icon = get(a:params, 'icon', '📅')
  call add(s:instances, #{
        \ id: id,
        \ section: section,
        \ name: name,
        \ icon: icon,
        \ max: get(a:params, 'max', 0),
        \ items: [],
        \ buf: [],
        \ job: v:null,
        \ timer: -1,
        \ fetched_key: '',
        \ })
  return #{
        \ icon: icon,
        \ label: name,
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
