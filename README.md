# Neovim Config — C#/Unity & C++/CMake IDE

Personal DIY Neovim configuration optimized for C# (Unity) and C++ (CMake) development on macOS, with AI completion, VSCode keybindings, DAP debugging, and per-project environment switching.

## Features

- **Per-project `.nvproj` files** — language-specific plugins (roslyn/clangd), formatters, and debug adapters gated by a single Lua config file
- **Smart instance modes** — `nvim <dir>` starts a project instance with full features; `nvim <file>` starts a lightweight edit session
- **Duplicate detection** — opening `nvim ./` in a project that's already running redirects to the existing instance
- **GitHub Copilot** — AI auto-complete via Tab (no chat panel)
- **DAP debugging** — full nvim-dap + dap-ui stack with VSCode F5/F9/F10/F11 keymaps
- **LSP & formatting** — roslyn (C#), clangd (C++), stylua (Lua), csharpier/clang-format
- **Catppuccin Mocha** — consistent theme across Neovim and Ghostty terminal
- **VSCode-compatible keybindings** — Ctrl+W closes buffer, Ctrl+Tab buffer switching, F12 for LSP actions

## Requirements

- **Neovim** >= 0.10 (tested on 0.12.2)
- **Git** (for lazy.nvim bootstrapping)
- **fd** (`brew install fd`) — for Telescope file search
- **ripgrep** (`brew install ripgrep`) — for Telescope live grep
- **make** (for telescope-fzf-native)
- **JetBrains Mono Nerd Font** — for icons
- **Ghostty** terminal (optional, config included)

### Language-specific tools

| Language | Tools |
|----------|-------|
| C# (Unity) | `roslyn` (via Mason), `csharpier`, `netcoredbg` |
| C++ | `clangd`, `clang-format`, `codelldb` (via Mason) |
| Lua | `lua_ls`, `stylua` |

## Installation

```bash
# Clone the repo
git clone https://github.com/<user>/neovim-config.git /path/to/neovim-config

# Symlink configs
/path/to/neovim-config/link-config.sh
```

The `link-config.sh` script creates:
- `~/.config/nvim` → `/path/to/neovim-config/nvim`
- `~/.config/ghostty` → `/path/to/neovim-config/ghostty`

On first launch, lazy.nvim will install all plugins. Open Mason (`:Mason`) to install LSP servers and DAP adapters, or run `:MasonInstallAll`.

## Instance Modes

| Invocation | Mode | Features |
|------------|------|----------|
| `nvim ./` or `nvim <dir>` | Project | Full: nvim-tree, telescope, which-key, .nvproj, socket for external tools |
| `nvim <file>` | Light | Minimal: no nvim-tree, no telescope, no which-key |
| `nvim` (no args) | Light | Same as above |

### Duplicate Detection

When you run `nvim ./` in a directory where a project instance is already running, the new instance detects the existing one, sends any file arguments to it, brings it to front, and exits. No daemon needed — detection uses a direct socket probe.

### External Tool Integration

External tools (Unity, Godot, etc.) can open files in a running project instance by connecting to its deterministic socket:

```bash
# Compute the socket path from the project root directory:
# ~/.local/state/nvim/sockets/nv-<sha256_short(project_root)>.sock

# Open a file (brings window to front automatically):
nvim --server <socket> --remote-expr "require('util.redirect').open_file('/path/to/file.cs', 42)"

# Just focus the window:
nvim --server <socket> --remote-expr "require('util.redirect').bring_to_front()"
```

The socket name is the first 12 characters of the SHA-256 hash of the project root path.

## Project Configuration (`.nvproj` file)

Create a `.nvproj` file in your project root. It's a Lua module returning a table:

```lua
-- C# / Unity project
return {
    env = {
        type = "csharp",
    },
    features = {
        debug = true,
        format_on_save = true,
    },
}

-- C++ / CMake project
-- return {
--     env = { type = "cpp" },
--     features = { debug = true, format_on_save = true },
-- }
```

| Field | Values | Description |
|-------|--------|-------------|
| `env.type` | `"csharp"`, `"cpp"` | Determines LSP server, debug adapter, treesitter parsers |
| `features.debug` | `true` / `false` | Enables nvim-dap + dap-ui |
| `features.format_on_save` | `true` / `false` | Auto-format on write via conform.nvim |
| `exclude.files` | `string[]` | File globs to hide in telescope (and rg-based filtering) |
| `exclude.dirs` | `string[]` | Directory names to hide in nvim-tree and telescope |

## Keybindings

### File & Buffer

| Key | Action |
|-----|--------|
| `Ctrl+W` | Close buffer |
| `Ctrl+T` | Find files (Telescope) |
| `Ctrl+Shift+F` | Live grep (Telescope) |
| `Ctrl+Shift+P` | Command palette (Telescope) |
| `Ctrl+Tab` | Next buffer (MRU order) |
| `Ctrl+Shift+Tab` | Previous buffer (MRU order) |
| `]b` | Next buffer (linear order) |
| `[b` | Previous buffer (linear order) |
| `Ctrl+N` | Toggle Neo-tree file explorer |

### Editor

| Key | Action |
|-----|--------|
| `Alt+Down/Up` | Move line/selection down/up |
| `Ctrl+Shift+K` | Delete line |
| `Ctrl+/` | Toggle comment |
| `Ctrl+Backtick` | Toggle terminal (horizontal) |

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
- **copilot.lua** — GitHub Copilot (Tab accepts ghost text)
- **nvim-cmp** — Completion engine with LSP, buffer, path, snippet sources
- **LuaSnip** — Snippet expansion

### LSP
- **mason.nvim** — LSP server / DAP adapter / linter installation
- **mason-lspconfig.nvim** — Bridge between Mason and lspconfig
- **nvim-lspconfig** — LSP server configuration
- **lspsaga.nvim** — Enhanced LSP UI (hover, finder, code actions)
- **roslyn.nvim** — C# Roslyn LSP (C# projects only)
- **conform.nvim** — Formatting via csharpier, clang-format, stylua

### Editor
- **nvim-tree.lua** — File explorer (project mode only)
- **telescope.nvim** — Fuzzy finder with fzf-native (project mode only)
- **bufferline.nvim** — Buffer tabs with close buttons
- **toggleterm.nvim** — Integrated terminal
- **which-key.nvim** — Keybinding hints popup (project mode only)
- **bufdelete.nvim** — Safe buffer deletion
- **Comment.nvim** — Comment toggling
- **vim-sleuth** — Auto-detect indentation

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

## File Structure

```
neovim-config/
├── ghostty/config              # Ghostty terminal config
├── nvim/
│   ├── init.lua                # Entry point, mode detection, socket lifecycle
│   ├── lazy-lock.json          # Plugin version lockfile
│   └── lua/
│       ├── config/
│       │   ├── options.lua     # Editor options
│       │   ├── keymaps.lua     # Keybindings
│       │   └── autocmds.lua    # Autocommands
│       ├── plugins/
│       │   ├── completion.lua  # Copilot, nvim-cmp, LuaSnip
│       │   ├── lsp.lua         # Mason, lspconfig, lspsaga
│       │   ├── editor.lua      # Neo-tree, Telescope, bufferline, etc.
│       │   ├── debug.lua       # nvim-dap, dap-ui, adapters
│       │   ├── ui.lua          # Colorscheme, statusline, gitsigns, etc.
│       │   ├── treesitter.lua  # Treesitter, autotag, Comment
│       │   └── lang.lua        # roslyn, conform (project-gated)
│       └── util/
│           ├── project.lua     # .nvproj detection, LSP/DAP setup
│           ├── redirect.lua    # Window focus + open_file for external tools
│           └── hash.lua        # SHA-256 utility for socket names
├── link-config.sh              # Symlink setup helper
└── .nvproj.example             # Template .nvproj file
```
