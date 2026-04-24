" vim-supertabpanel : moon phase widget

let s:timer = -1

function! s:setup_colors() abort
  hi default SuperTabPanelMoonHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelMoon     guifg=#c0caf5 guibg=#1a1b26 ctermfg=153 ctermbg=234
  hi default SuperTabPanelMoonSub  guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
endfunction

" Conway's 1978 approximation.
function! s:phase(y, m, d) abort
  let y = a:y
  let m = a:m
  if m < 3
    let y -= 1
    let m += 12
  endif
  let r = y % 100
  let r = r % 19
  if r > 9
    let r -= 19
  endif
  let r = ((r * 11) % 30) + m + a:d
  if m < 3
    let r += 2
  endif
  let r -= a:y < 2000 ? 4 : 8.3
  let r = r + 0.0
  while r < 0
    let r += 30
  endwhile
  let r = floor(r + 0.5)
  let r = fmod(r, 30)
  return float2nr(r)
endfunction

function! s:phase_info(age) abort
  let phases = [
        \ #{ icon: '🌑', name: 'New Moon'        },
        \ #{ icon: '🌒', name: 'Waxing Crescent' },
        \ #{ icon: '🌓', name: 'First Quarter'   },
        \ #{ icon: '🌔', name: 'Waxing Gibbous'  },
        \ #{ icon: '🌕', name: 'Full Moon'       },
        \ #{ icon: '🌖', name: 'Waning Gibbous'  },
        \ #{ icon: '🌗', name: 'Last Quarter'    },
        \ #{ icon: '🌘', name: 'Waning Crescent' },
        \ ]
  let idx = float2nr(floor((a:age + 0.0) / 29.53 * 8)) % 8
  return phases[idx]
endfunction

function! supertabpanel#widgets#moonphase#render() abort
  let y = str2nr(strftime('%Y'))
  let m = str2nr(strftime('%m'))
  let d = str2nr(strftime('%d'))
  let age = s:phase(y, m, d)
  let p = s:phase_info(age)
  let result = '%#SuperTabPanelMoonHead#  🌙 Moon%@'
  let result ..= '%#SuperTabPanelMoon#      ' .. p.icon .. '%@'
  let result ..= '%#SuperTabPanelMoonSub#   ' .. p.name .. '%@'
  let result ..= '%#SuperTabPanelMoonSub#   age: ' .. age .. 'd%@'
  return result
endfunction

function! supertabpanel#widgets#moonphase#activate() abort
  if s:timer == -1
    let s:timer = timer_start(3600000,
          \ {-> execute('redrawtabpanel')}, #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#moonphase#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#moonphase#init() abort
  call s:setup_colors()
  augroup supertabpanel_moon_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('moonphase', #{
        \ icon: '🌙',
        \ label: 'Moon',
        \ render: function('supertabpanel#widgets#moonphase#render'),
        \ on_activate: function('supertabpanel#widgets#moonphase#activate'),
        \ on_deactivate: function('supertabpanel#widgets#moonphase#deactivate'),
        \ })
endfunction
