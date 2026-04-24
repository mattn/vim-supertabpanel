" vim-supertabpanel : buffer explainer widget (asks Claude)
"
" Requires ANTHROPIC_API_KEY.
"
" Instance params:
"   model : Claude model id (default 'claude-sonnet-4-5')

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelExHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelEx     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelExBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
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
          call add(inst.buf, d.delta.text)
          if inst.popup > 0 && popup_getpos(inst.popup) != {}
            call popup_settext(inst.popup, split(join(inst.buf, ''), "\n"))
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

function! s:ask(id, prompt) abort
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return
  endif
  let inst = s:instances[a:id]
  let inst.buf = []
  let body = json_encode(#{
        \ model: inst.model,
        \ max_tokens: 2048,
        \ stream: v:true,
        \ messages: [#{ role: 'user', content: a:prompt }],
        \ })
  let inst.popup = popup_create(['Asking Claude...'], #{
        \ title: ' Explain ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 100, minwidth: 60, maxheight: 40,
        \ padding: [0,1,0,1],
        \ scrollbar: 1, close: 'click',
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

" minwid encodes id*10 + action (0=buffer, 1=selection)
function! supertabpanel#widgets#explain#click(info) abort
  let code = a:info.minwid
  let id = code / 10
  let action = code % 10
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  if action == 0
    let text = join(getline(1, '$'), "\n")
    call s:ask(id, "Briefly explain what this code does:\n\n" .. text)
  elseif action == 1
    let saved = @@
    silent normal! gvy
    let text = @@
    let @@ = saved
    if text ==# ''
      return 0
    endif
    call s:ask(id, "Briefly explain this code:\n\n" .. text)
  endif
  return 1
endfunction

function! s:render(id) abort
  let result = '%#SuperTabPanelExHead#  🔍 Explain%@'
  if $ANTHROPIC_API_KEY ==# ''
    return result .. '%#SuperTabPanelEx#  (set ANTHROPIC_API_KEY)%@'
  endif
  let result ..= '%' .. (a:id * 10 + 0) .. '[supertabpanel#widgets#explain#click]'
        \ .. '%#SuperTabPanelExBtn#  📄 whole buffer%[]%@'
  let result ..= '%' .. (a:id * 10 + 1) .. '[supertabpanel#widgets#explain#click]'
        \ .. '%#SuperTabPanelExBtn#  ✂ selection%[]%@'
  return result
endfunction

function! supertabpanel#widgets#explain#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_ex_colors
      autocmd!
      autocmd ColorScheme * call s:setup_colors()
    augroup END
    let s:colors_ready = 1
  endif
  let id = len(s:instances)
  call add(s:instances, #{
        \ id: id,
        \ model: get(a:params, 'model', 'claude-sonnet-4-5'),
        \ buf: [],
        \ job: v:null,
        \ popup: -1,
        \ })
  return #{
        \ icon: '🔍',
        \ label: 'Explain',
        \ render: function('s:render', [id]),
        \ }
endfunction
