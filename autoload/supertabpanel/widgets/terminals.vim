" vim-supertabpanel : terminal buffer list widget

function! s:setup_colors() abort
  hi default SuperTabPanelTermHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTerm     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTermRun  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelTermDead guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
endfunction

function! supertabpanel#widgets#terminals#goto(info) abort
  let nr = a:info.minwid
  if bufexists(nr)
    execute 'buffer ' .. nr
  endif
  return 1
endfunction

function! supertabpanel#widgets#terminals#render() abort
  let result = '%#SuperTabPanelTermHead#  💻 Terminals%@'
  let any = 0
  for b in getbufinfo()
    if getbufvar(b.bufnr, '&buftype') !=# 'terminal'
      continue
    endif
    let any = 1
    let status = term_getstatus(b.bufnr)
    let running = status =~# 'running'
    let name = fnamemodify(bufname(b.bufnr), ':t')
    if name ==# '' | let name = '[term]' | endif
    let name = supertabpanel#truncate(name, supertabpanel#content_width(8))
    let name = substitute(name, '%', '%%', 'g')
    let icon = running ? '▶' : '■'
    let hl = running ? '%#SuperTabPanelTermRun#' : '%#SuperTabPanelTermDead#'
    let result ..= '%' .. b.bufnr .. '[supertabpanel#widgets#terminals#goto]'
          \ .. hl .. '  ' .. icon .. ' ' .. name .. '%[]%@'
  endfor
  if !any
    let result ..= '%#SuperTabPanelTerm#  (no terminals)%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#terminals#activate() abort
  augroup supertabpanel_terminals
    autocmd!
    autocmd BufEnter,BufDelete,TerminalOpen *
          \ if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#terminals#deactivate() abort
  augroup supertabpanel_terminals
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#terminals#init() abort
  call s:setup_colors()
  augroup supertabpanel_term_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('terminals', #{
        \ icon: '💻',
        \ label: 'Terminals',
        \ render: function('supertabpanel#widgets#terminals#render'),
        \ on_activate: function('supertabpanel#widgets#terminals#activate'),
        \ on_deactivate: function('supertabpanel#widgets#terminals#deactivate'),
        \ })
endfunction
