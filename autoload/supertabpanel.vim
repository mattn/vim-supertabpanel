" vim-supertabpanel : core dispatcher / widget registry

let s:DEFAULT_COLUMNS = 32

let s:widgets = {}
let s:panels = []
let s:current_panel = 0
let s:columns = s:DEFAULT_COLUMNS
let s:anim_timer = -1
let s:anim_phase = ''
let s:did_setup = 0

function! supertabpanel#register(name, spec) abort
  let s:widgets[a:name] = a:spec
endfunction

function! supertabpanel#widget(name) abort
  return get(s:widgets, a:name, {})
endfunction

function! supertabpanel#panels() abort
  return copy(s:panels)
endfunction

function! supertabpanel#current_panel() abort
  return s:current_panel
endfunction

function! supertabpanel#columns() abort
  return s:columns
endfunction

" Usable text width inside a widget line after subtracting {margin} cells
" (leading spaces, icons, selection markers, trailing padding, etc).
" Clamped to at least 1 so callers can safely pass the result to truncate().
function! supertabpanel#content_width(margin) abort
  let w = s:columns - a:margin
  return w < 1 ? 1 : w
endfunction

" Current panel's widget names (short form, e.g. 'calendar')
function! s:current_widget_names() abort
  if s:current_panel < 0 || s:current_panel >= len(s:panels)
    return []
  endif
  return s:panels[s:current_panel].items
endfunction

function! supertabpanel#current_panel_name() abort
  if s:current_panel < 0 || s:current_panel >= len(s:panels)
    return ''
  endif
  return s:panels[s:current_panel].name
endfunction

function! s:activate_current() abort
  for name in s:current_widget_names()
    let w = get(s:widgets, name, {})
    if !empty(w) && has_key(w, 'on_activate')
      call w.on_activate()
    endif
  endfor
endfunction

function! s:deactivate_current() abort
  for name in s:current_widget_names()
    let w = get(s:widgets, name, {})
    if !empty(w) && has_key(w, 'on_deactivate')
      call w.on_deactivate()
    endif
  endfor
endfunction

function! supertabpanel#switch_panel(idx) abort
  if a:idx < 0 || a:idx >= len(s:panels) || a:idx == s:current_panel
    return
  endif
  call s:deactivate_current()
  let s:current_panel = a:idx
  call s:activate_current()
  if exists('*tabpanel_setscroll')
    call tabpanel_setscroll(0)
  endif
  redrawtabpanel
endfunction

" ---- Dispatcher ----
function! supertabpanel#dispatch() abort
  if g:actual_curtabpage != 1
    return ''
  endif
  let result = ''
  let first = 1
  for name in s:current_widget_names()
    let w = get(s:widgets, name, {})
    if empty(w) || !has_key(w, 'render')
      continue
    endif
    if !first
      let result ..= s:separator() .. '%@'
      let result ..= '%#SuperTabPanelNormal#%@'
    endif
    let first = 0
    let body = w.render()
    if type(body) == v:t_string && body !=# ''
      let result ..= body
    endif
  endfor
  return result
endfunction

function! s:separator() abort
  return '%#SuperTabPanelSep#  ' .. repeat('─', s:columns - 4)
endfunction

" Return the longest prefix of {str} whose display width is <= {width}.
" Tabs are normalized to a single space first.
function! supertabpanel#strwidthpart(str, width) abort
  let str = tr(a:str, "\t", ' ')
  let vcol = a:width + 2
  return matchstr(str, '.*\%<' . (vcol < 0 ? 0 : vcol) . 'v')
endfunction

" Truncate {str} to {width} cells, adding '..' if it was truncated.
function! supertabpanel#truncate(str, width) abort
  if strdisplaywidth(a:str) <= a:width
    return a:str
  endif
  return supertabpanel#strwidthpart(a:str, a:width - 2) .. '..'
endfunction

" Wrap {str} by display width {width}, returning a list of lines.
" Breaks by character (works for CJK text without word separators).
function! supertabpanel#wrap(str, width) abort
  let lines = []
  let rest = a:str
  while rest !=# ''
    let chunk = supertabpanel#strwidthpart(rest, a:width)
    if chunk ==# ''
      break
    endif
    call add(lines, chunk)
    let rest = strpart(rest, len(chunk))
  endwhile
  return lines
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelNormal  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelSep     guifg=#3b4261 guibg=#1a1b26 ctermfg=238 ctermbg=234
  " Flatten Vim's default tab-selection indicator column so the tabpanel
  " doesn't show a purple stripe on the left edge of the active tab.
  hi default TabPanel     guifg=#a9b1d6 guibg=#1a1b26 gui=NONE cterm=NONE ctermfg=249 ctermbg=234
  hi default TabPanelSel  guifg=#a9b1d6 guibg=#1a1b26 gui=NONE cterm=NONE ctermfg=249 ctermbg=234
  hi default TabPanelFill guifg=#a9b1d6 guibg=#1a1b26 gui=NONE cterm=NONE ctermfg=249 ctermbg=234
endfunction

" ---- Setup / animation ----
function! supertabpanel#did_setup() abort
  return s:did_setup
endfunction

