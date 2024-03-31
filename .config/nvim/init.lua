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

