local M = {}

local DAEMON_SOCKET = vim.fn.stdpath("state") .. "/daemon.sock"

function M.connect(retries)
	retries = retries or 3
	for i = 1, retries do
		local pipe = vim.uv.new_pipe(false)
		if pipe then
			local connected = false
			local conn_err = nil
			pipe:connect(DAEMON_SOCKET, function(err)
				connected = true
				conn_err = err
			end)
			local start = vim.uv.now()
			while not connected and (vim.uv.now() - start < 3000) do
				vim.wait(50)
			end
			if connected and not conn_err then
				return pipe
			end
			if not pipe:is_closing() then
				pipe:close()
			end
		end
		if i < retries then
			vim.wait(1000)
		end
	end
	return nil
end

function M.send(sock, msg)
	local data = vim.json.encode(msg) .. "\n"
	sock:write(data)
end

function M.recv(sock, timeout_ms)
	timeout_ms = timeout_ms or 5000
	local buf = ""
	local result = nil

	sock:read_start(function(err, data)
		if err then
			result = false
			return
		end
		if data then
			buf = buf .. data
			local nl = buf:find("\n")
			if nl then
				local line = buf:sub(1, nl - 1)
				buf = buf:sub(nl + 1)
				local ok, parsed = pcall(vim.json.decode, line)
				if ok then
					result = parsed
				end
			end
		end
	end)

	local start = vim.uv.now()
	while not result and (vim.uv.now() - start < timeout_ms) do
		vim.wait(50)
	end

	sock:read_stop()
	return result
end

function M.close(sock)
	if sock and not sock:is_closing() then
		sock:close()
	end
end

return M
