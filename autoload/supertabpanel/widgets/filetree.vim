" vim-supertabpanel : file tree widget

let s:root = getcwd()
let s:expanded = {}
let s:entries = []
let s:rendered = ''
let s:rendered_for = ''
let s:rendered_cols = -1

function! s:setup_colors() abort
  hi default SuperTabPanelFtHeader  guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelFtDir     guifg=#7aa2f7 guibg=#1a1b26 gui=bold cterm=bold ctermfg=111 ctermbg=234
  hi default SuperTabPanelFtFile    guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelFtFileSel guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
endfunction

function! s:icon_for(name, isdir) abort
  if a:isdir
    return get(s:expanded, a:name, 0) ? '📂' : '📁'
  endif
  let ext = tolower(fnamemodify(a:name, ':e'))
  if exists('g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols')
        \ && has_key(g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols, ext)
    return g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols[ext]
  endif
  return get(g:, 'WebDevIconsUnicodeDecorateFileNodesDefaultSymbol', '📄')
endfunction

function! s:list_dir(path) abort
  try
    let names = readdir(a:path, {n -> n !=# '.' && n !=# '..'})
  catch
    return []
  endtry
  let dirs = []
  let files = []
  for n in names
    let full = a:path .. '/' .. n
    if isdirectory(full)
      call add(dirs, n)
    else
      call add(files, n)
    endif
  endfor
  call sort(dirs)
  call sort(files)
  let items = []
  for d in dirs
    let p = a:path .. '/' .. d
    call add(items, {'name': d, 'path': p, 'abspath': fnamemodify(p, ':p'), 'isdir': 1})
  endfor
  for f in files
    let p = a:path .. '/' .. f
    call add(items, {'name': f, 'path': p, 'abspath': fnamemodify(p, ':p'), 'isdir': 0})
  endfor
  return items
endfunction

function! s:walk(path, depth, out) abort
  for entry in s:list_dir(a:path)
    let entry.depth = a:depth
    call add(a:out, entry)
    if entry.isdir && get(s:expanded, entry.path, 0)
      call s:walk(entry.path, a:depth + 1, a:out)
    endif
  endfor
endfunction

function! s:rebuild() abort
  let s:entries = []
  call s:walk(s:root, 0, s:entries)
  let s:rendered = ''
endfunction

function! supertabpanel#widgets#filetree#click(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:entries)
    return 0
  endif
  let entry = s:entries[idx]
  if entry.isdir
    if get(s:expanded, entry.path, 0)
      unlet s:expanded[entry.path]
    else
      let s:expanded[entry.path] = 1
    endif
    call s:rebuild()
    redrawtabpanel
  else
    execute 'edit ' .. fnameescape(entry.path)
  endif
  return 1
endfunction

function! supertabpanel#widgets#filetree#up(info) abort
  let s:root = fnamemodify(s:root, ':h')
  call s:rebuild()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#filetree#refresh(info) abort
  call s:rebuild()
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#filetree#render() abort
  let curfile = fnamemodify(bufname('%'), ':p')
  let cols = supertabpanel#columns()
  if s:rendered !=# '' && s:rendered_for ==# curfile && s:rendered_cols == cols
    return s:rendered
  endif
  let result = ''
  let root_name = fnamemodify(s:root, ':t')
  if root_name ==# ''
    let root_name = s:root
  endif
  let result ..= '%#SuperTabPanelFtHeader# 📁 ' .. root_name .. '%@'
  let result ..= '%#SuperTabPanelSep# ' .. repeat('─', supertabpanel#content_width(4)) .. '%@'
  let result ..= '%0[supertabpanel#widgets#filetree#up]'
        \ .. '%#SuperTabPanelFtFile#   ⬆️  ..%[]%@'
  let result ..= '%0[supertabpanel#widgets#filetree#refresh]'
        \ .. '%#SuperTabPanelFtFile#   🔄 refresh%[]%@'
  let result ..= '%#SuperTabPanelSep# ' .. repeat('─', supertabpanel#content_width(4)) .. '%@'

  let idx = 0
  for entry in s:entries
    let indent = repeat('  ', entry.depth)
    let icon = s:icon_for(entry.isdir ? entry.path : entry.name, entry.isdir)
    let maxw = supertabpanel#content_width(6) - entry.depth * 2
    let name = supertabpanel#truncate(entry.name, maxw)
    if entry.isdir
      let hl = '%#SuperTabPanelFtDir#'
    elseif entry.abspath ==# curfile
      let hl = '%#SuperTabPanelFtFileSel#'
    else
      let hl = '%#SuperTabPanelFtFile#'
    endif
    let result ..= '%' .. idx .. '[supertabpanel#widgets#filetree#click]'
          \ .. hl .. ' ' .. indent .. icon .. ' ' .. name .. '%[]%@'
    let idx += 1
  endfor
  let s:rendered = result
  let s:rendered_for = curfile
  let s:rendered_cols = cols
  return result
endfunction

function! supertabpanel#widgets#filetree#activate() abort
  call s:rebuild()
  augroup supertabpanel_filetree_update
    autocmd!
    autocmd BufEnter * if &showtabpanel | redrawtabpanel | endif
  augroup END
endfunction

function! supertabpanel#widgets#filetree#deactivate() abort
  augroup supertabpanel_filetree_update
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#filetree#init() abort
  call s:setup_colors()
  augroup supertabpanel_filetree_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('filetree', #{
        \ icon: '🌲',
        \ label: 'File Tree',
        \ render: function('supertabpanel#widgets#filetree#render'),
        \ on_activate: function('supertabpanel#widgets#filetree#activate'),
        \ on_deactivate: function('supertabpanel#widgets#filetree#deactivate'),
        \ })
endfunction
