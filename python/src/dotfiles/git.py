from pathlib import Path

from dotfiles.run_command import run_output

# Not cross-platform
GIT = "/usr/bin/git"


def _git_base_command(repo_dir: str | Path | None = None) -> list[str]:
    command: list[str] = [GIT]
    if repo_dir is not None:
        command += ["-C", str(repo_dir)]
    return command


def is_git_clean(repo_dir: str | Path | None = None) -> bool:
    command = [*_git_base_command(repo_dir), "status", "--porcelain"]

    return run_output(command) == ""


def git_branch(repo_dir: str | Path | None = None) -> str:
    command = [*_git_base_command(repo_dir), "branch", "--show-current"]

    return run_output(command)
