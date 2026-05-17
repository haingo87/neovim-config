return {
	{
		"famiu/bufdelete.nvim",
		event = "UIEnter",
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		enabled = not vim.g.neovim_light_mode,
		config = function()
			require("which-key").setup({
				preset = "modern",
			})
		end,
	},

	{
		"nvim-tree/nvim-tree.lua",
		lazy = vim.g.neovim_light_mode,
		enabled = not vim.g.neovim_light_mode,
		keys = {
			{ "<C-n>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
		},
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			local exclude_dirs = { ".DS_Store", "thumbs.db", ".git", "node_modules", "__pycache__" }

			if vim.g.project and vim.g.project.exclude then
				if vim.g.project.exclude.dirs then
					vim.list_extend(exclude_dirs, vim.g.project.exclude.dirs)
				end
			end

			local tree_width = 30
			local tree_actual_width = tree_width

			require("nvim-tree").setup({
				on_attach = function(bufnr)
					local api = require("nvim-tree.api")

					api.map.on_attach.default(bufnr)

					if not vim.g.initial_cwd then
						return
					end

					vim.keymap.del("n", "-", { buffer = bufnr })
					vim.keymap.del("n", "<C-]>", { buffer = bufnr })
					vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
				end,
				sync_root_with_cwd = false,
				sort = {
					sorter = "case_sensitive",
				},
				view = {
					width = tree_width,
				},
				filters = {
					dotfiles = false,
					custom = exclude_dirs,
				},
				git = {
					ignore = true,
				},
				renderer = {
					root_folder_label = false,
					group_empty = true,
				},
				actions = {
					open_file = {
						quit_on_open = false,
						window_picker = {
							enable = false,
						},
					},
				},
			})

			vim.api.nvim_create_autocmd("QuitPre", {
				desc = "Close nvim-tree when last file buffer is closed",
				callback = function()
					if vim.bo.buftype == "terminal" then
						local wins = vim.api.nvim_list_wins()
						local tree_count = 0
						local other_non_tree = 0
						for _, win in ipairs(wins) do
							if win ~= vim.api.nvim_get_current_win() then
								local buf = vim.api.nvim_win_get_buf(win)
								if vim.bo[buf].filetype == "NvimTree" then
									tree_count = tree_count + 1
								else
									other_non_tree = other_non_tree + 1
								end
							end
						end

						if other_non_tree == 0 and tree_count > 0 then
							vim.cmd("NvimTreeClose")
						end
						return
					end

					local wins = vim.api.nvim_list_wins()
					local tree_count = 0
					local non_tree_count = 0
					for _, win in ipairs(wins) do
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].filetype == "NvimTree" then
							tree_count = tree_count + 1
						else
							non_tree_count = non_tree_count + 1
						end
					end

					if tree_count > 0 and non_tree_count <= 1 then
						vim.cmd("NvimTreeClose")
					end
				end,
			})

			local tree_actual_width = tree_width

			vim.api.nvim_create_autocmd("WinResized", {
				desc = "Track and preserve nvim-tree width",
				callback = function()
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
							local current = vim.api.nvim_win_get_width(win)
							if current == tree_width and tree_actual_width ~= tree_width then
								vim.api.nvim_win_set_width(win, tree_actual_width)
							elseif current ~= tree_width then
								tree_actual_width = current
							end
							return
						end
					end
				end,
			})

			vim.api.nvim_create_autocmd("BufEnter", {
				desc = "Open scratch buffer when tree is the last window",
				callback = function()
					if vim.bo.filetype ~= "NvimTree" then return end

					vim.schedule(function()
						if #vim.api.nvim_list_wins() ~= 1 then return end

						-- Find existing hidden scratch buffer to reuse instead of creating new
						local reuse = nil
						for _, b in ipairs(vim.api.nvim_list_bufs()) do
							if vim.api.nvim_buf_is_valid(b)
								and vim.api.nvim_buf_get_name(b) == ""
								and vim.bo[b].buftype == ""
								and vim.bo[b].filetype == ""
								and vim.fn.bufwinnr(b) == -1
								and not vim.bo[b].modified then
								reuse = b
								break
							end
						end

						-- Delete orphaned hidden scratch buffers (never keep more than one)
						for _, b in ipairs(vim.api.nvim_list_bufs()) do
							if vim.api.nvim_buf_is_valid(b)
								and vim.api.nvim_buf_get_name(b) == ""
								and vim.bo[b].buftype == ""
								and vim.bo[b].filetype == ""
								and vim.fn.bufwinnr(b) == -1
								and not vim.bo[b].modified
								and b ~= reuse then
								pcall(vim.api.nvim_buf_delete, b, { force = true })
							end
						end

						vim.cmd("vsplit")
						if reuse then
							vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), reuse)
						else
							vim.cmd("enew")
						end

						for _, win in ipairs(vim.api.nvim_list_wins()) do
							if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
								vim.api.nvim_win_set_width(win, tree_actual_width)
								break
							end
						end
					end)
				end,
			})

			-- Redirect :terminal to a non-tree window to avoid extra window creation
			-- Community workaround: Neovim doesn't protect sidebar windows from splits
			vim.api.nvim_create_user_command("Terminal", function(opts)
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					local buf = vim.api.nvim_win_get_buf(win)
					if vim.bo[buf].filetype ~= "NvimTree" then
						vim.api.nvim_set_current_win(win)
						break
					end
				end
				vim.cmd("terminal " .. opts.args)
			end, { nargs = "*", desc = "Open terminal in a non-tree window" })

			-- Transparent abbreviation so :terminal runs our custom command
			vim.cmd([[
				cnoreabbrev <expr> terminal
					\ getcmdtype() == ':' && getcmdline() =~# '^terminal\s*$'
					\ ? 'Terminal' : 'terminal'
			]])
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		cmd = "Telescope",
		enabled = not vim.g.neovim_light_mode,
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
					preview = {
						treesitter = {
							enable = false,
						},
					},
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
					left_mouse_command = function(bufnr)
						local curwin = vim.api.nvim_get_current_win()
						local curbuf = vim.api.nvim_win_get_buf(curwin)
						if vim.bo[curbuf].filetype == "NvimTree" then
							local target = nil
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local buf = vim.api.nvim_win_get_buf(win)
								if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].buftype == "" then
									target = win
									break
								end
							end
							if target then
								vim.api.nvim_set_current_win(target)
							else
								vim.cmd("vsplit | enew")
							end
						end
						pcall(vim.api.nvim_set_current_buf, bufnr)
					end,
					indicator = {
						style = "none",
					},
					separator_style = "thin",
					show_close_icon = true,
					show_buffer_close_icons = true,
					diagnostics = "nvim_lsp",
					offsets = {
						{
							filetype = "NvimTree",
							text = "Explorer",
							highlight = "Directory",
							text_align = "left",
						},
					},
				},
			})
		end,
	},
}
