" vim-supertabpanel : world clock widget
"
" Instance params:
"   zones : list of #{ label: 'Tokyo', tz: 'Asia/Tokyo' }.
"           Defaults to Tokyo / London / NYC / SF.

let s:instances = []
let s:colors_ready = 0

function! s:default_zones() abort
  return [
        \ #{ label: 'Tokyo',  tz: 'Asia/Tokyo'       },
        \ #{ label: 'London', tz: 'Europe/London'    },
        \ #{ label: 'NYC',    tz: 'America/New_York' },
        \ #{ label: 'SF',     tz: 'America/Los_Angeles' },
        \ ]
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelWcHead  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelWcLabel guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelWcTime  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! s:refresh(id, timer) abort
  let inst = s:instances[a:id]
  let had = exists('$TZ')
  let save = $TZ
  try
    for z in inst.zones
      let $TZ = z.tz
      let inst.cache[z.tz] = strftime('%H:%M %a')
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

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelWcHead#  🌍 World Clock%@'
  for z in inst.zones
    let t = get(inst.cache, z.tz, '--:--')
    let label = printf('%-7s', z.label)
    let result ..= '%#SuperTabPanelWcLabel#  ' .. label
          \ .. '%#SuperTabPanelWcTime#' .. t .. '%@'
  endfor
  return result
endfunction

function! s:activate(id) abort
  let inst = s:instances[a:id]
  if inst.timer == -1
    call s:refresh(a:id, 0)
    let inst.timer = timer_start(60000,
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

function! supertabpanel#widgets#worldclock#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_wc_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ zones: get(a:params, 'zones', s:default_zones()),
        \ cache: {},
        \ timer: -1,
        \ })
  return #{
        \ icon: '🌍',
        \ label: 'World Clock',
        \ render: function('s:render', [id]),
        \ on_activate: function('s:activate', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
