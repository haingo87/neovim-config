local M = {}

local DAEMON_SOCKET = vim.fn.stdpath("state") .. "/daemon.sock"

function M.connect(retries)
	retries = retries or 3
	for i = 1, retries do
		local sock = vim.fn.sockconnect("unix", DAEMON_SOCKET, { rpc = false })
		if sock > 0 then
			return sock
		end
		if i < retries then
			vim.wait(1000)
		end
	end
	return nil
end

function M.send(sock, msg)
	local data = vim.json.encode(msg) .. "\n"
	return vim.fn.chansend(sock, data)
end

function M.recv(sock, timeout_ms)
	timeout_ms = timeout_ms or 5000
	local buf = ""
	local start = vim.uv.now()
	while vim.uv.now() - start < timeout_ms do
		local chunk = vim.fn.ch_readraw(sock, { timeout = 100 })
		if chunk and #chunk > 0 then
			buf = buf .. chunk
			local nl = buf:find("\n")
			if nl then
				local line = buf:sub(1, nl - 1)
				local ok, parsed = pcall(vim.json.decode, line)
				if ok then
					return parsed
				end
			end
		end
		vim.wait(50)
	end
	return nil
end

return M
