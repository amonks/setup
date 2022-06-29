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
Plug 'jlanzarotta/bufexplorer'
Plug 'christoomey/vim-tmux-navigator'
Plug 'cweagans/vim-taskpaper'
Plug 'easymotion/vim-easymotion' " type ,, before a motion for a visual selection rather than a count
Plug 'editorconfig/editorconfig-vim' " honor editorconfig files
Plug 'fatih/vim-go'
Plug 'google/vim-searchindex' " show 'n of m'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'luochen1990/indent-detector.vim'
Plug 'luochen1990/rainbow' " rainbow parentheses
Plug 'mbbill/undotree' " track a tree of edits
Plug 'milch/vim-fastlane'
Plug 'mileszs/ack.vim' " search in project
Plug 'morhetz/gruvbox'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'powerman/vim-plugin-AnsiEsc'
Plug 'sheerun/vim-polyglot'
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

let g:coc_global_extensions = [
  \ 'coc-tsserver',
  \ 'coc-json',
  \ 'coc-prettier',
  \ 'coc-eslint'
  \ ]



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

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

nmap <C-e> :BufExplorerVerticalSplit<CR>

nmap <C-p> :FZF<CR>
nmap <leader><space> <Plug>(coc-codeaction)
nmap <leader><leader><space> :<C-u>CocList commands<cr>
nmap <leader>o :<C-u>CocList outline<cr>
nmap <leader>f <Plug>(coc-fix-current)
nmap <leader>. :call CocActionAsync('doHover')<CR>
nmap <leader>r <Plug>(coc-rename)

nmap <C-c> gg:CocDiagnostics<CR>:lopen<CR>
nmap <C-n> :lnext<CR>

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> ,r <Plug>(coc-rename)



" Filetype Settings {{{1


autocmd Syntax sql setlocal foldmethod=marker
autocmd Syntax vim setlocal foldmethod=marker
autocmd Syntax typescript setlocal foldmethod=syntax foldlevel=99

autocmd FileType swift let b:coc_root_patterns = ['.xcodeproj', '.xcworkspace', ]

function! WritingWords()
	return system("cat ~/writing/*.md | sed 's/[^A-z ]//g\' | wc -w")[:-2] . " words"
endfunction
autocmd BufRead,BufNewFile,BufWritePost */ajm/writing/* setlocal statusline=%{WritingWords()}





