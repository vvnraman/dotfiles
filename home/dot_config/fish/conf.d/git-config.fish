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

function git-update-commit-date
  mg update-commit-date $argv
end

function git-init
  mg init $argv
end

function git-clone
  mg clone $argv
end

function git-show-ignored
  mg show-ignored $argv
end

function git-show-untracked
  mg show-untracked $argv
end

function git-switch
  mg switch $argv
end

function git-new-branch
  mg new-branch $argv
end

function git-branch-new-remote
  mg branch-new-remote $argv
end

function git-branch-existing-remote
  mg branch-existing-remote $argv
end
