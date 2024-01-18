""""""""""""""""""""""""""""""
" => Visual mode related
""""""""""""""""""""""""""""""
" Visual mode pressing * or # searches for the current selection
" Super useful! From an idea by Michael Naumann
vnoremap <silent> * :call VisualSelection('f')<CR>
vnoremap <silent> # :call VisualSelection('b')<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Treat long lines as break lines (useful when moving around in them)
nnoremap j gj
nnoremap k gk
nnoremap <Up> :-10<Cr>
nnoremap <Down> :+10<Cr>

" Disable highlight when <leader><cr> is pressed
nnoremap <silent> <leader><cr> :noh<cr>

" Smart way to move between windows
nnoremap <C-j> <C-W>j
nnoremap <C-k> <C-W>k
nnoremap <C-h> <C-W>h
nnoremap <C-l> <C-W>l

" Close the current buffer
nnoremap <leader>bd :Bclose<cr>

" Close all the buffers
nnoremap <leader>ba :1,1000 bd!<cr>

" Useful mappings for managing tabs
nnoremap <leader>tn :tabnew<cr>
nnoremap <leader>to :tabonly<cr>
nnoremap <leader>tc :tabclose<cr>
nnoremap <leader>tm :tabmove

" Move tab left or right"
nnoremap <silent> <A-Left> :execute 'silent! tabmove ' . (tabpagenr()-2)<Cr>
nnoremap <silent> <A-Right> :execute 'silent! tabmove ' . tabpagenr()<Cr>

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
nnoremap <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
nnoremap <leader>cd :cd %:p:h<cr>:pwd<cr>

"Map <Cr> in normal mode to insert a line
nnoremap <Cr> o<Esc>

" Ctrl + ] - open definition
" Ctrl + W, Ctrl + ] - open definition in horizontal split
" Ctrl + t - jump back
" Ctrl + o - up one level
" Ctrl + i - down one level
nnoremap <C-\> :vsp <CR>:exec("tag ".expand("<cword>"))<CR>
nnoremap <A-\> :sp <CR>:exec("tag ".expand("<cword>"))<CR>
nnoremap <A-]> :tabe <CR>:exec("tag ".expand("<cword>"))<CR>
nnoremap <A-LeftMouse> :vsp <CR>:exec("tag ".expand("<cword>"))<CR>
nnoremap <A-RightMouse> :sp <CR>:exec("tag ".expand("<cword>"))<CR>

" Press Alt+u to convert current word to uppercase
inoremap <A-u> <Esc>viwUi
" Press Alt+l to convert current word to lowercase
inoremap <A-l> <Esc>viwui
nnoremap <A-u> viwU
nnoremap <A-l> viwu

" Quickly open VIMRC in a vertical split
nnoremap <leader>ev :tabe $HOME/.local/share/chezmoi/dot-vim/plugins.vim<Cr>
" Quickly source VIMRC to apply settings
nnoremap <leader>sv :source $MYVIMRC<Cr>

" Search and replace the previous word with the word last searched for
inoremap <A-r> <Esc>mzyiw:%s//\=@0/g<Cr>`za
nnoremap <A-r> mzyiw:%s//\=@0/g<Cr>`z

" F2, F3 and F4 are used by marvim
" Map F5 to toggle search results highlights
" https://stackoverflow.com/questions/9054780/how-to-toggle-vims-search-highlight-visibility-without-disabling-it
let hlstate=0
nnoremap <F5> :if (hlstate == 0) \| nohlsearch \| else \| set hlsearch \| endif \| let hlstate=1-hlstate<Cr>

nnoremap <F6> :filetype detect<Cr>
inoremap <F6> <Esc>mz:filetype detect<Cr>`z

" Quick write session
map <F9> :mksession! ~/.vim/sessions/last.session <cr>
" And load session
map <F10> :source ~/.vim/sessions/last.session <cr>
