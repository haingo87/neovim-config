local M = {}

local daemon = require("util.daemon")

local function send_and_recv(msg, retries)
	local sock = daemon.connect(retries)
	if not sock then
		vim.notify("[session] Could not connect to daemon", vim.log.levels.WARN)
		return nil
	end
	daemon.send(sock, msg)
	local resp = daemon.recv(sock)
	daemon.close(sock)
	return resp
end

function M.register(project_root, socket_path, orphan)
	local msg = {
		cmd = "register",
		pid = vim.fn.getpid(),
		project_root = project_root,
		socket = socket_path,
	}
	if orphan then
		msg.orphan = true
	end
	local resp = send_and_recv(msg, 3)
	if not resp then
		vim.notify("[session] Daemon unreachable after 3 retries", vim.log.levels.WARN)
		return false
	end
	if resp.status == "dup" then
		return resp
	end
	vim.g.daemon_registered = true
	return true
end

function M.unregister(socket_path)
	if not vim.g.daemon_registered then
		return
	end
	local msg = {
		cmd = "unregister",
		socket = socket_path,
	}
	send_and_recv(msg, 1)
end

function M.lsp_start(server_type, cwd)
	if not vim.g.daemon_registered then
		return nil
	end
	local msg = { cmd = "lsp_start", type = server_type, cwd = cwd, pid = vim.fn.getpid() }
	for _ = 1, 10 do
		local resp = send_and_recv(msg)
		if not resp then
			return nil
		end
		if resp.socket_path then
			return resp.socket_path
		end
		if resp.status ~= "pending" then
			return nil
		end
		vim.wait(500, function() end, false)
	end
	return nil
end

function M.lsp_stop(server_type, cwd)
	if not vim.g.daemon_registered then
		return
	end
	local msg = { cmd = "lsp_stop", type = server_type, cwd = cwd, pid = vim.fn.getpid() }
	send_and_recv(msg, 1)
end

return M
