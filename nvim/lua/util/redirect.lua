local M = {}

function M.init()
	if vim.fn.executable("xdotool") == 1 and not vim.env.WAYLAND_DISPLAY then
		local wid = vim.fn.system({ "xdotool", "getactivewindow" }):gsub("%s+", "")
		if wid ~= "" and tonumber(wid) then
			M._x11_window = wid
		end
	end
end

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
	local win_id = vim.g.macos_window_id
	local tab_idx = vim.g.macos_tab_index
	local app = vim.g.macos_terminal_app

	if win_id and app then
		local lines
		if tab_idx and app == "Ghostty" then
			lines = {
				"osascript", "-e",
				"tell application \"" .. app .. "\"",
				"-e", "activate",
				"-e", "select tab (tab " .. tab_idx .. " of window id \"" .. win_id .. "\")",
				"-e", "end tell",
			}
		else
			lines = {
				"osascript", "-e",
				"tell application \"" .. app .. "\"",
				"-e", "activate",
				"-e", "set frontmost of window id \"" .. win_id .. "\" to true",
				"-e", "end tell",
			}
		end
		vim.fn.jobstart(lines, { detach = true })
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

	if M._x11_window then
		if vim.fn.executable("xdotool") == 1 then
			vim.fn.system({
				"xdotool", "windowactivate", M._x11_window,
				"set_window", "--urgency", "1", M._x11_window,
			})
		end
		return
	end

	if vim.fn.executable("xdotool") == 1 then
		local pid = vim.fn.getpid()
		for _ = 1, 10 do
			local wid = vim.fn.system({
				"xdotool", "search", "--pid", tostring(pid),
				"--limit", "1",
			}):gsub("%s+", "")
			if wid ~= "" and tonumber(wid) then
				vim.fn.system({ "xdotool", "windowactivate", wid })
				return
			end
			local ppid = vim.fn.system({ "ps", "-p", tostring(pid), "-o", "ppid=" })
			ppid = tonumber((ppid:gsub("%D+", "")))
			if not ppid or ppid <= 1 then break end
			pid = ppid
		end
	else
		vim.notify("[session] Install xdotool for auto-focus", vim.log.levels.INFO)
	end
end

function M.focus_info()
	if not M._x11_window then return "" end
	local info = M._x11_window
	if vim.g.project_dirname then
		info = info .. ":" .. vim.g.project_dirname
	end
	return info
end

function M._tmux_focus()
	local pane = vim.env.TMUX_PANE
	if pane and pane ~= "" then
		vim.fn.system({ "tmux", "select-pane", "-t", pane })
	end
end

return M
