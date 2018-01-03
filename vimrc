
"------------------------------------------------------------
" Vundle setup https://github.com/gmarik/vundle
"------------------------------------------------------------
set nocompatible              " be iMproved
filetype on                   " required!
filetype off                  " required!
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'


"------------------------------------------------------------
" Include Vundle bundles
"------------------------------------------------------------

" Utility sorta things
"
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-git'
Plugin 'tpope/vim-surround'


" UI Additions
"
" Show indent levels as background changes
Plugin 'nathanaelkane/vim-indent-guides'

" Better file/directory browsing
Plugin 'scrooloose/nerdtree'

" Easier commenting
Plugin 'scrooloose/nerdcommenter'

" IDE-ish syntax checking
" Plugin 'scrooloose/syntastic'

" Better status bar
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'

" Show live git diff markers
Plugin 'airblade/vim-gitgutter'

" Alignment
Plugin 'junegunn/vim-easy-align'

" Task list
" Plugin 'superjudge/tasklist-pathogen'

" Language support
"
Plugin 'Markdown'
Plugin 'chase/vim-ansible-yaml'
Plugin 'mustache/vim-mustache-handlebars'

:let vim_scala = $VIM_SCALA
if vim_scala == '1'
  Plugin 'derekwyatt/vim-scala'
endif
:let vim_puppet = $VIM_PUPPET
if vim_puppet == '1'
  Plugin 'rodjek/vim-puppet'
endif
:let vim_ruby = $VIM_RUBY
if vim_ruby == '1'
  Plugin 'vim-ruby/vim-ruby'
  Plugin 'tpope/vim-rake'
endif

" Tag support
" Plugin 'majutsushi/tagbar'

" A few other random tools
"
" The Silver Surfer integration for faster searching of code
Plugin 'rking/ag.vim'
" fasd integration and a required lib for it
Plugin 'tomtom/tlib_vim'
Plugin 'amiorin/vim-fasd'


"------------------------------------------------------------
" Customize the look of vim
"------------------------------------------------------------

" Default size
if has("gui_running")
  set lines=80
  set columns=140
endif


" https://github.com/tpope/vim-vividchalk
Plugin 'vividchalk.vim'

" https://github.com/nanotech/jellybeans.vim
Plugin 'nanotech/jellybeans.vim'


" Do syntax highlighting
syntax on

" automatically show matching (, { or [ after matching one is typed
set showmatch

" Spell check by default
" set spell

if has("gui_macvim")
  " set macvim specific stuff
  silent! set transparency=15
endif

"------------------------------------------------------------
" Other tweaks for how I like things
"------------------------------------------------------------

" Airline status bar config
" Light theme for good contrast
let g:airline_theme='light'
let g:airline#extensions#branch#enabled = 1


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

" Goodbye error bell
set vb t_vb=


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

map <C-n> :NERDTreeToggle<CR>
map <C-s> :set spell!<CR>
map <C-t> :TagbarToggle<CR>


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
  au BufNewFile,BufRead *.pig    set filetype=pig    syntax=pig 
  au BufNewFile,BufRead *.hive   set filetype=sql    syntax=sql 
  au BufNewFile,BufRead *.hsql   set filetype=sql    syntax=sql 
  au BufNewFile,BufRead *.config set filetype=yaml   syntax=yaml 
augroup END 
 
" Allow some local customizations of vim
if isdirectory(expand("$HOME/.vimlocal/"))
  for rcfile in split(globpath(expand("$HOME/.vimlocal"), "*.vim"), '\n') 
      execute('source '.rcfile)
  endfor
endif

" Required fix for vundle
call vundle#end()             " required!
filetype plugin indent on     " required!

" For some reason the usual ftplugins folder doesn't work for these settings for python
au FileType python set shiftwidth=2 softtabstop=2 tabstop=2 textwidth=100 textwidth=100 expandtab smarttab

" Color scheme
set background=dark

" These need to go after the vundle end so the plugins are really loaded
" Fallback if the vundle ones aren't there yet
colorscheme darkblue
" silent! colorscheme vividchalk
silent! colorscheme jellybeans
