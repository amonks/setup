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

    use {
        'nvim-telescope/telescope-fzf-native.nvim',
        run = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
    }


    use 'airblade/vim-gitgutter'
    use 'christoomey/vim-tmux-navigator' 
    use 'easymotion/vim-easymotion'           -- type, eg, ,,j
    use 'google/vim-searchindex'              -- show "N of M"
    use 'jose-elias-alvarez/null-ls.nvim' 
    use 'mbbill/undotree' 
    use 'morhetz/gruvbox' 
    use 'neovim/nvim-lspconfig' 
    use 'nvim-lua/plenary.nvim'               -- dependency of many lua plugins
    use 'nvim-telescope/telescope.nvim'       -- ctrlp, search
    use 'stefandtw/quickfix-reflector.vim'    -- find-and-replace

    -- tpope section (vary based)
    use 'tpope/vim-abolish'                   -- :%Subvert/facilit{y,ies}/building{,s}/g, crs(nake)
    use 'tpope/vim-commentary'                -- gcc
    use 'tpope/vim-eunuch'                    -- :Rename (also renames buffer), :SudoWrite
                                              -- also, redetect filetype and chmod+x after writing #! line
    use 'tpope/vim-fugitive'                  -- :Git blame
    use 'tpope/vim-repeat'                    -- make . repeat more things
    use 'tpope/vim-rsi'                       -- use bash-style insert bindings in commandline
    use 'tpope/vim-sleuth'                    -- automatically detect indent
    use 'tpope/vim-surround'                  -- ysiW"
    use 'tpope/vim-vinegar'                   -- press - to go to netrw
end)


-- gq wrap width; otherwise wraps to window
-- vim.opt.textwidth = 70

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

local function map(mode, shortcut, command, extra)
    opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.keymap.set(mode, shortcut, command, opts)
end
local function nmap(shortcut, command, extra) map('n', shortcut, command, extra) end
local function imap(shortcut, command, extra) map('i', shortcut, command, extra) end
local function vmap(shortcut, command, extra) map('v', shortcut, command, extra) end

local function mapcmd(mode, shortcut, command, extra)
    opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.api.nvim_set_keymap(mode, shortcut, command, opts)
end
local function nmapcmd(shortcut, command, extra) map('n', shortcut, command, extra) end
local function imapcmd(shortcut, command, extra) map('i', shortcut, command, extra) end
local function vmapcmd(shortcut, command, extra) map('v', shortcut, command, extra) end

-- no shift to enter command mode, just use semicolon
nmapcmd(";", ":")
vmapcmd(";", ":")

-- -- ctrl-j/k for 'next'/'prev'
-- nmapcmd("<C-j>", ":lnext<CR>")
-- nmapcmd("<C-k>", ":lprev<CR>")






require('nvim-treesitter.configs').setup {
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    },
}




require('telescope').load_extension('fzf')
local builtin = require('telescope.builtin')
local function find_files()
  builtin.find_files({
    find_command = {"fd", "--type=f", "--hidden", "--ignore", "--exclude=.git"},
  }) 
end
nmap("<C-p>", find_files)
nmap("<leader>ff", find_files) 
nmap("<leader>fg", builtin.live_grep)
nmap("<leader>fc", builtin.treesitter)
nmap("<leader>fb", builtin.buffers)
nmap("<leader>fh", builtin.help_tags)




local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
local group = vim.api.nvim_create_augroup("lsp_format_on_save", { clear = false })

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
                    vim.lsp.buf.format({ bufnr = bufnr, async = false })
                end,
                desc = "[lsp] format on save",
            })
        end
    end

    -- enable completion triggered by <C-x><C-o>
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

    local extra = { buffer = bufnr }
    nmap("gD", vim.lsp.buf.type_definition, extra)
    nmap("gd", vim.lsp.buf.definition, extra)
    nmap("gr", vim.lsp.buf.references, extra)

    nmap("K", vim.lsp.buf.hover, extra)
    nmap("gi", vim.lsp.buf.implementation, extra)

    nmap("<C-k>", vim.lsp.buf.signature_help, extra)
    imap("<C-k>", vim.lsp.buf.signature_help, extra)

    -- nmap("?", vim.diagnostic.open_float, extra)
    nmap("[d", vim.diagnostic.goto_prev, extra)
    nmap("]d", vim.diagnostic.goto_next, extra)

    nmap("<space>rn", vim.lsp.buf.rename, extra)
    nmap("<space>ca", vim.lsp.buf.code_action, extra)
    nmap("<space>f", function() vim.lsp.buf.format({ async = true }) end, extra)
end

local null_ls = require("null-ls")
null_ls.setup({
    debug = true,
    on_attach = on_attach,
    sources = {
        null_ls.builtins.formatting.prettierd,
        null_ls.builtins.diagnostics.eslint_d,
    },
})

local lspconfig = require("lspconfig")
lspconfig["tsserver"].setup({ on_attach = on_attach })
lspconfig["gopls"].setup({ on_attach = on_attach })

