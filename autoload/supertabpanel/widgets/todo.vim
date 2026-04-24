" vim-supertabpanel : TODO widget

let s:file = get(g:, 'supertabpanel_todo_file', expand('~/.vim-supertabpanel-todo.json'))
let s:todos = []

function! s:setup_colors() abort
  hi default SuperTabPanelTodoHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTodoOpen guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelTodoDone guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
  hi default SuperTabPanelTodoAdd  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
endfunction

function! s:load() abort
  if filereadable(s:file)
    try
      let s:todos = json_decode(join(readfile(s:file), ''))
    catch
      let s:todos = []
    endtry
  endif
endfunction

function! s:save() abort
  call writefile([json_encode(s:todos)], s:file)
endfunction

function! supertabpanel#widgets#todo#toggle(info) abort
  let idx = a:info.minwid
  if idx >= 0 && idx < len(s:todos)
    let s:todos[idx].done = !get(s:todos[idx], 'done', 0)
    call s:save()
    redrawtabpanel
  endif
  return 1
endfunction

function! supertabpanel#widgets#todo#add(info) abort
  call popup_create('', #{
        \ title: ' Add TODO ',
        \ border: [],
        \ padding: [0, 1, 0, 1],
        \ minwidth: 40,
        \ filter: function('s:add_filter'),
        \ callback: function('s:add_done'),
        \ })
  return 1
endfunction

let s:add_text = ''
function! s:add_filter(id, key) abort
  if a:key ==# "\<CR>"
    call popup_close(a:id, s:add_text)
    return 1
  elseif a:key ==# "\<Esc>"
    call popup_close(a:id, '')
    return 1
  elseif a:key ==# "\<BS>"
    let s:add_text = strcharpart(s:add_text, 0, strchars(s:add_text) - 1)
  elseif strlen(a:key) > 0 && a:key !~# '^\x'
    let s:add_text ..= a:key
  endif
  call popup_settext(a:id, s:add_text)
  return 1
endfunction

function! s:add_done(id, result) abort
  if type(a:result) == v:t_string && a:result !=# ''
    call add(s:todos, #{ text: a:result, done: 0 })
    call s:save()
    redrawtabpanel
  endif
  let s:add_text = ''
endfunction

function! supertabpanel#widgets#todo#remove_done(info) abort
  call filter(s:todos, '!get(v:val, "done", 0)')
  call s:save()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#todo#render() abort
  let result = '%#SuperTabPanelTodoHead#  ✅ TODO%@'
  let idx = 0
  for t in s:todos
    let mark = get(t, 'done', 0) ? '☑' : '☐'
    let hl = get(t, 'done', 0) ? '%#SuperTabPanelTodoDone#' : '%#SuperTabPanelTodoOpen#'
    let text = supertabpanel#truncate(get(t, 'text', ''), supertabpanel#content_width(8))
    let text = substitute(text, '%', '%%', 'g')
    let result ..= '%' .. idx .. '[supertabpanel#widgets#todo#toggle]'
          \ .. hl .. '  ' .. mark .. ' ' .. text .. '%[]%@'
    let idx += 1
  endfor
  let result ..= '%0[supertabpanel#widgets#todo#add]'
        \ .. '%#SuperTabPanelTodoAdd#  + add%[]%@'
  let result ..= '%0[supertabpanel#widgets#todo#remove_done]'
        \ .. '%#SuperTabPanelTodoDone#  × clear done%[]%@'
  return result
endfunction

function! supertabpanel#widgets#todo#init() abort
  call s:setup_colors()
  augroup supertabpanel_todo_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call s:load()
  call supertabpanel#register('todo', #{
        \ icon: '✅',
        \ label: 'TODO',
        \ render: function('supertabpanel#widgets#todo#render'),
        \ })
endfunction
