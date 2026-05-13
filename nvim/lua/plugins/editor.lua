return {
	{
		"famiu/bufdelete.nvim",
		event = "UIEnter",
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("which-key").setup({
				preset = "modern",
			})
		end,
	},

	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		cmd = "Neotree",
		keys = {
			{ "<C-n>", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("neo-tree").setup({
				close_if_last_window = true,
				window = {
					width = 30,
					mappings = {
						["<C-n>"] = "close_window",
					},
				},
				filesystem = {
					filtered_items = {
						visible = false,
						hide_dotfiles = false,
						hide_gitignored = true,
						never_show = {
							".DS_Store",
							"thumbs.db",
							".git",
							"node_modules",
							"__pycache__",
						},
						never_show_by_pattern = {
							"*.meta",
							"*.asset",
						},
					},
				},
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		cmd = "Telescope",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
		},
		config = function()
			local telescope = require("telescope")
			telescope.setup({
				defaults = {
					layout_strategy = "vertical",
					sorting_strategy = "ascending",
					preview_title = false,
					border = true,
					borderchars = {
						preview = { " ", " ", " ", " ", " ", " ", " ", " " },
						prompt = { " ", " ", " ", " ", " ", " ", " ", " " },
						results = { " ", " ", " ", " ", " ", " ", " ", " " },
					},
					path_display = { "truncate" },
				},
				pickers = {
					find_files = {
						hidden = true,
						find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
					},
					live_grep = {
						additional_args = { "--hidden" },
					},
				},
			})

			pcall(telescope.load_extension, "fzf")
		end,
	},

	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("bufferline").setup({
				options = {
					mode = "buffers",
					indicator = {
						style = "none",
					},
					separator_style = "thin",
					show_close_icon = true,
					show_buffer_close_icons = true,
					diagnostics = "nvim_lsp",
					offsets = {
						{
							filetype = "neo-tree",
							text = "Explorer",
							highlight = "Directory",
							text_align = "left",
						},
					},
				},
			})
		end,
	},

	{
		"akinsho/toggleterm.nvim",
		cmd = { "ToggleTerm", "TermExec" },
		config = function()
			require("toggleterm").setup({
				size = function(term)
					if term.direction == "horizontal" then
						return math.floor(vim.o.lines * 0.35)
					elseif term.direction == "vertical" then
						return math.floor(vim.o.columns * 0.35)
					end
				end,
				direction = "horizontal",
				close_on_exit = false,
				persist_mode = true,
				start_in_insert = true,
				insert_mappings = true,
				terminal_mappings = true,
				shade_terminals = true,
				shading_factor = 2,
			})
		end,
	},
}
