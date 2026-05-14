return {
	{
		"famiu/bufdelete.nvim",
		event = "UIEnter",
	},

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

	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		cmd = "Neotree",
		enabled = not vim.g.neovim_orphan_group,
		keys = {
			{ "<C-n>", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		config = function()
			local never_show = { ".DS_Store", "thumbs.db", ".git", "node_modules", "__pycache__" }
			local never_show_patterns = { "*.meta", "*.asset" }

			if vim.g.project and vim.g.project.exclude then
				if vim.g.project.exclude.files then
					vim.list_extend(never_show_patterns, vim.g.project.exclude.files)
				end
				if vim.g.project.exclude.dirs then
					vim.list_extend(never_show, vim.g.project.exclude.dirs)
				end
			end

			require("neo-tree").setup({
				close_if_last_window = true,
				window = {
					width = 30,
					mappings = {
						["<C-n>"] = "close_window",
						["<bs>"] = function()
							local commands = require("neo-tree.sources.filesystem.commands")
							local state = require("neo-tree.sources.manager").get_state("filesystem")
							if not state or state.path == vim.g.initial_cwd then
								return
							end
							commands.navigate_up(state)
						end,
					},
				},
				filesystem = {
					bind_to_cwd = false,
					filtered_items = {
						visible = false,
						hide_dotfiles = false,
						hide_gitignored = true,
						never_show = never_show,
						never_show_by_pattern = never_show_patterns,
					},
				},
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		cmd = "Telescope",
		enabled = not vim.g.neovim_orphan_group,
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
			local find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" }
			local grep_args = { "--hidden" }

			local file_patterns = { "*.meta", "*.asset" }
			local dir_names = {}

			if vim.g.project and vim.g.project.exclude then
				if vim.g.project.exclude.files then
					vim.list_extend(file_patterns, vim.g.project.exclude.files)
				end
				if vim.g.project.exclude.dirs then
					vim.list_extend(dir_names, vim.g.project.exclude.dirs)
				end
			end

			for _, pattern in ipairs(file_patterns) do
				vim.list_extend(find_command, { "--glob", "!" .. pattern })
				vim.list_extend(grep_args, { "--glob", "!" .. pattern })
			end
			for _, dir in ipairs(dir_names) do
				vim.list_extend(find_command, { "--glob", "!" .. dir .. "/**" })
				vim.list_extend(grep_args, { "--glob", "!" .. dir .. "/**" })
			end

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
						find_command = find_command,
					},
					live_grep = {
						additional_args = grep_args,
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
					close_command = "Bdelete %d",
					right_mouse_command = "Bdelete %d",
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
