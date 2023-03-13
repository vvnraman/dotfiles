#!/usr/bin/env bash

# Even though we have a dotfiles repo, the Neovim config is also available as
# a separate repo. When we make changes to the Neovim config, we update the
# `chezmoi` source state with it via this script.

# We could easily do this manually. But eventually there will come a time where
# I forgot to do the right thing. Hence the indirection.
chezmoi add ~/.config/nvim/lua/

# FIXME: Use git comamnds in `~/.config/nvim/lua` repo to find out added,
#        updated and deleted files and do it that way.
#        Doing what we're doing above won't delete the files here which
#        we've deleted in our Neovim config.
