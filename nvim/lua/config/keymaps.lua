local map = vim.keymap.set

--- File / Buffer Operations ---
map("n", "<C-w>", "<cmd>Bdelete<CR>", { desc = "Close buffer", nowait = true })
map("n", "<leader>w", "<cmd>Bdelete<CR>", { desc = "Close buffer" })
map("n", "<C-t>", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<C-S-f>", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<C-S-p>", "<cmd>Telescope commands<CR>", { desc = "Commands" })
map("n", "<C-Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<C-S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

--- Editor ---
map("n", "<A-Down>", "<cmd>move +1<CR>==", { desc = "Move line down" })
map("n", "<A-Up>", "<cmd>move -2<CR>==", { desc = "Move line up" })
map("v", "<A-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })
map("i", "<A-Down>", "<Esc>:move +1<CR>==gi", { desc = "Move line down" })
map("i", "<A-Up>", "<Esc>:move -2<CR>==gi", { desc = "Move line up" })
map("n", "<C-S-k>", "<cmd>delete<CR>", { desc = "Delete line" })
map("i", "<C-S-k>", "<C-o>dd", { desc = "Delete line" })

--- Window / Split Management ---
map("n", "<C-h>", "<C-w>h", { desc = "Left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Right window" })
map("n", "<C-s>", "<cmd>split<CR>", { desc = "Horizontal split" })
map("n", "<C-v>", "<cmd>vsplit<CR>", { desc = "Vertical split" })

--- Terminal ---
map("n", "<C-`>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Toggle terminal" })
map("t", "<C-`>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Toggle terminal" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal normal mode" })

--- Telescope from leader ---
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Document symbols" })

--- Debug (DAP) ---
map("n", "<F5>", function()
	local ok, dap = pcall(require, "dap")
	if ok then dap.continue() end
end, { desc = "Debug: Continue" })
map("n", "<F9>", function()
	local ok, dap = pcall(require, "dap")
	if ok then dap.toggle_breakpoint() end
end, { desc = "Debug: Toggle breakpoint" })
map("n", "<F10>", function()
	local ok, dap = pcall(require, "dap")
	if ok then dap.step_over() end
end, { desc = "Debug: Step over" })
map("n", "<F11>", function()
	local ok, dap = pcall(require, "dap")
	if ok then dap.step_into() end
end, { desc = "Debug: Step into" })
map("n", "<S-F11>", function()
	local ok, dap = pcall(require, "dap")
	if ok then dap.step_out() end
end, { desc = "Debug: Step out" })
