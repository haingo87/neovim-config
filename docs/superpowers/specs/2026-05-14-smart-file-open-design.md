# Smart File Open for Neovim

Open files from Finder, Unity, or terminal into the right Neovim instance automatically.

## Routing Rules

| Launch method | Behavior |
|---------------|----------|
| `nvim` (no args) | Registers `cwd` as project root in session registry; socket = `~/.local/state/nvim/sockets/nv-<sha256[:12]>.sock` |
| `nvim <directory>` | Registers that directory as project root (even if nested inside another project's tree) |
| `nvim-open <file>` | Matches file path prefix against running project roots in registry → routes to that socket. No match → routes to orphan instance |

**Key principle:** User intent is respected. Launching `nvim <dir>` always creates a project. Opening a file never walks up for `.project` — it only routes to already-running projects or the orphan.

## Components

### 1. `nvim-open` CLI script

Python script (~60 lines), symlinked into PATH.

```
nvim-open <file>
```

Logic:
1. Resolve `<file>` to absolute path
2. Read and acquire advisory lock on `~/.local/state/nvim/sessions.json`
3. Health-check each entry: `nvim --server <socket> --remote-expr "1"` — prune dead entries
4. Prefix-match file path against remaining entries' `project_root` (must include trailing `/`)
5. If matched: `nvim --server <socket> --remote <file>`, exit
6. If no match or `--remote` fails: `NVIM_ORPHAN_GROUP=1 nvim --listen ~/.local/state/nvim/sockets/nv-orphan.sock --remote <file>`
7. If orphan not running: retry `--remote` up to 3 times (100ms sleep between), then fall back to `NVIM_ORPHAN_GROUP=1 nvim --listen ~/.local/state/nvim/sockets/nv-orphan.sock <file>`

### 2. Session registry

File: `~/.local/state/nvim/sessions.json`

```json
[
  {"project_root": "/Users/haingo/Code/unity-game", "socket": "/Users/haingo/.local/state/nvim/sockets/nv-a1b2c3d4e5f6.sock"},
  {"project_root": "/Users/haingo/Code/cpp-engine",  "socket": "/Users/haingo/.local/state/nvim/sockets/nv-f6e5d4c3b2a1.sock"}
]
```

Lifecycle:
- `UIEnter` autocmd registers: `{ project_root = cwd, socket = hash_of(realpath(cwd)) }`
- `VimLeave` autocmd unregisters: removes the entry matching **both** `project_root` AND `socket` (prevents a later instance's entry from being removed when an earlier instance exits)
- If the entry already exists (same project root, same socket), it is overwritten — harmless no-op on re-register

**Why match on socket:** If two instances A and B start for the same project root, B overwrites A's entry. When A exits, it must not remove B's entry. Matching on `socket` ensures A only removes its own.

**File writes:** All writers use PID-based exclusive-create lock on `~/.local/state/nvim/sessions.lock` (shared between Python and Lua) for read-modify-write serialization. Writes use atomic pattern: write to temp file, then `os.rename()` (Python) or `vim.fn.rename()` (Lua). Stale locks from crashes are detected via PID liveness check and pruned automatically.

Socket naming: deterministic — `sha256(realpath(project_root)).hex[:12]`. Orphan uses fixed name `nv-orphan`. All sockets live under `~/.local/state/nvim/sockets/` (user-private, not world-accessible `/tmp`). Direct inspection: `nvim --server ~/.local/state/nvim/sockets/nv-<hash>.sock --remote-expr "..."`.

### 3. Neovim config changes

**`nvim/init.lua`:**
- On startup, set `vim.g.neovim_orphan_group = (os.getenv("NVIM_ORPHAN_GROUP") == "1")`
- Single consolidated `UIEnter` autocmd (replaces the existing neo-tree auto-open one):
  1. Write `{ project_root = vim.g.initial_cwd, socket = <computed hash> }` to `sessions.json`
  2. If `vim.g.project` is set **and** `not vim.g.neovim_orphan_group`: open neo-tree
- `VimLeave` autocmd: remove entry matching both `vim.g.initial_cwd` and the computed socket from `sessions.json`

**`nvim/lua/plugins/editor.lua`:**
- neo-tree, telescope, which-key specs: add `enabled = not vim.g.neovim_orphan_group`

**No changes needed** (already correct for orphan mode):
- `roslyn.nvim` / `conform.nvim` / `nvim-dap` — no-op via `vim.g.project == nil` guard
- `toggleterm`, `bufferline`, `lualine`, `gitsigns`, `treesitter`, completion, LSP — load normally
- Telescope-dependent keymaps (`C-t`, `C-S-f`, `C-S-p`, leader ff/fg/fb/fh/fs) — not defined when telescope is disabled, so they pass through to Neovim defaults (effectively silent)

### 4. OS integration

- **Unity:** Preferences → External Tools → External Script Editor → point to `nvim-open`
- **Finder:** `nvim-open` set as default handler for source file types, or right-click → Open With
- **Terminal:** `nvim-open src/foo.cs`

## Error Handling

| Case | Behavior |
|------|----------|
| `sessions.json` missing/corrupt | Treated as empty registry → routes to orphan |
| Registry entry is stale (process dead) | `nvim-open` health-checks each entry via `--remote-expr "1"`, prunes failures before routing |
| Project instance A exits, B still running same dir | `VimLeave` removes A's entry by socket match; B's entry (different socket) stays |
| `nvim-open` races with `VimLeave` on file write | PID-based exclusive-create lock serializes writers; atomic rename prevents partial writes |
| Two `nvim-open` calls race to launch orphan | First binds socket; second retries `--remote` (up to 3x with 100ms backoff), then connects — no duplicate |
| `nvim <directory>` follows symlink | `realpath()` resolves before hashing and registry write — symlink variants map to same instance |
| File under registered project but that instance doesn't have `.project` loaded yet | Instance's `DirChanged`/`BufEnter` autocmd fires on file open, `detect()` finds `.project` automatically |
