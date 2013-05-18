" Vim Notes:
" ----------
"
" -You can use * in command mode to search for the word under the
"  cursor.  This will search using the word delimiters \< and \>
"  so if you do it over a loop counter variable i, it won't find
"  i in the middle of a word.
"
" -To replace all tabs in a file with spaces, make sure expandtab is
"  set and type :retab in command mode
"
" -To disable vim's auto indenting when pasting text into vim,
"  type :set paste to enter paste mode, then :set nopaste when finished
"
" -To indent a region, highlight it and then press >  To unindent,
"  press <

"------------------------------------------------------------
" Includes
"------------------------------------------------------------
"
source $VIMRUNTIME/vimrc_example.vim 
source $VIMRUNTIME/filetype.vim 
source $VIMRUNTIME/indent.vim 
source $VIMRUNTIME/ftplugin.vim 

"------------------------------------------------------------
" Customize the look of vim
"------------------------------------------------------------

" background color of the window vim's running in
"set background=light
set background=dark
" Use a different color scheme (brighter to work better on transparent backgrounds)
" colorscheme elflord
" colorscheme pablo
colorscheme darkblue
"colorscheme default

" automatically show matching (, { or [ after matching one is typed
set showmatch

" number of spaces to automatically indent
set sw=4
set shiftwidth=4
set softtabstop=4
set tabstop=4

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

" Turn on spell checking if available (Vim 7)
" if has("spell")
"   set spell
" endif

" From https://github.com/seekshreyas/dotfiles/blob/master/.vimrc
" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
  set undodir=~/.vim/undo
endif

"------------------------------------------------------------
" Customizations for compiling 
"------------------------------------------------------------

" Automatically write the current file before a :make
set autowrite

" Automatically cd to the directory of the current file whenever
" a buffer is entered.  see :help filename-modifiers
" This is necessary for assault to work since it searches up from the
" current directory to find the appropriate build.xml file
autocmd BufEnter * cd %:p:h

" Default compile command for java is to use javac on the current file
"autocmd BufNewFile,BufRead *.java set makeprg=javac\ -J\-Xms$JAVA_MIN\ -J\-Xmx$JAVA_MAX\ %

" Use JDK 1.3 for buzzword
"autocmd BufNewFile,BufRead */buzzword/*.java set makeprg=/usr/java/jdk1.3.1_08/bin/javac\ -J\-Xms$JAVA_MIN\ -J\-Xmx$JAVA_MAX\ %
"autocmd BufNewFile,BufRead */buzzword/*.java set makeprg=javac\ -J\-Xms$JAVA_MIN\ -J\-Xmx$JAVA_MAX\ %


" Compile command to use ant when editing a java file under a src dir
" in metamorph.  Can't just do */metamorph/*.java because dynamic
" java files in the config dir don't seem to compile with assault

" Old Solipsys make commands
" autocmd BufNewFile,BufRead */{metamorph,tdf-*}/*/src/*.java set makeprg=ant\ -q\ -emacs\ compile\ 2>&1
" autocmd BufNewFile,BufRead */{metamorph,tdf-*}/*/testsrc/*.java set makeprg=ant\ -q\ -emacs\ test\ 2>&1
" autocmd BufNewFile,BufRead */{metamorph,tdf-*}/*/docsrc/*.xml set makeprg=ant\ createManuals\ 2>&1
" autocmd BufNewFile,BufRead */{metamorph,tdf-*}/example/*.java set makeprg=javac\ -J\-Xms$JAVA_MIN\ -J\-Xmx$JAVA_MAX\ %

" Ozone related build commands
"autocmd BufNewFile,BufRead */*Service/*/src/main/java/ozone/*/*.java set makeprg=mvnjpm.bat\ java:compile
"autocmd BufNewFile,BufRead */*Service/*/src/main/java/ozone/*/*.java nmap <F9> :! mvnjpm.bat compile
"autocmd BufNewFile,BufRead */*Service/*/src/test/java/ozone/*/*.java nmap <F9> :! mvnjpm.bat surefire-report:report

"autocmd BufNewFile,BufRead */TTBD-Source/*.java set makeprg=ant\ -q\ -emacs\ build\ 2>&1

" autocmd BufNewFile,BufRead */metamorph/*.java set makeprg=ant\ -DTO_COMPILE=`cygpath\ -a\ %\ \\\|\ gawk\ '{\ print\ substr\(\ $1,\ index\(\ $1,\ \"com\"\ \)\ \)\ }'`\ -q\ -emacs\ compilethis\ 2>&1\ \\\|\ sed\ 's/.:.*\\\\\\(.*\\.java\\)\\(.*\\)/\\1\\2/'

