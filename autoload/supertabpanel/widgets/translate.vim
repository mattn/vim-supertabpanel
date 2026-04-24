" vim-supertabpanel : translate widget (Google Translate free endpoint)

let s:job = v:null
let s:buf = []
let s:popup = -1
let s:source = get(g:, 'supertabpanel_translate_source', 'auto')
let s:target = get(g:, 'supertabpanel_translate_target', 'ja')

function! s:setup_colors() abort
  hi default SuperTabPanelTrHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTr     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTrBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  call add(s:buf, a:msg)
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
  if a:status != 0 || empty(s:buf) || s:popup <= 0
    return
  endif
  try
    let data = json_decode(join(s:buf, ''))
    let text = ''
    if type(data) == v:t_list && len(data) > 0 && type(data[0]) == v:t_list
      for part in data[0]
        if type(part) == v:t_list && len(part) > 0
          let text ..= part[0]
        endif
      endfor
    endif
    call popup_settext(s:popup, split(text, "\n"))
  catch
  endtry
endfunction

function! s:translate(text) abort
  if a:text ==# ''
    return
  endif
  let s:buf = []
  let url = 'https://translate.googleapis.com/translate_a/single'
        \ .. '?client=gtx'
        \ .. '&sl=' .. s:source
        \ .. '&tl=' .. s:target
        \ .. '&dt=t'
        \ .. '&q=' .. substitute(a:text, '[^A-Za-z0-9]',
        \                '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
  let s:popup = popup_create(['Translating...'], #{
        \ title: ' Translate ' .. s:source .. ' → ' .. s:target .. ' ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 80, minwidth: 60, maxheight: 20,
        \ padding: [0,1,0,1],
        \ scrollbar: 1, close: 'click',
        \ })
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
endfunction

function! supertabpanel#widgets#translate#selection(info) abort
  let saved = @@
  silent normal! gvy
  let text = @@
  let @@ = saved
  call s:translate(text)
  return 1
endfunction

function! supertabpanel#widgets#translate#line(info) abort
  call s:translate(getline('.'))
  return 1
endfunction

function! supertabpanel#widgets#translate#swap(info) abort
  let t = s:source
  let s:source = s:target ==# 'auto' ? 'en' : s:target
  let s:target = t ==# 'auto' ? 'ja' : t
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#translate#render() abort
  let result = '%#SuperTabPanelTrHead#  🈳 Translate%@'
  let result ..= '%0[supertabpanel#widgets#translate#swap]'
        \ .. '%#SuperTabPanelTr#  ' .. s:source .. ' → ' .. s:target .. '%[]%@'
  let result ..= '%0[supertabpanel#widgets#translate#line]'
        \ .. '%#SuperTabPanelTrBtn#  📋 current line%[]%@'
  let result ..= '%0[supertabpanel#widgets#translate#selection]'
        \ .. '%#SuperTabPanelTrBtn#  ✂ selection%[]%@'
  return result
endfunction

function! supertabpanel#widgets#translate#init() abort
  call s:setup_colors()
  augroup supertabpanel_tr_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('translate', #{
        \ icon: '🈳',
        \ label: 'Translate',
        \ render: function('supertabpanel#widgets#translate#render'),
        \ })
endfunction
