return {
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup({
				registries = {
					"github:mason-org/mason-registry",
					"github:Crashdummyy/mason-registry",
				},
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
			local capabilities = require("cmp_nvim_lsp").default_capabilities(
				vim.lsp.protocol.make_client_capabilities()
			)
			vim.lsp.config("*", { capabilities = capabilities })

			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local bufnr = args.buf
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
				end,
			})

			vim.lsp.enable({ "jsonls", "yamlls", "marksman" })

			local f = require("util.features")

			if f.has("lua") then
				vim.lsp.config("lua_ls", {
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
				})
				vim.lsp.enable("lua_ls")
			end

			if f.has("cpp") then
				require("util.lsp").setup_clangd()
			end

			if f.has("cmake") then
				vim.lsp.config("cmake_ls", {})
				vim.lsp.enable("cmake_ls")
			end

			if f.has("go") then
				vim.lsp.config("gopls", {})
				vim.lsp.enable("gopls")
			end

			if f.has("dart") then
				vim.lsp.config("dartls", {
					cmd = {
						"dart",
						"language-server",
						"--protocol=lsp",
					},
					filetypes = { "dart" },
					init_options = {
						onlyAnalyzeProjectsWithOpenFiles = false,
					},
				})
				vim.lsp.enable("dartls")
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
