return {
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = " ",
						package_pending = "",
						package_uninstalled = "",
					},
				},
			})
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		event = "VeryLazy",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("util.project").ensure_lsp_servers()
		end,
	},

	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"nvimdev/lspsaga.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

			local on_attach = function(client, bufnr)
				local map = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
				end

				map("n", "<S-A-F>", vim.lsp.buf.format, "Format document")
				map("n", "<F12>", vim.lsp.buf.definition, "Go to definition")
				map("n", "<C-F12>", vim.lsp.buf.implementation, "Go to implementation")
				map("n", "<S-F12>", vim.lsp.buf.references, "Find references")
				map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
				map("n", "<C-.>", vim.lsp.buf.code_action, "Code action")
				map("n", "<C-S-.>", function() vim.diagnostic.goto_next({ wrap = false }) end, "Next diagnostic")
				map("n", "<S-K>", vim.lsp.buf.hover, "Hover docs")

				map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
				map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
			end

			local always_servers = {
				lua_ls = {
					settings = {
						Lua = {
							runtime = { version = "LuaJIT" },
							diagnostics = { globals = { "vim" } },
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								checkThirdParty = false,
							},
							telemetry = { enable = false },
						},
					},
				},
				jsonls = {},
				yamlls = {},
				marksman = {},
			}

			for server, cfg in pairs(always_servers) do
				lspconfig[server].setup(vim.tbl_extend("force", {
					capabilities = capabilities,
					on_attach = on_attach,
				}, cfg))
			end

			--- Conditional: clangd (C++ projects) ---
			if vim.g.project and vim.g.project.env and vim.g.project.env.type == "cpp" then
				lspconfig.clangd.setup({
					capabilities = capabilities,
					on_attach = on_attach,
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
			end
		end,
	},

	{
		"nvimdev/lspsaga.nvim",
		event = "LspAttach",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("lspsaga").setup({
				ui = {
					border = "rounded",
					code_action = " ",
				},
				symbol_in_winbar = { enable = false },
				lightbulb = { enable = false },
				finder = {
					default = "def+ref+imp",
				},
			})
		end,
	},
}
