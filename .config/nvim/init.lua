require("libmap")

vim.cmd([[
    let clone_dir = stdpath('config') . '/pack/packer/start/packer.nvim'
    if !filereadable(clone_dir)
        silent execute '!git clone --depth 1 https://github.com/wbthomason/packer.nvim ' . clone_dir
    endif
    unlet clone_dir

    autocmd BufWritePre * :%s/\s\+$//e

    filetype plugin indent on
]])


require('packer').startup(function(use)
    use {
        'lewis6991/gitsigns.nvim', requires = { 'nvim-lua/plenary.nvim' },
        config = function() require('gitsigns').setup() end
    }

    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' } -- fast syntax highlighting

    use 'airblade/vim-gitgutter'
    use 'overcache/NeoSolarized'
    use 'christoomey/vim-tmux-navigator'
    use 'dhruvasagar/vim-table-mode'          -- markdown tables
    use 'easymotion/vim-easymotion'           -- type, eg, ,,j
    use 'google/vim-searchindex'              -- show "N of M"
    -- use 'HiPhish/nvim-ts-rainbow2'
    use 'jose-elias-alvarez/null-ls.nvim'
    -- use 'luochen1990/rainbow'
    use 'mbbill/undotree'
    use 'morhetz/gruvbox'
    use 'neovim/nvim-lspconfig'
    use 'nvim-lua/plenary.nvim'               -- dependency of many lua plugins
    use 'junegunn/fzf'                        -- ctrlp, search -- telescope seems cool but the implementation is insane
    use 'stefandtw/quickfix-reflector.vim'    -- find-and-replace

    -- tpope section (very based)
    use 'tpope/vim-abolish'                   -- :%Subvert/facilit{y,ies}/building{,s}/g, crs(nake)
    use 'tpope/vim-commentary'                -- gcc
    use 'tpope/vim-eunuch'                    -- :Rename (also renames buffer), :SudoWrite
                                              -- also, redetect filetype and chmod+x after writing #! line
    use 'tpope/vim-fireplace'                 -- clojure repl
    use 'tpope/vim-fugitive'                  -- :Git blame
    use 'masukomi/vim-markdown-folding'
    use 'tpope/vim-repeat'                    -- make . repeat more things
    use 'tpope/vim-rsi'                       -- use bash-style insert bindings in commandline
    use 'tpope/vim-sleuth'                    -- automatically detect indent
    use 'tpope/vim-surround'                  -- ysiW"
    use 'tpope/vim-vinegar'                   -- press - to go to netrw
end)





local HOME = os.getenv("HOME")


local vim_opts = {
    -- gq wrap width; otherwise wraps to window
    -- textwidth = 70,

    -- allow editing multiple files at once
    hidden = true,

    -- no wrap
    wrap = false,

    -- / search; case sensitive unless search query contains caps
    ignorecase = true,
    smartcase = true,

    -- use rg for grep
    grepprg = "rg --vimgrep --no-heading --smart-case",

    -- swp in ~/.vim-tmp
    backup = true,
    swapfile = true,
    backupdir = HOME .. "/.vim-tmp",
    directory = HOME .. "/.vim-tmp",

    -- highlight selected line
    cursorline = true,

    -- line numbers
    number = true,

    -- be more verbose about stuff generally
    showcmd = true,

    -- briefly highlight matching brackets on close/open
    showmatch = true,

    -- use sh for scripting
    -- the fish conditional in this file,
    --     https://github.com/tpope/vim-sensible/blob/master/plugin/sensible.vim#L64
    -- looks tempting but doesn't seem to work for me :shrug:
    shell = "/bin/sh",

    -- default to spaces for indent
    shiftwidth = 2,
    softtabstop = 2,

    -- make backspace normal
    backspace = "indent,eol,start"
}

for k, v in pairs(vim_opts) do
    vim.opt[k] = v
end

vim.cmd([[
set foldmethod=syntax "syntax highlighting items specify folds
let javaScript_fold=1 "activate folding by JS syntax
let typeScript_fold=1 "activate folding by JS syntax
set foldlevelstart=99 "start file with all folds opened
]])


-- rainbow parens
-- vim.g.rainbow_active = 1


-- color scheme

vim.opt.termguicolors = true

function set_theme(theme)
    vim.opt.background = theme
    vim.cmd.colorscheme("monks")
end

function sync_theme()
    vim.fn.system("grep 'light mode' ~/.config/alacritty/alacritty.yml")
    if vim.v.shell_error == 0 then
        set_theme("light")
    else
        set_theme("dark")
    end
end
sync_theme()

nmap("<F6>", function ()
    vim.fn.system("fish -c toggle-night-mode")
    sync_theme()
end)



-- use comma as leader
vim.g.mapleader = ","

vim.g.markdown_fold_override_foldtext = 0




-- no shift to enter command mode, just use semicolon
nmapcmd(";", ":")
vmapcmd(";", ":")

-- -- ctrl-j/k for 'next'/'prev'
-- nmapcmd("<C-j>", ":lnext<CR>")
-- nmapcmd("<C-k>", ":lprev<CR>")






require('nvim-treesitter.configs').setup {
    ensure_installed = {
        "go",
        "bash",
        "comment",
        "fish",
        "glsl",
        "ledger",
        "terraform",
        "tsx",
        "typescript",
    },
    highlight = {
        enable = true,
        -- additional_vim_regex_highlighting = false,
    },
    -- rainbow = {
    --     enable = true,
    -- }
}




-- live grep
nmap("<C-f>", function()
  local fzf_run = vim.fn["fzf#run"]
  local fzf_wrp = vim.fn["fzf#wrap"]
  rg_prefix="rg --column --line-number --no-heading --color=always --smart-case"
  fzf_run(fzf_wrp({
    source = "echo ''",
    options = {
      "--bind", "start:reload:"..rg_prefix.." ''",
      "--bind", "change:reload:"..rg_prefix.." {q} || true",
      "--ansi", "--disabled",
      "--layout=reverse",
    },
    sink = function(item)
      print("hello", item)
      local firstColonIndex, _ = string.find(item, ":")
      local filepath = string.sub(item, 1, firstColonIndex-1)

      local secondColonIndex, _ = string.find(item, ":", firstColonIndex+1)
      local lineno = string.sub(item, firstColonIndex+1, secondColonIndex-1)

      vim.cmd("e +"..lineno.." "..filepath)
    end,
  }))
end)

-- ctrlp
nmap("<C-p>", function()
  local fzf_run = vim.fn["fzf#run"]
  local fzf_wrp = vim.fn["fzf#wrap"]
  fd = "fd --type=f --hidden --ignore --exclude=.git"
  fzf_run(fzf_wrp({
    source = "echo ''",
    options = {
      "--bind", "start:reload:"..fd,
      "--ansi",
      "--layout=reverse",
    },
    sink = "e"
  }))
end)



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

