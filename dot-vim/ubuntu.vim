scriptencoding utf-8
set encoding=utf-8
set nocompatible


"===============================================================================
"My .vimrc

syntax enable
filetype plugin indent on
let mapleader = "\<Space>"

function! GetOS()
    if has("win32")
        return "windows"
    endif
    if has("unix")
        if system('uname')=~'Darwin'
            return "mac"
        else
            return "linux"
        endif
    endif
endfunction

let os=GetOS()

"Map jj to Escape out of Insert Mode 
inoremap jk <Esc>

source ~/dot-vim/functions.vim
source ~/dot-vim/plugins.vim
source ~/dot-vim/settings.vim
source ~/dot-vim/mappings.vim
source ~/dot-vim/autocommands.vim
