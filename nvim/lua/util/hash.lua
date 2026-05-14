local M = {}

function M.sha256_short(data)
	local hash = vim.fn.sha256(data)
	return hash:sub(1, 12)
end

return M
