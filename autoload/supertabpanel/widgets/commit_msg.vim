" vim-supertabpanel : AI-generated commit message widget
"
" Runs `git diff --cached` and asks Claude for a concise commit message.
" Requires ANTHROPIC_API_KEY.

let s:job = v:null
let s:buf = []
let s:popup = -1
let s:model = get(g:, 'supertabpanel_claude_model', 'claude-sonnet-4-5')

function! s:setup_colors() abort
  hi default SuperTabPanelCmHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelCm     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelCmBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
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
    let d = json_decode(join(s:buf, ''))
    if has_key(d, 'content') && !empty(d.content)
      let text = d.content[0].text
      call popup_settext(s:popup, split(text, "\n"))
    endif
  catch
  endtry
endfunction

function! supertabpanel#widgets#commit_msg#generate(info) abort
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return 0
  endif
  silent let diff = system('git diff --cached')
  if v:shell_error != 0 || diff ==# ''
    echohl WarningMsg | echom 'No staged changes' | echohl None
    return 0
  endif
  let body = json_encode(#{
        \ model: s:model,
        \ max_tokens: 512,
        \ messages: [#{
        \   role: 'user',
        \   content: "Write a concise git commit message (subject + blank line + "
        \     .. "one-paragraph body, no bullet lists) for this diff:\n\n" .. diff,
        \ }],
        \ })
  let s:buf = []
  let s:popup = popup_create(['Generating...'], #{
        \ title: ' Commit Message ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 80, minwidth: 60, maxheight: 20,
        \ padding: [0,1,0,1],
        \ scrollbar: 1,
        \ close: 'click',
        \ borderhighlight: ['SuperTabPanelSep'],
        \ })
  if s:job isnot v:null && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:job = job_start(['curl', '-sL', 'https://api.anthropic.com/v1/messages',
        \ '-H', 'x-api-key: ' .. $ANTHROPIC_API_KEY,
        \ '-H', 'anthropic-version: 2023-06-01',
        \ '-H', 'content-type: application/json',
        \ '-d', body], #{
        \ out_cb: function('s:on_chunk'),
        \ exit_cb: function('s:on_done'),
        \ mode: 'raw',
        \ })
  return 1
endfunction

function! supertabpanel#widgets#commit_msg#render() abort
  let result = '%#SuperTabPanelCmHead#  📝 Commit Msg%@'
  if $ANTHROPIC_API_KEY ==# ''
    return result .. '%#SuperTabPanelCm#  (set ANTHROPIC_API_KEY)%@'
  endif
  let result ..= '%0[supertabpanel#widgets#commit_msg#generate]'
        \ .. '%#SuperTabPanelCmBtn#   ✨ generate%[]%@'
  return result
endfunction

function! supertabpanel#widgets#commit_msg#init() abort
  call s:setup_colors()
  augroup supertabpanel_cm_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('commit_msg', #{
        \ icon: '📝',
        \ label: 'Commit Msg',
        \ render: function('supertabpanel#widgets#commit_msg#render'),
        \ })
endfunction
