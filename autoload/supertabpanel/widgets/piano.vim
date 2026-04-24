" vim-supertabpanel : piano widget (click keys to play tones)
"
" Requires `sox` (play) or `ffplay` for sine-wave playback.

let s:keys = [
      \ #{ name: 'C',  freq: 261.63 },
      \ #{ name: 'D',  freq: 293.66 },
      \ #{ name: 'E',  freq: 329.63 },
      \ #{ name: 'F',  freq: 349.23 },
      \ #{ name: 'G',  freq: 392.00 },
      \ #{ name: 'A',  freq: 440.00 },
      \ #{ name: 'B',  freq: 493.88 },
      \ #{ name: 'C5', freq: 523.25 },
      \ ]

function! s:setup_colors() abort
  hi default SuperTabPanelPiHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelPiKey  guifg=#c0caf5 guibg=#1a1b26 ctermfg=153 ctermbg=234
  hi default SuperTabPanelPiHit  guifg=#1a1b26 guibg=#7dcfff gui=bold cterm=bold ctermfg=234 ctermbg=117
endfunction

let s:last_hit = -1

function! supertabpanel#widgets#piano#hit(info) abort
  let idx = a:info.minwid
  if idx < 0 || idx >= len(s:keys)
    return 0
  endif
  let k = s:keys[idx]
  if executable('play')
    call job_start(['play', '-n', '-q', 'synth', '0.3', 'sine', string(k.freq)])
  elseif executable('ffplay')
    call job_start(['ffplay', '-nodisp', '-loglevel', 'quiet', '-autoexit',
          \ '-f', 'lavfi',
          \ '-i', 'sine=frequency=' .. string(k.freq) .. ':duration=0.6'])
  endif
  let s:last_hit = idx
  redrawtabpanel
  call timer_start(200, {-> s:clear_hit()})
  return 1
endfunction

function! s:clear_hit() abort
  let s:last_hit = -1
  redrawtabpanel
endfunction

function! supertabpanel#widgets#piano#render() abort
  let result = '%#SuperTabPanelPiHead#  🎹 Piano%@'
  let idx = 0
  let line = '  '
  for k in s:keys
    let hl = (idx == s:last_hit)
          \ ? '%#SuperTabPanelPiHit#'
          \ : '%#SuperTabPanelPiKey#'
    let line ..= '%' .. idx .. '[supertabpanel#widgets#piano#hit]'
          \ .. hl .. printf(' %-2s', k.name) .. '%[]'
    let idx += 1
  endfor
  let result ..= line .. '%@'
  if !executable('play') && !executable('ffplay')
    let result ..= '%#SuperTabPanelPiKey#  (install sox or ffplay)%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#piano#init() abort
  call s:setup_colors()
  augroup supertabpanel_pi_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('piano', #{
        \ icon: '🎹',
        \ label: 'Piano',
        \ render: function('supertabpanel#widgets#piano#render'),
        \ })
endfunction
