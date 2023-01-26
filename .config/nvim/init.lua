vim.cmd([[
    let clone_dir = stdpath('config') . '/pack/packer/start/packer.nvim'
    if !filereadable(clone_dir)
        silent execute '!git clone --depth 1 https://github.com/wbthomason/packer.nvim ' . clone_dir
    endif
    unlet clone_dir
]])


require('packer').startup(function(use)
    use {
        'lewis6991/gitsigns.nvim', requires = { 'nvim-lua/plenary.nvim' },
        config = function() require('gitsigns').setup() end
    }

    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' } -- fast syntax highlighting

    use 'airblade/vim-gitgutter'
    use 'christoomey/vim-tmux-navigator' 
    use 'easymotion/vim-easymotion'           -- type, eg, ,,j
    use 'google/vim-searchindex'              -- show "N of M"
    use 'jose-elias-alvarez/null-ls.nvim' 
    use 'luochen1990/indent-detector.vim'     -- auto set tab to match file
    use 'mbbill/undotree' 
    use 'morhetz/gruvbox' 
    use 'neovim/nvim-lspconfig' 
    use 'nvim-lua/plenary.nvim'               -- dependency of many lua plugins
    use 'nvim-telescope/telescope.nvim'       -- ctrlp, search
    use 'stefandtw/quickfix-reflector.vim'    -- find-and-replace
    use 'tpope/vim-commentary'                -- comment stuff out with gc
    use 'tpope/vim-fugitive'                  -- :Git blame
    use 'tpope/vim-repeat'                    -- make . repeat more things
    use 'tpope/vim-rsi'                       -- use bash-style insert bindings in commandline
    use 'tpope/vim-surround' 
    use 'tpope/vim-vinegar'                   -- press - to go to netrw
end)


-- gq wrap width; otherwise wraps to window
vim.opt.textwidth = 70

-- allow editing multiple files at once
vim.opt.hidden = true

-- 
vim.opt.wrap = false

-- / search; case sensitive unless search query contains caps
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- swp in ~/.vim-tmp
vim.opt.backup = true
vim.opt.swapfile = true
local HOME = os.getenv("HOME")
vim.opt.backupdir = HOME .. "/.vim-tmp"
vim.opt.directory = HOME .. "/.vim-tmp"

-- highlight selected line
vim.opt.cursorline = true

-- line numbers
vim.opt.number = true

-- be more verbose about stuff generally
vim.opt.showcmd = true

-- briefly highlight matching brackets on close/open
vim.opt.showmatch = true

-- use bash for scripting
-- the fish conditional in this file
-- https://github.com/tpope/vim-sensible/blob/master/plugin/sensible.vim#L64
-- looks tempting but doesn't seem to work for me :shrug:
vim.opt.shell = "/bin/bash"

-- default to spaces for indent
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2

-- make backspace normal
vim.opt.backspace = "indent,eol,start"

-- color scheme
vim.opt.background = "dark"
vim.cmd.colorscheme("gruvbox")

-- italic comments (but doesn't work with termguicolors :( )
vim.cmd.highlight("Comment cterm=italic")

-- prettier colors but no cool italic comments
-- -- vim.opt.termguicolors = false

-- use comma as leader
vim.g.mapleader = ","




-- keyboard mapping helpers

local function map(mode, shortcut, command)
    vim.api.nvim_set_keymap(mode, shortcut, command, { noremap = true, silent = true })
end

local function nmap(shortcut, command)
    map('n', shortcut, command)
end

local function imap(shortcut, command)
    map('i', shortcut, command)
end

local function vmap(shortcut, command)
    map('v', shortcut, command)
end

-- no shift to enter command mode, just use semicolon
nmap(";", ":")
vmap(";", ":")

-- -- ctrl-j/k for 'next'/'prev'
-- nmap("<C-j>", ":lnext<CR>")
-- nmap("<C-k>", ":lprev<CR>")






require('nvim-treesitter.configs').setup {
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    },
}


local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local on_attach = function(client, bufnr)
    -- avoid formatting conflict between tsserver and prettier
    if client.name == "tsserver" then
        client.server_capabilities.documentFormattingProvider = false
    end

    -- make null-ls format on save when possible
    if client.name == "null-ls" then
        if client.supports_method("textDocument/formatting") then
            vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = augroup,
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.formatting_ssync()
                end,
            })
        end
    end

    -- enable completion triggered by <C-x><C-o>
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

    local function map(mode, shortcut, command)
        vim.keymap.set(mode, shortcut, command, { noremap = true, silent = true, buffer = bufnr })
    end
    local function nmap(shortcut, command) map('n', shortcut, command) end
    local function imap(shortcut, command) map('i', shortcut, command) end

    nmap("gD", vim.lsp.buf.type_definition)
    nmap("gd", vim.lsp.buf.definition)
    nmap("gr", vim.lsp.buf.references)

    nmap("K", vim.lsp.buf.hover)
    nmap("gi", vim.lsp.buf.implementation)

    nmap("<C-k>", vim.lsp.buf.signature_help)
    imap("<C-k>", vim.lsp.buf.signature_help)

    nmap("?", vim.diagnostic.open_float)
    nmap("[d", vim.diagnostic.goto_prev)
    nmap("]d", vim.diagnostic.goto_next)

    nmap("<space>rn", vim.lsp.buf.rename)
    nmap("<space>ca", vim.lsp.buf.code_action)
    nmap("<space>f", function() vim.lsp.buf.format { async = true } end)
end

local null_ls = require("null-ls")
null_ls.setup({
    on_attach = on_attach,
    sources = {
        null_ls.builtins.formatting.prettierd,
        null_ls.builtins.diagnostics.eslint_d,
    },
})

local lspconfig = require("lspconfig")
lspconfig["tsserver"].setup({ on_attach = on_attach })
lspconfig["gopls"].setup({ on_attach = on_attach })

