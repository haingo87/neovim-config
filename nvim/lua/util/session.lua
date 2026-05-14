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
	pcall(vim.fn.chanclose, sock, "rw")
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

return M
