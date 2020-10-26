"===============================================================================
" vim-plug plugin manager config.

" Specify a directory for plugins (for Neovim: ~/.local/share/nvim/plugged)
call plug#begin('~/.vim/plugged')

" Use single quotes for all arguments to Plug

" Alignment
Plug 'vim-scripts/Align'
Plug 'godlygeek/tabular'

" Movements
Plug 'Lokaltog/vim-easymotion'
Plug 'terryma/vim-multiple-cursors'
Plug 'justinmk/vim-sneak'

" Zig
Plug 'ziglang/zig.vim'

" Status
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'edkolev/tmuxline.vim'

" tpope plugins
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-markdown'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-ragtag'
Plug 'tpope/vim-repeat'

Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'garbas/vim-snipmate'
Plug 'honza/vim-snippets'
Plug 'SirVer/ultisnips'

" Uses the sign column to indicate added, modified and removed lines in a file
" under version control
" - async execution
Plug 'mhinz/vim-signify'

Plug 'scrooloose/nerdcommenter'
Plug 'kien/rainbow_parentheses.vim'
Plug 'flazz/vim-colorschemes'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'tmux-plugins/vim-tmux'
Plug 'mzlogin/vim-markdown-toc'

" fzf and others from the same author
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'junegunn/goyo.vim'

" Save named macros
Plug 'vvnraman/marvim'

" Python
Plug 'nvie/vim-flake8'

" golang
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" Typescript Javascript
Plug 'leafgarland/typescript-vim'
Plug 'pangloss/vim-javascript'
Plug 'yuezk/vim-js'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'prettier/vim-prettier'

" Linters
Plug 'dense-analysis/ale'

" YouCompleteMe.
Plug 'ycm-core/YouCompleteMe'

" Initialize plugin system
call plug#end()

" Brief help
" PlugInstall [name ...] [#threads]   Install plugins
" PlugUpdate [name ...] [#threads]    Install or update plugins
" PlugClean[!]                        Remove unused directories (bang version
"                                     will clean without prompt)
" PlugUpgrade                         Upgrade vim-plug itself
" PlugStatus                          Check the status of plugins
" PlugDiff                            Examine changes from the previous update
"                                     and the pending changes
" PlugSnapshot[!] [output path]       Generate script for restoring the current
"                                     snapshot of the plugins
"-------------------------------------------------------------------------------

"===============================================================================
" netrw - Built in file browser plugin
"===============================================================================
"Don't separate *.h from other files (as is done by default) in Explore
let g:netrw_sort_sequence = "[\/]$,*,\.bak$,\.o$,\.info$,\.swp$,\.obj$"

"-------------------------------------------------------------------------------

"===============================================================================
" octol/vim-cpp-enhanced-highlight options
"===============================================================================
let g:cpp_class_scope_highlight = 1
let g_cpp_experimental_template_highlight = 1
"-------------------------------------------------------------------------------

"===============================================================================
" YouCompleteMe options
"===============================================================================

nnoremap <F11> :YcmForceCompileAndDiagnostics <CR>

let g:ycm_filetype_blacklist = {
  \ 'md' : 1,
  \ 'rst' : 1,
  \ 'tagbar' : 1,
  \ 'qf' : 1,
  \ 'notes' : 1,
  \ 'markdown' : 1,
  \ 'unite' : 1,
  \ 'text' : 1,
  \ 'vimwiki' : 1,
  \ 'pandoc' : 1,
  \ 'infolog' : 1,
  \ 'mail' : 1
  \}

let g:ycm_python_binary_path = 'python3'
let g:ycm_python_interpreter_path = 'python3'
let g:ycm_key_list_select_completion = []

" Make the auto-complete window go away when we're done with it.
let g:ycm_autoclose_window_after_completion=1

"-------------------------------------------------------------------------------

"===============================================================================
" Syntastic options - Disabled 2017-03-14
"===============================================================================

"" " Jump to errors with ']'/'[' and lowercase 'L'
"" let g:syntastic_always_populate_loc_list = 1
"" 
"" " C++
"" let g:syntastic_cpp_check_header = 1
"" let g:syntastic_cpp_checkers=['g++']
"-------------------------------------------------------------------------------

"===============================================================================
" Rainbow Parentheses"
"===============================================================================
let g:rbpt_colorpairs = [
    \ ['brown',       'RoyalBlue3'],
    \ ['Darkblue',    'SeaGreen3'],
    \ ['darkgray',    'DarkOrchid3'],
    \ ['darkgreen',   'firebrick3'],
    \ ['darkcyan',    'RoyalBlue3'],
    \ ['darkred',     'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['brown',       'firebrick3'],
    \ ['gray',        'RoyalBlue3'],
    \ ['black',       'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['Darkblue',    'firebrick3'],
    \ ['darkgreen',   'RoyalBlue3'],
    \ ['darkcyan',    'SeaGreen3'],
    \ ['darkred',     'DarkOrchid3'],
    \ ['red',         'firebrick3'],
    \ ]

let g:rbpt_max = 16
let g:rbpt_loadcmd_toggle = 0
"-------------------------------------------------------------------------------

" Format the status line, this should be in settings.vim but I don't know how to
" conditionally enable it only when vim-arline hasn't loaded.
" Used in case we don't have powerline
"set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ [%l,%c]


"===============================================================================
" Tabularize
"===============================================================================
if exists(":Tabularize")
    nnoremap <Leader>a= :Tabularize /=<CR>
    vnoremap <Leader>a= :Tabularize /=<CR>
    nnoremap <Leader>a: :Tabularize /:\zs<CR>
    vnoremap <Leader>a: :Tabularize /:\zs<CR>
endif
"-------------------------------------------------------------------------------

"Font
if os == "windows"
  " set guifont=Consolas:h12:cANSI
  silent! set guifont=Inconsolata:h12:cANSI
else
  silent! set guifont=Monospace\ 10
endif


"Color schemes
silent colorscheme molokai

"===============================================================================
" Airline
"===============================================================================
let g:airline_theme='jellybeans'
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#formatter='unique_tail_improved'
let g:airline#extensions#tmuxline#enabled=0
let g:airline#extensions#default#section_truncate_width={
    \ 'a'       : 20,
    \ 'b'       : 30,
    \ 'c'       : 30,
    \ 'x'       : 60,
    \ 'y'       : 88,
    \ 'z'       : 25,
    \ 'warning' : 40,
    \ 'error'   : 40
    \ }

"===============================================================================
" Tmuxline
"===============================================================================
let g:tmuxline_theme='zenburn'
let g:tmuxline_preset={
    \'a'        : '#S',
    \'b'        : '#I',
    \'win'      : ['#I', '#W'],
    \'cwin'     : ['#I', '#W', '#F'],
    \'x'        : '#(uptime | cut -d " " -f 3,4,5)',
    \'y'        : ['%R', '%a', '%b', '%d'],
    \'z'        : ['#(whoami)', '#H'],
    \ }
