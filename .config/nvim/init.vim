" Plugins {{{1

" Bootstrap Plug
let autoload_plug_path = stdpath('data') . '/site/autoload/plug.vim'
if !filereadable(autoload_plug_path)
  silent execute '!curl -fLo ' . autoload_plug_path . '  --create-dirs
      \ "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
unlet autoload_plug_path

" Install plugins
call plug#begin('~/.local/share/nvim/plugged')
Plug 'airblade/vim-gitgutter' " see icons for changed lines in gutter
Plug 'christoomey/vim-tmux-navigator'
Plug 'cweagans/vim-taskpaper'
Plug 'darfink/vim-plist'
Plug 'easymotion/vim-easymotion' " type ,, before a motion for a visual selection rather than a count
Plug 'editorconfig/editorconfig-vim' " honor editorconfig files
Plug 'google/vim-searchindex' " show 'n of m'
Plug 'jlanzarotta/bufexplorer'
Plug 'nvim-lua/plenary.nvim' " lua thing idk
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'jose-elias-alvarez/null-ls.nvim' " lua thing idk
Plug 'MunifTanjim/prettier.nvim'
Plug 'luochen1990/indent-detector.vim'
Plug 'luochen1990/rainbow' " rainbow parentheses
Plug 'mbbill/undotree' " track a tree of edits
Plug 'milch/vim-fastlane'
Plug 'mileszs/ack.vim' " search in project
Plug 'morhetz/gruvbox'
Plug 'neovim/nvim-lspconfig' " Interface for language servers to interact w/ built in LSP
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'powerman/vim-plugin-AnsiEsc'
Plug 'stefandtw/quickfix-reflector.vim' " project-wide find and replace
Plug 'tomtom/tcomment_vim' " like commentary but supports contextual JSX
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat' " support repeating more things with .
Plug 'tpope/vim-rsi' " regular bash movement bindings in commandline and insert modes (ctrl-a to go to the beginning of a line, etc)
Plug 'tpope/vim-speeddating' " increment dates intelligently with ctrl-a and ctrl-x in normal mode
Plug 'tpope/vim-surround' " ys<movement><surround> to add surround, cs<movement><surround> to change surround, ds<surround> to delete surround,
Plug 'tpope/vim-vinegar' " press - to go up a directory
call plug#end()



" Settings {{{1
"

" allow editing multiple files at once
set hidden

" enable syntax highlighting
syntax enable

" enable scrolling
set mouse=a

" no wrap
set nowrap

" search while typing, not just after pressing enter
set incsearch

" highlight search results
set hlsearch

" case insensitive, unless the search term contains caps
set ignorecase
set smartcase

" use better autoindent
set cindent

" save swp in ~/.vim-tmp
set backup
set swapfile
set backupdir=~/.vim-tmp
set directory=~/.vim-tmp

" highlight the selected line
set cursorline

" show line numbers
set number

" be more verbose about stuff generally
set showcmd

" briefly highlight matching brackets on close/open
set showmatch

" Allow scrolling past the bottom of the document
set scrolloff=1

" make vim use bash for it's scripting stuff, fish isn't compatible
" the fish conditional in this file
" https://github.com/tpope/vim-sensible/blob/master/plugin/sensible.vim#L64
" looks tempting but doesn't seem to work for me :shrug:
set shell=/bin/bash

" use spaces for tab indentation if editorconfig isn't set
set shiftwidth=2
set softtabstop=2

" don't break mid word
set linebreak

" Color scheme
set background=dark
colorscheme gruvbox

" italic comments but doesn't work with termguicolors
highlight Comment cterm=italic

" prettier colors but no italics
set termguicolors


" Plugin Settings {{{1


" Rainbow Parentheses {{{2

let g:rainbow_active = 0
" Colors I got off the internet somewhere
let g:rainbow_conf = { 'ctermfgs': ['cyan', 'magenta', 'yellow', 'grey', 'red', 'green', 'blue'], 'guifgs': ['#FF0000', '#FF00FF', '#FFFF00', '#000000', '#FF0000', '#00FF00', '#0000FF'] }

" Ack.vim {{{2

" use ack alternatives if present
if executable('rg')
  let g:ackprg = 'rg --vimgrep'
elseif executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif

" FZF {{{2

let $FZF_DEFAULT_COMMAND = 'fd --type f'

" COC {{{2

" let g:coc_global_extensions = [
"   \ 'coc-tsserver',
"   \ 'coc-json',
"   \ 'coc-prettier',
"   \ 'coc-eslint'
"   \ ]



" Keyboard {{{1


" I think this has to come before any mappings that use leader
" the leader is a prefix-modifier key used for lots of stuff.
" the default leader is backslash but comma is more common for some reason
" <leader><leader>j means 'press comma twice then pres j'
let mapleader = ","

" no shift to enter command mode, just use the semicolon key
nnoremap ; :
vnoremap ; :

" make backspace normal
set backspace=indent,eol,start


nmap <C-e> :BufExplorerVerticalSplit<CR>

