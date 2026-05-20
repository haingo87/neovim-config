local M = {}

local features = require("util.features")

M.cache = {}

function M.detect(cwd)
	local cached = M.cache[cwd]
	if cached ~= nil then
		return cached
	end

	local found = vim.fs.find(".nvproj", { upward = true, path = cwd })
	local result = nil

	if #found > 0 then
		local path = found[1]
		vim.g.project_dirname = vim.fn.fnamemodify(path, ":h:t")
		vim.g.project_nvproj_path = path
		local chunk, load_err = loadfile(path)
		if chunk then
			local ok, parsed = pcall(chunk)
			if ok and type(parsed) == "table" then
				result = parsed
				vim.g.project = parsed
				features.load(parsed, path)
				vim.notify("[project] Loaded " .. path, vim.log.levels.INFO)
			else
				vim.notify("[project] Failed to parse " .. path .. ": " .. tostring(parsed), vim.log.levels.WARN)
			end
		else
			vim.notify("[project] Failed to load " .. path .. ": " .. tostring(load_err), vim.log.levels.WARN)
		end
	else
		vim.g.project = nil
		vim.g.project_dirname = nil
		vim.g.project_nvproj_path = nil
		features.flush()
	end

	M.cache[cwd] = result
	return result
end

function M.ensure_lsp_servers()
	local base = { "jsonls", "yamlls", "marksman" }
	local servers = vim.deepcopy(base)

	if features.has("lua") then
		table.insert(servers, "lua_ls")
	end
	if features.has("csharp") then
		local ok, registry = pcall(require, "mason-registry")
		if ok and not registry.is_installed("roslyn") then
			vim.schedule(function()
				vim.cmd("MasonInstall roslyn")
			end)
		end
	end
	if features.has("cpp") then
		table.insert(servers, "clangd")
	end
	if features.has("cmake") then
		table.insert(servers, "cmake_ls")
	end
	if features.has("go") then
		table.insert(servers, "gopls")
	end
	-- dartls is a system LSP (Dart SDK) — not a Mason package, so it's not
	-- added to ensure_installed here. It is configured in lsp.lua instead.
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
	if not features.has("debug") then
		return
	end

	local adapters = {}
	if features.has("csharp") then
		table.insert(adapters, "netcoredbg")
	end
	if features.has("cpp") then
		table.insert(adapters, "codelldb")
	end
	if features.has("go") then
		table.insert(adapters, "delve")
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
