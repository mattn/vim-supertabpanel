" vim-supertabpanel : undo tree widget

function! s:setup_colors() abort
  hi default SuperTabPanelUdHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelUd     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelUdCur  guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
endfunction

function! supertabpanel#widgets#undo#goto(info) abort
  let num = a:info.minwid
  if num > 0
    execute 'undo ' .. num
  endif
  return 1
endfunction

function! s:walk(entries, depth, out) abort
  for e in a:entries
    call add(a:out, #{
          \ seq: e.seq,
          \ time: e.time,
          \ depth: a:depth,
          \ })
    if has_key(e, 'alt')
      call s:walk(e.alt, a:depth + 1, a:out)
    endif
  endfor
endfunction

function! supertabpanel#widgets#undo#render() abort
  let tree = undotree()
  let result = '%#SuperTabPanelUdHead#  ↶ Undo%@'
  if empty(tree.entries)
    return result .. '%#SuperTabPanelUd#  (no changes)%@'
  endif
  let nodes = []
  call s:walk(tree.entries, 0, nodes)
  let cur = tree.seq_cur
  let start = max([0, len(nodes) - 15])
  for n in nodes[start:]
    let indent = repeat('  ', n.depth)
    let tdiff = localtime() - n.time
    let ago = tdiff < 60 ? tdiff . 's'
          \ : tdiff < 3600 ? (tdiff / 60) . 'm'
          \ : (tdiff / 3600) . 'h'
    let hl = n.seq == cur ? '%#SuperTabPanelUdCur#' : '%#SuperTabPanelUd#'
    let mark = n.seq == cur ? '▶ ' : '  '
    let result ..= '%' .. n.seq .. '[supertabpanel#widgets#undo#goto]'
          \ .. hl .. mark .. indent .. '#' .. n.seq .. ' ' .. ago .. '%[]%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#undo#activate() abort
  augroup supertabpanel_ud
    autocmd!
    autocmd TextChanged,TextChangedI *
          \ if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#undo#deactivate() abort
  augroup supertabpanel_ud
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#undo#init() abort
  call s:setup_colors()
  augroup supertabpanel_ud_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('undo', #{
        \ icon: '↶',
        \ label: 'Undo',
        \ render: function('supertabpanel#widgets#undo#render'),
        \ on_activate: function('supertabpanel#widgets#undo#activate'),
        \ on_deactivate: function('supertabpanel#widgets#undo#deactivate'),
        \ })
endfunction
