" Enable modeline for individual file specific settings"
set modeline

" Force 256 color
set term=screen-256color
set t_Co=256
set t_ut=

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Enable mouse
set mouse=a

" Set 3 lines to the cursor - when moving vertically using j/k
set so=4

" Turn on the WiLd menu
set wildmenu
set wildmode=list:longest,full

" Ignore compiled files
set wildignore=*.o,*~,*.gch,*.pyc,*.jpg,*.gif,*.png

"Always show current position
set ruler

" Height of the command bar
set cmdheight=2

" A buffer becomes hidden when it is abandoned
set hidden

" Configure backspace so it acts as it should act
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" No idea what this does
set nostartofline

" List the tab spaces and trailing charaters as below
set list
"set listchars=tab:»·,eol:¬,trail:·,extends:↪,precedes:↩
set listchars=tab:»·,trail:·,extends:↪,precedes:↩

" Always show tabs (avoids frequent window resizing)
set showtabline=2

" Open new horizontal split below the current window
set splitbelow

" Open vertical split to the right of the current window
set splitright

" Set minimum windows height to 3, doesn't work
"set winheight=3
"set winminheight=3

" When searching try to be smart about cases 
set smartcase

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch
" How many tenths of a second to blink when matching brackets
set mat=2


"" messages and info
set shortmess=aoOstTI
set showcmd
set showmode
set cursorline
set report=0
set noerrorbells
set novisualbell t_vb=".

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Files, backups and undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn backup off, since most stuff is in SVN, git et.c anyway...
set nobackup
set nowb
set noswapfile


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use spaces instead of tabs
set expandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 4 spaces
highlight ColorColumn ctermbg=235 guibg=#2c2d27
set tabstop=2
set shiftwidth=2
set softtabstop=2
set textwidth=80
set colorcolumn=+1,100
set autoindent
set smartindent

" Commenting this out as it is not compatible with vi"
" folding
set nofoldenable
"set foldmarker={,}
"set foldmethod=syntax
"set foldlevel=0
"set foldopen+=jump

"Show the line numbers
set number

" Linebreak on 80 characters
set lbr
set tw=80

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines

" Disable scrollbars and tab button bar.
setglobal guioptions-=L
setglobal guioptions-=l
setglobal guioptions-=R
setglobal guioptions-=r
setglobal guioptions-=b
setglobal guioptions-=h

" Always show the status line
set laststatus=2
set enc=utf-8
set fillchars+=stl:=,stlnc:\ 

" Remember info about open buffers on close
set viminfo^=%

" Don't redraw while executing macros (good performance config)
set lazyredraw

""100 command line editing history
set history=100

" default updatetime 4000ms is not good for async update
" This is specially needed for vim-signify
set updatetime=100