"autocmd BufNewFile,BufRead *.C set makeprg=gcc\ %


" Used to toggle on/off autoindent when pasting into vim
" nmap <F2> :set paste
" nmap <F3> :set nopaste

" Used to run the main method of the file being edited
"nmap <F6> :!jrun %

" F7 comments out the selected region in visual mode
" F8 comments it back in
au FileType java,c let b:comment_leader = '// '
au FileType sh,make,perl let b:comment_leader = '# '
au FileType vim let b:comment_leader = '" '
vmap <F7> :<C-B>sil <C-E>s/^/<C-R>=escape(b:comment_leader,'\/')<CR>/<CR>:nohlsearch<CR>
vmap <F8> :<C-B>sil <C-E>s/^\V<C-R>=escape(b:comment_leader,'\/')<CR>//e<CR>:nohlsearch<CR>

" Mappings to make edit-compile-fix cycle go faster
nmap <F8> :clist
nmap <F9> :make
nmap <F11> :cprev
nmap <F12> :cnext


" Replaced by 
" F7 comments out the selected region in visual mode
" F8 comments it back in
"vmap <F7> :s/^/\/\//|:nohlsearch
"vmap <F8> :s/^\/\//|:nohlsearch

"------------------------------------------------------------
" Abbreviations
" imap maps the <code>first param to the rest while in insert mode
" All the ^M characters are entered by typing "Ctrl-v Enter"
" while in insert mode. ^] is the escape key, entered by "Ctrl-v ESC"
" The abbrevs have no indentation since it's assumed cindent is turned on
"------------------------------------------------------------

" Wrap the word under the cursor in a <XXX></XXX> block
" The cursor must be on the first letter of the word to wrap.
nmap !code i<code>ea</code>
nmap !iname i<interfacename>ea</interfacename>
nmap !cname i<classname>ea</classname>
nmap !meth i<methodname>ea</methodname>
nmap !emp i<emphasis>ea</emphasis>
nmap !con i<constant>ea</constant>
nmap !file i<filename>ea</filename>

imap !dp System.out.println( "" );gei

imap !time long time = System.currentTimeMillis();time = System.currentTimeMillis() - time;System.out.println( "time = " + time + "ms" );

imap !code <code></code>2ba
imap !iname <interfacename></interfacename>2ba
imap !cname <classname></classname>2ba
imap !meth <methodname></methodname>2ba
imap !emp <emphasis></emphasis>2ba
imap !con <constant></constant>2ba
imap !file <filename></filename>2ba

imap !li {@link }i

imap !implug import com.solipsys.dynamicloader.Plugin;
imap !imsol import com.solipsys.
imap !imswg import javax.swing.

imap !il SwingUtilities.invokeLater( new Runnable() {public void run(){}} );kO

imap !aa addActionListener( new ActionListener() {public void actionPerformed( ActionEvent e ){}} );kO

imap !ap addPropertyChangeListener( new PropertyChangeListener() {public void propertyChange( PropertyChangeEvent evt ){}} );kO

imap !ac addChangeListener( new ChangeListener() {public void stateChanged( ChangeEvent e ){}} );kO

imap !ai addItemListener( new ItemListener() {public void itemStateChanged( ItemEvent e ){if ( e.getStateChange() == ItemEvent.SELECTED ){}}} );2kO

imap !ad getDocument().addDocumentListener( new DocumentListener() {public void insertUpdate( DocumentEvent e ){}public void removeUpdate( DocumentEvent e ){}public void changedUpdate( DocumentEvent e ){}} );kO

imap !main public static void main( String[] args ){JPanel panel = new ;JFrame frame = new JFrame( "Test Program" );frame.getContentPane().add( panel , BorderLayout.CENTER );frame.setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE );frame.pack();frame.show();}%j$i

imap !log private final static org.apache.log4j.Logger log =org.apache.log4j.Logger.getLogger( .class );3bi

imap !res private final static com.solipsys.util.resource.Resources res =com.solipsys.util.resource.ResourceManager.getDefault().getResources( .class );3bi

imap !scroll JScrollPane scroller = new JScrollPane(  );scroller.getHorizontalScrollBar().setUnitIncrement( 10 );scroller.getVerticalScrollBar().setUnitIncrement( 10 );kkhhi



augroup filetypedetect 
  au BufNewFile,BufRead *.pig set filetype=pig syntax=pig 
  au BufNewFile,BufRead *.hive set filetype=sql syntax=sql 
augroup END 
 

