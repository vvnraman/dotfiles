" Setup autocommands.
" autocommands are grouped into various categories in this fashion so that they
" do not reloaded on sourcing vimrc again. More accurately when vimrc is sourced
" again, each group gets cleared and set again. Otherwise each autocommand is
" appended again and again on each file source.

"===============================================================================
" common group for all auto commands
"_______________________________________________________________________________
augroup common
  autocmd!

  " Return to last edit position when opening files (You want this!)
  autocmd BufReadPost *
      \ if line("'\"") > 0 && line("'\"") <= line("$") |
      \   exe "normal! g`\"" |
      \ endif

  "Set current working directory to change on window enter.
  autocmd BufEnter * silent! lcd %:p:h
  augroup END
"-------------------------------------------------------------------------------

"===============================================================================
" Python
"_______________________________________________________________________________
" Set python pep8 style
augroup edit_python
  autocmd!
  autocmd BufNewFile,BufRead,BufEnter *.py
      \ set tabstop=4                 |
      \ set softtabstop=4             |
      \ set shiftwidth=4              |
      \ set colorcolumn=+1            |
      \ let python_highlight_all=1    |
augroup END
"-------------------------------------------------------------------------------


"===============================================================================
" Triger `autoread` when files changes on disk
" https://unix.stackexchange.com/questions/149209/refresh-changed-content-of-file-opened-in-vim/383044#383044
"_______________________________________________________________________________
" https://vi.stackexchange.com/questions/13692/prevent-focusgained-autocmd-running-in-command-line-editing-mode
augroup reload_changed_files
  autocmd!
  autocmd FocusGained,BufEnter,CursorHold,CursorHoldI *
      \ if mode() !~ '\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif

  " Notification after file change
  " https://vi.stackexchange.com/questions/13091/autocmd-event-for-autoread
  autocmd FileChangedShellPost *
    \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None
augroup END
"-------------------------------------------------------------------------------

"===============================================================================
" Template: new augroup
"_______________________________________________________________________________
" TBD
"-------------------------------------------------------------------------------

