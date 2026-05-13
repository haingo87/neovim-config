return {
	{
		"mfussenegger/nvim-dap",
		keys = {
			{ "<F5>", mode = "n" },
			{ "<F9>", mode = "n" },
			{ "<F10>", mode = "n" },
			{ "<F11>", mode = "n" },
			{ "<S-F11>", mode = "n" },
		},
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"theHamsta/nvim-dap-virtual-text",
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			local project = vim.g.project
			if not (project and project.features and project.features.debug == true) then
				return
			end

			local dap = require("dap")

			if project and project.env then
				if project.env.type == "csharp" then
					dap.adapters.coreclr = {
						type = "executable",
						command = "netcoredbg",
						args = { "--interpreter=vscode" },
					}
					dap.configurations.cs = {
						{
							type = "coreclr",
							name = "Launch - netcoredbg",
							request = "launch",
							program = function()
								return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
							end,
						},
					}
				elseif project.env.type == "cpp" then
					dap.adapters.codelldb = {
						type = "server",
						port = "${port}",
						executable = {
							command = "codelldb",
							args = { "--port", "${port}" },
						},
					}
					dap.configurations.c = {
						{
							name = "Launch (codelldb)",
							type = "codelldb",
							request = "launch",
							program = function()
								return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
							end,
							cwd = "${workspaceFolder}",
							stopOnEntry = false,
						},
					}
					dap.configurations.cpp = dap.configurations.c
				end
			end

			local dapui = require("dapui")
			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.25 },
							{ id = "breakpoints", size = 0.25 },
							{ id = "stacks", size = 0.25 },
							{ id = "watches", size = 0.25 },
						},
						position = "left",
						size = 40,
					},
					{
						elements = {
							{ id = "repl", size = 0.5 },
							{ id = "console", size = 0.5 },
						},
						position = "bottom",
						size = 10,
					},
				},
			})

			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			require("nvim-dap-virtual-text").setup({
				commented = true,
			})

			require("mason-nvim-dap").setup({
				automatic_installation = true,
				handlers = {},
			})
		end,
	},
}
