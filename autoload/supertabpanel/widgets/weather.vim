" vim-supertabpanel : weather widget (wttr.in)
"
" Instance params:
"   location : wttr.in location string (default '' = geoip guess)

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelWxHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelWxTemp guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelWx     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
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
    let inst.data = json_decode(join(inst.buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! s:fetch(id, timer) abort
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    return
  endif
  let inst.buf = []
  let url = 'https://wttr.in/' .. inst.location .. '?format=j1'
  let inst.job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'raw',
        \ })
endfunction

function! s:icon(code) abort
  let m = {
        \ '113': '☀️', '116': '⛅', '119': '☁️', '122': '☁️',
        \ '143': '🌫️', '176': '🌦️', '179': '🌨️', '182': '🌧️',
        \ '185': '🌧️', '200': '⛈️', '227': '❄️', '230': '❄️',
        \ '248': '🌫️', '260': '🌫️', '263': '🌦️', '266': '🌦️',
        \ '281': '🌧️', '284': '🌧️', '293': '🌦️', '296': '🌦️',
        \ '299': '🌧️', '302': '🌧️', '305': '🌧️', '308': '🌧️',
        \ '311': '🌨️', '314': '🌨️', '317': '🌨️', '320': '🌨️',
        \ '323': '🌨️', '326': '🌨️', '329': '❄️', '332': '❄️',
        \ '335': '❄️', '338': '❄️', '353': '🌦️', '356': '🌧️',
        \ '359': '🌧️', '362': '🌨️', '365': '🌨️', '368': '🌨️',
        \ '371': '❄️', '386': '⛈️', '389': '⛈️', '392': '🌨️',
        \ '395': '❄️',
        \ }
  return get(m, a:code, '🌡️')
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelWxHead#  ☁️ Weather%@'
  if empty(inst.data) || !has_key(inst.data, 'current_condition')
    return result .. '%#SuperTabPanelWx#  fetching...%@'
  endif
  let cur = inst.data.current_condition[0]
  let code = cur.weatherCode
  let icon = s:icon(code)
  let temp = cur.temp_C
  let desc = supertabpanel#truncate(cur.weatherDesc[0].value, supertabpanel#content_width(12))
  let result ..= '%#SuperTabPanelWxTemp#  ' .. icon .. ' ' .. temp .. '°C%@'
  let result ..= '%#SuperTabPanelWx#  ' .. desc .. '%@'
  if has_key(inst.data, 'nearest_area')
    let area = inst.data.nearest_area[0].areaName[0].value
    let result ..= '%#SuperTabPanelWx#  📍 ' .. area .. '%@'
  endif
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:fetch(a:id, 0)
    let inst.timer = timer_start(1800000,
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
endfunction

function! supertabpanel#widgets#weather#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_wx_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ location: get(a:params, 'location', ''),
        \ data: {},
        \ buf: [],
        \ job: v:null,
        \ timer: -1,
        \ })
  return #{
        \ icon: '☁️',
        \ label: 'Weather',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
