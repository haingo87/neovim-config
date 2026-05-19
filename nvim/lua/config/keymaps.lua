local map = vim.keymap.set

--- Disable terminal flow control for <C-s> ---
vim.api.nvim_set_keymap("n", "<C-s>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<C-s>", "<Nop>", { noremap = true, silent = true })
vim.cmd([[silent! stty -ixon --file /dev/stdin]])

--- File / Buffer Operations ---
map("n", "<C-s>", "<cmd>write<CR>", { desc = "Save file" })
map("i", "<C-s>", "<C-o><cmd>write<CR>", { desc = "Save file" })
map("n", "<C-w>", "<cmd>Bdelete<CR>", { desc = "Close buffer", nowait = true })
map("n", "<leader>w", "<cmd>Bdelete<CR>", { desc = "Close buffer" })
map("n", "<C-t>", ":Telescope find_files<CR>", { desc = "Find files" })
map("n", "<C-S-f>", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<C-S-p>", "<cmd>Telescope commands<CR>", { desc = "Commands" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

--- Editor ---
map("n", "<A-Down>", "<cmd>move +1<CR>==", { desc = "Move line down" })
map("n", "<A-Up>", "<cmd>move -2<CR>==", { desc = "Move line up" })
map("v", "<A-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })
map("i", "<A-Down>", "<Esc>:move +1<CR>==gi", { desc = "Move line down" })
map("i", "<A-Up>", "<Esc>:move -2<CR>==gi", { desc = "Move line up" })
map("n", "<C-S-k>", "<cmd>delete<CR>", { desc = "Delete line" })
map("i", "<C-S-k>", "<C-o>dd", { desc = "Delete line" })

--- Display-line navigation (wrap-friendly) ---
map("n", "<Down>", "gj", { desc = "Down (display line)" })
map("n", "<Up>", "gk", { desc = "Up (display line)" })
map("i", "<Down>", "<C-o>gj", { desc = "Down (display line)" })
map("i", "<Up>", "<C-o>gk", { desc = "Up (display line)" })

--- Window / Split Management ---

map("n", "<leader>t", "<cmd>Terminal<CR>", { desc = "Open terminal" })

--- Telescope from leader ---
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Document symbols" })

--- Utility Commands ---
vim.api.nvim_create_user_command("Totabs", function()
	local et = vim.bo.expandtab
	vim.bo.expandtab = false
	vim.cmd("retab!")
	vim.bo.expandtab = et
	vim.notify("retab! done", vim.log.levels.INFO)
end, { desc = "Convert spaces to tabs respecting tabstop" })
