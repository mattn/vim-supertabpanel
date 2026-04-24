" vim-supertabpanel : sunrise / sunset widget (uses api.sunrise-sunset.org)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:data = {}
let s:lat = get(g:, 'supertabpanel_sunmoon_lat', 35.6895)   " Tokyo
let s:lng = get(g:, 'supertabpanel_sunmoon_lng', 139.6917)

function! s:setup_colors() abort
  hi default SuperTabPanelSmHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelSm     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelSmSun  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0 || empty(s:buf)
    return
  endif
  try
    let d = json_decode(join(s:buf, ''))
    if get(d, 'status', '') ==# 'OK'
      let s:data = d.results
      redrawtabpanel
    endif
  catch
  endtry
endfunction

function! supertabpanel#widgets#sunmoon#refresh(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let url = printf('https://api.sunrise-sunset.org/json?lat=%.4f&lng=%.4f&formatted=0',
        \ s:lat, s:lng)
  let s:job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! s:is_leap(y) abort
  return (a:y % 4 == 0 && a:y % 100 != 0) || a:y % 400 == 0
endfunction

function! s:utc_epoch(Y, M, D, h, m, s) abort
  let days = 0
  for y in range(1970, a:Y - 1)
    let days += s:is_leap(y) ? 366 : 365
  endfor
  let mdays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if s:is_leap(a:Y)
    let mdays[1] = 29
  endif
  for mo in range(a:M - 1)
    let days += mdays[mo]
  endfor
  let days += a:D - 1
  return days * 86400 + a:h * 3600 + a:m * 60 + a:s
endfunction

function! s:to_local(utc) abort
  " Input: "2026-04-23T20:42:00+00:00" (UTC). Parse the components ourselves
  " so we don't depend on strptime (missing on native Windows Vim).
  let m = matchlist(a:utc,
        \ '^\(\d\{4\}\)-\(\d\{2\}\)-\(\d\{2\}\)T\(\d\{2\}\):\(\d\{2\}\):\(\d\{2\}\)')
  if empty(m)
    return ''
  endif
  let epoch = s:utc_epoch(str2nr(m[1]), str2nr(m[2]), str2nr(m[3]),
        \ str2nr(m[4]), str2nr(m[5]), str2nr(m[6]))
  return strftime('%H:%M', epoch)
endfunction

function! supertabpanel#widgets#sunmoon#render() abort
  let result = '%#SuperTabPanelSmHead#  ☀ Sunrise / Sunset%@'
  if empty(s:data)
    return result .. '%#SuperTabPanelSm#  fetching...%@'
  endif
  let rise = s:to_local(s:data.sunrise)
  let set  = s:to_local(s:data.sunset)
  let noon = s:to_local(s:data.solar_noon)
  let result ..= '%#SuperTabPanelSmSun#  ☀ ' .. rise .. '  ☼ ' .. noon .. '  ☾ ' .. set .. '%@'
  let result ..= '%#SuperTabPanelSm#  daylen: ' .. s:data.day_length .. 's%@'
  return result
endfunction

function! supertabpanel#widgets#sunmoon#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#sunmoon#refresh(0)
    let s:timer = timer_start(3600000,
          \ function('supertabpanel#widgets#sunmoon#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#sunmoon#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#sunmoon#init() abort
  call s:setup_colors()
  augroup supertabpanel_sm_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('sunmoon', #{
        \ icon: '☀',
        \ label: 'Sun',
        \ render: function('supertabpanel#widgets#sunmoon#render'),
        \ on_activate: function('supertabpanel#widgets#sunmoon#activate'),
        \ on_deactivate: function('supertabpanel#widgets#sunmoon#deactivate'),
        \ })
endfunction
