# Smart File Open Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open files from Finder, Unity, or terminal into the correct running Neovim instance based on project membership.

**Architecture:** Four pieces: a Python CLI script (`nvim-open`) that health-checks a JSON registry and routes files via `--remote`; a Lua session module (`util/session.lua`) for registry read/write with cross-process PID-based locking; `init.lua` wiring to `serverstart()` on deterministic sockets and register/unregister on startup/exit; and `editor.lua` `enabled` guards to suppress neo-tree/telescope/which-key in orphan mode.

**Tech Stack:** Python 3 (stdlib only), Lua (uv/luv via Neovim API), shell (bash for PATH symlink)

**Behavior note:** `nvim <file>` (file argument, not directory) registers `cwd` as the project root — same as `nvim` with no args. This is intentional: the user's current directory is the project context.

---

### Task 1: Session Registry Utility Module

**Files:**
- Create: `nvim/lua/util/session.lua`
- Create: `nvim/lua/util/hash.lua`

- [ ] **Step 1: Write the hash utility for deterministic socket names**

```lua
-- nvim/lua/util/hash.lua
-- SHA-256 hex digest, first 12 chars only (for short socket names).
local M = {}

function M.sha256_short(data)
	local hash = vim.fn.sha256(data)
	return hash:sub(1, 12)
end

return M
```

- [ ] **Step 2: Write the session registry module**

Uses PID-based exclusive-create locking — same mechanism as the Python `nvim-open` script. Both sides write their PID into `sessions.lock` via `O_CREAT | O_EXCL`. If the lock file already exists, the waiter reads the PID, checks if that process is alive (`kill -0`), and removes the stale lock if dead.

```lua
-- nvim/lua/util/session.lua
local M = {}

local function sessions_path()
	return vim.fn.stdpath("state") .. "/sessions.json"
end

local function lockfile_path()
	return vim.fn.stdpath("state") .. "/sessions.lock"
end

-- Unix-only: check if a PID belongs to a running Neovim process.
-- Uses kill -0 for liveness, then ps to verify it's actually nvim (not a reused PID).
local function pid_alive(pid)
	if pid and vim.fn.has("unix") == 1 then
		vim.fn.system({ "kill", "-0", tostring(pid) })
		if vim.v.shell_error == 0 then
			local comm = vim.fn.system({ "ps", "-p", tostring(pid), "-o", "comm=" }):gsub("%s+", "")
			return comm:find("nvim") ~= nil
		end
	end
	return false
end

--- Acquire exclusive lock using O_CREAT|O_EXCL with PID + staleness detection.
--- Same mechanism as nvim-open Python script. Crash-safe: dead locks detected and pruned.
--- Bounded: 40 attempts × 50ms = 2 second max wait before giving up.
local function with_lock(fn)
	local lockfile = lockfile_path()
	local pid = tostring(vim.fn.getpid())
	local acquired = false
	for _ = 1, 40 do
		local fd = vim.uv.fs_open(lockfile, "wx", 438)
		if fd then
			vim.uv.fs_write(fd, pid, 0)
			vim.uv.fs_close(fd)
			acquired = true
			break
		end
		local data = vim.fn.readfile(lockfile)
		local holder_pid = tonumber(data[1] or "")
		if pid_alive(holder_pid) then
			vim.wait(50, function() end, 20)
		else
			os.remove(lockfile)
		end
	end
	if not acquired then
		vim.notify("[session] Could not acquire lock after 2s", vim.log.levels.ERROR)
		return
	end
	local ok, result = pcall(fn)
	if ok then
		return result
	end
end

local function read_sessions()
	local path = sessions_path()
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.size == 0 then
		return {}
	end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return {}
	end
	local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

local function write_sessions(sessions)
	local path = sessions_path()
	local tmp = path .. ".tmp"
	vim.fn.writefile({ vim.json.encode(sessions) }, tmp)
	vim.fn.rename(tmp, path)
end

--- Register the current Neovim instance in the session registry.
function M.register(project_root, socket)
	with_lock(function()
		local sessions = read_sessions()
		for i, s in ipairs(sessions) do
			if s.socket == socket then
				sessions[i] = { project_root = project_root, socket = socket }
				write_sessions(sessions)
				return
			end
		end
		table.insert(sessions, { project_root = project_root, socket = socket })
		write_sessions(sessions)
	end)
end

--- Unregister the current instance. Matches both project_root AND socket
--- to avoid instance A removing instance B's entry for the same directory.
function M.unregister(project_root, socket)
	with_lock(function()
		local sessions = read_sessions()
		for i = #sessions, 1, -1 do
			if sessions[i].project_root == project_root and sessions[i].socket == socket then
				table.remove(sessions, i)
				break
			end
		end
		write_sessions(sessions)
	end)
end

return M
```

