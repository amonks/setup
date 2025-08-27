-- install lazy if necessary
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
    -- when editing lua, only lazily load nvim-related types
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },

    -- fast syntax highlighting
    {
        'nvim-treesitter/nvim-treesitter',
        lazy = false,
        branch = 'main',
        build = ':TSUpdate'
    },

    'mason-org/mason.nvim',               -- language-tool manager
    'mason-org/mason-lspconfig.nvim',     -- language-tool manager integration
    'zapling/mason-lock.nvim',            -- save deps

    'darfink/vim-plist',
    'christoomey/vim-tmux-navigator',     -- ctrl+j,k,l,m across tmux and vim panes (doesn't support nesting)
    'dhruvasagar/vim-table-mode',         -- markdown tables; use :TableModeToggle
    'easymotion/vim-easymotion',          -- type, eg, ,,j
    'google/vim-searchindex',             -- show "N of M"
    'nvimtools/none-ls.nvim',             -- uses nvim's lsp integration as a hook to add a bunch of non-lsp tools
    "ibhagwan/fzf-lua",
    'lewis6991/gitsigns.nvim',            -- gitgutter
    'masukomi/vim-markdown-folding',      -- makes markdown headers foldable
    'mbbill/undotree',                    -- UndotreeToggle
    'neovim/nvim-lspconfig',              -- seems required for using builtin lsp
    'nvim-lua/plenary.nvim',              -- dependency of many lua plugins
    'stefandtw/quickfix-reflector.vim',   -- find-and-replace
    'vrischmann/tree-sitter-templ',       -- highlighting for go-templ

    -- tpope section (very based)
    'tpope/vim-abolish',                  -- :%Subvert/facilit{y,ies}/building{,s}/g, crs(nake)
    'tpope/vim-commentary',               -- gcc
    'tpope/vim-eunuch',                   -- :Rename (also renames buffer), :SudoWrite, :Mkdir
                                          -- also, redetect filetype and chmod+x after writing #! line
    'tpope/vim-fireplace',                -- clojure repl
    'tpope/vim-fugitive',                 -- :Git blame
    'tpope/vim-repeat',                   -- make . repeat more things
    'tpope/vim-rsi',                      -- use bash-style insert bindings in commandline
    'tpope/vim-sleuth',                   -- automatically detect indent
    'tpope/vim-surround',                 -- ysiW"
    'tpope/vim-vinegar',                  -- press - to go to netrw
})

