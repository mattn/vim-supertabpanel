" vim-supertabpanel : web radio widget (plays stream via ffplay)
"
" Instance params:
"   stations : list of #{ name, url }.  Default is a small SomaFM set.

let s:instances = []
let s:colors_ready = 0

" Global play state — only one stream plays at a time across all instances.
let s:play_job = v:null
let s:play_inst = -1
let s:play_idx = -1

function! s:default_stations() abort
  return [
        \ #{ name: 'SomaFM Groove Salad', url: 'https://somafm.com/groovesalad.pls' },
        \ #{ name: 'SomaFM DefCon Radio', url: 'https://somafm.com/defcon.pls' },
        \ #{ name: 'SomaFM Secret Agent', url: 'https://somafm.com/secretagent.pls' },
        \ #{ name: 'Lofi Hip Hop',        url: 'https://play.streamafrica.net/lofiradio' },
        \ ]
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelRdHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelRd     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelRdPlay guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
endfunction

function! s:stop_play() abort
  if s:play_job isnot v:null && job_status(s:play_job) ==# 'run'
    call job_stop(s:play_job)
  endif
  let s:play_job = v:null
  let s:play_inst = -1
  let s:play_idx = -1
endfunction

function! s:resolve_stream(url) abort
  if a:url !~? '\.\(pls\|m3u8\?\)\%(?.*\)\?$'
    return a:url
  endif
  if !executable('curl')
    return a:url
  endif
  silent let lines = systemlist('curl -sL ' .. shellescape(a:url) .. ' 2>/dev/null')
  for l in lines
    let m = matchstr(l, '\c^File\d*\s*=\s*\zs\S\+')
    if m !=# ''
      return m
    endif
    if l =~# '^https\?://'
      return trim(l)
    endif
  endfor
  return a:url
endfunction

" minwid encodes id*1000 + idx for play, just id for stop.
function! supertabpanel#widgets#radio#play(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx < 0 || idx >= len(inst.stations)
    return 0
  endif
  if !executable('ffplay')
    echohl WarningMsg | echom 'ffplay not found' | echohl None
    return 0
  endif
  call s:stop_play()
  let s:play_inst = id
  let s:play_idx = idx
  let stream = s:resolve_stream(inst.stations[idx].url)
  let s:play_job = job_start(['ffplay', '-nodisp', '-loglevel', 'quiet',
        \ '-autoexit', '-infbuf', stream])
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#radio#stop(info) abort
  call s:stop_play()
  redrawtabpanel
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelRdHead#  📻 Radio%@'
  let idx = 0
  for s in inst.stations
    let playing = (s:play_inst == a:id && s:play_idx == idx)
    let hl = playing ? '%#SuperTabPanelRdPlay#' : '%#SuperTabPanelRd#'
    let icon = playing ? '▶' : ' '
    let name = supertabpanel#truncate(s.name, supertabpanel#content_width(6))
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#radio#play]'
          \ .. hl .. ' ' .. icon .. ' ' .. name .. '%[]%@'
    let idx += 1
  endfor
  if s:play_inst == a:id
    let result ..= '%0[supertabpanel#widgets#radio#stop]'
          \ .. '%#SuperTabPanelRd#  ⏹ stop%[]%@'
  endif
  return result
endfunction

function! s:deactivate(id) abort
  if s:play_inst == a:id
    call s:stop_play()
  endif
endfunction

function! supertabpanel#widgets#radio#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_rd_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ stations: get(a:params, 'stations', s:default_stations()),
        \ })
  return #{
        \ icon: '📻',
        \ label: 'Radio',
        \ render: function('s:render', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
