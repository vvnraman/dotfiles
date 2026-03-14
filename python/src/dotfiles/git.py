from dotfiles.run_command import run_output

# Not cross-platform
GIT = "/usr/bin/git"


def is_git_clean(git_path: str | None = None) -> bool:
    cmd: list[str] = [GIT]
    if git_path is not None:
        cmd += ["-C", git_path]

    cmd += ["status", "--porcelain"]

    return run_output(cmd) == ""


def git_branch(git_path: str | None = None) -> str:
    cmd: list[str] = [GIT]
    if git_path is not None:
        cmd += ["-C", git_path]

    cmd += ["branch", "--show-current"]

    return run_output(cmd)
