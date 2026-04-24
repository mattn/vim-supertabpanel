" vim-supertabpanel : sunrise / sunset widget (uses api.sunrise-sunset.org)
"
" Instance params:
"   lat : latitude  (default 35.6895 — Tokyo)
"   lng : longitude (default 139.6917)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelSmHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelSm     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelSmSun  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
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
    let d = json_decode(join(inst.buf, ''))
    if get(d, 'status', '') ==# 'OK'
      let inst.data = d.results
      redrawtabpanel
    endif
  catch
  endtry
endfunction

function! s:refresh(id, timer) abort
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    return
  endif
  let inst.buf = []
  let url = printf('https://api.sunrise-sunset.org/json?lat=%.4f&lng=%.4f&formatted=0',
        \ inst.lat, inst.lng)
  let inst.job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
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
  let m = matchlist(a:utc,
        \ '^\(\d\{4\}\)-\(\d\{2\}\)-\(\d\{2\}\)T\(\d\{2\}\):\(\d\{2\}\):\(\d\{2\}\)')
  if empty(m)
    return ''
  endif
  let epoch = s:utc_epoch(str2nr(m[1]), str2nr(m[2]), str2nr(m[3]),
        \ str2nr(m[4]), str2nr(m[5]), str2nr(m[6]))
  return strftime('%H:%M', epoch)
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelSmHead#  ☀ Sunrise / Sunset%@'
  if empty(inst.data)
    return result .. '%#SuperTabPanelSm#  fetching...%@'
  endif
  let rise = s:to_local(inst.data.sunrise)
  let set  = s:to_local(inst.data.sunset)
  let noon = s:to_local(inst.data.solar_noon)
  let result ..= '%#SuperTabPanelSmSun#  ☀ ' .. rise .. '  ☼ ' .. noon .. '  ☾ ' .. set .. '%@'
  let result ..= '%#SuperTabPanelSm#  daylen: ' .. inst.data.day_length .. 's%@'
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:refresh(a:id, 0)
    let inst.timer = timer_start(3600000,
          \ function('s:refresh', [a:id]), #{ repeat: -1 })
  endif
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  if inst.timer != -1
    call timer_stop(inst.timer)
    let inst.timer = -1
  endif
endfunction

function! supertabpanel#widgets#sunmoon#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_sm_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ lat: get(a:params, 'lat', 35.6895),
        \ lng: get(a:params, 'lng', 139.6917),
        \ data: {},
        \ buf: [],
        \ job: v:null,
        \ timer: -1,
        \ })
  return #{
        \ icon: '☀',
        \ label: 'Sun',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
