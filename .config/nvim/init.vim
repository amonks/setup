" Bootstrap Plug
let autoload_plug_path = stdpath('data') . '/site/autoload/plug.vim'
if !filereadable(autoload_plug_path)
  silent execute '!curl -fLo ' . autoload_plug_path . '  --create-dirs
      \ "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
unlet autoload_plug_path

call plug#begin('~/.local/share/nvim/plugged')

Plug 'christoomey/vim-tmux-navigator'

Plug 'neoclide/coc.nvim', {'branch': 'release'}
let g:coc_global_extensions = [
  \ 'coc-tsserver',
  \ 'coc-json',
  \ 'coc-prettier',
  \ 'coc-eslint'
  \ ]

" syntax
Plug 'sheerun/vim-polyglot'
Plug 'milch/vim-fastlane'

Plug 'powerman/vim-plugin-AnsiEsc'

" other
" Plug '~/.fzf'
Plug 'ap/vim-buftabline'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
let $FZF_DEFAULT_COMMAND = 'fd --type f'
Plug 'tpope/vim-fugitive'
Plug 'godlygeek/tabular' " required for vim-markdown
Plug 'airblade/vim-gitgutter' " see icons for changed lines in gutter
Plug 'easymotion/vim-easymotion' " type ,, before a motion for a visual selection rather than a count
Plug 'editorconfig/editorconfig-vim' " honor editorconfig files
Plug 'luochen1990/rainbow' " rainbow parentheses
Plug 'google/vim-searchindex' " show 'n of m'
Plug 'mbbill/undotree' " track a tree of edits
Plug 'mileszs/ack.vim' " search in project
Plug 'stefandtw/quickfix-reflector.vim' " project-wide find and replace
" Plug 'tpope/vim-commentary' " gc<motion> to comment
Plug 'tomtom/tcomment_vim' " like commentary but supports contextual JSX
Plug 'morhetz/gruvbox'
Plug 'tpope/vim-repeat' " support repeating more things with .
Plug 'tpope/vim-rsi' " regular bash movement bindings in commandline and insert modes (ctrl-a to go to the beginning of a line, etc)
Plug 'tpope/vim-speeddating' " increment dates intelligently with ctrl-a and ctrl-x in normal mode
Plug 'tpope/vim-surround' " ys<movement><surround> to add surround, cs<movement><surround> to change surround, ds<surround> to delete surround,
			  " for example, ysiw<em> surrounds the current word in an <em> tag
Plug 'tpope/vim-vinegar' " press - to go up a directory

" Plug 'vim-airline/vim-airline' " status bar
" Plug 'vim-airline/vim-airline-themes'

call plug#end()









" I think this has to come before any mappings that use leader
" the leader is a prefix-modifier key used for lots of stuff.
" the default leader is backslash but comma is more common for some reason
" <leader><leader>j means 'press comma twice then pres j'
let mapleader = ","

" no shift to enter command mode, just use the semicolon key
nnoremap ; :
vnoremap ; :

" allow editing multiple files at once
set hidden

" enable syntax highlighting
syntax enable

" " show files as a tree (press dash in normal mode). You can press i in the
" " file browser to switch views. ':help netrw' for more.
" let g:netrw_liststyle=3

" show buffer numbers
let g:buftabline_numbers=1
" disable weird alternate buffer numbering
let g:buftabline_plug_max=0

" enable scrolling
set mouse=a

" search while typing, not just after pressing enter
set incsearch

" case insensitive, unless the search term contains caps
set ignorecase
set smartcase

" use escape in normal mode to clear the highlighting from the last search
nnoremap <space> :let @/ = ""<return><esc>

" ctrl-dash to see a list of open files
map <C--> :BufExplorer<CR>

" highlight search results
set hlsearch

" use better autoindent
set cindent

" make backspace normal
set backspace=indent,eol,start

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


" RAINBOW PARENTHESES
let g:rainbow_active = 1
" Colors I got off the internet somewhere
let g:rainbow_conf = { 'ctermfgs': ['cyan', 'magenta', 'yellow', 'grey', 'red', 'green', 'blue'], 'guifgs': ['#FF0000', '#FF00FF', '#FFFF00', '#000000', '#FF0000', '#00FF00', '#0000FF'] }


" ACK
" use ack alternatives if present
if executable('rg')
  let g:ackprg = 'rg --vimgrep'
elseif executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif


" MARKDOWN
" disable annoying code folding with vim-markdown
let g:vim_markdown_folding_disabled=1
" enable yaml front matter highlighting in vim-markdown
let g:vim_markdown_frontmatter=1


" COLOR SCHEME
set background=dark
colorscheme gruvbox



" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

nmap <C-P> :FZF<CR>
nmap <leader><space> <Plug>(coc-codeaction)
nmap <leader><leader><space> :<C-u>CocList commands<cr>
nmap <leader>o :<C-u>CocList outline<cr>
nmap <leader>f <Plug>(coc-fix-current)
nmap <leader>. :call CocAction('doHover')<CR>
nmap <leader>r <Plug>(coc-rename)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

