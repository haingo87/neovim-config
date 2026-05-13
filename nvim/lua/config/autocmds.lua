local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local general = augroup("General", { clear = true })

--- Strip trailing whitespace + format on save (gated by project config) ---
autocmd("BufWritePre", {
	group = general,
	pattern = "*",
	callback = function()
		local view = vim.fn.winsaveview()
		vim.cmd([[keeppatterns %s/\s\+$//e]])
		vim.fn.winrestview(view)

		local project = vim.g.project
		if project and project.features and project.features.format_on_save then
			local ok, conform = pcall(require, "conform")
			if ok then
				conform.format({ bufnr = vim.api.nvim_get_current_buf(), lsp_fallback = true })
			end
		end
	end,
})

autocmd("TextYankPost", {
	group = general,
	callback = function()
		vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
	end,
})

--- Project detection on dir change (cached) ---
local project_group = augroup("ProjectDetection", { clear = true })

local last_cwd = nil

--- Prevent leaving an active project root ---
autocmd("DirChangedPre", {
	group = project_group,
	callback = function()
		local p = require("util.project")
		if not p.project_root or not vim.v.event.cwd then
			return
		end
		local new_cwd = vim.fs.normalize(vim.v.event.cwd)
		local root = vim.fs.normalize(p.project_root)
		if new_cwd ~= root and not vim.startswith(new_cwd, root .. "/") then
			vim.notify("[project] Locked to " .. root .. ". Use :ProjectReload to switch.", vim.log.levels.WARN)
			error("Directory change blocked by active project")
		end
	end,
})

autocmd({ "BufEnter", "DirChanged" }, {
	group = project_group,
	callback = function()
		local cwd = vim.fn.getcwd()
		if cwd == last_cwd then
			return
		end
		last_cwd = cwd
		require("util.project").detect(cwd)
	end,
})

--- Auto-detect filetype from shebang ---
autocmd({ "BufRead", "BufNewFile" }, {
	group = general,
	callback = function()
		local line = vim.fn.getline(1)
		if line:match("^#!") then
			vim.cmd("filetype detect")
		end
	end,
})
