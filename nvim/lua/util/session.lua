local M = {}

local function sessions_path()
	return vim.fn.stdpath("state") .. "/sessions.json"
end

local function lockfile_path()
	return vim.fn.stdpath("state") .. "/sessions.lock"
end

local function pid_alive(pid)
	if pid and vim.fn.has("unix") == 1 then
		vim.fn.system({ "kill", "-0", tostring(pid) })
		if vim.v.shell_error == 0 then
			local comm = vim.fn.system({ "ps", "-p", tostring(pid), "-o", "comm=" }):gsub("%s+", "")
			return comm:find("nvim") ~= nil
		end
	end
	return false
end

local function with_lock(fn)
	local lockfile = lockfile_path()
	local pid = tostring(vim.fn.getpid())
	local acquired = false
	for _ = 1, 40 do
		local fd = vim.uv.fs_open(lockfile, "wx", 438)
		if fd then
			vim.uv.fs_write(fd, pid, 0)
			vim.uv.fs_close(fd)
			acquired = true
			break
		end
		local data = vim.fn.readfile(lockfile)
		local holder_pid = tonumber(data[1])
		if pid_alive(holder_pid) then
			vim.wait(50, function() return false end, 20)
		else
			os.remove(lockfile)
		end
	end
	if not acquired then
		vim.notify("[session] Could not acquire lock after 2s", vim.log.levels.ERROR)
		return
	end
	local ok, result = pcall(fn)
	os.remove(lockfile)
	if ok then
		return result
	end
end

local function read_sessions()
	local path = sessions_path()
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.size == 0 then
		return {}
	end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return {}
	end
	local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

local function write_sessions(sessions)
	local path = sessions_path()
	local tmp = path .. ".tmp"
	vim.fn.writefile({ vim.json.encode(sessions) }, tmp)
	vim.fn.rename(tmp, path)
end

function M.register(project_root, socket)
	with_lock(function()
		local sessions = read_sessions()
		for i, s in ipairs(sessions) do
			if s.socket == socket then
				sessions[i] = { project_root = project_root, socket = socket }
				write_sessions(sessions)
				return
			end
		end
		table.insert(sessions, { project_root = project_root, socket = socket })
		write_sessions(sessions)
	end)
end

function M.unregister(project_root, socket)
	with_lock(function()
		local sessions = read_sessions()
		for i = #sessions, 1, -1 do
			if sessions[i].project_root == project_root and sessions[i].socket == socket then
				table.remove(sessions, i)
				break
			end
		end
		write_sessions(sessions)
	end)
end

return M