- [ ] **Step 3: Verify modules load without error**

```bash
nvim --headless -c "lua require('util.hash'); require('util.session'); print('OK')" -c qa 2>&1
```
Expected: prints `OK`, no errors.

- [ ] **Step 4: Commit**

```bash
git add nvim/lua/util/session.lua nvim/lua/util/hash.lua
git commit -m "feat: add session registry and hash utility modules"
```

---

### Task 2: Neovim init.lua Changes

**Files:**
- Modify: `nvim/init.lua`

- [ ] **Step 1: Replace the existing init.lua with the updated version**

Changes from current:
1. Set `vim.g.neovim_orphan_group` from env var
2. Compute project root with `vim.fn.resolve()` (symlink-safe)
3. Orphan uses fixed socket `sockets/nv-orphan.sock` under `stdpath("state")`; project uses `sockets/nv-<sha256[:12]>.sock`
4. Start server on deterministic socket (unless already listening from `--listen`)
5. Consolidated `UIEnter`: register session (project only) + conditional neo-tree open
6. `VimLeave`: unregister session (project only, socket-matched)

```lua
-- nvim/init.lua
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.neovim_orphan_group = (vim.fn.getenv("NVIM_ORPHAN_GROUP") == "1")

vim.g.initial_cwd = vim.fn.getcwd()
require("util.project").detect(vim.g.initial_cwd)

local hash = require("util.hash")
local project_root = vim.fn.fnamemodify(vim.fn.resolve(vim.g.initial_cwd), ":p"):gsub("/$", "")
local socket_dir = vim.fn.stdpath("state") .. "/sockets"
vim.fn.mkdir(socket_dir, "p")
local socket_name

if vim.g.neovim_orphan_group then
	socket_name = socket_dir .. "/nv-orphan.sock"
else
	socket_name = socket_dir .. "/nv-" .. hash.sha256_short(project_root)
end

-- Start server if not already listening (e.g., from --listen on CLI).
-- Orphan uses --listen from nvim-open; project uses serverstart here.
if #vim.fn.serverlist() == 0 then
	local ok, server_err = pcall(vim.fn.serverstart, socket_name)
	if ok then
		vim.g.nvim_socket_name = socket_name
	else
		vim.notify("[session] Could not start server: " .. tostring(server_err), vim.log.levels.WARN)
	end
else
	vim.g.nvim_socket_name = socket_name
end

-- Only project instances register. Orphan socket is always at stdpath/sockets/nv-orphan.sock.
local should_register = vim.g.nvim_socket_name ~= nil and not vim.g.neovim_orphan_group

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("config.options")
require("config.keymaps")
require("config.autocmds")

require("lazy").setup("plugins", {
	change_detection = { notify = false },
})

-- Consolidated UIEnter: register session + conditionally open neo-tree
vim.api.nvim_create_autocmd("UIEnter", {
	once = true,
	callback = function()
		if should_register then
			require("util.session").register(project_root, vim.g.nvim_socket_name)
		end
		if vim.g.project and not vim.g.neovim_orphan_group then
			vim.schedule(function()
				vim.cmd("Neotree show")
			end)
		end
	end,
})

-- Unregister on exit (match on socket to avoid removing another instance's entry)
vim.api.nvim_create_autocmd("VimLeave", {
	once = true,
	callback = function()
		if should_register then
			require("util.session").unregister(project_root, vim.g.nvim_socket_name)
		end
	end,
})

vim.api.nvim_create_user_command("ProjectReload", function()
	local project = require("util.project")
	project.cache = {}
	project.detect(vim.fn.getcwd())
	project.ensure_lsp_servers()
	project.ensure_dap_adapters()

	if vim.g.project and vim.g.project.env and vim.g.project.env.type == "cpp" then
		vim.lsp.config("clangd", {
			cmd = {
				"clangd",
				"--background-index",
				"--clang-tidy",
				"--completion-style=detailed",
			},
			init_options = {
				usePlaceholders = true,
				completeUnimported = true,
				clangdFileStatus = true,
			},
		})
		vim.lsp.enable("clangd")
	end

	vim.cmd("Lazy reload seblj/roslyn.nvim")
	vim.cmd("Lazy reload stevearc/conform.nvim")
	vim.cmd("Lazy reload mfussenegger/nvim-dap")
	vim.notify("[project] Environment reloaded", vim.log.levels.INFO)
end, {})
```

