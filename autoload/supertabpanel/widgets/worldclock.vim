" vim-supertabpanel : world clock widget

let s:timer = -1
let s:zones = get(g:, 'supertabpanel_worldclock_zones', [
      \ #{ label: 'Tokyo',  tz: 'Asia/Tokyo'       },
      \ #{ label: 'London', tz: 'Europe/London'    },
      \ #{ label: 'NYC',    tz: 'America/New_York' },
      \ #{ label: 'SF',     tz: 'America/Los_Angeles' },
      \ ])
let s:cache = {}

function! s:setup_colors() abort
  hi default SuperTabPanelWcHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelWcLabel guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelWcTime  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:refresh(timer) abort
  let had = exists('$TZ')
  let save = $TZ
  try
    for z in s:zones
      let $TZ = z.tz
      let s:cache[z.tz] = strftime('%H:%M %a')
    endfor
  finally
    if had
      let $TZ = save
    else
      unlet $TZ
    endif
  endtry
  redrawtabpanel
endfunction

function! supertabpanel#widgets#worldclock#render() abort
  let result = '%#SuperTabPanelWcHead#  🌍 World Clock%@'
  for z in s:zones
    let t = get(s:cache, z.tz, '--:--')
    let label = printf('%-7s', z.label)
    let result ..= '%#SuperTabPanelWcLabel#  ' .. label
          \ .. '%#SuperTabPanelWcTime#' .. t .. '%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#worldclock#activate() abort
  if s:timer == -1
    call s:refresh(0)
    let s:timer = timer_start(60000,
          \ function('s:refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#worldclock#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#worldclock#init() abort
  call s:setup_colors()
  augroup supertabpanel_wc_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('worldclock', #{
        \ icon: '🌍',
        \ label: 'World Clock',
        \ render: function('supertabpanel#widgets#worldclock#render'),
        \ on_activate: function('supertabpanel#widgets#worldclock#activate'),
        \ on_deactivate: function('supertabpanel#widgets#worldclock#deactivate'),
        \ })
endfunction
