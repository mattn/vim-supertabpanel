" vim-supertabpanel : system monitor widget (CPU / memory / battery)

let s:timer = -1
let s:prev_cpu = []
let s:cpu_cached = 0
let s:mem_cached = 0
let s:bat_cached = [-1, '']
let s:win_job = v:null

function! s:setup_colors() abort
  hi default SuperTabPanelSysHead guifg=#7dcfff guibg=#1a1b26 gui=bold cterm=bold ctermfg=117 ctermbg=234
  hi default SuperTabPanelSys     guifg=#a9b1d6 guibg=#1a1b26 ctermfg=249 ctermbg=234
  hi default SuperTabPanelSysOk   guifg=#9ece6a guibg=#1a1b26 ctermfg=149 ctermbg=234
  hi default SuperTabPanelSysWarn guifg=#e0af68 guibg=#1a1b26 ctermfg=179 ctermbg=234
  hi default SuperTabPanelSysHot  guifg=#f7768e guibg=#1a1b26 ctermfg=204 ctermbg=234
endfunction

function! s:read_cpu() abort
  try
    for l in readfile('/proc/stat')
      if l =~# '^cpu '
        let parts = split(l)[1:]
        return map(parts, 'str2nr(v:val)')
      endif
    endfor
  catch
  endtry
  return []
endfunction

function! s:cpu_pct() abort
  let cur = s:read_cpu()
  if empty(s:prev_cpu) || empty(cur)
    let s:prev_cpu = cur
    return 0
  endif
  let prev_idle = s:prev_cpu[3] + (len(s:prev_cpu) > 4 ? s:prev_cpu[4] : 0)
  let cur_idle  = cur[3]         + (len(cur) > 4         ? cur[4]         : 0)
  let prev_total = 0
  for v in s:prev_cpu
    let prev_total += v
  endfor
  let cur_total = 0
  for v in cur
    let cur_total += v
  endfor
  let dt = cur_total - prev_total
  let di = cur_idle - prev_idle
  let s:prev_cpu = cur
  if dt <= 0
    return 0
  endif
  return float2nr(100.0 * (dt - di) / dt)
endfunction

function! s:mem_pct() abort
  try
    let total = 0
    let avail = 0
    for l in readfile('/proc/meminfo')
      if l =~# '^MemTotal:'
        let total = str2nr(matchstr(l, '\d\+'))
      elseif l =~# '^MemAvailable:'
        let avail = str2nr(matchstr(l, '\d\+'))
      endif
    endfor
    if total > 0
      return float2nr(100.0 * (total - avail) / total)
    endif
  catch
  endtry
  return 0
endfunction

function! s:battery() abort
  if !has('unix') || has('mac')
    return [-1, '']
  endif
  try
    let dirs = glob('/sys/class/power_supply/BAT*', 0, 1)
    if empty(dirs)
      return [-1, '']
    endif
    let dir = dirs[0]
    let cap_file = dir .. '/capacity'
    let stat_file = dir .. '/status'
    if !filereadable(cap_file)
      return [-1, '']
    endif
    let pct = str2nr(get(readfile(cap_file), 0, '0'))
    let status = filereadable(stat_file) ? get(readfile(stat_file), 0, '') : ''
    return [pct, status]
  catch
  endtry
  return [-1, '']
endfunction

" ---- Windows (async PowerShell) ----
function! s:win_out(ch, msg) abort
  let line = substitute(a:msg, '\r$', '', '')
  if line =~# '^CPU='
    let s:cpu_cached = str2nr(matchstr(line, '\d\+'))
  elseif line =~# '^MEM='
    let s:mem_cached = str2nr(matchstr(line, '\d\+'))
  elseif line =~# '^BAT='
    let s:bat_cached[0] = str2nr(matchstr(line, '\d\+'))
  elseif line =~# '^STATUS='
    let code = str2nr(matchstr(line, '\d\+'))
    let s:bat_cached[1] = code == 2 ? 'Charging' : (code == 3 ? 'Full' : '')
  endif
endfunction

function! s:win_exit(job, status) abort
  let s:win_job = v:null
  redrawtabpanel
endfunction

