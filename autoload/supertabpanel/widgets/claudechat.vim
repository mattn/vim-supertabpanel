" vim-supertabpanel : Claude chat widget
"
" Requires ANTHROPIC_API_KEY in environment.
" Click "new chat" to open a popup prompt; response streams back.

let s:job = v:null
let s:popup = -1
let s:response = []
let s:model = get(g:, 'supertabpanel_claude_model', 'claude-sonnet-4-5')

function! s:setup_colors() abort
  hi default SuperTabPanelClHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelCl     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelClBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:ask_prompt_filter(id, key) abort
  if a:key ==# "\<CR>"
    call popup_close(a:id, s:prompt_text)
    return 1
  elseif a:key ==# "\<Esc>"
    call popup_close(a:id, '')
    return 1
  elseif a:key ==# "\<BS>"
    let s:prompt_text = strcharpart(s:prompt_text, 0, strchars(s:prompt_text) - 1)
  elseif strlen(a:key) > 0 && a:key !~# '^\x'
    let s:prompt_text ..= a:key
  endif
  call popup_settext(a:id, s:prompt_text)
  return 1
endfunction

let s:prompt_text = ''
function! s:ask_done(id, result) abort
  if type(a:result) != v:t_string || a:result ==# ''
    let s:prompt_text = ''
    return
  endif
  call s:send(a:result)
  let s:prompt_text = ''
endfunction

function! supertabpanel#widgets#claudechat#ask(info) abort
  let s:prompt_text = ''
  call popup_create('', #{
        \ title: ' Ask Claude ',
        \ border: [], padding: [0, 1, 0, 1],
        \ minwidth: 60,
        \ filter: function('s:ask_prompt_filter'),
        \ callback: function('s:ask_done'),
        \ })
  return 1
endfunction

function! s:on_chunk(ch, msg) abort
  " Server-Sent Events; collect 'data:' text blocks.
  for l in split(a:msg, "\n")
    if l =~# '^data: '
      let json = l[6:]
      if json ==# '[DONE]' | continue | endif
      try
        let d = json_decode(json)
        if has_key(d, 'delta') && has_key(d.delta, 'text')
          call add(s:response, d.delta.text)
          if s:popup > 0 && popup_getpos(s:popup) != {}
            call popup_settext(s:popup, split(join(s:response, ''), "\n"))
          endif
        endif
      catch
      endtry
    endif
  endfor
endfunction

function! s:on_done(job, status) abort
  let s:job = v:null
endfunction

function! s:send(prompt) abort
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return
  endif
  let s:response = []
  let body = json_encode(#{
        \ model: s:model,
        \ max_tokens: 1024,
        \ stream: v:true,
        \ messages: [#{ role: 'user', content: a:prompt }],
        \ })
  let s:popup = popup_create([a:prompt, '', '...'], #{
        \ title: ' Claude ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 80, minwidth: 60,
        \ maxheight: 30,
        \ padding: [0,1,0,1],
        \ scrollbar: 1,
        \ close: 'click',
        \ borderhighlight: ['SuperTabPanelSep'],
        \ })
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = job_start(['curl', '-sN', 'https://api.anthropic.com/v1/messages',
        \ '-H', 'x-api-key: ' .. $ANTHROPIC_API_KEY,
        \ '-H', 'anthropic-version: 2023-06-01',
        \ '-H', 'content-type: application/json',
        \ '-d', body], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'nl',
        \ })
endfunction

function! supertabpanel#widgets#claudechat#render() abort
  let result = '%#SuperTabPanelClHead#  ✨ Claude%@'
  let key_ok = $ANTHROPIC_API_KEY !=# ''
  if !key_ok
    let result ..= '%#SuperTabPanelCl#  (set ANTHROPIC_API_KEY)%@'
    return result
  endif
  let result ..= '%#SuperTabPanelCl#  model: ' .. s:model .. '%@'
  let result ..= '%0[supertabpanel#widgets#claudechat#ask]'
        \ .. '%#SuperTabPanelClBtn#   💬 new chat%[]%@'
  return result
endfunction

function! supertabpanel#widgets#claudechat#deactivate() abort
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = v:null
endfunction

function! supertabpanel#widgets#claudechat#init() abort
  call s:setup_colors()
  augroup supertabpanel_cl_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('claudechat', #{
        \ icon: '✨',
        \ label: 'Claude',
        \ render: function('supertabpanel#widgets#claudechat#render'),
        \ on_deactivate: function('supertabpanel#widgets#claudechat#deactivate'),
        \ })
endfunction
