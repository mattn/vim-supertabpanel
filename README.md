# vim-supertabpanel

A tabpanel-based dashboard for Vim with clickable widgets for git, feeds,
system monitoring, a file tree, games, and more. Widgets are grouped
into rotatable panels that you switch between with a single key.

## Requirements

- Vim 9.2 with the `+tabpanel` feature (`:echo has('tabpanel')` returns 1)

## Install

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'mattn/vim-supertabpanel'
```

With Vim's built-in package system:

```sh
git clone https://github.com/mattn/vim-supertabpanel \
    ~/.vim/pack/plugins/start/vim-supertabpanel
```

## Usage

The panel auto-configures on `VimEnter` with a default widget layout.
Three commands and three `<Plug>` maps are provided:

| Command                      | Default map | Description                |
| ---------------------------- | ----------- | -------------------------- |
| `:SuperTabPanel`             | `,tt`       | Toggle the panel open/shut |
| `:SuperTabPanelRotate`       | `,tr`       | Rotate to the next panel   |
| `:SuperTabPanelRotateBack`   | `,tR`       | Rotate to the previous one |

The default maps are only installed if you haven't already bound
`<Plug>(supertabpanel-toggle)`, `<Plug>(supertabpanel-rotate)` or
`<Plug>(supertabpanel-rotate-back)` yourself.

Most widgets are clickable: click a buffer name to open it, a PR row to
open the URL in your browser, a station name to start streaming, etc.

## Panels and widgets

The default layout groups widgets into these panels:

- **Time** — clock, calendar, weather, sunrise/sunset, moon phase, world clock
- **Feed** — BTC chart, stock ticker, Asahi news
- **Tech** — Hacker News, GitHub trending
- **Git** — git status, diff hunks, stash, pull requests, GitHub notifications
- **Nav** — buffers, recent files, marks, jumplist, tags
- **Edit** — quickfix, diagnostics, registers, macros, undo, clipboard, terminals, quicklaunch
- **Work** — todo, pomodoro, system monitor (CPU/MEM/BAT)
- **Ops** — build, tests, docker, Kubernetes pods
- **AI** — Claude chat, explain, commit message, translate
- **Game** — tetris, snake, 2048, game of life
- **Media** — piano, web radio, podcast
- **Fun** — random 名言 (meigen), ASCII art
- **Files** — file tree

## Configuration

```vim
" Override the entire panel layout (see plugin/supertabpanel.vim for the default).
let g:supertabpanel_panels = [
      \ #{ name: 'Time', items: ['clock', 'calendar'] },
      \ #{ name: 'Git',  items: ['gitstatus', 'diff'] },
      \ ]

" Panel width in cells (default 32).
let g:supertabpanel_columns = 32

" Index of the panel shown first (default 0).
let g:supertabpanel_default = 0
```

A few widgets take their own options, for example:

```vim
let g:supertabpanel_worldclock_zones = [
      \ #{ label: 'Tokyo',  tz: 'Asia/Tokyo'         },
      \ #{ label: 'London', tz: 'Europe/London'      },
      \ ]

let g:supertabpanel_radio_stations = [
      \ #{ name: 'SomaFM Groove Salad', url: 'https://somafm.com/groovesalad.pls' },
      \ ]

let g:supertabpanel_podcast_feeds = [
      \ #{ name: 'Show A', url: 'https://feeds.example.com/a.rss' },
      \ #{ name: 'Show B', url: 'https://feeds.example.com/b.rss' },
      \ ]
" Single-feed form is still supported for backward compat:
" let g:supertabpanel_podcast_feed = 'https://feeds.example.com/my.rss'
let g:supertabpanel_sunmoon_lat     = 35.6895
let g:supertabpanel_sunmoon_lng     = 139.6917
let g:supertabpanel_trending_lang   = 'go'
let g:supertabpanel_k8s_all_namespaces = 0
```

## Optional external tools

Widgets degrade gracefully when their tool is missing, but for full
functionality install the following:

- `curl` — all network widgets (news, podcast, trending, weather, BTC, etc.)
- `git` — git status, diff, stash
- `gh` — GitHub PRs, notifications, trending
- `kubectl` — k8s pods
- `docker` — docker widget
- `ffplay` (FFmpeg) / `sox` (`play`) — radio, podcast, piano
- `ctags` — tags widget

## License

MIT

## Author

Yasuhiro Matsumoto (a.k.a. mattn)