function! s:win_refresh() abort
  if s:win_job isnot v:null && job_status(s:win_job) ==# 'run'
    return
  endif
  let ps = join([
        \ '$ErrorActionPreference=''SilentlyContinue'';',
        \ '$o=Get-CimInstance Win32_OperatingSystem;',
        \ 'if($o){''MEM=''+[int](100-100*$o.FreePhysicalMemory/$o.TotalVisibleMemorySize)}',
        \ '$c=Get-CimInstance Win32_Processor|Measure-Object -Property LoadPercentage -Average;',
        \ 'if($c){''CPU=''+[int]$c.Average}',
        \ '$b=Get-CimInstance Win32_Battery;',
        \ 'if($b){''BAT=''+[int]$b.EstimatedChargeRemaining;''STATUS=''+[int]$b.BatteryStatus}',
        \ ], ' ')
  let cmd = ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', ps]
  try
    let s:win_job = job_start(cmd, #{
          \ out_cb: function('s:win_out'),
          \ exit_cb: function('s:win_exit'),
          \ out_mode: 'nl',
          \ err_io: 'null',
          \ })
  catch
    let s:win_job = v:null
  endtry
endfunction

function! s:bat_icon(status) abort
  if a:status ==# 'Charging'
    return '⚡'
  elseif a:status ==# 'Full'
    return '🔌'
  endif
  return '🔋'
endfunction

function! s:bat_hl(pct, status) abort
  if a:status ==# 'Charging' || a:status ==# 'Full'
    return '%#SuperTabPanelSysOk#'
  endif
  if a:pct <= 15
    return '%#SuperTabPanelSysHot#'
  elseif a:pct <= 30
    return '%#SuperTabPanelSysWarn#'
  endif
  return '%#SuperTabPanelSysOk#'
endfunction

function! s:bar(pct, width) abort
  let filled = a:pct * a:width / 100
  if filled > a:width
    let filled = a:width
  endif
  return repeat('█', filled) .. repeat('░', a:width - filled)
endfunction

function! s:hl_for(pct) abort
  if a:pct >= 85
    return '%#SuperTabPanelSysHot#'
  elseif a:pct >= 60
    return '%#SuperTabPanelSysWarn#'
  endif
  return '%#SuperTabPanelSysOk#'
endfunction

function! s:refresh(timer) abort
  if has('win32')
    call s:win_refresh()
    return
  endif
  let s:cpu_cached = s:cpu_pct()
  let s:mem_cached = s:mem_pct()
  let s:bat_cached = s:battery()
  redrawtabpanel
endfunction

function! supertabpanel#widgets#sysmon#render() abort
  let cpu = s:cpu_cached
  let mem = s:mem_cached
  let bar_w = supertabpanel#content_width(5)
  let result = '%#SuperTabPanelSysHead#  📊 System%@'
  let result ..= '%#SuperTabPanelSys#  CPU ' .. printf('%3d%%%%', cpu) .. '%@'
  let result ..= s:hl_for(cpu) .. '  ' .. s:bar(cpu, bar_w) .. '%@'
  let result ..= '%#SuperTabPanelSys#  MEM ' .. printf('%3d%%%%', mem) .. '%@'
  let result ..= s:hl_for(mem) .. '  ' .. s:bar(mem, bar_w) .. '%@'
  let [bat, status] = s:bat_cached
  if bat >= 0
    let icon = s:bat_icon(status)
    let result ..= '%#SuperTabPanelSys#  BAT ' .. printf('%3d%%%%', bat) .. icon .. '%@'
    let result ..= s:bat_hl(bat, status) .. '  ' .. s:bar(bat, bar_w) .. '%@'
  endif
  return result
endfunction

function! supertabpanel#widgets#sysmon#activate() abort
  if s:timer == -1
    let s:prev_cpu = s:read_cpu()
    call s:refresh(0)
    let s:timer = timer_start(2000,
          \ function('s:refresh'), #{ repeat: -1 })
  endif
endfunction

function! supertabpanel#widgets#sysmon#deactivate() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! supertabpanel#widgets#sysmon#init() abort
  call s:setup_colors()
  augroup supertabpanel_sys_colors
    autocmd!
    autocmd ColorScheme * call s:setup_colors()
  augroup END
  call supertabpanel#register('sysmon', #{
        \ icon: '📊',
        \ label: 'System',
        \ render: function('supertabpanel#widgets#sysmon#render'),
        \ on_activate: function('supertabpanel#widgets#sysmon#activate'),
        \ on_deactivate: function('supertabpanel#widgets#sysmon#deactivate'),
        \ })
endfunction
