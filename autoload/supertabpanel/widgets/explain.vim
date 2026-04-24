" vim-supertabpanel : buffer explainer widget (asks Claude)
"
" Requires ANTHROPIC_API_KEY.

let s:job = v:null
let s:buf = []
let s:popup = -1
let s:model = get(g:, 'supertabpanel_claude_model', 'claude-sonnet-4-5')

function! s:setup_colors() abort
  hi default SuperTabPanelExHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelEx     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelExBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
endfunction

function! s:on_chunk(ch, msg) abort
  for l in split(a:msg, "\n")
    if l =~# '^data: '
      let json = l[6:]
      if json ==# '[DONE]' | continue | endif
      try
        let d = json_decode(json)
        if has_key(d, 'delta') && has_key(d.delta, 'text')
          call add(s:buf, d.delta.text)
          if s:popup > 0 && popup_getpos(s:popup) != {}
            call popup_settext(s:popup, split(join(s:buf, ''), "\n"))
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

function! s:ask(prompt) abort
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return
  endif
  let s:buf = []
  let body = json_encode(#{
        \ model: s:model,
        \ max_tokens: 2048,
        \ stream: v:true,
        \ messages: [#{ role: 'user', content: a:prompt }],
        \ })
  let s:popup = popup_create(['Asking Claude...'], #{
        \ title: ' Explain ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 100, minwidth: 60, maxheight: 40,
        \ padding: [0,1,0,1],
        \ scrollbar: 1, close: 'click',
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

function! supertabpanel#widgets#explain#buffer(info) abort
  let text = join(getline(1, '$'), "\n")
  call s:ask("Briefly explain what this code does:\n\n" .. text)
  return 1
endfunction

function! supertabpanel#widgets#explain#selection(info) abort
  let saved = @@
  silent normal! gvy
  let text = @@
  let @@ = saved
  if text ==# ''
    return 0
  endif
  call s:ask("Briefly explain this code:\n\n" .. text)
  return 1
endfunction

function! supertabpanel#widgets#explain#render() abort
  let result = '%#SuperTabPanelExHead#  🔍 Explain%@'
  if $ANTHROPIC_API_KEY ==# ''
    return result .. '%#SuperTabPanelEx#  (set ANTHROPIC_API_KEY)%@'
  endif
  let result ..= '%0[supertabpanel#widgets#explain#buffer]'
        \ .. '%#SuperTabPanelExBtn#  📄 whole buffer%[]%@'
  let result ..= '%0[supertabpanel#widgets#explain#selection]'
        \ .. '%#SuperTabPanelExBtn#  ✂ selection%[]%@'
  return result
endfunction

function! supertabpanel#widgets#explain#init() abort
  call s:setup_colors()
  augroup supertabpanel_ex_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('explain', #{
        \ icon: '🔍',
        \ label: 'Explain',
        \ render: function('supertabpanel#widgets#explain#render'),
        \ })
endfunction