function! supertabpanel#setup(...) abort
  let s:did_setup = 1
  let opts = get(a:, 1, {})
  let s:columns = get(opts, 'columns', s:DEFAULT_COLUMNS)
  let panels = get(opts, 'panels', [])

  " Normalize panels.  Each panel may be either:
  "   - a list of widget names:         ['calendar', 'btcchart']
  "   - a dict with name + items:       #{ name: 'Time', items: [...] }
  " Widget names may be short ('calendar') or fully qualified
  " ('supertabpanel#widgets#calendar', 'widgets#calendar').
  let s:panels = []
  let auto_idx = 0
  for p in panels
    if type(p) == v:t_dict
      let name = get(p, 'name', '')
      let raw_items = get(p, 'items', [])
    else
      let name = ''
      let raw_items = p
    endif
    let widgets = []
    for n in raw_items
      let short = substitute(n, '^\%(supertabpanel#\)\?\%(widgets#\)\?', '', '')
      call add(widgets, short)
    endfor
    if name ==# ''
      let name = 'Panel ' .. (auto_idx + 1)
    endif
    call add(s:panels, #{ name: name, items: widgets })
    let auto_idx += 1
  endfor

  " Load widgets (triggers autoload -> register).
  let seen = {}
  for p in s:panels
    for name in p.items
      if has_key(seen, name)
        continue
      endif
      let seen[name] = 1
      try
        call call('supertabpanel#widgets#' .. name .. '#init', [])
      catch
        echohl ErrorMsg
        echom 'supertabpanel: failed to load "' .. name .. '": ' .. v:exception
        echohl None
      endtry
    endfor
  endfor

  let s:current_panel = get(opts, 'default', 0)
  if s:current_panel < 0 || s:current_panel >= len(s:panels)
    let s:current_panel = 0
  endif

  call s:setup_colors()
  augroup supertabpanel_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END

  let &tabpanelopt = 'columns:' .. s:columns .. ',vert,scroll,scrollbar'
  if &fillchars !~# 'tpl_vert:'
    set fillchars+=tpl_vert:│
  endif
  set tabpanel=%!supertabpanel#dispatch()

  call s:activate_current()
endfunction

" ---- Rotation with close/open animation ----
function! supertabpanel#rotate(...) abort
  if len(s:panels) <= 1
    return
  endif
  let step = get(a:, 1, 1)
  if s:anim_timer > 0
    call timer_stop(s:anim_timer)
    let s:anim_timer = -1
  endif
  let s:anim_step = step
  if &showtabpanel == 0
    " Hidden: skip close phase, just switch + open animation.
    let n = len(s:panels)
    let s:current_panel = ((s:current_panel + step) % n + n) % n
    call s:activate_current()
    let &tabpanelopt = 'columns:4,vert,scroll,scrollbar'
    set showtabpanel=2
    let s:anim_phase = 'open'
  else
    let s:anim_phase = 'close'
  endif
  let s:anim_timer = timer_start(20,
        \ function('s:rotate_step'), #{ repeat: -1 })
endfunction

function! s:rotate_step(timer) abort
  let cur = str2nr(matchstr(&tabpanelopt, 'columns:\zs\d\+'))
  if s:anim_phase ==# 'close'
    let cur -= 4
    if cur <= 0
      let &tabpanelopt = 'columns:4,vert,scroll,scrollbar'
      call s:deactivate_current()
      let n = len(s:panels)
      let s:current_panel = ((s:current_panel + s:anim_step) % n + n) % n
      call s:activate_current()
      let s:anim_phase = 'open'
      if exists('*tabpanel_setscroll')
        call tabpanel_setscroll(0)
      endif
      redrawtabpanel
      return
    endif
    let &tabpanelopt = 'columns:' .. cur .. ',vert,scroll,scrollbar'
  else
    let cur += 4
    if cur >= s:columns
      let cur = s:columns
      call timer_stop(a:timer)
      let s:anim_timer = -1
      echo '▶ ' .. s:panels[s:current_panel].name
    endif
    let &tabpanelopt = 'columns:' .. cur .. ',vert,scroll,scrollbar'
  endif
endfunction

" ---- Simple open/close toggle (no rotation) ----
function! supertabpanel#toggle() abort
  if s:anim_timer > 0
    call timer_stop(s:anim_timer)
    let s:anim_timer = -1
  endif
  if &showtabpanel == 0
    call s:activate_current()
    let &tabpanelopt = 'columns:4,vert,scroll,scrollbar'
    set showtabpanel=2
    let s:anim_phase = 'open'
    let s:anim_timer = timer_start(20,
          \ function('s:toggle_step'), #{ repeat: -1 })
  else
    let s:anim_phase = 'close_hide'
    let s:anim_timer = timer_start(20,
          \ function('s:toggle_step'), #{ repeat: -1 })
  endif
endfunction

function! s:toggle_step(timer) abort
  let cur = str2nr(matchstr(&tabpanelopt, 'columns:\zs\d\+'))
  if s:anim_phase ==# 'open'
    let cur += 4
    if cur >= s:columns
      let cur = s:columns
      call timer_stop(a:timer)
      let s:anim_timer = -1
    endif
    let &tabpanelopt = 'columns:' .. cur .. ',vert,scroll,scrollbar'
  else
    let cur -= 4
    if cur <= 0
      call timer_stop(a:timer)
      let s:anim_timer = -1
      call s:deactivate_current()
      set showtabpanel=0
      return
    endif
    let &tabpanelopt = 'columns:' .. cur .. ',vert,scroll,scrollbar'
  endif
endfunction
