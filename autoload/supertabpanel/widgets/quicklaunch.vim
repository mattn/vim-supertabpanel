" vim-supertabpanel : quick launch widget
"
" Instance params:
"   items : list of #{ icon, label, cmd } entries.  Clicking a row runs `cmd`
"           via :execute.  Defaults to Make / Test / Format.

let s:instances = []
let s:colors_ready = 0

function! s:default_items() abort
  return [
        \ #{ icon: '🔨', label: 'Make',   cmd: 'make'    },
        \ #{ icon: '🧪', label: 'Test',   cmd: '!make test' },
        \ #{ icon: '🎯', label: 'Format', cmd: 'Format'  },
        \ ]
endfunction

function! s:setup_colors() abort
  hi default SuperTabPanelQlHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelQl     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

" minwid encodes id*1000 + idx.
function! supertabpanel#widgets#quicklaunch#run(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx >= 0 && idx < len(inst.items)
    let cmd = inst.items[idx].cmd
    try
      execute cmd
    catch
      echohl ErrorMsg | echom 'quicklaunch: ' .. v:exception | echohl None
    endtry
  endif
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelQlHead#  🚀 Quick Launch%@'
  let idx = 0
  for item in inst.items
    let icon = get(item, 'icon', '▶')
    let label = get(item, 'label', get(item, 'cmd', ''))
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#quicklaunch#run]'
          \ .. '%#SuperTabPanelQl#  ' .. icon .. ' ' .. label .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#quicklaunch#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_ql_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ items: get(a:params, 'items', s:default_items()),
        \ })
  return #{
        \ icon: '🚀',
        \ label: 'Quick Launch',
        \ render: function('s:render', [id]),
        \ }
endfunction
