-- treesitter setup

require("nvim-treesitter.parsers").get_parser_configs().templ = {
  install_info = {
    url = "https://github.com/vrischmann/tree-sitter-templ.git",
    files = {"src/parser.c", "src/scanner.c"},
    branch = "master",
  },
}
vim.treesitter.language.register('templ', 'templ')

require('nvim-treesitter.configs').setup {
    ensure_installed = {
        "bash",
        "comment",
        "fish",
        "glsl",
        "go",
        "ledger",
        "templ",
        "terraform",
        "tsx",
        "typescript",
    },
    highlight = {
        enable = true,
    },
}

