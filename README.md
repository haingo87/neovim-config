# Neovim Config — C#/Unity & C++/CMake IDE

Personal DIY Neovim configuration optimized for C# (Unity), C++ (CMake), Go, and Dart/Flutter development on macOS, with AI completion, VSCode keybindings, DAP debugging, and per-project environment switching.

## Features

- **Per-project `.nvproj` files** — language-specific plugins (roslyn/clangd), formatters, and debug adapters gated by a single Lua config file with feature defaults and resolution
- **`nv` CLI** — routes files opened from Finder, Unity, or terminal to the correct running Neovim instance based on project membership; supports VSCode-style `-g file:line:col` syntax
- **Neovim.app** — native macOS app bundle (Swift launcher) for seamless Finder/Unity file opening via Apple Events
- **AI completion** — minuet-ai.nvim (Groq/Gemini/Ollama) for inline AI suggestions + gen.nvim for AI code fixes
- **DAP debugging** — full nvim-dap + dap-ui stack with VSCode F5/F9/F10/F11 keymaps
- **LSP & formatting** — roslyn (C#), clangd (C++), stylua (Lua), gopls (Go), dartls (Dart), csharpier/clang-format/gofumpt
- **Daemon-managed LSP lifecycle** — async LSP server registry with grace period, shared clangd instances via socat bridge
- **Catppuccin Mocha** — consistent theme across Neovim and Ghostty terminal
- **VSCode-compatible keybindings** — Ctrl+W closes buffer, Ctrl+Tab buffer switching, F12 for LSP actions, gj/gk wrap-friendly navigation
- **Orphan instances** — files outside any project open in a lightweight instance with project plugins disabled

## Requirements

- **Neovim** >= 0.10 (tested on 0.12.2)
- **Git** (for lazy.nvim bootstrapping)
- **Python 3** (for `nv` script)
- **fd** (`brew install fd`) — for Telescope file search
- **ripgrep** (`brew install ripgrep`) — for Telescope live grep
- **make** (for telescope-fzf-native)
- **socat** (`brew install socat`) — LSP stdio bridge for daemon-managed clangd
- **JetBrains Mono Nerd Font** — for icons
- **Ghostty** terminal (optional, config included)

### Language-specific tools

| Language | Tools |
|----------|-------|
| C# (Unity) | `roslyn` (via Mason), `csharpier`, `netcoredbg` |
| C++ | `clangd` (daemon-managed with socat bridge), `clang-format`, `codelldb` (via Mason) |
| Go | `gopls`, `gofumpt`, `delve` |
| Dart | `dartls`, `dart_format` |
| Lua | `lua_ls`, `stylua` |

## Installation

### macOS

```bash
# Clone the repo
git clone https://github.com/<user>/neovim-config.git /path/to/neovim-config

# Run the macOS installer (symlinks configs, nv, nvim-daemon, Neovim.app)
/path/to/neovim-config/install_mac.sh
```

The `install_mac.sh` script creates:
- `~/.config/nvim` → `/path/to/neovim-config/nvim`
- `~/.config/ghostty` → `/path/to/neovim-config/ghostty`
- `/usr/local/bin/nv` → `/path/to/neovim-config/nvim-open`
- `/usr/local/bin/nvim-daemon` → `/path/to/neovim-config/nvim-daemon`
- `/Applications/Neovim.app` → `/path/to/neovim-config/Neovim.app`
- Builds the native Swift launcher for the app bundle

### Linux

```bash
/path/to/neovim-config/install_linux.sh
```

On first launch, lazy.nvim will install all plugins. Open Mason (`:Mason`) to install LSP servers and DAP adapters, or run `:MasonInstallAll`.

### Manual PATH setup

If `install_mac.sh` doesn't suit your needs, symlink manually:

```bash
ln -sf /path/to/neovim-config/nvim-open /usr/local/bin/nv
ln -sf /path/to/neovim-config/nvim-daemon /usr/local/bin/nvim-daemon
```

Then configure your editor to use `nv` as the external editor command.

## Project Configuration (`.nvproj` file)

Create a `.nvproj` file in your project root. It's a Lua module returning a table:

```lua
-- C# / Unity project
return {
    features = {
        csharp = true,       -- roslyn LSP, csharpier, netcoredbg
        -- unity = true,     -- implies csharp, uses nvim-dap-unity
        -- format_on_save = true,  -- on by default
    },
    exclude = {
        files = { "*.meta" },
        dirs = { "Library", "Temp", "Build", "obj" },
    },
}
```

| Field | Values | Description |
|-------|--------|-------------|
| `features` | `csharp`, `unity`, `cpp`, `cmake`, `go`, `flutter`, `lua`, `debug`, `format_on_save` | Language features auto-enable LSP + formatter + DAP + treesitter |
| `features.debug` | `true` / `false` | On by default — set to `false` to disable |
| `features.format_on_save` | `true` / `false` | On by default — conform.nvim auto-format on save |
| `exclude.files` | `string[]` | File globs to hide in telescope (and rg-based filtering) |
| `exclude.dirs` | `string[]` | Directory names to hide in nvim-tree and telescope |

**Feature defaults:** `debug` and `format_on_save` are enabled by default. Add `debug = false` to your `.nvproj` to opt out.

**Feature implications:** `unity` implies `csharp`, `flutter` implies `dart`.

**Backward compatibility:** Old `env.type = "csharp"` is still detected but logs a deprecation warning. Migrate to `features = { csharp = true }`.

Without a `.nvproj` file, the editor still works — neo-tree auto-opens, terminal title shows the folder name, basic LSP servers (jsonls, yamlls, marksman) are available. Project-specific plugins (roslyn, conform, nvim-dap) remain inactive.

## Smart File Open (`nv`)

```
nv <file|directory> [-g file:line:col]
```

| Argument | Behavior |
|----------|----------|
| **File** inside a running project | Routes to that project's Neovim instance (opens in new tab) |
| **File** outside any project | Routes to the shared orphan Neovim instance |
| **Directory** with a running instance | Routes to the existing project instance |
| **Directory** not yet open | Launches a new project instance |
| `-g file:line:col` | VSCode-style open with cursor position (e.g., `nv -g src/foo.cs:42:10`) |

### OS Integration

- **Unity**: Preferences → External Tools → External Script Editor → `/usr/local/bin/nv`
- **Finder**: Set `nv` as default handler via `nvim-open.desktop`
- **Terminal**: `nv src/foo.cs`

### Daemon Architecture

`nv` is a pure file router. It does not detect projects or manage state — it delegates to `nvim-daemon`, a persistent background process.

**How it works:**
1. `nvim-daemon` runs as a background process listening on a Unix domain socket (`~/.local/state/nvim/daemon.sock`)
2. When Neovim starts, `init.lua` registers the instance with the daemon via `session.lua` + `daemon.lua` (socket-based JSON-lines protocol)
3. When a file is opened, `nv` asks the daemon which instance should receive it
4. The daemon routes by path prefix matching against registered project roots, with an orphan fallback for files outside any project
5. If a second Neovim instance starts in the same project, the daemon returns a `dup` response — the new instance routes its files to the existing one and exits

**Duplicate prevention:** Starting `nvim` in a project directory with a running instance auto-exits after routing files to the existing instance using `nvim --server --remote` and `bring_to_front()`.

**Redirect strategy:** When a `dup` instance exits, `redirect.lua` brings the original window to focus:
- **macOS:** `osascript` to bring the terminal process to front; detects Ghostty/Apple Terminal and tracks window/tab IDs for precise tab-aware focus
- **Linux X11:** `xdotool` to activate the terminal window and switch tabs via AT-SPI2 (`python-atspi`)
- **tmux:** `tmux select-pane` to switch to the right pane
- **SSH/Wayland:** Notification only (auto-focus unavailable)

**Daemon-managed LSP:** The daemon also manages LSP server lifecycles:
- `lsp_start` — starts LSP servers (e.g., clangd) as daemon subprocesses, returning a Unix socket path
- `lsp_stop` — terminates LSP servers by PID, with dedup protection
- Shared clangd instances: multiple Neovim sessions in the same C++ project share a single clangd process via a socat stdio bridge (`util.lsp`)

**`nvproj` changes:** Updating `.nvproj` does not require a daemon restart. Use `:ProjectReload` to re-detect the environment.

Inspect registered instances: `nv --list`

## Keybindings

### File & Buffer

| Key | Action |
|-----|--------|
| `Ctrl+W` | Close buffer |
| `Ctrl+T` | Find files (Telescope) |
| `Ctrl+Shift+F` | Live grep (Telescope) |
| `Ctrl+Tab` | Next buffer (MRU order) |
| `Ctrl+Shift+Tab` | Previous buffer (MRU order) |
| `]b` | Next buffer (linear order) |
| `[b` | Previous buffer (linear order) |
| `Ctrl+N` | Toggle Nvim-tree file explorer |

### Editor

| Key | Action |
|-----|--------|
| `Alt+Down/Up` | Move line/selection down/up |
| `Ctrl+Shift+K` | Delete line |
| `Ctrl+Backtick` | Toggle terminal (horizontal) |
| `<Down>`, `<Up>` | Display-line navigation (gj/gk — wrap-friendly) |

### LSP

| Key | Action |
|-----|--------|
| `F12` | Go to definition |
| `Ctrl+F12` | Go to implementation |
| `Shift+F12` | Find references |
| `F2` | Rename symbol |
| `Ctrl+.` | Code action |
| `Shift+Alt+F` | Format document |
| `Shift+K` | Hover documentation |
| `Ctrl+Shift+.` | Next diagnostic |

### Debug (DAP)

| Key | Action |
|-----|--------|
| `F5` | Continue |
| `F9` | Toggle breakpoint |
| `F10` | Step over |
| `F11` | Step into |
| `Shift+F11` | Step out |

### Leader (`<Space>`)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find buffers |
| `<leader>fh` | Help tags |
| `<leader>fs` | Document symbols |
| `<leader>w` | Close buffer |
| `<leader>ca` | Code action |
| `<leader>rn` | Rename |
| `<leader>hs` | Stage hunk (Git) |
| `<leader>hr` | Reset hunk (Git) |

## Plugins

### Completion & AI
- **minuet-ai.nvim** — AI inline completion via Groq, Ollama, or Gemini
- **gen.nvim** — AI-powered code fixes and text transformations
- **nvim-cmp** — Completion engine with LSP, buffer, path, snippet sources
- **LuaSnip** — Snippet expansion

### LSP
- **mason.nvim** — LSP server / DAP adapter / linter installation
- **mason-lspconfig.nvim** — Bridge between Mason and lspconfig
- **nvim-lspconfig** — LSP server configuration
- **lspsaga.nvim** — Enhanced LSP UI (hover, finder, code actions)
- **roslyn.nvim** — C# Roslyn LSP (C# projects only)
- **conform.nvim** — Formatting via csharpier, clang-format, stylua, gofumpt, dart_format
- **util/lsp.lua** — Shared clangd setup with socat bridge for daemon-managed instances

### Editor
- **nvim-tree.lua** — File explorer (project mode only)
- **bufferline.nvim** — Buffer tabs with close buttons
- **toggleterm.nvim** — Integrated terminal
- **which-key.nvim** — Keybinding hints popup
- **bufdelete.nvim** — Safe buffer deletion
- **Comment.nvim** — Comment toggling
- **vim-sleuth** — Auto-detect indentation
- **nvim-scrollview** — Scrollbar indicator

### Debug
- **nvim-dap** — Debug adapter protocol client
- **nvim-dap-ui** — Debug UI (scopes, breakpoints, stacks, watches, REPL, console)
- **nvim-dap-virtual-text** — Inline variable values
- **nvim-dap-unity** — Unity debugger integration
- **mason-nvim-dap.nvim** — DAP adapter installation

### UI
- **catppuccin/nvim** — Mocha colorscheme
- **lualine.nvim** — Statusline
- **indent-blankline.nvim** — Indentation guides
- **gitsigns.nvim** — Git gutter signs
- **todo-comments.nvim** — Highlight TODO/FIXME/HACK/NOTE

### Syntax
- **nvim-treesitter** — Syntax parsing, highlighting, indentation
- **nvim-treesitter-textobjects** — Text objects via treesitter
- **nvim-ts-autotag** — Auto-close HTML/JSX tags

## Commands

| Command | Description |
|---------|-------------|
| `:ProjectReload` | Re-detect `.nvproj`, reinstall LSP/DAP, reload project plugins |
| `:Totabs` | Convert spaces to tabs respecting `tabstop` |
| `nv --list` | Show registered project instances with alive/dead status |

## File Structure

```
neovim-config/
├── ghostty/config              # Ghostty terminal config
├── nvim/
│   ├── init.lua                # Entry point, server start, session lifecycle, daemon LSP hooks
│   ├── lazy-lock.json          # Plugin version lockfile
│   └── lua/
│       ├── config/
│       │   ├── options.lua     # Editor options
│       │   ├── keymaps.lua     # Keybindings
│       │   └── autocmds.lua    # Autocommands
│       ├── plugins/
│       │   ├── completion.lua  # minuet-ai, gen.nvim, nvim-cmp, LuaSnip
│       │   ├── lsp.lua         # Mason, lspconfig, lspsaga (feature-gated)
│       │   ├── editor.lua      # Nvim-tree, Telescope, bufferline, which-key, etc.
│       │   ├── debug.lua       # nvim-dap, dap-ui, adapters (feature-gated)
│       │   ├── ui.lua          # Colorscheme, statusline, gitsigns, scrollview, etc.
│       │   ├── treesitter.lua  # Treesitter, autotag, Comment, sleuth
│       │   └── lang.lua        # roslyn, conform (feature-gated)
│       └── util/
│           ├── project.lua     # .nvproj detection, LSP/DAP setup
│           ├── features.lua    # Feature resolution, defaults, implication, validation
│           ├── session.lua     # Instance registration + lsp_start/lsp_stop helpers
│           ├── daemon.lua      # Low-level daemon socket JSON-lines client
│           ├── lsp.lua         # Shared clangd setup with socat bridge
│           ├── redirect.lua    # Window focus for macOS/Linux/tmux/SSH
│           └── hash.lua        # SHA-256 utility for socket names
├── Neovim.app/                 # macOS app bundle for Finder/Unity file opening
│   ├── Contents/
│   │   ├── Info.plist          # App metadata, URL/document type handlers
│   │   ├── MacOS/neovim        # Compiled Swift launcher binary
│   │   └── Resources/icon.icns # App icon
├── neovim-launcher.swift       # Swift source for native macOS Apple Event handling
├── nvim-daemon                 # Persistent background daemon (Unix socket, JSON-lines protocol)
├── nvim-open                   # CLI script for smart file routing (talks to daemon, supports -g flag)
├── nvim-open.desktop           # Linux desktop entry for file association
├── install_mac.sh              # macOS installation script (symlinks + app bundle build)
├── install_linux.sh            # Linux installation script
├── .nvproj.example            # Template .nvproj file with features table
└── tests/
    ├── conftest.py             # Pytest fixtures (daemon startup/shutdown, temp sockets)
    └── test_daemon.py          # Protocol, routing, and LSP command tests
```
