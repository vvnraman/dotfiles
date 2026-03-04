if test -f "$HOME/.config/fish/linux-config.fish"
  source "$HOME/.config/fish/linux-config.fish"
end

set --universal --export SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket

fish_add_path --path --prepend "$HOME/.local/bin/vvnraman/arch/"
