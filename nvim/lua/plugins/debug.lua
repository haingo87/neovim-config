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
			{
				"ownself/nvim-dap-unity",
				build = function()
					require("nvim-dap-unity").install()
				end,
			},
		},
		config = function()
			local f = require("util.features")
			if not f.has("debug") then
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

			if f.has("csharp") and f.has("unity") then
				local unity_ok = pcall(require, "nvim-dap-unity")
				if unity_ok then
					require("nvim-dap-unity").setup({
						auto_install_on_start = false,
					})
				end
			end

			if f.has("cpp") then
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

			if f.has("go") then
				dap.adapters.delve = {
					type = "server",
					port = "${port}",
					executable = {
						command = "dlv",
						args = { "dap", "-l", "127.0.0.1:${port}" },
					},
				}
				dap.configurations.go = {
					{
						type = "delve",
						name = "Debug",
						request = "launch",
						program = "${file}",
					},
				}
			end

			if f.has("flutter") then
				dap.adapters.dart = {
					type = "executable",
					command = "flutter",
					args = { "debug-adapter" },
				}
				dap.configurations.dart = {
					{
						type = "dart",
						name = "Flutter",
						request = "launch",
						program = "${workspaceFolder}/lib/main.dart",
					},
				}
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

			local function close_dapui()
				pcall(dapui.close)
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
						vim.api.nvim_win_set_width(win, 30)
					end
				end
			end

			dap.listeners.before.event_terminated["dapui_config"] = close_dapui
			dap.listeners.before.event_exited["dapui_config"] = close_dapui
			dap.listeners.before.disconnect["dapui_config"] = close_dapui
			dap.listeners.before.terminate["dapui_config"] = close_dapui

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
