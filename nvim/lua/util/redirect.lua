local M = {}

function M.bring_to_front()
	if vim.env.SSH_CONNECTION then
		local pid = vim.fn.getpid()
		vim.notify("[session] Opened in existing nvim instance (pid " .. pid .. ")", vim.log.levels.INFO)
		return
	end

	if vim.env.TMUX then
		M._tmux_focus()
		return
	end

	local uname = vim.fn.system("uname"):gsub("%s+", "")
	if uname == "Darwin" then
		M._macos_focus()
	else
		M._linux_focus()
	end
end

function M._macos_focus()
	local tab_idx = vim.g.ghostty_tab_index
	local win_id = vim.g.ghostty_window_id
	if tab_idx and win_id then
		vim.fn.jobstart({
			"osascript", "-e",
			"tell application \"Ghostty\"",
			"-e", "activate",
			"-e", "select tab (tab " .. tab_idx .. " of window id \"" .. win_id .. "\")",
			"-e", "end tell",
		}, { detach = true })
		return
	end

	local terminal = vim.env.TERM_PROGRAM
	local process_name = "Terminal"
	if terminal == "iTerm.app" then
		process_name = "iTerm2"
	elseif terminal == "Apple_Terminal" then
		process_name = "Terminal"
	elseif terminal == "WezTerm" then
		process_name = "WezTerm"
	elseif terminal == "kitty" then
		process_name = "kitty"
	end

	vim.api.nvim_echo({ { "\027[1t", "" } }, false, {})
	vim.fn.jobstart({
		"osascript",
		"-e",
		'tell application "System Events" to set frontmost of process "' .. process_name .. '" to true',
	}, { detach = true })
end

function M._linux_focus()
	if vim.env.WAYLAND_DISPLAY then
		vim.notify("[session] Auto-focus unsupported on Wayland", vim.log.levels.INFO)
		return
	end

	vim.api.nvim_echo({ { "\027[1t", "" } }, false, {})

	if vim.fn.executable("xdotool") == 1 then
		vim.fn.jobstart({ "xdotool", "search", "--pid", vim.fn.getpid(), "windowactivate" }, { detach = true })
	elseif vim.fn.executable("wmctrl") == 1 then
		vim.fn.jobstart({ "wmctrl", "-a", M._terminal_process() }, { detach = true })
	else
		vim.notify("[session] Install wmctrl or xdotool for auto-focus", vim.log.levels.INFO)
	end
end

function M._tmux_focus()
	local pane = vim.env.TMUX_PANE
	if pane and pane ~= "" then
		vim.fn.system({ "tmux", "select-pane", "-t", pane })
	end
end

function M._terminal_process()
	local ppid = vim.uv.os_getppid()
	local cmd = vim.fn.system({ "ps", "-p", tostring(ppid), "-o", "comm=" }):gsub("%s+", "")
	if cmd == "" then
		cmd = "Terminal"
	end
	return cmd
end

return M
