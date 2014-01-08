
"------------------------------------------------------------
" Vundle setup https://github.com/gmarik/vundle
"------------------------------------------------------------
set nocompatible              " be iMproved
filetype on                   " required!
filetype off                  " required!
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'gmarik/vundle'


"------------------------------------------------------------
" Include Vundle bundles
"------------------------------------------------------------

" Utility sorta things
"
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-git'


" UI Additions
"
" Show indent levels as background changes
Bundle 'nathanaelkane/vim-indent-guides'
" Better file/directory browsing
Bundle 'scrooloose/nerdtree'
" Easier commenting
Bundle 'scrooloose/nerdcommenter'
" IDE-ish syntax checking
Bundle 'scrooloose/syntastic'
" Better status bar
Bundle 'bling/vim-airline'
" Show live git diff markers
Bundle 'airblade/vim-gitgutter'


" Language support
"
Bundle 'vim-ruby/vim-ruby'
Bundle 'Markdown'

"------------------------------------------------------------
" Customize the look of vim
"------------------------------------------------------------

" Default size
set lines=80
set columns=140

" Color scheme
set background=dark

" Fallback if the vundle ones aren't there yet
colorscheme darkblue

" https://github.com/tpope/vim-vividchalk
Bundle 'vividchalk.vim'
" silent! colorscheme vividchalk

" https://github.com/nanotech/jellybeans.vim
Bundle "nanotech/jellybeans.vim"
silent! colorscheme jellybeans


" Do syntax highlighting
syntax on

" automatically show matching (, { or [ after matching one is typed
set showmatch


"------------------------------------------------------------
" Other tweaks for how I like things
"------------------------------------------------------------


" number of spaces to automatically indent
set sw=2
set shiftwidth=2
set softtabstop=2
set tabstop=2

" disable automatic text wrapping
" set nowrap " but still wrap long lines for display
set textwidth=0
set wrapmargin=0

" Use spaces instead of tabs
set expandtab

" ignore case while searching.
set ignorecase

" Force file format to always be unix.  If it's allowed to auto-detect
" it will hide all the ^M's because it will think it's a dos file
set fileformats=unix,dos
"set fileformats=unix

" When more than one filename matches during completion, list all 
" matches and complete up until the longest common string (like the shell).
set wildmode=list:longest

" Don't autoindent pasted text
set paste

" From https://github.com/seekshreyas/dotfiles/blob/master/.vimrc
" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
  set undodir=~/.vim/undo
endif



"------------------------------------------------------------
" A few plugin specific configs
silent! let g:indent_guides_enable_on_vim_startup = 1   " Enable vim-indent-guides by default
set laststatus=2  " Enable vim-airline by default


" Sql formatting mods for SQLUtilities
" Disable aligning the = in where clauses
let g:sqlutil_align_where = 0
vmap <silent>!sf        <Plug>SQLUFormatter<CR> 
nmap <silent>!scl       <Plug>SQLUCreateColumnList<CR> 
nmap <silent>!scd       <Plug>SQLUGetColumnDef<CR> 
nmap <silent>!scdt      <Plug>SQLUGetColumnDataType<CR> 
nmap <silent>!scp       <Plug>SQLUCreateProcedure<CR> 

" Ctrl-N to toggle NERDTree
map <C-n> :NERDTreeToggle<CR>

autocmd BufEnter * cd %:p:h


" Special file type mappings
augroup filetypedetect 
  au BufNewFile,BufRead *.pig    set filetype=pig  syntax=pig 
  au BufNewFile,BufRead *.hive   set filetype=sql  syntax=sql 
  au BufNewFile,BufRead *.hsql   set filetype=sql  syntax=sql 
  au BufNewFile,BufRead *.config set filetype=yaml syntax=yaml 
augroup END 
 

" Required fix for vundle
filetype plugin indent on     " required!

