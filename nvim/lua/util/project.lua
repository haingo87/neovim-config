local M = {}

M.cache = {}

function M.detect(cwd)
	local cached = M.cache[cwd]
	if cached ~= nil then
		return cached
	end

	local found = vim.fs.find(".project", { upward = true, path = cwd })
	local result = nil

	if #found > 0 then
		local path = found[1]
		local chunk, load_err = loadfile(path)
		if chunk then
			local ok, parsed = pcall(chunk)
			if ok and type(parsed) == "table" then
				result = parsed
				vim.g.project = parsed
				vim.notify("[project] Loaded " .. path, vim.log.levels.INFO)
			else
				vim.notify("[project] Failed to parse " .. path .. ": " .. tostring(parsed), vim.log.levels.WARN)
			end
		else
			vim.notify("[project] Failed to load " .. path .. ": " .. tostring(load_err), vim.log.levels.WARN)
		end
	else
		vim.g.project = nil
	end

	M.cache[cwd] = result
	return result
end

function M.ensure_lsp_servers()
	local base = { "lua_ls", "jsonls", "yamlls", "marksman" }
	local servers = vim.deepcopy(base)

	if vim.g.project and vim.g.project.env then
		local t = vim.g.project.env.type
		if t == "csharp" then
			vim.schedule(function()
				vim.cmd("MasonInstall roslyn")
			end)
		elseif t == "cpp" then
			table.insert(servers, "clangd")
		end
	end

	local status, mason_lspconfig = pcall(require, "mason-lspconfig")
	if status then
		mason_lspconfig.setup({
			ensure_installed = servers,
			automatic_installation = true,
			handlers = { function() end },
		})
		vim.notify("[project] LSP servers: " .. table.concat(servers, ", "), vim.log.levels.INFO)
	end
end

function M.ensure_dap_adapters()
	if not vim.g.project or not vim.g.project.features or not vim.g.project.features.debug then
		return
	end

	local adapters = {}
	local t = vim.g.project.env and vim.g.project.env.type
	if t == "csharp" then
		adapters = { "netcoredbg" }
	elseif t == "cpp" then
		adapters = { "codelldb" }
	end

	local status, mason_nvim_dap = pcall(require, "mason-nvim-dap")
	if status and #adapters > 0 then
		mason_nvim_dap.setup({
			ensure_installed = adapters,
			automatic_installation = true,
		})
		vim.notify("[project] DAP adapters: " .. table.concat(adapters, ", "), vim.log.levels.INFO)
	end
end

return M
