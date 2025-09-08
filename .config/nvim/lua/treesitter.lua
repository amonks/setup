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

-- requires nvim-treesitter
local parsers = require("nvim-treesitter.parsers")

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = parsers.ft_to_lang(ft)              -- maps e.g. 'typescriptreact' -> 'tsx'

    if parsers.has_parser(lang) then                 -- only start if we have a grammar
      vim.treesitter.start(args.buf, lang)
    end
  end,
})
