" vim-supertabpanel : TODO widget
"
" Instance params:
"   file : path of JSON file that stores the TODOs
"          (default '~/.vim-supertabpanel-todo.json')

let s:instances = []
let s:colors_ready = 0
let s:add_text = ''
let s:add_owner = -1

function! s:setup_colors() abort
  hi default SuperTabPanelTodoHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTodoOpen guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelTodoDone guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
  hi default SuperTabPanelTodoAdd  guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
endfunction

function! s:load(id) abort
  let inst = s:instances[a:id]
  if filereadable(inst.file)
    try
      let inst.todos = json_decode(join(readfile(inst.file), ''))
    catch
      let inst.todos = []
    endtry
  endif
endfunction

function! s:save(id) abort
  let inst = s:instances[a:id]
  call writefile([json_encode(inst.todos)], inst.file)
endfunction

" minwid encodes id*1000 + (idx+1) for items, or -id-1 for add, -(id+1)*2
" would conflict.  Easier: use separate click functions for buttons.
function! supertabpanel#widgets#todo#toggle(info) abort
  let code = a:info.minwid
  let id = code / 1000
  let idx = code % 1000
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if idx >= 0 && idx < len(inst.todos)
    let inst.todos[idx].done = !get(inst.todos[idx], 'done', 0)
    call s:save(id)
    redrawtabpanel
  endif
  return 1
endfunction

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
        \ && s:add_owner >= 0 && s:add_owner < len(s:instances)
    let inst = s:instances[s:add_owner]
    call add(inst.todos, #{ text: a:result, done: 0 })
    call s:save(s:add_owner)
    redrawtabpanel
  endif
  let s:add_text = ''
  let s:add_owner = -1
endfunction

function! supertabpanel#widgets#todo#add(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let s:add_text = ''
  let s:add_owner = id
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

function! supertabpanel#widgets#todo#remove_done(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  call filter(inst.todos, '!get(v:val, "done", 0)')
  call s:save(id)
  redrawtabpanel
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelTodoHead#  ✅ TODO%@'
  let idx = 0
  for t in inst.todos
    let mark = get(t, 'done', 0) ? '☑' : '☐'
    let hl = get(t, 'done', 0) ? '%#SuperTabPanelTodoDone#' : '%#SuperTabPanelTodoOpen#'
    let text = supertabpanel#truncate(get(t, 'text', ''), supertabpanel#content_width(8))
    let text = substitute(text, '%', '%%', 'g')
    let code = a:id * 1000 + idx
    let result ..= '%' .. code .. '[supertabpanel#widgets#todo#toggle]'
          \ .. hl .. '  ' .. mark .. ' ' .. text .. '%[]%@'
    let idx += 1
  endfor
  let result ..= '%' .. a:id .. '[supertabpanel#widgets#todo#add]'
        \ .. '%#SuperTabPanelTodoAdd#  + add%[]%@'
  let result ..= '%' .. a:id .. '[supertabpanel#widgets#todo#remove_done]'
        \ .. '%#SuperTabPanelTodoDone#  × clear done%[]%@'
  return result
endfunction

function! supertabpanel#widgets#todo#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_todo_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ file: expand(get(a:params, 'file', '~/.vim-supertabpanel-todo.json')),
        \ todos: [],
        \ })
  call s:load(id)
  return #{
        \ icon: '✅',
        \ label: 'TODO',
        \ render: function('s:render', [id]),
        \ }
endfunction
