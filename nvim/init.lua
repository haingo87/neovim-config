vim.g.mapleader = " "
vim.g.maplocalleader = " "

local has_dir_arg = false
local project_dir = nil

for i = 2, #vim.v.argv do
	local arg = vim.v.argv[i]
	if type(arg) == "string" and vim.fn.isdirectory(arg) == 1 then
		has_dir_arg = true
		project_dir = vim.fn.fnamemodify(arg, ":p"):gsub("/$", "")
		break
	end
end

vim.g.neovim_light_mode = not has_dir_arg

if project_dir then
	vim.fn.chdir(project_dir)
else
	project_dir = vim.fn.getcwd()
end

if not vim.g.neovim_light_mode and project_dir then
	vim.g.initial_cwd = project_dir
	require("util.project").detect(project_dir)
	if not vim.g.project then
		vim.g.project_dirname = vim.fn.fnamemodify(project_dir, ":t")
	end
else
	vim.g.initial_cwd = vim.fn.getcwd()
	if not vim.g.project then
		vim.g.project_dirname = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	end
end

local socket_dir = vim.fn.stdpath("state") .. "/sockets"
local socket_name

if not vim.g.neovim_light_mode and project_dir then
	vim.fn.mkdir(socket_dir, "p")
	local hash = require("util.hash")
	socket_name = socket_dir .. "/nv-" .. hash.sha256_short(project_dir)

	local is_dup = false

	if vim.fn.filereadable(socket_name) == 1 then
		local pipe = vim.uv.new_pipe(false)
		local connected = false
		local connect_err = nil
		pipe:connect(socket_name, function(err)
			connected = true
			connect_err = err
		end)
		local start = vim.uv.now()
		while not connected and (vim.uv.now() - start < 2000) do
			vim.wait(50)
		end
		if connected and not connect_err then
			is_dup = true
			pipe:close()
		else
			if not pipe:is_closing() then
				pipe:close()
			end
			os.remove(socket_name)
		end
	end

	if is_dup then
		local redirect = require("util.redirect")
		for i = 2, #vim.v.argv do
			local arg = vim.v.argv[i]
			if type(arg) ~= "string" or arg == "" or arg:sub(1, 1) == "-" then
				goto continue
			end
			local filepath = vim.fn.fnamemodify(arg, ":p")
			if vim.fn.isdirectory(filepath) ~= 1 then
				vim.fn.system({
					"nvim", "--server", socket_name,
					"--remote-expr",
					string.format(
						"require('util.redirect').open_file('%s')",
						filepath:gsub("'", "\\'")
					),
				})
			end
			::continue::
		end
		redirect.bring_to_front()
		vim.cmd("qa!")
		return
	end
end

vim.g.nvim_socket_name = nil

if not vim.g.neovim_light_mode and project_dir then
	pcall(os.remove, socket_name)
	local server_result = vim.fn.serverstart(socket_name)
	if server_result ~= 0 then
		vim.g.nvim_socket_name = socket_name
	else
		vim.notify("[session] Could not start server on " .. socket_name, vim.log.levels.WARN)
	end
end

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
		if not vim.g.neovim_light_mode then
			vim.schedule(function()
				vim.cmd("Neotree show")
			end)
		end
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
					if term == "ghostty" then
						local tab_idx = vim.fn.system({
							"osascript", "-e",
							'tell application "Ghostty" to get index of selected tab of window 1',
						}):gsub("%s+", "")
						local n = tonumber(tab_idx)
						if n then
							vim.g.macos_tab_index = n
						end
					end
				end)
			end
		end
	end,
})

vim.api.nvim_create_autocmd("VimLeave", {
	once = true,
	callback = function()
		if vim.g.nvim_socket_name then
			pcall(os.remove, vim.g.nvim_socket_name)
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

	if vim.g.project and vim.g.project.env then
		if vim.g.project.env.type == "csharp" then
			pcall(require("lazy.core.loader").reload, "roslyn.nvim")
		end
		if vim.g.project.env.type == "csharp" or vim.g.project.env.type == "cpp" then
			pcall(require("lazy.core.loader").reload, "conform.nvim")
		end
	end
	pcall(require("lazy.core.loader").reload, "nvim-dap")
	vim.notify("[project] Environment reloaded", vim.log.levels.INFO)
end, {})
