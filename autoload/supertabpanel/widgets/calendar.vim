" vim-supertabpanel : calendar widget

let s:offset = 0

function! s:setup_colors() abort
  hi default SuperTabPanelCalTitle guifg=#bb9af7 guibg=#1a1b26 gui=bold cterm=bold ctermfg=141 ctermbg=234
  hi default SuperTabPanelCalHead  guifg=#565f89 guibg=#1a1b26 ctermfg=242 ctermbg=234
  hi default SuperTabPanelCalDay   guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelCalToday guifg=#1a1b26 guibg=#7aa2f7 gui=bold cterm=bold ctermfg=234 ctermbg=111
endfunction

function! supertabpanel#widgets#calendar#prev_month(info) abort
  let s:offset -= 1
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#calendar#next_month(info) abort
  let s:offset += 1
  redrawtabpanel
  return 1
endfunction

function! supertabpanel#widgets#calendar#goto_today(info) abort
  let s:offset = 0
  redrawtabpanel
  return 1
endfunction

function! s:build() abort
  let year = str2nr(strftime('%Y'))
  let month = str2nr(strftime('%m')) + s:offset
  while month > 12
    let month -= 12
    let year += 1
  endwhile
  while month < 1
    let month += 12
    let year -= 1
  endwhile
  let today = s:offset == 0 ? str2nr(strftime('%d')) : 0
  let month_names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        \ 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  let mdays = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    let mdays[2] = 29
  endif
  let days_in_month = mdays[month]
  let zy = year
  let zm = month
  if zm <= 2
    let zm += 12
    let zy -= 1
  endif
  let k = zy % 100
  let j = zy / 100
  let h = (1 + (13 * (zm + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
  let first_dow = (h + 6) % 7
  let lines = []
  call add(lines, {'type': 'title', 'text': printf('%s %d', month_names[month], year)})
  call add(lines, {'type': 'head',  'text': ' Su Mo Tu We Th Fr Sa'})
  let week = []
  for i in range(first_dow)
    call add(week, {'day': 0})
  endfor
  for d in range(1, days_in_month)
    call add(week, {'day': d, 'today': d == today})
    if len(week) == 7
      call add(lines, {'type': 'days', 'days': week})
      let week = []
    endif
  endfor
  if len(week) > 0
    call add(lines, {'type': 'days', 'days': week})
  endif
  return lines
endfunction

function! s:render_line(entry) abort
  if a:entry.type ==# 'title'
    let arrow_l = ' ◀ '
    let arrow_r = ' ▶ '
    let arrow_w = strdisplaywidth(arrow_l) + strdisplaywidth(arrow_r)
    let text_w = strdisplaywidth(a:entry.text)
    let pad_total = max([24 - arrow_w - text_w, 2])
    let pad_l = pad_total / 2
    let pad_r = pad_total - pad_l
    return '%0[supertabpanel#widgets#calendar#prev_month]%#SuperTabPanelCalTitle#' .. arrow_l .. '%[]'
          \ .. '%0[supertabpanel#widgets#calendar#goto_today]%#SuperTabPanelCalTitle#'
          \ .. repeat(' ', pad_l) .. a:entry.text .. repeat(' ', pad_r) .. '%[]'
          \ .. '%0[supertabpanel#widgets#calendar#next_month]%#SuperTabPanelCalTitle#'
          \ .. arrow_r .. '%[]'
  elseif a:entry.type ==# 'head'
    return '%#SuperTabPanelCalHead# ' .. a:entry.text
  else
    let line = '%#SuperTabPanelCalDay#  '
    for d in a:entry.days
      if d.day == 0
        let line ..= '   '
      elseif get(d, 'today', 0)
        let line ..= '%#SuperTabPanelCalToday#' .. printf('%3d', d.day) .. '%#SuperTabPanelCalDay#'
      else
        let line ..= printf('%3d', d.day)
      endif
    endfor
    return line
  endif
endfunction

function! supertabpanel#widgets#calendar#render() abort
  let result = ''
  for entry in s:build()
    let result ..= s:render_line(entry) .. '%@'
  endfor
  return result
endfunction

function! supertabpanel#widgets#calendar#init() abort
  call s:setup_colors()
  augroup supertabpanel_calendar_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('calendar', #{
        \ icon: '📅',
        \ label: 'Calendar',
        \ render: function('supertabpanel#widgets#calendar#render'),
        \ })
endfunction
