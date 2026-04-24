" vim-supertabpanel : Claude chat widget
"
" Requires ANTHROPIC_API_KEY in environment.
"
" Instance params:
"   model : Claude model id (default 'claude-sonnet-4-5')

let s:instances = []
let s:colors_ready = 0
let s:prompt_text = ''
let s:prompt_owner = -1

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

function! s:ask_done(id, result) abort
  if type(a:result) != v:t_string || a:result ==# ''
        \ || s:prompt_owner < 0 || s:prompt_owner >= len(s:instances)
    let s:prompt_text = ''
    let s:prompt_owner = -1
    return
  endif
  call s:send(s:prompt_owner, a:result)
  let s:prompt_text = ''
  let s:prompt_owner = -1
endfunction

function! supertabpanel#widgets#claudechat#ask(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  let s:prompt_text = ''
  let s:prompt_owner = id
  call popup_create('', #{
        \ title: ' Ask Claude ',
        \ border: [], padding: [0, 1, 0, 1],
        \ minwidth: 60,
        \ filter: function('s:ask_prompt_filter'),
        \ callback: function('s:ask_done'),
        \ })
  return 1
endfunction

function! s:on_chunk(id, ch, msg) abort
  let inst = s:instances[a:id]
  for l in split(a:msg, "\n")
    if l =~# '^data: '
      let json = l[6:]
      if json ==# '[DONE]' | continue | endif
      try
        let d = json_decode(json)
        if has_key(d, 'delta') && has_key(d.delta, 'text')
          call add(inst.response, d.delta.text)
          if inst.popup > 0 && popup_getpos(inst.popup) != {}
            call popup_settext(inst.popup, split(join(inst.response, ''), "\n"))
          endif
        endif
      catch
      endtry
    endif
  endfor
endfunction

function! s:on_done(id, job, status) abort
  let s:instances[a:id].job = v:null
endfunction

function! s:send(id, prompt) abort
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return
  endif
  let inst = s:instances[a:id]
  let inst.response = []
  let body = json_encode(#{
        \ model: inst.model,
        \ max_tokens: 1024,
        \ stream: v:true,
        \ messages: [#{ role: 'user', content: a:prompt }],
        \ })
  let inst.popup = popup_create([a:prompt, '', '...'], #{
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
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = job_start(['curl', '-sN', 'https://api.anthropic.com/v1/messages',
        \ '-H', 'x-api-key: ' .. $ANTHROPIC_API_KEY,
        \ '-H', 'anthropic-version: 2023-06-01',
        \ '-H', 'content-type: application/json',
        \ '-d', body], #{
        \ out_cb: function('s:on_chunk', [a:id]),
        \ exit_cb: function('s:on_done', [a:id]),
        \ mode: 'nl',
        \ })
endfunction

function! s:render(id) abort
  let inst = s:instances[a:id]
  let result = '%#SuperTabPanelClHead#  ✨ Claude%@'
  if $ANTHROPIC_API_KEY ==# ''
    let result ..= '%#SuperTabPanelCl#  (set ANTHROPIC_API_KEY)%@'
    return result
  endif
  let result ..= '%#SuperTabPanelCl#  model: ' .. inst.model .. '%@'
  let result ..= '%' .. a:id .. '[supertabpanel#widgets#claudechat#ask]'
        \ .. '%#SuperTabPanelClBtn#   💬 new chat%[]%@'
  return result
endfunction

function! s:deactivate(id) abort
  let inst = s:instances[a:id]
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = v:null
endfunction

function! supertabpanel#widgets#claudechat#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_cl_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ model: get(a:params, 'model', 'claude-sonnet-4-5'),
        \ response: [],
        \ job: v:null,
        \ popup: -1,
        \ })
  return #{
        \ icon: '✨',
        \ label: 'Claude',
        \ render: function('s:render', [id]),
        \ on_deactivate: function('s:deactivate', [id]),
        \ }
endfunction
