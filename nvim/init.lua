vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("util.project").detect(vim.fn.getcwd())

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

vim.api.nvim_create_user_command("ProjectReload", function()
	local project = require("util.project")
	project.cache = {}
	project.detect(vim.fn.getcwd())
	project.ensure_lsp_servers()
	project.ensure_dap_adapters()

	local capabilities = require("cmp_nvim_lsp").default_capabilities(
		vim.lsp.protocol.make_client_capabilities()
	)
	project.setup_clangd(capabilities)

	vim.cmd("Lazy reload seblj/roslyn.nvim")
	vim.cmd("Lazy reload stevearc/conform.nvim")
	vim.cmd("Lazy reload mfussenegger/nvim-dap")
	vim.notify("[project] Environment reloaded", vim.log.levels.INFO)
end, {})
