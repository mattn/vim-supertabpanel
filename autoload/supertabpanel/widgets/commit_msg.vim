" vim-supertabpanel : AI-generated commit message widget
"
" Runs `git diff --cached` and asks Claude for a concise commit message.
" Requires ANTHROPIC_API_KEY.
"
" Instance params:
"   model : Claude model id (default 'claude-sonnet-4-5')

let s:instances = []
let s:colors_ready = 0

function! s:setup_colors() abort
  hi default SuperTabPanelCmHead guifg=#e0af68 guibg=#1a1b26 gui=bold cterm=bold ctermfg=179 ctermbg=234
  hi default SuperTabPanelCm     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelCmBtn  guifg=#bb9af7 guibg=#1a1b26 ctermfg=141 ctermbg=234
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
    let d = json_decode(join(inst.buf, ''))
    if has_key(d, 'content') && !empty(d.content)
      let text = d.content[0].text
      call popup_settext(inst.popup, split(text, "\n"))
    endif
  catch
  endtry
endfunction

function! supertabpanel#widgets#commit_msg#generate(info) abort
  let id = a:info.minwid
  if id < 0 || id >= len(s:instances)
    return 0
  endif
  if $ANTHROPIC_API_KEY ==# ''
    echohl ErrorMsg | echom 'ANTHROPIC_API_KEY not set' | echohl None
    return 0
  endif
  silent let diff = system('git diff --cached')
  if v:shell_error != 0 || diff ==# ''
    echohl WarningMsg | echom 'No staged changes' | echohl None
    return 0
  endif
  let inst = s:instances[id]
  let body = json_encode(#{
        \ model: inst.model,
        \ max_tokens: 512,
        \ messages: [#{
        \   role: 'user',
        \   content: "Write a concise git commit message (subject + blank line + "
        \     .. "one-paragraph body, no bullet lists) for this diff:\n\n" .. diff,
        \ }],
        \ })
  let inst.buf = []
  let inst.popup = popup_create(['Generating...'], #{
        \ title: ' Commit Message ',
        \ border: [],
        \ borderchars: ['─','│','─','│','╭','╮','╯','╰'],
        \ maxwidth: 80, minwidth: 60, maxheight: 20,
        \ padding: [0,1,0,1],
        \ scrollbar: 1,
        \ close: 'click',
        \ borderhighlight: ['SuperTabPanelSep'],
        \ })
  if inst.job isnot v:null && job_status(inst.job) ==# 'run'
    call job_stop(inst.job)
  endif
  let inst.job = job_start(['curl', '-sL', 'https://api.anthropic.com/v1/messages',
        \ '-H', 'x-api-key: ' .. $ANTHROPIC_API_KEY,
        \ '-H', 'anthropic-version: 2023-06-01',
        \ '-H', 'content-type: application/json',
        \ '-d', body], #{
        \ out_cb: function('s:on_chunk', [id]),
        \ exit_cb: function('s:on_done', [id]),
        \ mode: 'raw',
        \ })
  return 1
endfunction

function! s:render(id) abort
  let result = '%#SuperTabPanelCmHead#  📝 Commit Msg%@'
  if $ANTHROPIC_API_KEY ==# ''
    return result .. '%#SuperTabPanelCm#  (set ANTHROPIC_API_KEY)%@'
  endif
  let result ..= '%' .. a:id .. '[supertabpanel#widgets#commit_msg#generate]'
        \ .. '%#SuperTabPanelCmBtn#   ✨ generate%[]%@'
  return result
endfunction

function! supertabpanel#widgets#commit_msg#instance(params) abort
  if !s:colors_ready
    call s:setup_colors()
    augroup supertabpanel_cm_colors
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
        \ icon: '📝',
        \ label: 'Commit Msg',
        \ render: function('s:render', [id]),
        \ }
endfunction
