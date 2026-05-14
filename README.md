# Neovim Config — C#/Unity & C++/CMake IDE

Personal DIY Neovim configuration optimized for C# (Unity) and C++ (CMake) development on macOS, with AI completion, VSCode keybindings, DAP debugging, and per-project environment switching.

## Features

- **Per-project `.project` files** — language-specific plugins (roslyn/clangd), formatters, and debug adapters gated by a single Lua config file
- **Smart file open (`nvim-open`)** — routes files opened from Finder, Unity, or terminal to the correct running Neovim instance based on project membership
- **GitHub Copilot** — AI auto-complete via Tab (no chat panel)
- **DAP debugging** — full nvim-dap + dap-ui stack with VSCode F5/F9/F10/F11 keymaps
- **LSP & formatting** — roslyn (C#), clangd (C++), stylua (Lua), csharpier/clang-format
- **Catppuccin Mocha** — consistent theme across Neovim and Ghostty terminal
- **VSCode-compatible keybindings** — Ctrl+W closes buffer, Ctrl+Tab buffer switching, F12 for LSP actions
- **Orphan instances** — files outside any project open in a lightweight instance with project plugins disabled

## Requirements

- **Neovim** >= 0.10 (tested on 0.12.2)
- **Git** (for lazy.nvim bootstrapping)
- **Python 3** (for `nvim-open` script)
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

Add `nvim-open` to your PATH:

```bash
ln -sf /path/to/neovim-config/nvim-open ~/.local/bin/nvim-open
```

On first launch, lazy.nvim will install all plugins. Open Mason (`:Mason`) to install LSP servers and DAP adapters, or run `:MasonInstallAll`.

## Project Configuration (`.project` file)

Create a `.project` file in your project root. It's a Lua module returning a table:

```lua
-- C# / Unity project
return {
    env = {
        type = "csharp",
    },
    features = {
        debug = true,           -- nvim-dap + dap-ui + adapters
        format_on_save = true,  -- conform.nvim auto-format
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
| `exclude.files` | `string[]` | File globs to hide in neo-tree and telescope |
| `exclude.dirs` | `string[]` | Directory names to hide in neo-tree and telescope |

Without a `.project` file, the editor still works — neo-tree auto-opens, terminal title shows the folder name, basic LSP servers (lua_ls, jsonls, yamlls, marksman) are available. Project-specific plugins (roslyn, conform, nvim-dap) remain inactive.

## Smart File Open (`nvim-open`)

```
nvim-open <file|directory>
```

| Argument | Behavior |
|----------|----------|
| **File** inside a running project | Routes to that project's Neovim instance (opens in new tab) |
| **File** outside any project | Routes to the shared orphan Neovim instance |
| **Directory** with a running instance | Routes to the existing project instance |
| **Directory** not yet open | Launches a new project instance |

### OS Integration

- **Unity**: Preferences → External Tools → External Script Editor → `nvim-open`
- **Finder**: Set `nvim-open` as default handler for source file types
- **Terminal**: `nvim-open src/foo.cs`

### Session Registry

Running Neovim instances register themselves in `~/.local/state/nvim/sessions.json`. The `nvim-open` script reads this file to determine which project a file belongs to. Health checks automatically prune dead entries.

Inspect with: `nvim-open --list`

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
- **neo-tree.nvim** — File explorer (v3)
- **telescope.nvim** — Fuzzy finder with fzf-native
- **bufferline.nvim** — Buffer tabs with close buttons
- **toggleterm.nvim** — Integrated terminal
- **which-key.nvim** — Keybinding hints popup
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
| `:ProjectReload` | Re-detect `.project`, reinstall LSP/DAP, reload project plugins |
| `nvim-open --list` | Show registered project instances with alive/dead status |

## File Structure

```
neovim-config/
├── ghostty/config              # Ghostty terminal config
├── nvim/
│   ├── init.lua                # Entry point, server start, session lifecycle
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
│           ├── project.lua     # .project detection, LSP/DAP setup
│           ├── session.lua     # Session registry (instance discovery)
│           └── hash.lua        # SHA-256 utility for socket names
├── nvim-open                   # CLI script for smart file routing
├── link-config.sh              # Symlink setup helper
└── .project.example            # Template .project file
```
