-- require ./lua/XYZ.lua
require("libmap")
require("plugins")
require("options")
require("colors")
require("treesitter")
require("fzf")
require("lsp")

-- don't save trailling whitespace
vim.api.nvim_create_autocmd({"BufWritePre"}, {
    pattern = {"*"},
    command = ":%s/\\s\\+$//e",
})


-- no shift to enter command mode, just use semicolon
nmapcmd(";", ":")
vmapcmd(";", ":")

-- undotree with ctrl+u
nmapcmd("<C-u>", ":UndotreeToggle<CR>")
vmapcmd("<C-u>", ":UndotreeToggle<CR>")

-- set up gitsigns
require('gitsigns').setup({
    -- tell it about config repo
    worktrees = {
        { toplevel = vim.env.HOME, gitdir = vim.env.HOME .. '/.cfg' },
    },
    -- use gitgutter's sigils
    signs = {
        add    = { text = "+" },
        change = { text = "~" },
        delete = { text = "-" },
    },
})

