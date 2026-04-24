" vim-supertabpanel : BTC chart widget

let s:prices = []
let s:currency = 'usd'
let s:job = v:null
let s:fetch_buf = []
let s:timer = -1
let s:chart_cache = []
let s:chart_cache_w = -1
let s:chart_cache_gen = -1
let s:prices_gen = 0

function! s:setup_colors() abort
  hi default SuperTabPanelBtcLabel guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelBtcUp    guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelBtcDown  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
  hi default SuperTabPanelBtcText  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelBtcChart0 guifg=#1e3a5f guibg=#1a1b26 ctermfg=23  ctermbg=234
  hi default SuperTabPanelBtcChart1 guifg=#1e5a8f guibg=#1a1b26 ctermfg=25  ctermbg=234
  hi default SuperTabPanelBtcChart2 guifg=#2a7ab5 guibg=#1a1b26 ctermfg=32  ctermbg=234
  hi default SuperTabPanelBtcChart3 guifg=#3d94cf guibg=#1a1b26 ctermfg=74  ctermbg=234
  hi default SuperTabPanelBtcChart4 guifg=#5aafe0 guibg=#1a1b26 ctermfg=75  ctermbg=234
  hi default SuperTabPanelBtcChart5 guifg=#7dcfff guibg=#1a1b26 ctermfg=117 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:fetch_buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0
    return
  endif
  try
    let data = json_decode(join(s:fetch_buf, ''))
    if has_key(data, 'prices')
      let s:prices = data.prices
      let s:prices_gen += 1
      redrawtabpanel
    endif
  catch
  endtry
endfunction

function! supertabpanel#widgets#btcchart#fetch(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:fetch_buf = []
  let url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency='
        \ .. s:currency .. '&days=1&interval=hourly'
  let s:job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#btcchart#toggle_currency(info) abort
  let s:currency = s:currency ==# 'usd' ? 'jpy' : 'usd'
  let s:prices = []
  let s:prices_gen += 1
  redrawtabpanel
  call supertabpanel#widgets#btcchart#fetch(0)
  return 1
endfunction

function! s:draw_chart(prices, width, height) abort
  if len(a:prices) == 0
    return repeat([''], a:height)
  endif
  let values = map(copy(a:prices), 'v:val[1]')
  let vmin = min(map(copy(values), 'float2nr(v:val)'))
  let vmax = max(map(copy(values), 'float2nr(v:val)'))
  if vmax == vmin
    let vmax = vmin + 1
  endif
  let sampled = []
  for i in range(a:width)
    let idx = i * (len(values) - 1) / max([a:width - 1, 1])
    call add(sampled, float2nr(values[idx]))
  endfor
  let blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
  let lines = []
  for row in range(a:height - 1, 0, -1)
    let line = ''
    for col in range(a:width)
      let v = sampled[col]
      let normalized = (v - vmin) * (a:height * 8 - 1) / (vmax - vmin)
      let row_base = row * 8
      if normalized >= row_base + 8
        let line ..= '█'
      elseif normalized >= row_base
        let line ..= blocks[normalized - row_base]
      else
        let line ..= ' '
      endif
    endfor
    call add(lines, line)
  endfor
  return lines
endfunction

function! supertabpanel#widgets#btcchart#render() abort
  let result = ''
  if len(s:prices) == 0
    let result ..= '%0[supertabpanel#widgets#btcchart#toggle_currency]'
          \ .. '%#SuperTabPanelBtcText#  BTC  fetching...%[]%@'
    return result
  endif
  let current = s:prices[-1][1]
  let prev = s:prices[0][1]
  let diff = current - prev
  let pct = diff / prev * 100.0
  let is_up = diff >= 0
  let sign = is_up ? '+' : ''
  let arrow = is_up ? ' ▲' : ' ▼'
  let price_str = substitute(printf('%.0f', current),
        \ '\d\zs\(\(\d\{3}\)\+\)$', ',&', '')
  let sym = s:currency ==# 'jpy' ? '¥' : '$'
  let hl_change = is_up ? '%#SuperTabPanelBtcUp#' : '%#SuperTabPanelBtcDown#'
  let pct_str = printf('%.1f', pct)
  let price_line = '%#SuperTabPanelBtcText#  %#SuperTabPanelBtcLabel#₿ BTC  '
        \ .. '%#SuperTabPanelBtcText#' .. sym .. price_str .. ' '
        \ .. hl_change .. sign .. pct_str .. '%%' .. arrow
  let result ..= '%0[supertabpanel#widgets#btcchart#toggle_currency]'
        \ .. price_line .. '%[]%@'

  let chart_height = 6
  let chart_w = supertabpanel#content_width(5)
  if s:chart_cache_gen == s:prices_gen && s:chart_cache_w == chart_w
    let chart = s:chart_cache
  else
    let chart = s:draw_chart(s:prices, chart_w, chart_height)
    let s:chart_cache = chart
    let s:chart_cache_gen = s:prices_gen
    let s:chart_cache_w = chart_w
  endif
  let row = 0
  for c in chart
    let grad = (chart_height - 1) - row
    let hl = '%#SuperTabPanelBtcChart' .. grad .. '#'
    let result ..= '%0[supertabpanel#widgets#btcchart#toggle_currency]'
          \ .. hl .. '  ' .. c .. '%[]%@'
    let row += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#btcchart#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#btcchart#fetch(0)
    let s:timer = timer_start(300000,
          \ function('supertabpanel#widgets#btcchart#fetch'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#btcchart#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#btcchart#init() abort
  call s:setup_colors()
  augroup supertabpanel_btcchart_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('btcchart', #{
        \ icon: '₿',
        \ label: 'BTC',
        \ render: function('supertabpanel#widgets#btcchart#render'),
        \ on_activate: function('supertabpanel#widgets#btcchart#activate'),
        \ on_deactivate: function('supertabpanel#widgets#btcchart#deactivate'),
        \ })
endfunction