- [ ] **Step 2: Verify Neovim starts without errors**

```bash
nvim --headless -c qa 2>&1
```
Expected: clean exit, no error messages.

- [ ] **Step 3: Verify orphan flag works**

```bash
NVIM_ORPHAN_GROUP=1 nvim --headless -c "lua print(vim.g.neovim_orphan_group)" -c qa 2>&1
```
Expected: prints `true`.

- [ ] **Step 4: Verify session registry is written on startup**

```bash
rm -f ~/.local/state/nvim/sessions.json ~/.local/state/nvim/sessions.lock
nvim --headless -c qa 2>&1
cat ~/.local/state/nvim/sessions.json
```
Expected: JSON array with one entry containing `project_root` and `socket`.

- [ ] **Step 5: Commit**

```bash
git add nvim/init.lua
git commit -m "feat: session registry registration, orphan flag, consolidated UIEnter"
```

---

### Task 3: Orphan Guards in editor.lua

**Files:**
- Modify: `nvim/lua/plugins/editor.lua`

- [ ] **Step 1: Add `enabled` guard to which-key spec**

Insert `enabled = not vim.g.neovim_orphan_group` into the which-key plugin spec. The spec becomes:

```lua
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		enabled = not vim.g.neovim_orphan_group,
		config = function()
			require("which-key").setup({
				preset = "modern",
			})
		end,
	},
```

- [ ] **Step 2: Add `enabled` guard to neo-tree spec**

Insert `enabled = not vim.g.neovim_orphan_group` into the neo-tree plugin spec. The spec becomes:

```lua
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		cmd = "Neotree",
		enabled = not vim.g.neovim_orphan_group,
		keys = {
			{ "<C-n>", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
		},
		dependencies = {
```

- [ ] **Step 3: Add `enabled` guard to telescope spec**

Insert `enabled = not vim.g.neovim_orphan_group` into the telescope plugin spec. The spec becomes:

```lua
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		cmd = "Telescope",
		enabled = not vim.g.neovim_orphan_group,
		dependencies = {
```

- [ ] **Step 4: Verify orphan mode loads without the three guarded plugins**

```bash
NVIM_ORPHAN_GROUP=1 nvim --headless +"lua require('lazy').setup('plugins'); vim.wait(2000, function() end); local loaded = require('lazy').plugins(); for _, p in ipairs(loaded) do if vim.startswith(p.name, 'neo-tree') or vim.startswith(p.name, 'telescope') or vim.startswith(p.name, 'which-key') then print('FAIL: ' .. p.name .. ' loaded') end end; print('DONE')" +qa 2>&1
```
Expected: prints `DONE`, no `FAIL:` lines.

- [ ] **Step 5: Verify normal mode loads all three guarded plugins**

