" vim-supertabpanel : plugin entry

if exists('g:loaded_supertabpanel')
  finish
endif
let g:loaded_supertabpanel = 1

" Requires Vim 9.2.386 for `scroll`/`scrollbar` in 'tabpanelopt' (v9.2.0386)
" and %[FuncName] click handler support (v9.2.0360).
if !has('patch-9.2.386')
  echohl WarningMsg
  echom 'vim-supertabpanel requires Vim 9.2.386 or later'
  echohl None
  finish
endif

if !has('tabpanel')
  echohl WarningMsg
  echom 'vim-supertabpanel: this Vim build does not have the +tabpanel feature'
  echohl None
  finish
endif

command! SuperTabPanel         call supertabpanel#toggle()
command! SuperTabPanelRotate   call supertabpanel#rotate(1)
command! SuperTabPanelRotateBack call supertabpanel#rotate(-1)
command! -nargs=1 -complete=customlist,supertabpanel#complete_panel
      \ SuperTabPanelActivate call supertabpanel#activate(<q-args>)

if !hasmapto('<Plug>(supertabpanel-toggle)', 'n')
  nmap <silent> ,tt <Plug>(supertabpanel-toggle)
endif
if !hasmapto('<Plug>(supertabpanel-rotate)', 'n')
  nmap <silent> ,tr <Plug>(supertabpanel-rotate)
endif
if !hasmapto('<Plug>(supertabpanel-rotate-back)', 'n')
  nmap <silent> ,tR <Plug>(supertabpanel-rotate-back)
endif

nnoremap <silent> <Plug>(supertabpanel-toggle)
      \ <Cmd>call supertabpanel#toggle()<CR>
nnoremap <silent> <Plug>(supertabpanel-rotate)
      \ <Cmd>call supertabpanel#rotate(1)<CR>
nnoremap <silent> <Plug>(supertabpanel-rotate-back)
      \ <Cmd>call supertabpanel#rotate(-1)<CR>

let g:supertabpanel_panels = get(g:, 'supertabpanel_panels', [
      \ #{ name: 'Time',      items: [
      \   'supertabpanel#widgets#clock',
      \   'supertabpanel#widgets#calendar',
      \   'supertabpanel#widgets#weather',
      \   'supertabpanel#widgets#sunmoon',
      \   'supertabpanel#widgets#moonphase',
      \   'supertabpanel#widgets#worldclock',
      \ ]},
      \ #{ name: 'Feed',      items: [
      \   'supertabpanel#widgets#btcchart',
      \   'supertabpanel#widgets#stockticker',
      \   #{ widget: 'rssfeed', params: #{
      \     name: '朝日新聞',
      \     url: 'https://www.asahi.com/rss/asahi/newsheadlines.rdf',
      \     max: 5,
      \   }},
      \   #{ widget: 'rssfeed', params: #{
      \     name: '毎日新聞',
      \     url: 'https://mainichi.jp/rss/etc/mainichi-flash.rss',
      \     max: 5,
      \   }},
      \ ]},
      \ #{ name: 'Tech',      items: [
      \   'supertabpanel#widgets#hackernews',
      \   'supertabpanel#widgets#github_trending',
      \ ]},
      \ #{ name: 'Fun',       items: [
      \   'supertabpanel#widgets#meigen',
      \   'supertabpanel#widgets#asciiart',
      \ ]},
      \ #{ name: 'Git',       items: [
      \   'supertabpanel#widgets#gitstatus',
      \   'supertabpanel#widgets#diff',
      \   'supertabpanel#widgets#stash',
      \   'supertabpanel#widgets#pullrequests',
      \   'supertabpanel#widgets#notifications',
      \ ]},
      \ #{ name: 'Nav',       items: [
      \   'supertabpanel#widgets#buffers',
      \   'supertabpanel#widgets#recent',
      \   'supertabpanel#widgets#marks',
      \   'supertabpanel#widgets#jumplist',
      \   'supertabpanel#widgets#tags',
      \ ]},
      \ #{ name: 'Edit',      items: [
      \   'supertabpanel#widgets#quickfix',
      \   'supertabpanel#widgets#diagnostics',
      \   'supertabpanel#widgets#registers',
      \   'supertabpanel#widgets#macros',
      \   'supertabpanel#widgets#undo',
      \   'supertabpanel#widgets#clipboard',
      \   'supertabpanel#widgets#terminals',
      \   'supertabpanel#widgets#quicklaunch',
      \ ]},
      \ #{ name: 'Work',      items: [
      \   'supertabpanel#widgets#todo',
      \   'supertabpanel#widgets#pomodoro',
      \ ]},
      \ #{ name: 'Ops',       items: [
      \   'supertabpanel#widgets#sysmon',
      \   'supertabpanel#widgets#build',
      \   'supertabpanel#widgets#tests',
      \   'supertabpanel#widgets#docker',
      \   'supertabpanel#widgets#k8s_pods',
      \ ]},
      \ #{ name: 'AI',        items: [
      \   'supertabpanel#widgets#claudechat',
      \   'supertabpanel#widgets#explain',
      \   'supertabpanel#widgets#commit_msg',
      \   'supertabpanel#widgets#translate',
      \ ]},
      \ #{ name: 'Game',      items: [
      \   'supertabpanel#widgets#tetris',
      \   'supertabpanel#widgets#snake',
      \   'supertabpanel#widgets#g2048',
      \   'supertabpanel#widgets#gameoflife',
      \ ]},
      \ #{ name: 'Media',     items: [
      \   'supertabpanel#widgets#piano',
      \   'supertabpanel#widgets#radio',
      \   #{ widget: 'podcast', params: #{
      \     url: 'https://feeds.megaphone.fm/TFM9640066968',
      \   }},
      \ ]},
      \ #{ name: 'Files',     items: [
      \   'supertabpanel#widgets#filetree',
      \ ]},
      \ ])
let g:supertabpanel_columns = get(g:, 'supertabpanel_columns', 32)
let g:supertabpanel_default = get(g:, 'supertabpanel_default', 0)

" Defer auto-setup to VimEnter so a user's explicit supertabpanel#setup()
" call in their vimrc wins over the defaults here.
function! s:auto_setup() abort
  if supertabpanel#did_setup()
    return
  endif
  call supertabpanel#setup(#{
        \ columns: g:supertabpanel_columns,
        \ panels: g:supertabpanel_panels,
        \ default: g:supertabpanel_default,
        \ })
endfunction

augroup supertabpanel_autosetup
  autocmd!
  autocmd VimEnter * ++once call s:auto_setup()
augroup END
