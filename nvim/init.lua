vim.g.mapleader = " "
vim.g.maplocalleader = " "

if vim.g.neovim_orphan_group == nil then
	vim.g.neovim_orphan_group = vim.fn.getenv("NVIM_ORPHAN_GROUP") == "1"
end

local project_dir = nil

for i = 2, #vim.v.argv do
	local arg = vim.v.argv[i]
	if type(arg) == "string" and vim.fn.isdirectory(arg) == 1 then
		project_dir = vim.fn.fnamemodify(arg, ":p"):gsub("/$", "")
		break
	end
end

if not project_dir then
	-- Try vim.v.argv[1] as a file arg (the common case: nvim <filepath>)
	local arg1 = vim.v.argv[1]
	if type(arg1) == "string" and arg1 ~= "" and arg1:sub(1, 1) ~= "-" then
		local abs = vim.fn.fnamemodify(arg1, ":p")
		if vim.fn.isdirectory(abs) ~= 1 and vim.fn.filereadable(abs) == 1 then
			project_dir = vim.fn.fnamemodify(abs, ":p:h")
		end
	end
end

if not project_dir then
	for i = 2, #vim.v.argv do
		local arg = vim.v.argv[i]
		if type(arg) ~= "string" or arg == "" or arg:sub(1, 1) == "-" then
			goto continue
		end
		-- Skip values of flags that take a non-file argument
		if i > 1 then
			local prev = vim.v.argv[i - 1]
			if type(prev) == "string" then
				local p = prev
				if p == "--listen" or p == "-c" or p == "--cmd"
					or p == "-u" or p == "--server"
					or p == "--remote" or p == "--remote-silent" then
					goto continue
				end
			end
		end
		local abs = vim.fn.fnamemodify(arg, ":p")
		if vim.fn.isdirectory(abs) ~= 1 and vim.fn.filereadable(abs) == 1 then
			project_dir = vim.fn.fnamemodify(abs, ":p:h")
			break
		end
		::continue::
	end
end

if project_dir then
	vim.fn.chdir(project_dir)
else
	project_dir = vim.fn.getcwd()
end

vim.g.initial_cwd = project_dir
require("util.project").detect(vim.g.initial_cwd)

local hash = require("util.hash")
local project_root = vim.fn.fnamemodify(vim.fn.resolve(vim.g.initial_cwd), ":p"):gsub("/$", "")

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
				for i = 2, #vim.v.argv do
					local arg = vim.v.argv[i]
					if type(arg) ~= "string" or arg == "" or arg:sub(1, 1) == "-" then
						goto continue
					end
					local filepath = vim.fn.fnamemodify(arg, ":p")
					if vim.fn.isdirectory(filepath) ~= 1 then
						vim.fn.system({ "nvim", "--server", result.socket, "--remote", filepath })
					end
					::continue::
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
				vim.cmd("NvimTreeOpen")
			end)
		end
		require("util.redirect").init()
		-- Detect macOS terminal window for window-aware focus
		if vim.env.TERM_PROGRAM then
			local term = vim.env.TERM_PROGRAM
			if term == "ghostty" or term == "Apple_Terminal" then
				vim.schedule(function()
					local app = (term == "Apple_Terminal") and "Terminal" or "Ghostty"
					local win_id = vim.fn.system({
						"osascript", "-e",
						'tell application "' .. app .. '" to get id of front window',
					}):gsub("%s+", "")
					if win_id and win_id ~= "" then
						vim.g.macos_window_id = win_id
						vim.g.macos_terminal_app = app
					end
				end)
			end
		end
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	once = true,
	callback = function()
		if require("util.features").has("cpp") then
			require("util.session").lsp_stop("clangd", vim.g.initial_cwd)
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
	local features = require("util.features")
	project.cache = {}
	features.flush()
	project.detect(vim.fn.getcwd())
	project.ensure_lsp_servers()
	project.ensure_dap_adapters()

	if features.has("cpp") then
		require("util.lsp").setup_clangd()
	end

	if features.has("csharp") then
		pcall(require("lazy.core.loader").reload, "roslyn.nvim")
	end
	if features.has("csharp") or features.has("cpp") then
		pcall(require("lazy.core.loader").reload, "conform.nvim")
	end
	pcall(require("lazy.core.loader").reload, "nvim-dap")
	vim.notify("[project] Environment reloaded", vim.log.levels.INFO)
end, {})
