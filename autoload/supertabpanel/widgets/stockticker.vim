" vim-supertabpanel : stock ticker widget (Yahoo Finance quote API)

let s:timer = -1
let s:symbols = get(g:, 'supertabpanel_stocks',
      \ ['^N225', '^GSPC', '^IXIC', 'USDJPY=X'])
let s:quotes = {}
let s:pending = {}

function! s:setup_colors() abort
  hi default SuperTabPanelStkHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelStkSym  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelStk     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelStkUp   guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelStkDown guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
endfunction

function! s:on_chunk(sym, ch, msg) abort
  if !has_key(s:pending, a:sym)
    let s:pending[a:sym] = []
  endif
  call add(s:pending[a:sym], a:msg)
endfunction

function! s:on_done(sym, job, status) abort
  if a:status != 0 || !has_key(s:pending, a:sym)
    return
  endif
  try
    let d = json_decode(join(s:pending[a:sym], ''))
    let r = d.chart.result[0]
    let cur = r.meta.regularMarketPrice
    let prev = r.meta.chartPreviousClose
    let s:quotes[a:sym] = #{ cur: cur, prev: prev }
  catch
  endtry
  unlet s:pending[a:sym]
  redrawtabpanel
endfunction

function! supertabpanel#widgets#stockticker#refresh(timer) abort
  for sym in s:symbols
    let url = 'https://query1.finance.yahoo.com/v8/finance/chart/'
          \ .. sym .. '?interval=1d&range=5d'
    call job_start(['curl', '-sL',
          \ '-H', 'User-Agent: Mozilla/5.0',
          \ url], #{
          \ out_cb: function('s:on_chunk', [sym]),
          \ exit_cb: function('s:on_done', [sym]),
          \ mode: 'raw',
          \ })
  endfor
endfunction

function! supertabpanel#widgets#stockticker#render() abort
  let result = '%#SuperTabPanelStkHead#  📈 Markets%@'
  for sym in s:symbols
    let q = get(s:quotes, sym, {})
    if empty(q)
      let result ..= '%#SuperTabPanelStk#  ' .. sym .. '  ...%@'
      continue
    endif
    let diff = q.cur - q.prev
    let pct = q.prev == 0 ? 0 : diff / q.prev * 100.0
    let hl = diff >= 0 ? '%#SuperTabPanelStkUp#' : '%#SuperTabPanelStkDown#'
    let arrow = diff >= 0 ? '▲' : '▼'
    let label = printf('%-9s', sym)
    let price = printf('%7.2f', q.cur)
    let pct_s = printf('%+5.2f%%%%', pct)
    let result ..= '%#SuperTabPanelStkSym#  ' .. label
          \ .. '%#SuperTabPanelStk#' .. price .. ' '
          \ .. hl .. arrow .. pct_s .. '%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#stockticker#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#stockticker#refresh(0)
    let s:timer = timer_start(120000,
          \ function('supertabpanel#widgets#stockticker#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#stockticker#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#stockticker#init() abort
  call s:setup_colors()
  augroup supertabpanel_stk_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('stockticker', #{
        \ icon: '📈',
        \ label: 'Markets',
        \ render: function('supertabpanel#widgets#stockticker#render'),
        \ on_activate: function('supertabpanel#widgets#stockticker#activate'),
        \ on_deactivate: function('supertabpanel#widgets#stockticker#deactivate'),
        \ })
endfunction
