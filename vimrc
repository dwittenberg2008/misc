set nocompatible	" Use Vim defaults (much better!)
" set bs=2		" allow backspacing over everything in insert mode
" inoremap  
" set t_kb=
" set t_kD=
" set ai		" always set autoindenting on
set number            " turn on line numbers
" set list
" set backup		" keep a backup file
set viminfo='20,\"50	" read/write a .viminfo file, don't store more
			" than 50 lines of register

" set statusline=%<%f\ %h%m%r%=%-14.(%l,%c%V%)\ %P
"hi StatusLine term=reverse ctermfg=0 ctermbg=0 gui=bold,reverse guifg=SlateBlue guibg=Purple

" Make sure when we use tab it's actually 4 spaces instead
" set smartindent
set softtabstop=4
set tabstop=4
set shiftwidth=4
set expandtab

set showmode
set showcmd
set hidden
set wildmenu
set laststatus=2        " always show the status line
set incsearch           " do incremental searching
set hlsearch            " highlight searches
set ignorecase          " ignore case while searching
set smartcase
set scrolloff=3         " keep 3 lines when scrolling
set wildmode=longest,list
colorscheme desert

"## Syntastic
"set statusline+=%#warningmsg#
"set statusline+=%{SyntasticStatuslineFlag()}
"set statusline+=%*

let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_loc_list_height = 5

" HCL
let g:hcl_fmt_autosave = 1
let g:tf_fmt_autosave = 1
let g:nomad_fmt_autosave = 1

" In text files, always limit the width of text to 78 characters
"autocmd BufRead *.txt set tw=78	
set nowrap

" Uncomment the following to have Vim jump to the last position when                                                       
" reopening a file
if has("autocmd")
   au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
   \| exe "normal! g'\"" | endif
endif

" Don't use Ex mode, use Q for formatting
map Q gq

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  " set hlsearch
endif

augroup cprog
  " Remove all cprog autocommands
  au!

  " When starting to edit a file:
  "   For *.c and *.h files set formatting of comments and set C-indenting on.
  "   For other files switch it off.
  "   Don't change the order, it's important that the line with * comes first.
  autocmd BufRead *       set formatoptions=tcql nocindent comments&
  autocmd BufRead *.c,*.h set formatoptions=croql cindent comments=sr:/*,mb:*,el:*/,://
augroup END

augroup gzip
  " Remove all gzip autocommands
  au!

  " Enable editing of gzipped files
  "	  read:	set binary mode before reading the file
  "		uncompress text in buffer after reading
  "	 write:	compress file after writing
  "	append:	uncompress file, append, compress file
  autocmd BufReadPre,FileReadPre	*.gz set bin
  autocmd BufReadPost,FileReadPost	*.gz let ch_save = &ch|set ch=2
  autocmd BufReadPost,FileReadPost	*.gz '[,']!gunzip
  autocmd BufReadPost,FileReadPost	*.gz set nobin
  autocmd BufReadPost,FileReadPost	*.gz let &ch = ch_save|unlet ch_save
  autocmd BufReadPost,FileReadPost	*.gz execute ":doautocmd BufReadPost " . expand("%:r")

  autocmd BufWritePost,FileWritePost	*.gz !mv <afile> <afile>:r
  autocmd BufWritePost,FileWritePost	*.gz !gzip <afile>:r

  autocmd FileAppendPre			*.gz !gunzip <afile>
  autocmd FileAppendPre			*.gz !mv <afile>:r <afile>
  autocmd FileAppendPost		*.gz !mv <afile> <afile>:r
  autocmd FileAppendPost		*.gz !gzip <afile>:r
augroup END

" Pathogen
execute pathogen#infect()
syntax on
filetype plugin indent on

