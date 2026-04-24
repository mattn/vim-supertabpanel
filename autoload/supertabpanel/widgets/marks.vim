" vim-supertabpanel : marks widget

function! s:setup_colors() abort
  hi default SuperTabPanelMarksHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelMarkName  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
  hi default SuperTabPanelMarkLoc   guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
endfunction

let s:marks = []

function! s:refresh() abort
  let s:marks = []
  for m in getmarklist()
    let name = m.mark[1:]
    if name =~# '^[a-zA-Z0-9]$'
      let file = fnamemodify(bufname(m.pos[0]), ':t')
      if file ==# ''
        let file = '[No Name]'
      endif
      call add(s:marks, #{
            \ name: name, file: file, lnum: m.pos[1], bufnr: m.pos[0],
            \ })
    endif
  endfor
endfunction

function! supertabpanel#widgets#marks#jump(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:marks)
    execute 'normal! `' .. s:marks[idx].name
  endif
  return 1
endfunction

function! supertabpanel#widgets#marks#render() abort
  call s:refresh()
  let result = '%#SuperTabPanelMarksHead#  🔖 Marks%@'
  let idx = 0
  for m in s:marks
    let name = supertabpanel#truncate(m.file, supertabpanel#content_width(10))
    let name = substitute(name, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#marks#jump]'
          \ .. '%#SuperTabPanelMarkName#  ' .. m.name .. ' '
          \ .. '%#SuperTabPanelMarkLoc#' .. name
          \ .. ':' .. m.lnum .. '%[]%@'
    let idx += 1
  endfor
  return result
endfunction

function! supertabpanel#widgets#marks#init() abort
  call s:setup_colors()
  augroup supertabpanel_marks_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('marks', #{
        \ icon: '🔖',
        \ label: 'Marks',
        \ render: function('supertabpanel#widgets#marks#render'),
        \ })
endfunction
