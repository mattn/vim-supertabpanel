" vim-supertabpanel : colorscheme selector widget

let s:cached = []

function! s:setup_colors() abort
  hi default SuperTabPanelCsHead    guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelCs        guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelCsCurrent guifg=#9ece6a guibg=#1a1b26 gui=bold cterm=bold ctermfg=149 ctermbg=234
endfunction

function! s:refresh() abort
  let s:cached = getcompletion('', 'color')
endfunction

function! supertabpanel#widgets#colorscheme#apply(info) abort
  if supertabpanel#is_repeat_click(a:info) | return 1 | endif
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:cached)
    call supertabpanel#flash('colorscheme', idx)
    execute 'colorscheme ' .. fnameescape(s:cached[idx])
  endif
  return 1
endfunction

function! supertabpanel#widgets#colorscheme#render() abort
  let result = '%#SuperTabPanelCsHead#  🎨 Colorscheme%@'
  let current = get(g:, 'colors_name', '')
  let idx = 0
  for name in s:cached
    let is_current = name ==# current
    let label = supertabpanel#truncate(name, supertabpanel#content_width(4))
    let label = substitute(label, '%', '%%', 'g')
    let default_hl = is_current
          \ ? '%#SuperTabPanelCsCurrent#'
          \ : '%#SuperTabPanelCs#'
    let hl = supertabpanel#flash_hl('colorscheme', idx, default_hl)
    let mark = is_current ? '✓ ' : '  '
    let result ..= '%' .. idx .. '[supertabpanel#widgets#colorscheme#apply]'
          \ .. hl .. '  ' .. mark .. label .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#colorscheme#activate() abort
  call s:refresh()
endfunction

function! supertabpanel#widgets#colorscheme#deactivate() abort
endfunction

function! supertabpanel#widgets#colorscheme#init() abort
  call s:setup_colors()
  augroup supertabpanel_colorscheme_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('colorscheme', #{
        \ icon: '🎨',
        \ label: 'Colorscheme',
        \ render: function('supertabpanel#widgets#colorscheme#render'),
        \ on_activate: function('supertabpanel#widgets#colorscheme#activate'),
        \ on_deactivate: function('supertabpanel#widgets#colorscheme#deactivate'),
        \ })
endfunction
