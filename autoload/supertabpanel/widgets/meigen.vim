" vim-supertabpanel : 名言 widget (meigen.doodlenote.net)

let s:timer = -1
let s:job = v:null
let s:buf = []
let s:quote = ''
let s:author = ''

function! s:setup_colors() abort
  hi default SuperTabPanelMgHead   guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelMgQuote  guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelMgAuthor guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0 || empty(s:buf)
    return
  endif
  try
    let data = json_decode(join(s:buf, ''))
    if type(data) == v:t_list && !empty(data)
      let s:quote  = get(data[0], 'meigen', get(data[0], 'q', ''))
      let s:author = get(data[0], 'auther', get(data[0], 'author', get(data[0], 'a', '')))
    endif
    redrawtabpanel
  catch
  endtry
endfunction

function! supertabpanel#widgets#meigen#refresh(timer) abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    return
  endif
  let s:buf = []
  let s:job = job_start(['curl', '-sL', 'https://meigen.doodlenote.net/api/json.php?num=1'], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#meigen#render() abort
  let result = '%#SuperTabPanelMgHead#  💭 名言%@'
  if s:quote ==# ''
    return result .. '%#SuperTabPanelMgQuote#  fetching...%@'
  endif
  let lines = supertabpanel#wrap(s:quote, supertabpanel#content_width(5))
  for l in lines
    let l = substitute(l, '%', '%%', 'g')
    let result ..= '%#SuperTabPanelMgQuote#  ' .. l .. '%@'
  endfor
  let author = substitute(s:author, '%', '%%', 'g')
  let result ..= '%#SuperTabPanelMgAuthor#  — ' .. author .. '%@'
  return result
endfunction

function! supertabpanel#widgets#meigen#activate() abort
  if s:timer == -1
    call supertabpanel#widgets#meigen#refresh(0)
    let s:timer = timer_start(3600000,
          \ function('supertabpanel#widgets#meigen#refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#meigen#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#meigen#init() abort
  call s:setup_colors()
  augroup supertabpanel_mg_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('meigen', #{
        \ icon: '💭',
        \ label: '名言',
        \ render: function('supertabpanel#widgets#meigen#render'),
        \ on_activate: function('supertabpanel#widgets#meigen#activate'),
        \ on_deactivate: function('supertabpanel#widgets#meigen#deactivate'),
        \ })
endfunction
