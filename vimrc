
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

" Alignment
Bundle 'junegunn/vim-easy-align'

" Language support
"
Bundle 'vim-ruby/vim-ruby'
Bundle 'tpope/vim-rake'
Bundle 'Markdown'

" A few other random tools
"
" The Silver Surfer integration for faster searching of code
Bundle 'rking/ag.vim'
" fasd integration and a required lib for it
Bundle 'tomtom/tlib_vim'
Bundle 'amiorin/vim-fasd'


"------------------------------------------------------------
" Customize the look of vim
"------------------------------------------------------------

" Default size
if has("gui_running")
  set lines=80
  set columns=140
endif

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

" Spell check by default
" set spell


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


" Set the <leader> key to be , instead of \
let mapleader = ","



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
" Ctrl-S to toggle spell check
map <C-s> :set spell!<CR>


" Fancy tab auto-complete
function! Smart_TabComplete()
  let line = getline('.')                         " current line

  let substr = strpart(line, -1, col('.')+1)      " from the start of the current
                                                  " line to one character right
                                                  " of the cursor
  let substr = matchstr(substr, "[^ \t]*$")       " word till cursor
  if (strlen(substr)==0)                          " nothing to match on empty string
    return "\<tab>"
  endif
  let has_period = match(substr, '\.') != -1      " position of period, if any
  let has_slash = match(substr, '\/') != -1       " position of slash, if any
  if (!has_period && !has_slash)
    return "\<C-X>\<C-P>"                         " existing text matching
  elseif ( has_slash )
    return "\<C-X>\<C-F>"                         " file matching
  else
    return "\<C-X>\<C-O>"                         " plugin matching
  endif
endfunction

inoremap <tab> <c-r>=Smart_TabComplete()<CR>


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

