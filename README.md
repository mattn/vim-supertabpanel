# vim-supertabpanel

A tabpanel-based dashboard for Vim with clickable widgets for git, feeds,
system monitoring, a file tree, games, and more. Widgets are grouped
into rotatable panels that you switch between with a single key.

https://github.com/user-attachments/assets/6dadef02-efd8-4815-977e-1b78db27e70b

## Requirements

- Vim 9.2.386 or later (`scroll`/`scrollbar` support in `'tabpanelopt'`)
- Built with the `+tabpanel` feature (`:echo has('tabpanel')` returns 1)

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

| Command                         | Default map | Description                             |
| ------------------------------- | ----------- | --------------------------------------- |
| `:SuperTabPanel`                | `,tt`       | Toggle the panel open/shut              |
| `:SuperTabPanelRotate`          | `,tr`       | Rotate to the next panel                |
| `:SuperTabPanelRotateBack`      | `,tR`       | Rotate to the previous one              |
| `:SuperTabPanelActivate {name}` |             | Jump to a named panel (tab-completes)   |

From Vim script the same is available programmatically:

```vim
echo supertabpanel#panel_names()           " ['Time', 'Feed', 'Tech', ...]
echo supertabpanel#current_panel_name()    " 'Feed'
call supertabpanel#activate('Feed')        " by name
call supertabpanel#activate(2)             " by index
```

The default maps are only installed if you haven't already bound
`<Plug>(supertabpanel-toggle)`, `<Plug>(supertabpanel-rotate)` or
`<Plug>(supertabpanel-rotate-back)` yourself.

Most widgets are clickable: click a buffer name to open it, a PR row to
open the URL in your browser, a station name to start streaming, etc.

## Panels and widgets

The default layout groups widgets into these panels:

- **Time** — clock, calendar, weather, sunrise/sunset, moon phase, world clock
- **Feed** — BTC chart, stock ticker, RSS feed (Asahi news by default)
- **Tech** — Hacker News, GitHub trending
- **Git** — git status, diff hunks, stash, pull requests, GitHub notifications
- **Nav** — buffers, recent files, marks, jumplist, tags
- **Edit** — quickfix, diagnostics, registers, macros, undo, clipboard, terminals, quicklaunch
- **Work** — todo, pomodoro
- **Ops** — build, tests, docker, Kubernetes pods, system monitor (CPU/MEM/BAT)
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

Each item in a panel's `items` list can take one of two forms:

- **Bare widget name** — `'clock'` / `'weather'` / `'supertabpanel#widgets#weather'`.
  The widget is instantiated with default parameters.
- **Dict with params** — `#{ widget: '<name>', params: #{ ... } }`.
  The widget is instantiated with the given parameters. Using the dict
  form you can place the same widget in a panel multiple times with
  different parameters.

All per-widget options live in `params` — there are no `g:supertabpanel_<widget>_*`
globals any more.

```vim
let g:supertabpanel_panels = [
      \ #{ name: 'Time', items: [
      \   'clock',
      \   'calendar',
      \   #{ widget: 'weather',    params: #{ location: 'Tokyo' } },
      \   #{ widget: 'sunmoon',    params: #{ lat: 35.6895, lng: 139.6917 } },
      \   #{ widget: 'worldclock', params: #{ zones: [
      \     #{ label: 'Tokyo',  tz: 'Asia/Tokyo'         },
      \     #{ label: 'London', tz: 'Europe/London'      },
      \     #{ label: 'NYC',    tz: 'America/New_York'   },
      \   ]}},
      \ ]},
      \ #{ name: 'News', items: [
      \   #{ widget: 'rssfeed', params: #{
      \     name: '朝日新聞',
      \     url:  'https://www.asahi.com/rss/asahi/newsheadlines.rdf',
      \   }},
      \   #{ widget: 'rssfeed', params: #{
      \     name: 'Hatena',
      \     url:  'https://b.hatena.ne.jp/hotentry.rss',
      \     icon: '🔖',
      \   }},
      \ ]},
      \ #{ name: 'Podcasts', items: [
      \   #{ widget: 'podcast', params: #{
      \     name: 'Show A',
      \     url:  'https://feeds.example.com/a.rss',
      \   }},
      \   #{ widget: 'podcast', params: #{
      \     name: 'Show B',
      \     url:  'https://feeds.example.com/b.rss',
      \   }},
      \ ]},
      \ #{ name: 'Media', items: [
      \   #{ widget: 'radio', params: #{ stations: [
      \     #{ name: 'SomaFM Groove Salad', url: 'https://somafm.com/groovesalad.pls' },
      \   ]}},
      \ ]},
      \ #{ name: 'Tech', items: [
      \   #{ widget: 'github_trending', params: #{ lang: 'go' } },
      \ ]},
      \ #{ name: 'Ops', items: [
      \   #{ widget: 'tests',    params: #{ cmd: 'go test ./...', on_save: 1 } },
      \   #{ widget: 'k8s_pods', params: #{ all_namespaces: 1 } },
      \ ]},
      \ #{ name: 'AI', items: [
      \   #{ widget: 'claudechat', params: #{ model: 'claude-sonnet-4-5' } },
      \   #{ widget: 'translate',  params: #{ source: 'en', target: 'ja' } },
      \ ]},
      \ ]
```

### Widget parameters

| widget            | params                                                       |
| ----------------- | ------------------------------------------------------------ |
| `rssfeed`         | `url` (required), `name`, `icon`, `max`, `content_selector` (CSS-ish: `tag` / `#id` / `.class`) |
| `podcast`         | `url` (required), `name`, `icon`                             |
| `radio`           | `stations` (list of `#{ name, url }`)                        |
| `stockticker`     | `symbols` (list of Yahoo tickers)                            |
| `worldclock`      | `zones` (list of `#{ label, tz }`)                           |
| `weather`         | `location` (wttr.in query, default geoip)                    |
| `sunmoon`         | `lat`, `lng`                                                 |
| `asciiart`        | `arts` (list of frames; each frame is a list of lines)       |
| `quicklaunch`     | `items` (list of `#{ icon, label, cmd }`)                    |
| `todo`            | `file`                                                       |
| `tests`           | `cmd`, `on_save`                                             |
| `translate`       | `source`, `target`                                           |
| `claudechat`, `explain`, `commit_msg` | `model`                                  |
| `github_trending` | `lang`                                                       |
| `k8s_pods`        | `all_namespaces`                                             |

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
