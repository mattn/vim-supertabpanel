" vim-supertabpanel : stock ticker widget (Yahoo Finance quote API)
"
" Instance params:
"   symbols : list of Yahoo ticker symbols (default Nikkei/S&P/NASDAQ/USDJPY)

let s:instances = []
let s:colors_ready = 0

function! s:default_symbols() abort
  return ['^N225', '^GSPC', '^IXIC', 'USDJPY=X']
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelStkHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelStkSym  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelStk     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelStkUp   guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelStkDown guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
endfunction

function! s:on_chunk(id, sym, ch, msg) abort
  let inst = s:instances[a:id]
  if !has_key(inst.pending, a:sym)
    let inst.pending[a:sym] = []
  endif
  call add(inst.pending[a:sym], a:msg)
endfunction

function! s:on_done(id, sym, job, status) abort
  let inst = s:instances[a:id]
  if a:status != 0 || !has_key(inst.pending, a:sym)
    return
  endif
  try
    let d = json_decode(join(inst.pending[a:sym], ''))
    let r = d.chart.result[0]
    let cur = r.meta.regularMarketPrice
    let prev = r.meta.chartPreviousClose
    let inst.quotes[a:sym] = #{ cur: cur, prev: prev }
  catch
  endtry
  unlet inst.pending[a:sym]
  redrawtabpanel
endfunction

function! s:refresh(id, timer) abort
  let inst = s:instances[a:id]
  for sym in inst.symbols
    let url = 'https://query1.finance.yahoo.com/v8/finance/chart/'
          \ .. sym .. '?interval=1d&range=5d'
    call job_start(['curl', '-sL',
          \ '-H', 'User-Agent: Mozilla/5.0',
          \ url], #{
          \ out_cb: function('s:on_chunk', [a:id, sym]),
          \ exit_cb: function('s:on_done', [a:id, sym]),
          \ mode: 'raw',
          \ })
  endfor
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelStkHead#  📈 Markets%@'
  for sym in inst.symbols
    let q = get(inst.quotes, sym, {})
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

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:refresh(a:id, 0)
    let inst.timer = timer_start(120000,
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

function! supertabpanel#widgets#stockticker#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_stk_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ symbols: get(a:params, 'symbols', s:default_symbols()),
        \ quotes: {},
        \ pending: {},
        \ timer: -1,
        \ })
  return #{
        \ icon: '📈',
        \ label: 'Markets',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
