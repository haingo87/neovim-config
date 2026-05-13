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

--- Set terminal title ---
local title_group = augroup("SetTitle", { clear = true })

local last_file = nil

local function track_last_file()
	local buftype = vim.bo.buftype
	local bufname = vim.api.nvim_buf_get_name(0)
	if buftype == "" and bufname ~= "" then
		last_file = bufname
	end
end

local function set_title()
	local buftype = vim.bo.buftype
	local fname
	if buftype == "" then
		fname = vim.fn.expand("%:t")
		if fname == "" then
			fname = "[No Name]"
		end
	elseif last_file then
		fname = vim.fn.fnamemodify(last_file, ":t")
	else
		local bufs = vim.fn.getbufinfo({ buflisted = 1 })
		for _, buf in ipairs(bufs) do
			if buf.name ~= "" and vim.fn.bufwinid(buf.bufnr) ~= -1 then
				fname = vim.fn.fnamemodify(buf.name, ":t")
				break
			end
		end
		if not fname then
			fname = "[No Name]"
		end
	end
	if vim.g.project_dirname then
		vim.o.titlestring = vim.g.project_dirname .. " - " .. fname
	else
		vim.o.titlestring = fname
	end
end

autocmd({ "BufEnter", "BufReadPost", "BufNewFile", "FileReadPost", "FocusGained" }, {
	group = title_group,
	callback = function()
		track_last_file()
		set_title()
	end,
})

track_last_file()
set_title()
