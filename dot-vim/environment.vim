if has('nvim')
  " Explicitly set python3 to 3.9
  let g:python3_host_prog = '/home/vvnraman/.pyenv/shims/python3.9'

  " Disable python2 support
  let g:loaded_python_provider = 0
endif