```bash
nvim --headless +"lua vim.g.neovim_orphan_group = nil; require('lazy').setup('plugins'); vim.wait(2000, function() end); local loaded = require('lazy').plugins(); local found = {neo_tree=false, telescope=false, which_key=false}; for _, p in ipairs(loaded) do if vim.startswith(p.name, 'neo-tree') then found.neo_tree = true elseif vim.startswith(p.name, 'telescope') then found.telescope = true elseif vim.startswith(p.name, 'which-key') then found.which_key = true end end; for k, v in pairs(found) do if v then print('OK: ' .. k) else print('MISSING: ' .. k) end end; print('DONE')" +qa 2>&1
```
Expected: `OK: neo_tree`, `OK: telescope`, `OK: which_key`, `DONE`.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/plugins/editor.lua
git commit -m "feat: guard neo-tree, telescope, which-key behind orphan flag"
```

---

### Task 4: nvim-open CLI Script

**Files:**
- Create: `nvim-open`

- [ ] **Step 1: Write the nvim-open Python script**

Lock mechanism matches Lua's `session.lua`: PID-based exclusive-create (`O_CREAT | O_EXCL`) with staleness detection. Health checks use 0.5s timeout per entry. Orphan launch passes `--listen` to eliminate socket-creation race.

```python
#!/usr/bin/env python3
"""
nvim-open <file> — open a file in the correct running Neovim instance.

Routes by prefix-matching the file's path against registered project roots
in ~/.local/state/nvim/sessions.json. Unmatched files go to the orphan instance.
"""
import argparse
import json
import os
import subprocess
import time

SESSIONS_DIR = os.path.expanduser("~/.local/state/nvim")
SESSIONS_PATH = os.path.join(SESSIONS_DIR, "sessions.json")
LOCK_FILE = os.path.join(SESSIONS_DIR, "sessions.lock")
SOCKETS_DIR = os.path.join(SESSIONS_DIR, "sockets")
ORPHAN_SOCKET = os.path.join(SOCKETS_DIR, "nv-orphan.sock")


def _acquire_lock():
    """PID-based exclusive-create lock. Matches session.lua mechanism.
    Writes our PID into the lock file. If lock exists and holder is dead (stale),
    removes it and retries. Crash-safe: dead lock detected via kill(pid, 0)
    and ps-based nvim verification.
    Lock file is NOT deleted on release — stale detection handles dead holders."""
    os.makedirs(SESSIONS_DIR, exist_ok=True)
    pid = os.getpid()
    for _ in range(40):  # 2 second max wait
        try:
            fd = os.open(LOCK_FILE, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(pid).encode())
            os.close(fd)
            return
        except FileExistsError:
            try:
                with open(LOCK_FILE) as f:
                    holder_pid = int(f.read().strip())
                os.kill(holder_pid, 0)
                comm = subprocess.run(
                    ["ps", "-p", str(holder_pid), "-o", "comm="],
                    capture_output=True, text=True, timeout=2,
                ).stdout.strip()
                if "nvim" not in comm:
                    raise ProcessLookupError
            except (ProcessLookupError, FileNotFoundError, ValueError):
                try:
                    os.unlink(LOCK_FILE)
                except OSError:
                    pass
                continue
            time.sleep(0.05)
    raise RuntimeError("Could not acquire session lock after 2s")


