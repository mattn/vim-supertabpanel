" vim-supertabpanel : weather widget (wttr.in)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:data = {}
let s:location = get(g:, 'supertabpanel_weather_location', '')

function! s:setup_colors() abort
  hi default SuperTabPanelWxHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelWxTemp guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelWx     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
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
    let s:data = json_decode(join(s:buf, ''))
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#weather#fetch(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let url = 'https://wttr.in/' .. s:location .. '?format=j1'
  let s:job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
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

function! supertabpanel#widgets#weather#render() abort
  let result = '%#SuperTabPanelWxHead#  ☁️ Weather%@'
  if empty(s:data) || !has_key(s:data, 'current_condition')
    return result .. '%#SuperTabPanelWx#  fetching...%@'
  endif
  let cur = s:data.current_condition[0]
  let code = cur.weatherCode
  let icon = s:icon(code)
  let temp = cur.temp_C
  let desc = supertabpanel#truncate(cur.weatherDesc[0].value, supertabpanel#content_width(12))
  let result ..= '%#SuperTabPanelWxTemp#  ' .. icon .. ' ' .. temp .. '°C%@'
  let result ..= '%#SuperTabPanelWx#  ' .. desc .. '%@'
  if has_key(s:data, 'nearest_area')
    let area = s:data.nearest_area[0].areaName[0].value
    let result ..= '%#SuperTabPanelWx#  📍 ' .. area .. '%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#weather#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#weather#fetch(0)
    let s:timer = timer_start(1800000,
          \ function('supertabpanel#widgets#weather#fetch'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#weather#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#weather#init() abort
  call s:setup_colors()
  augroup supertabpanel_wx_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('weather', #{
        \ icon: '☁️',
        \ label: 'Weather',
        \ render: function('supertabpanel#widgets#weather#render'),
        \ on_activate: function('supertabpanel#widgets#weather#activate'),
        \ on_deactivate: function('supertabpanel#widgets#weather#deactivate'),
        \ })
endfunction
