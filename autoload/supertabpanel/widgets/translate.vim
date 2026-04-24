" vim-supertabpanel : translate widget (Google Translate free endpoint)
"
" Instance params:
"   source : source language code (default 'auto')
"   target : target language code (default 'ja')

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelTrHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelTr     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelTrBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(id, ch, msg) abort
  call add(s:instances[a:id].buf, a:msg)
endfunction

function! s:on_done(id, job, status) abort
  let inst = s:instances[a:id]
  let inst.job = v:null
  if a:status != 0 || empty(inst.buf) || inst.popup <= 0
    return
  endif
  try
    let data = json_decode(join(inst.buf, ''))
    let text = ''
    if type(data) == v:t_list && len(data) > 0 && type(data[0]) == v:t_list
      for part in data[0]
        if type(part) == v:t_list && len(part) > 0
          let text ..= part[0]
        endif
      endfor
    endif
    call popup_settext(inst.popup, split(text, "\n"))
  catch
  endtry
endfunction

function! s:translate(id, text) abort
  if a:text ==# ''
    return
  endif
  let inst = s:instances[a:id]
  let inst.buf = []
  let url = 'https://translate.googleapis.com/translate_a/single'
        \ .. '?client=gtx'
        \ .. '&sl=' .. inst.source
        \ .. '&tl=' .. inst.target
        \ .. '&dt=t'
        \ .. '&q=' .. substitute(a:text, '[^A-Za-z0-9]',
        \                '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
  let inst.popup = popup_create(['Translating...'], #{
        \ title: ' Translate ' .. inst.source .. ' → ' .. inst.target .. ' ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 80, minwidth: 60, maxheight: 20,
        \ padding: [0,1,0,1],
        \ scrollbar: 1, close: 'click',
        \ })
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = job_start(['curl', '-sL', url], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'raw',
        \ })
endfunction

" minwid encodes id*10 + action (0=selection, 1=line, 2=swap)
function! supertabpanel#widgets#translate#click(info) abort
  let code = a:info.minwid
  let id = code / 10
  let action = code % 10
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let inst = s:instances[id]
  if action == 0
    let saved = @@
    silent normal! gvy
    let text = @@
    let @@ = saved
    call s:translate(id, text)
  elseif action == 1
    call s:translate(id, getline('.'))
  elseif action == 2
    let t = inst.source
    let inst.source = inst.target ==# 'auto' ? 'en' : inst.target
    let inst.target = t ==# 'auto' ? 'ja' : t
    redrawtabpanel
  endif
  return 1
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelTrHead#  🈳 Translate%@'
  let result ..= '%' .. (a:id * 10 + 2) .. '[supertabpanel#widgets#translate#click]'
        \ .. '%#SuperTabPanelTr#  ' .. inst.source .. ' → ' .. inst.target .. '%[]%@'
  let result ..= '%' .. (a:id * 10 + 1) .. '[supertabpanel#widgets#translate#click]'
        \ .. '%#SuperTabPanelTrBtn#  📋 current line%[]%@'
  let result ..= '%' .. (a:id * 10 + 0) .. '[supertabpanel#widgets#translate#click]'
        \ .. '%#SuperTabPanelTrBtn#  ✂ selection%[]%@'
  return result
endfunction

function! supertabpanel#widgets#translate#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_tr_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ source: get(a:params, 'source', 'auto'),
        \ target: get(a:params, 'target', 'ja'),
        \ buf: [],
        \ job: v:null,
        \ popup: -1,
        \ })
  return #{
        \ icon: '🈳',
        \ label: 'Translate',
        \ render: function('s:render', [id]),
        \ }
endfunction
