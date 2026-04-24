" vim-supertabpanel : diagnostics count widget (works with any source that
" populates the quickfix/location list; supports :LspDiagnostics if available).

function! s:setup_colors() abort
  hi default SuperTabPanelDiagHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelDiagErr  guifg=#f7768e guibg=#1a1b26 gui=bold cterm=bold ctermfg=204 ctermbg=234
  hi default SuperTabPanelDiagWarn guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelDiagInfo guifg=#7aa2f7 guibg=#1a1b26 ctermfg=111 ctermbg=234
  hi default SuperTabPanelDiagOk   guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
endfunction

function! s:count() abort
  let errs = 0
  let warns = 0
  let infos = 0
  for q in getqflist() + getloclist(0)
    if q.type ==? 'E' || q.nr > 0 && q.type ==? ''
      let errs += 1
    elseif q.type ==? 'W'
      let warns += 1
    else
      let infos += 1
    endif
  endfor
  return #{ errors: errs, warnings: warns, info: infos }
endfunction

function! supertabpanel#widgets#diagnostics#open_qf(info) abort
  copen
  return 1
endfunction

function! supertabpanel#widgets#diagnostics#render() abort
  let c = s:count()
  let result = '%#SuperTabPanelDiagHead#  🩺 Diagnostics%@'
  if c.errors == 0 && c.warnings == 0 && c.info == 0
    let result ..= '%0[supertabpanel#widgets#diagnostics#open_qf]'
          \ .. '%#SuperTabPanelDiagOk#  ✔ clean%[]%@'
    return result
  endif
  let result ..= '%0[supertabpanel#widgets#diagnostics#open_qf]'
        \ .. '%#SuperTabPanelDiagErr#  ✘ ' .. c.errors .. ' errors%[]%@'
  let result ..= '%0[supertabpanel#widgets#diagnostics#open_qf]'
        \ .. '%#SuperTabPanelDiagWarn#  ⚠ ' .. c.warnings .. ' warnings%[]%@'
  if c.info > 0
    let result ..= '%0[supertabpanel#widgets#diagnostics#open_qf]'
          \ .. '%#SuperTabPanelDiagInfo#  ℹ ' .. c.info .. ' info%[]%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#diagnostics#activate() abort
  augroup supertabpanel_diag
    autocmd!
    autocmd QuickFixCmdPost *
          \ if &showtabpanel | redrawtabpanel | endif
    if exists('##DiagnosticChanged')
      autocmd DiagnosticChanged *
            \ if &showtabpanel | redrawtabpanel | endif
    endif
  augroup END
endfunction

function! supertabpanel#widgets#diagnostics#deactivate() abort
  augroup supertabpanel_diag
    autocmd!
  augroup END
endfunction

function! supertabpanel#widgets#diagnostics#init() abort
  call s:setup_colors()
  augroup supertabpanel_diag_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('diagnostics', #{
        \ icon: '🩺',
        \ label: 'Diagnostics',
        \ render: function('supertabpanel#widgets#diagnostics#render'),
        \ on_activate: function('supertabpanel#widgets#diagnostics#activate'),
        \ on_deactivate: function('supertabpanel#widgets#diagnostics#deactivate'),
        \ })
endfunction