nmap <C-p> :FZF<CR>
" nmap <leader><space> <Plug>(coc-codeaction)
" nmap <leader><leader><space> :<C-u>CocList commands<cr>
" nmap <leader>o :<C-u>CocList outline<cr>
" nmap <leader>f <Plug>(coc-fix-current)
" nmap <leader>. :call CocActionAsync('doHover')<CR>
" nmap <leader>r <Plug>(coc-rename)

" nmap <C-c> gg:CocDiagnostics<CR>:lopen<CR>
nmap <C-n> :lnext<CR>

" GoTo code navigation.
" nmap <silent> gd <Plug>(coc-definition)
" nmap <silent> gy <Plug>(coc-type-definition)
" nmap <silent> gi <Plug>(coc-implementation)
" nmap <silent> gr <Plug>(coc-references)
" nmap <silent> ,r <Plug>(coc-rename)



" Filetype Settings {{{1


autocmd Syntax sql setlocal foldmethod=marker
autocmd Syntax vim setlocal foldmethod=marker
autocmd Syntax typescript setlocal foldmethod=syntax foldlevel=99

" autocmd FileType swift let b:coc_root_patterns = ['.xcodeproj', '.xcworkspace', ]

function! WritingWords()
  return system("cat ~/writing/*.md | sed 's/[^A-z ]//g\' | wc -w")[:-2] . " words"
endfunction
autocmd BufRead,BufNewFile,BufWritePost */ajm/writing/* setlocal statusline=%{WritingWords()}





" COC completion keybindings {{{1

"
" all from h coc-completion-example
" 




" " Use <tab> and <S-tab> to navigate completion list: >
"
"  function! s:check_back_space() abort
"    let col = col('.') - 1
"    return !col || getline('.')[col - 1]  =~ '\s'
"  endfunction
"
" " Insert <tab> when previous text is space, refresh completion if not.
" inoremap <silent><expr> <TAB>
" \ coc#pum#visible() ? coc#pum#next(1):
" \ <SID>check_back_space() ? "\<Tab>" :
" \ coc#refresh()
" inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
"
" " Use <c-space> to trigger completion:
"
" if has('nvim')
"   inoremap <silent><expr> <c-space> coc#refresh()
" else
"   inoremap <silent><expr> <c-@> coc#refresh()
" endif
"
" " Use <CR> to confirm completion, use:
"
" inoremap <expr> <cr> coc#pum#visible() ? coc#_select_confirm() : "\<CR>"
"
" " To make <CR> to confirm selection of selected complete item or notify coc.nvim
" " to format on enter, use:
"
" inoremap <silent><expr> <CR> coc#pum#visible() ? coc#_select_confirm()
"   \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
"
" " Map <tab> for trigger completion, completion confirm, snippet expand and jump
" " like VSCode:
"
" inoremap <silent><expr> <TAB>
"   \ coc#pum#visible() ? coc#_select_confirm() :
"   \ coc#expandableOrJumpable() ?
"   \ "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
"   \ <SID>check_back_space() ? "\<TAB>" :
"   \ coc#refresh()
"
" function! s:check_back_space() abort
"   let col = col('.') - 1
"   return !col || getline('.')[col - 1]  =~# '\s'
" endfunction
"
" let g:coc_snippet_next = '<tab>'
"
" " Note: the `coc-snippets` extension is required for this to work.
"


" TreeSitter syntax highlighting {{{1

lua <<EOF
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}
EOF


" Neovim LSP {{{1


lua <<EOF


-- from https://github.com/MunifTanjim/prettier.nvim
local null_ls = require("null-ls")

local group = vim.api.nvim_create_augroup("lsp_format_on_save", { clear = false })
local event = "BufWritePre" -- or "BufWritePost"
local async = event == "BufWritePost"

null_ls.setup({
  on_attach = function(client, bufnr)
    if client.supports_method("textDocument/formatting") then
      vim.keymap.set("n", "<Leader>f", function()
        vim.lsp.buf.format({ bufnr = vim.api.nvim_get_current_buf() })
      end, { buffer = bufnr, desc = "[lsp] format" })

      -- format on save
      vim.api.nvim_clear_autocmds({ buffer = bufnr, group = group })
      vim.api.nvim_create_autocmd(event, {
        buffer = bufnr,
        group = group,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr, async = async })
        end,
        desc = "[lsp] format on save",
      })
    end

    if client.supports_method("textDocument/rangeFormatting") then
      vim.keymap.set("x", "<Leader>f", function()
        vim.lsp.buf.format({ bufnr = vim.api.nvim_get_current_buf() })
      end, { buffer = bufnr, desc = "[lsp] format" })
    end
  end,
})


-- from https://github.com/MunifTanjim/prettier.nvim
local prettier = require("prettier")
prettier.setup({
  bin = 'prettier', -- or `'prettierd'` (v0.22+)
  filetypes = {
    "css",
    "graphql",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "less",
    "markdown",
    "scss",
    "typescript",
    "typescriptreact",
    "yaml",
  },
})


-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local opts = { noremap=true, silent=true }
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
end

require('lspconfig')['tsserver'].setup{
    on_attach = on_attach,
    flags = lsp_flags,
}

require('lspconfig')['gopls'].setup{
  on_attach = on_attach,
  flags = lsp_flags,
}

EOF



