return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				flavour = "mocha",
				transparent_background = false,
				integrations = {
					bufferline = true,
					gitsigns = true,
					indent_blankline = { enabled = true },
					lualine = true,
					mason = true,
					neotree = true,
					dap = { enabled = true, enable_ui = true },
					telescope = { enabled = true },
					todo_comments = true,
					which_key = true,
				},
			})
			vim.cmd.colorscheme("catppuccin")
		end,
	},

	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		config = function()
			require("lualine").setup({
				options = {
					theme = "catppuccin",
					section_separators = "",
					component_separators = "",
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch" },
					lualine_c = { "filename" },
					lualine_x = { "diagnostics" },
					lualine_y = { "filetype" },
					lualine_z = { "location" },
				},
			})
		end,
	},

	{
		"nvim-tree/nvim-web-devicons",
		lazy = true,
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		event = "VeryLazy",
		main = "ibl",
		config = function()
			require("ibl").setup({
				scope = { enabled = false },
			})
		end,
	},

	{
		"lewis6991/gitsigns.nvim",
		event = "BufReadPre",
		config = function()
			require("gitsigns").setup({
				signcolumn = true,
				numhl = false,
				current_line_blame = true,
				current_line_blame_opts = {
					virt_text = true,
					virt_text_pos = "eol",
					delay = 1000,
				},
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns
					local map = function(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end
					map("n", "]c", gs.next_hunk, { desc = "Next hunk" })
					map("n", "[c", gs.prev_hunk, { desc = "Previous hunk" })
					map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
					map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
					map("n", "<leader>hS", gs.stage_buffer, { desc = "Stage buffer" })
					map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
					map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview hunk" })
					map("n", "<leader>hb", gs.blame_line, { desc = "Blame line" })
				end,
			})
		end,
	},

	{
		"folke/todo-comments.nvim",
		event = "BufReadPre",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("todo-comments").setup({
				keywords = {
					TODO = { icon = " ", color = "info", alt = { "TO-DO" } },
					FIXME = { icon = " ", color = "error", alt = { "FIX", "FIXIT", "BUG" } },
					HACK = { icon = " ", color = "warning", alt = { "HACK" } },
					WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
					PERF = { icon = " ", color = "hint", alt = { "OPTIM", "PERFORMANCE" } },
					NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
				},
			})
		end,
	},
}
