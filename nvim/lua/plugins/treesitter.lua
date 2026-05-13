return {
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		priority = 10,
		build = ":TSUpdate",
		config = function()
			local ensure_installed = {
				"lua",
				"json",
				"yaml",
				"toml",
				"markdown",
				"markdown_inline",
				"query",
				"vimdoc",
				"python",
				"bash",
			}

			if vim.g.project and vim.g.project.env then
				local t = vim.g.project.env.type
				if t == "csharp" then
					vim.list_extend(ensure_installed, { "c_sharp" })
				elseif t == "cpp" then
					vim.list_extend(ensure_installed, { "c", "cpp" })
				end
			end

			require("nvim-treesitter.configs").setup({
				ensure_installed = ensure_installed,
				auto_install = true,
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				indent = { enable = true },
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "gnn",
						node_incremental = "grn",
						scope_incremental = "grc",
						node_decremental = "grm",
					},
				},
			})
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		lazy = true,
	},

	{
		"windwp/nvim-ts-autotag",
		event = "BufReadPre",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-ts-autotag").setup()
		end,
	},

	{
		"numToStr/Comment.nvim",
		keys = {
			{ "<C-_>", mode = { "n", "v" }, desc = "Comment toggle" },
		},
		config = function()
			require("Comment").setup()
		end,
	},

	{
		"tpope/vim-sleuth",
		event = "VeryLazy",
	},
}