def _read_sessions():
    try:
        with open(SESSIONS_PATH, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def _write_sessions(sessions):
    tmp = SESSIONS_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(sessions, f)
    os.replace(tmp, SESSIONS_PATH)


def _health_check(sessions):
    """Prune dead entries. 0.5s timeout — local socket responds fast."""
    alive = []
    for s in sessions:
        result = subprocess.run(
            ["nvim", "--server", s["socket"], "--remote-expr", "1"],
            capture_output=True,
            timeout=0.5,
        )
        if result.returncode == 0:
            alive.append(s)
    return alive


def _nvim_remote(socket, filepath):
    result = subprocess.run(
        ["nvim", "--server", socket, "--remote", os.path.abspath(filepath)],
        capture_output=True,
        timeout=5,
    )
    return result.returncode == 0


def _launch_orphan(filepath):
    """Launch orphan Neovim with --listen so the socket exists immediately.
    The init.lua serverlist() check prevents double-serverstart."""
    os.makedirs(SOCKETS_DIR, exist_ok=True)
    env = os.environ.copy()
    env["NVIM_ORPHAN_GROUP"] = "1"
    subprocess.Popen(
        ["nvim", "--listen", ORPHAN_SOCKET, os.path.abspath(filepath)],
        env=env,
        start_new_session=True,
    )


def main():
    parser = argparse.ArgumentParser(description="Open file in correct Neovim instance")
    parser.add_argument("file", help="File path to open")
    args = parser.parse_args()

    filepath = os.path.abspath(args.file)

    # Read sessions under lock, health-check, write back pruned list
    os.makedirs(SESSIONS_DIR, exist_ok=True)
    _acquire_lock()
    sessions = _read_sessions()
    sessions = _health_check(sessions)
    _write_sessions(sessions)

    # Route to matching project instance
    for s in sessions:
        if filepath.startswith(s["project_root"] + os.sep):
            if _nvim_remote(s["socket"], filepath):
                return
            break  # matched project but server is gone

    # Route to orphan instance (retry with backoff for race on socket creation)
    for attempt in range(3):
        if _nvim_remote(ORPHAN_SOCKET, filepath):
            return
        time.sleep(0.1)

    # Orphan not running — launch it
    _launch_orphan(filepath)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x nvim-open
```

- [ ] **Step 3: Symlink into PATH (once, for OS integration)**

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/nvim-open" ~/.local/bin/nvim-open
```

- [ ] **Step 4: Verify script parses help text**

```bash
./nvim-open --help
```
Expected: prints usage information without error.

- [ ] **Step 5: Test with no running Neovim (should launch orphan)**

```bash
rm -f ~/.local/state/nvim/sessions.json
./nvim-open /tmp/test.txt 2>&1 &
sleep 2
nvim --server ~/.local/state/nvim/sockets/nv-orphan.sock --remote-expr "qall!" 2>/dev/null
rm -f /tmp/test.txt
```
Expected: No errors. Orphan Neovim launches and can be remote-quit.

- [ ] **Step 6: Commit**

```bash
git add nvim-open
git commit -m "feat: add nvim-open CLI script for smart file routing"
```

---

### Task 5: Integration Verification

**Files:** (none — verification only)

- [ ] **Step 1: Full cycle test — project instance registers, routing works**

```bash
# Clean slate
rm -f ~/.local/state/nvim/sessions.json ~/.local/state/nvim/sessions.lock

# Launch project neovim (uses serverstart in init.lua)
SOCKETS_DIR=~/.local/state/nvim/sockets
mkdir -p $SOCKETS_DIR /tmp/test-project
cd /tmp/test-project
nvim --headless --listen "$SOCKETS_DIR/nv-test.sock" +"lua vim.g.initial_cwd='/tmp/test-project'; vim.g.neovim_orphan_group=nil; vim.g.nvim_socket_name='$SOCKETS_DIR/nv-test.sock'; require('util.session').register('/tmp/test-project', '$SOCKETS_DIR/nv-test.sock')" 2>&1 &

sleep 1

# Verify sessions.json has the entry
cat ~/.local/state/nvim/sessions.json
```
Expected: JSON array with `"project_root": "/tmp/test-project"` and socket path under `~/.local/state/nvim/sockets/nv-test.sock`.

- [ ] **Step 2: Verify orphan Neovim starts without guarded plugins**

```bash
NVIM_ORPHAN_GROUP=1 nvim --headless --listen ~/.local/state/nvim/sockets/nv-orphan.sock \
  +"lua require('lazy').setup('plugins'); vim.wait(3000, function() end); local p = require('lazy').plugins(); for _, pp in ipairs(p) do print(pp.name) end" \
  +qa 2>&1 | grep -E "(neo-tree|telescope|which-key)"
```
Expected: no output (none of the three appear).

- [ ] **Step 3: Verify normal Neovim DOES load all plugins**

```bash
nvim --headless +"lua require('lazy').setup('plugins'); vim.wait(3000, function() end); local p = require('lazy').plugins(); for _, pp in ipairs(p) do print(pp.name) end" +qa 2>&1 | grep -E "(neo-tree|telescope|which-key)"
```
Expected: all three appear in output.

- [ ] **Step 4: Cleanup test artifacts**

```bash
nvim --server ~/.local/state/nvim/sockets/nv-orphan.sock --remote-expr "qall!" 2>/dev/null
for sock in ~/.local/state/nvim/sockets/nv-*.sock; do
  nvim --server "$sock" --remote-expr "qall!" 2>/dev/null
done
rm -f ~/.local/state/nvim/sessions.json ~/.local/state/nvim/sessions.lock
rm -rf ~/.local/state/nvim/sockets /tmp/test-project /tmp/test.txt
```

- [ ] **Step 5: Commit (if any changes from verification fixes)**

```bash
git status
git add -A
git diff --cached
# git commit -m "chore: verification fixes" (only if changes were needed)
```
