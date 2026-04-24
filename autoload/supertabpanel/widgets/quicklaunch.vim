" vim-supertabpanel : quick launch widget

let g:supertabpanel_quicklaunch = get(g:, 'supertabpanel_quicklaunch', [
      \ #{ icon: '🔨', label: 'Make',   cmd: 'make'    },
      \ #{ icon: '🧪', label: 'Test',   cmd: '!make test' },
      \ #{ icon: '🎯', label: 'Format', cmd: 'Format'  },
      \ ])

function! s:setup_colors() abort
  hi default SuperTabPanelQlHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelQl     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

function! supertabpanel#widgets#quicklaunch#run(info) abort
  let idx = a:info.minwid
  let items = g:supertabpanel_quicklaunch
  if idx >= 0 && idx < len(items)
    let cmd = items[idx].cmd
    try
      execute cmd
    catch
      echohl ErrorMsg | echom 'quicklaunch: ' .. v:exception | echohl None
    endtry
  endif
  return 1
endfunction

function! supertabpanel#widgets#quicklaunch#render() abort
  let result = '%#SuperTabPanelQlHead#  🚀 Quick Launch%@'
  let idx = 0
  for item in g:supertabpanel_quicklaunch
    let icon = get(item, 'icon', '▶')
    let label = get(item, 'label', item.cmd)
    let result ..= '%' .. idx .. '[supertabpanel#widgets#quicklaunch#run]'
          \ .. '%#SuperTabPanelQl#  ' .. icon .. ' ' .. label .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#quicklaunch#init() abort
  call s:setup_colors()
  augroup supertabpanel_ql_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('quicklaunch', #{
        \ icon: '🚀',
        \ label: 'Quick Launch',
        \ render: function('supertabpanel#widgets#quicklaunch#render'),
        \ })
endfunction
