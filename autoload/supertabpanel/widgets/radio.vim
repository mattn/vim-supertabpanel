" vim-supertabpanel : web radio widget (plays stream via ffplay)

let s:job = v:null
let s:current = -1
let s:stations = get(g:, 'supertabpanel_radio_stations', [
      \ #{ name: 'SomaFM Groove Salad', url: 'https://somafm.com/groovesalad.pls' },
      \ #{ name: 'SomaFM DefCon Radio', url: 'https://somafm.com/defcon.pls' },
      \ #{ name: 'SomaFM Secret Agent', url: 'https://somafm.com/secretagent.pls' },
      \ #{ name: 'Lofi Hip Hop',        url: 'https://play.streamafrica.net/lofiradio' },
      \ ])

function! s:setup_colors() abort
  hi default SuperTabPanelRdHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelRd     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelRdPlay guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
endfunction

function! s:stop() abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
  let s:current = -1
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

function! supertabpanel#widgets#radio#play(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:stations)
    return 0
  endif
  if !executable('ffplay')
    echohl WarningMsg | echom 'ffplay not found' | echohl None
    return 0
  endif
  call s:stop()
  let s:current = idx
  let stream = s:resolve_stream(s:stations[idx].url)
  let s:job = job_start(['ffplay', '-nodisp', '-loglevel', 'quiet',
        \ '-autoexit', '-infbuf', stream])
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#radio#stop(info) abort
  call s:stop()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#radio#render() abort
  let result = '%#SuperTabPanelRdHead#  📻 Radio%@'
  let idx = 0
  for s in s:stations
    let playing = (idx == s:current)
    let hl = playing ? '%#SuperTabPanelRdPlay#' : '%#SuperTabPanelRd#'
    let icon = playing ? '▶' : ' '
    let name = supertabpanel#truncate(s.name, supertabpanel#content_width(6))
    let result ..= '%' .. idx .. '[supertabpanel#widgets#radio#play]'
          \ .. hl .. ' ' .. icon .. ' ' .. name .. '%[]%@'
    let idx += 1
  endfor
  if s:current >= 0
    let result ..= '%0[supertabpanel#widgets#radio#stop]'
          \ .. '%#SuperTabPanelRd#  ⏹ stop%[]%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#radio#deactivate() abort
  call s:stop()
endfunction

function! supertabpanel#widgets#radio#init() abort
  call s:setup_colors()
  augroup supertabpanel_rd_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('radio', #{
        \ icon: '📻',
        \ label: 'Radio',
        \ render: function('supertabpanel#widgets#radio#render'),
        \ on_deactivate: function('supertabpanel#widgets#radio#deactivate'),
        \ })
endfunction
