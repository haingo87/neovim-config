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
	vim.api.nvim_echo({ { "\027[1t", "" } }, false, {})
	vim.fn.jobstart({
		"osascript",
		"-e",
		'tell application "System Events" to set frontmost of process "' .. M._terminal_process() .. '" to true',
	}, { detach = true })
end

function M._linux_focus()
	if vim.env.WAYLAND_DISPLAY then
		vim.notify("[session] Auto-focus unsupported on Wayland", vim.log.levels.INFO)
		return
	end

	vim.api.nvim_echo({ { "\027[1t", "" } }, false, {})

	if vim.fn.executable("wmctrl") == 1 then
		vim.fn.jobstart({ "wmctrl", "-a", M._terminal_window() }, { detach = true })
	elseif vim.fn.executable("xdotool") == 1 then
		vim.fn.jobstart({ "xdotool", "search", "--pid", vim.fn.getpid(), "windowactivate" }, { detach = true })
	else
		vim.notify("[session] Install wmctrl or xdotool for auto-focus", vim.log.levels.INFO)
	end
end

function M._tmux_focus()
	local pane = vim.fn.truncate(vim.env.TMUX_PANE or "", 0, 0)
	if pane and pane ~= "" then
		vim.fn.system({ "tmux", "select-pane", "-t", pane })
	end
end

function M._terminal_process()
	local cmd = vim.fn.system({ "ps", "-p", tostring(vim.fn.getppid()), "-o", "comm=" }):gsub("%s+", "")
	if cmd == "" then
		cmd = "Terminal"
	end
	return cmd
end

function M._terminal_window()
	return vim.o.titlestring or "nvim"
end

return M
