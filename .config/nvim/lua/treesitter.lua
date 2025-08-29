-- treesitter setup

require('nvim-treesitter').setup {
    ensure_installed = {
        "bash",
        "comment",
        "fish",
        "glsl",
        "go",
        "ledger",
        "markdown",
        "markdown_inline",
        "templ",
        "terraform",
        "tsx",
        "typescript",
    },
}

vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        vim.treesitter.start()
    end,
})
