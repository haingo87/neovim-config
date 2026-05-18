return {
	{
		"L3MON4D3/LuaSnip",
		event = "InsertEnter",
		dependencies = { "saadparwaiz1/cmp_luasnip" },
		config = function()
			require("luasnip.loaders.from_lua").lazy_load()
		end,
	},

	{
		"milanglacier/minuet-ai.nvim",
		event = "InsertEnter",
		config = function()
			require("minuet").setup({
				n_completions = 1,
				context_window = 512,
				cmp = {
					enable_auto_complete = false,
				},
				virtualtext = {
					auto_trigger_ft = {},
					keymap = {
						accept = '<A-\\>',
						accept_line  = '<A-a>',
						accept_n_lines = '<A-z>',
						next         = '<A-]>',
						prev         = '<A-[>',
						dismiss      = '<A-e>',
					},
				},
				lsp = {
					enabled_ft = { 'toml', 'lua', 'cpp', 'json', 'csharp', 'go', 'dart' },
					-- It is recommended to disable completion when use inline_completion
					completion = { enable = false },
					inline_completion = {
						enable = true,
						enabled_auto_trigger_ft = {},
					},
				},

				--[[ Google Gemini
				provider = "gemini",
				provider_options = {
					openai_compatible = {
						end_point = 'https://generativelanguage.googleapis.com/v1beta/models',
						api_key = "GEMINI_API_KEY",
						name = "Google Gemini",
						model = "gemma-4-26b-a4b-it",
						system = "see [Prompt] section for the default value",
						few_shots = "see [Prompt] section for the default value",
						chat_input = "See [Prompt Section for default value]",
						stream = true,
						transform = {},
						optional = {
							generationConfig = {
								maxOutputTokens = 256,
								thinkingConfig = {
									-- Disable thinking for gemini 2.5 models
									thinkingBudget = 0,
									-- Disable thinking for gemini 3.x models
									thinkingLevel = 'minimal',
									-- Setting only one of the above options is sufficient.
								},
							},
							safetySettings = {
								{
									-- HARM_CATEGORY_HATE_SPEECH,
									-- HARM_CATEGORY_HARASSMENT
									-- HARM_CATEGORY_SEXUALLY_EXPLICIT
									category = 'HARM_CATEGORY_DANGEROUS_CONTENT',
									-- BLOCK_NONE
									threshold = 'BLOCK_ONLY_HIGH',
								},
							},
						},
					},
				},
				]]

				provider = 'openai_compatible',
				provider_options = {
					openai_compatible = {
						model = 'llama-3.1-8b-instant',
						end_point = 'https://api.groq.com/openai/v1/chat/completions',
						api_key = 'GROQ_API_KEY',
						name = 'Groq',
					},
				},
			})
		end,
	},

	{
		"David-Kunz/gen.nvim",
		keys = {
			{ "<leader>gf", ":Gen Fix_Code<CR>", mode = "v", desc = "Fix code with AI" },
			{ "<leader>gt", ":Gen Fix_Typos<CR>", mode = "v", desc = "Fix typos with AI" },
		},
		opts = {
			model = "llama-3.1-8b-instant",
			json_response = true,
			init = function() end,
			command = function(options)
				local key = os.getenv("GROQ_API_KEY")
				if not key then
					vim.notify("GROQ_API_KEY not set", vim.log.levels.ERROR)
					return ""
				end
				return "curl --silent --no-buffer -X POST https://api.groq.com/openai/v1/chat/completions"
					.. " -H 'Content-Type: application/json'"
					.. " -H 'Authorization: Bearer " .. key .. "'"
					.. " -d $body"
			end,
		},
		config = function(_, opts)
			require("gen").setup(opts)
			local p = require("gen").prompts
			p["Fix_Code"] = {
				prompt = "Fix bugs, syntax errors, and typos in the following code. Only output the fixed code in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
				replace = true,
				extract = "```$filetype\n(.-)```",
			}
			p["Fix_Typos"] = {
				prompt = "Fix grammar, spelling, and typos in the following text. Keep the original meaning. Only output the fixed text:\n$text",
				replace = true,
			}
		end,
	},

	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			local cmp = require("cmp")

			local has_words_before = function()
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return col ~= 0
				and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s")
				== nil
			end

			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif require("luasnip").expand_or_jumpable() then
							require("luasnip").expand_or_jump()
						elseif has_words_before() then
							cmp.complete()
						else
							fallback()
						end
					end, { "i", "s" }),

					["<S-Tab>"] = cmp.mapping(function(fallback)
						if require("luasnip").jumpable(-1) then
							require("luasnip").jump(-1)
						else
							cmp.select_prev_item()
						end
					end, { "i", "s" }),
					["<C-Space>"] = cmp.mapping.complete(),
					["<CR>"] = cmp.mapping.confirm({ select = false }),
					["<C-e>"] = cmp.mapping.abort(),
				}),
				sources = cmp.config.sources(
					{
						{ name = "nvim_lsp" },
						{ name = "luasnip" },
						{ name = "minuet" },
					},
					{
						{ name = "buffer" },
						{ name = "path" },
					}
				),
			})
		end,
	},
}
