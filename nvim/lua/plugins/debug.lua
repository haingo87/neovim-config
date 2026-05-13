return {
	{
		"mfussenegger/nvim-dap",
		keys = {
			{ "<F5>", function() require("dap").continue() end, mode = "n", desc = "Debug: Continue" },
			{ "<F9>", function() require("dap").toggle_breakpoint() end, mode = "n", desc = "Debug: Toggle breakpoint" },
			{ "<F10>", function() require("dap").step_over() end, mode = "n", desc = "Debug: Step over" },
			{ "<F11>", function() require("dap").step_into() end, mode = "n", desc = "Debug: Step into" },
			{ "<S-F11>", function() require("dap").step_out() end, mode = "n", desc = "Debug: Step out" },
		},
		dependencies = {
			"nvim-neotest/nvim-nio",
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

			local vscode = require("dap.ext.vscode")
			local orig_getconfigs = vscode.getconfigs
			vscode.getconfigs = function(path)
				local ok, result = pcall(orig_getconfigs, path)
				if ok then return result end
				return {}
			end

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
						{
							type = "coreclr",
							name = "Attach to Unity",
							request = "attach",
							processId = function()
								local handle = io.popen("pgrep -x Unity 2>/dev/null")
								if not handle then
									return tonumber(vim.fn.input("Unity PID: "))
								end
								local result = handle:read("*a")
								handle:close()
								local pid = tonumber(result:match("%d+"))
								if pid then
									return pid
								end
								return tonumber(vim.fn.input("Unity PID: "))
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
				pcall(dapui.close)
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				pcall(dapui.close)
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
