" vim-supertabpanel : buffer list widget

function! s:setup_colors() abort
  hi default SuperTabPanelBufHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelBuf     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelBufCur  guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelBufMod  guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
endfunction

function! supertabpanel#widgets#buffers#goto(info) abort
  let nr = a:info.minwid
  if bufexists(nr)
    execute 'buffer ' .. nr
    redrawtabpanel
  endif
  return 1
endfunction

function! supertabpanel#widgets#buffers#render() abort
  let result = '%#SuperTabPanelBufHead#  📚 Buffers%@'
  let bufs = getbufinfo(#{ buflisted: 1 })
  let cur = bufnr('%')
  for b in bufs
    let name = fnamemodify(bufname(b.bufnr), ':t')
    if name ==# ''
      let name = '[No Name]'
    endif
    let name = supertabpanel#truncate(name, supertabpanel#content_width(6))
    let name = substitute(name, '%', '%%', 'g')
    if b.bufnr == cur
      let hl = '%#SuperTabPanelBufCur#'
    elseif b.changed
      let hl = '%#SuperTabPanelBufMod#'
    else
      let hl = '%#SuperTabPanelBuf#'
    endif
    let mark = b.changed ? ' ●' : ''
    let result ..= '%' .. b.bufnr .. '[supertabpanel#widgets#buffers#goto]'
          \ .. hl .. '  ' .. name .. mark .. '%[]%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#buffers#activate() abort
  augroup supertabpanel_buffers
    autocmd!
    autocmd BufEnter,BufDelete,BufWritePost *
          \ if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#buffers#deactivate() abort
  augroup supertabpanel_buffers
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#buffers#init() abort
  call s:setup_colors()
  augroup supertabpanel_buffers_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('buffers', #{
        \ icon: '📚',
        \ label: 'Buffers',
        \ render: function('supertabpanel#widgets#buffers#render'),
        \ on_activate: function('supertabpanel#widgets#buffers#activate'),
        \ on_deactivate: function('supertabpanel#widgets#buffers#deactivate'),
        \ })
endfunction
