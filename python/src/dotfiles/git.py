import subprocess

# Not cross-platform
GIT = "/usr/bin/git"


def is_git_clean(git_path: str | None = None) -> bool:
    cmd: list[str] = [GIT]
    if git_path is not None:
        cmd += ["-C", git_path]

    cmd += ["status", "--porcelain"]

    git_clean_result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return 0 == len(git_clean_result.stdout.strip())


def git_branch(git_path: str | None = None) -> str:
    cmd: list[str] = [GIT]
    if git_path is not None:
        cmd += ["-C", git_path]

    cmd += ["branch", "--show-current"]

    git_branch_result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return git_branch_result.stdout.strip()
