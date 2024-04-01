-- vim options
-- equivalent to `set x=y` in viml
for k, v in pairs({
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
    backupdir = os.getenv("HOME") .. "/.vim-tmp",
    directory = os.getenv("HOME") .. "/.vim-tmp",

    -- line numbers
    number = false,
    cursorline = false,

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
    backspace = "indent,eol,start",

    -- infer folds from syntax highlighting somehow idk
    foldmethod = "syntax",
    -- start with all folds open
    foldlevelstart = 99,
}) do
    vim.opt[k] = v
end

-- vim globals
-- equivalent to `let g.x=y` in viml
for k, v in pairs({
    -- tell typescript.vim to set fold points
    -- am I even using typescript.vim? It isn't listed as a plugin; this might not do anything.
    javaScript_fold = 1,
    typeScript_fold = 1,

    -- used by masukomi/vim-markdown-folding; not sure what it does tho
    markdown_fold_override_foldtext = 0,

    -- make markdown tables compatible with markdown
    table_mode_corner = "|",

    -- use comma as leader
    mapleader = ",",
}) do
    vim.g[k] = v
end

