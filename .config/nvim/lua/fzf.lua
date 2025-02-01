require("fzf-lua").setup()
require("fzf-lua").register_ui_select()

vim.api.nvim_set_keymap("n", "<C-b>", [[<Cmd>lua require"fzf-lua".buffers()<CR>]], {})
vim.api.nvim_set_keymap("n", "<C-p>", [[<Cmd>lua require"fzf-lua".files()<CR>]], {})
vim.api.nvim_set_keymap("n", "<C-f>", [[<Cmd>lua require"fzf-lua".live_grep_glob()<CR>]], {})



