set --global fish_greeting
set --global fish_key_bindings fish_vi_key_bindings

function source_script
  if test -f "$argv[1]"
    source "$argv[1]"
  end
end

# custom binaries in `bin`
# Add other entries to path above.
fish_add_path --path --prepend "$HOME/.local/bin"
fish_add_path --path --prepend "$HOME/bin"

source_script ~/.config/fish/os-config.fish
source_script ~/.config/fish/user-config.fish

# This is intentionally unconditional.
set --universal --export STARSHIP_CONFIG ~/.config/starship/starship.toml
if status is-interactive
    # Commands to run in interactive sessions can go here

    # starship
    if command --query starship
      starship init fish | source
    end
end
