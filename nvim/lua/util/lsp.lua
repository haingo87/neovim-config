local M = {}

function M.setup_clangd(cwd)
	cwd = cwd or vim.fn.getcwd()
	local socket_path = require("util.session").lsp_start("clangd", cwd)
	local init_options = {
		usePlaceholders = true,
		completeUnimported = true,
		clangdFileStatus = true,
	}
	if socket_path then
		vim.lsp.config("clangd", {
			cmd = { "socat", "STDIO", "UNIX-CONNECT:" .. socket_path },
			init_options = init_options,
		})
	else
		vim.lsp.config("clangd", {
			cmd = {
				"clangd",
				"--background-index",
				"--clang-tidy",
				"--completion-style=detailed",
			},
			init_options = init_options,
		})
	end
	vim.lsp.enable("clangd")
end

return M
