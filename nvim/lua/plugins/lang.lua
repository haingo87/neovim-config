return {
	{
		"seblj/roslyn.nvim",
		ft = "cs",
		config = function()
			local project = vim.g.project
			if not (project and project.env and project.env.type == "csharp") then
				return
			end
			require("roslyn").setup({
				config = {
					filetypes = { "cs" },
					settings = {
						["csharp|inlay_hints"] = {
							csharp_enable_inlay_hints_for_implicit_object_creation = true,
							csharp_enable_inlay_hints_for_implicit_variable_types = true,
							csharp_enable_inlay_hints_for_lambda_parameter_types = true,
							csharp_enable_inlay_hints_for_types = true,
							dotnet_enable_inlay_hints_for_indexer_parameters = true,
							dotnet_enable_inlay_hints_for_literal_parameters = true,
							dotnet_enable_inlay_hints_for_object_creation_parameters = true,
							dotnet_enable_inlay_hints_for_other_parameters = true,
							dotnet_enable_inlay_hints_for_parameters = true,
							dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = false,
							dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = false,
							dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = false,
						},
					},
				},
			})
		end,
	},

	{
		"stevearc/conform.nvim",
		cmd = "ConformInfo",
		config = function()
			local project = vim.g.project
			if not (project and project.features and project.features.format_on_save == true) then
				return
			end
			require("conform").setup({
				formatters_by_ft = {
					cs = { "csharpier" },
					c = { "clang_format" },
					cpp = { "clang_format" },
					lua = { "stylua" },
				},
				format_on_save = false,
				default_format_opts = {
					lsp_fallback = true,
				},
			})
		end,
	},
}
