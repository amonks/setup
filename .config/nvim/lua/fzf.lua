require("fzf-lua").setup()
require("fzf-lua").register_ui_select()

local config = [[{ file_ignore_patterns = { "terraform/output" } }]]

vim.api.nvim_set_keymap("n", "<C-b>", [[<Cmd>lua require"fzf-lua".buffers(]]..config..[[)<CR>]], {})
vim.api.nvim_set_keymap("n", "<C-p>", [[<Cmd>lua require"fzf-lua".files(]]..config..[[)<CR>]], {})
vim.api.nvim_set_keymap("n", "<C-f>", [[<Cmd>lua require"fzf-lua".live_grep_glob(]]..config..[[)<CR>]], {})
