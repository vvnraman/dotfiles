abbr --add gl git log -1
abbr --add glm git log -10 --pretty=oneline
abbr --add gs git status
abbr --add gd git diff --name-status
abbr --add gdm git diff main --name-status
abbr --add gd1 git diff HEAD^1 --name-status
abbr --add cs chezmoi status
abbr --add ca chezmoi add
abbr --add cra chezmoi re-add

if command --query lazygit
  alias lg="lazygit"
end
