"===============================================================================
" common group for all auto commands
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

"===============================================================================
"Python
" Set python pep8 style
augroup edit_python
  autocmd!
  autocmd BufNewFile,BufRead,BufEnter *.py
      \ set tabstop=4                 |
      \ set softtabstop=4             |
      \ set shiftwidth=4              |
      \ set textwidth=79              |
      \ set colorcolumn=+1            |
      \ let python_highlight_all=1    |
augroup END


"===============================================================================

