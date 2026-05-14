vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.neovim_orphan_group = (vim.fn.getenv("NVIM_ORPHAN_GROUP") == "1")

vim.g.initial_cwd = vim.fn.getcwd()
require("util.project").detect(vim.g.initial_cwd)

local hash = require("util.hash")
local project_root = vim.fn.fnamemodify(vim.fn.resolve(vim.g.initial_cwd), ":p"):gsub("/$", "")
-- project_dirname: use .project parent dir if .project exists, else cwd basename.
-- Check vim.g.project (nil when no .project) rather than project_dirname
-- (which can be vim.NIL, a truthy userdata that breaks == nil and not checks).
if not vim.g.neovim_orphan_group and not vim.g.project then
	vim.g.project_dirname = vim.fn.fnamemodify(project_root, ":t")
end
local socket_dir = vim.fn.stdpath("state") .. "/sockets"
vim.fn.mkdir(socket_dir, "p")
local socket_name

if vim.g.neovim_orphan_group then
	socket_name = socket_dir .. "/nv-orphan.sock"
else
	socket_name = socket_dir .. "/nv-" .. hash.sha256_short(project_root)
end

-- Start server on deterministic socket so --remote can reach us.
-- Skip if already listening on this socket (e.g., from --listen passed by nvim-open).
-- Don't check serverlist() emptiness — Neovim has a default pipe server in the list.
local already_listening = false
for _, addr in ipairs(vim.fn.serverlist()) do
	if addr == socket_name then
		already_listening = true
		vim.g.nvim_socket_name = socket_name
		break
	end
end
if not already_listening then
	os.remove(socket_name)
	local server_result = vim.fn.serverstart(socket_name)
	if server_result ~= 0 then
		vim.g.nvim_socket_name = socket_name
	else
		vim.notify("[session] Could not start server on " .. socket_name, vim.log.levels.WARN)
	end
end

local should_register = not vim.g.neovim_orphan_group
vim.g.daemon_registered = false

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

vim.api.nvim_create_autocmd("UIEnter", {
	once = true,
	callback = function()
		if should_register then
			local session = require("util.session")
			local result = session.register(project_root, vim.g.nvim_socket_name)
			if result == false then
				-- Daemon unreachable — instance works standalone but isn't routable
				return
			end
			if type(result) == "table" and result.status == "dup" then
				-- Duplicate instance for same project — route files and exit
				local redirect = require("util.redirect")
				local args = vim.v.argv or {}
				for _, arg in ipairs(args) do
					if arg:match("^/") or arg:match("^%.") then
						vim.fn.system({ "nvim", "--server", result.socket, "--remote", arg })
					end
				end
				redirect.bring_to_front()
				vim.cmd("qa!")
				return
			end
			vim.g.daemon_registered = true
		else
			local session = require("util.session")
			session.register(project_root, vim.g.nvim_socket_name, true)
		end
		if not vim.g.neovim_orphan_group then
			vim.schedule(function()
				vim.cmd("Neotree show")
			end)
		end
		-- Detect Ghostty window/tab for tab-aware window focus
		if vim.env.TERM_PROGRAM == "ghostty" then
			vim.schedule(function()
				local win_id = vim.fn.system({
					"osascript", "-e",
					'tell application "Ghostty" to get id of front window',
				}):gsub("%s+", "")
				if win_id and win_id ~= "" then
					vim.g.ghostty_window_id = win_id
				end
				local tab_idx = vim.fn.system({
					"osascript", "-e",
					'tell application "Ghostty" to get index of selected tab of window 1',
				}):gsub("%s+", "")
				local n = tonumber(tab_idx)
				if n then
					vim.g.ghostty_tab_index = n
				end
			end)
		end
	end,
})

vim.api.nvim_create_autocmd("VimLeave", {
	once = true,
	callback = function()
		if vim.g.daemon_registered then
			require("util.session").unregister(vim.g.nvim_socket_name)
		end
		pcall(os.remove, socket_name)
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
