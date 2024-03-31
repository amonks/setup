vim.cmd([[
    " install packer if necessary
    let clone_dir = stdpath('config') . '/pack/packer/start/packer.nvim'
    if !filereadable(clone_dir)
        silent execute '!git clone --depth 1 https://github.com/wbthomason/packer.nvim ' . clone_dir
    endif
    unlet clone_dir
]])

require('packer').startup(function(use)
    use 'lewis6991/gitsigns.nvim'

    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' } -- fast syntax highlighting

    use 'christoomey/vim-tmux-navigator'      -- ctrl+j,k,l,m across tmux and vim panes (doesn't support nesting)
    use 'dhruvasagar/vim-table-mode'          -- markdown tables; use :TableModeToggle
    use 'easymotion/vim-easymotion'           -- type, eg, ,,j
    use 'google/vim-searchindex'              -- show "N of M"
    use 'jose-elias-alvarez/null-ls.nvim'     -- uses nvim's lsp integration as a hook to add a bunch of non-lsp tools
    use 'junegunn/fzf'                        -- ctrlp, search -- telescope seems cool but the implementation is insane
    use 'masukomi/vim-markdown-folding'       -- makes markdown headers foldable
    use 'mbbill/undotree'                     -- UndotreeToggle
    use 'neovim/nvim-lspconfig'               -- seems required for using builtin lsp
    use 'nvim-lua/plenary.nvim'               -- dependency of many lua plugins
    use 'stefandtw/quickfix-reflector.vim'    -- find-and-replace
    use 'vrischmann/tree-sitter-templ'        -- highlighting for go-templ

    -- tpope section (very based)
    use 'tpope/vim-abolish'                   -- :%Subvert/facilit{y,ies}/building{,s}/g, crs(nake)
    use 'tpope/vim-commentary'                -- gcc
    use 'tpope/vim-eunuch'                    -- :Rename (also renames buffer), :SudoWrite, :Mkdir
                                              -- also, redetect filetype and chmod+x after writing #! line
    use 'tpope/vim-fireplace'                 -- clojure repl
    use 'tpope/vim-fugitive'                  -- :Git blame
    use 'tpope/vim-repeat'                    -- make . repeat more things
    use 'tpope/vim-rsi'                       -- use bash-style insert bindings in commandline
    use 'tpope/vim-sleuth'                    -- automatically detect indent
    use 'tpope/vim-surround'                  -- ysiW"
    use 'tpope/vim-vinegar'                   -- press - to go to netrw
end)

require('gitsigns').setup({
    signs = {
        add    = { text = "+" },
        change = { text = "~" },
        delete = { text = "-" },
    },
})
