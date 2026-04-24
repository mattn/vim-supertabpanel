" vim-supertabpanel : clock widget

let s:timer = -1

function! s:setup_colors() abort
  hi default SuperTabPanelClock guifg=#7aa2f7 guibg=#1a1b26 ctermfg=111 ctermbg=234
endfunction

function! supertabpanel#widgets#clock#render() abort
  return '%#SuperTabPanelClock#   ' .. strftime('%Y-%m-%d  %H:%M') .. '%@'
endfunction

function! supertabpanel#widgets#clock#activate() abort
  if s:timer == -1
    let s:timer = timer_start(60000,
          \ {-> execute('redrawtabpanel')}, #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#clock#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#clock#init() abort
  call s:setup_colors()
  augroup supertabpanel_clock_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('clock', #{
        \ icon: '🕐',
        \ label: 'Clock',
        \ render: function('supertabpanel#widgets#clock#render'),
        \ on_activate: function('supertabpanel#widgets#clock#activate'),
        \ on_deactivate: function('supertabpanel#widgets#clock#deactivate'),
        \ })
endfunction
