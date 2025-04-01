import shutil
import subprocess
import sys
import traceback
from datetime import datetime
from pathlib import Path

import typer

PROJECT_NAME = "dotfiles"
GITHUB_URL = "vvnraman/dotfiles"
REMOTE_NAME = "github"

# Not cross-platform
GIT = "/usr/bin/git"

CURRENT_FILE = Path(__file__)
PROJECT_DIR = CURRENT_FILE.parent.parent.parent
DOCS_DIR = (PROJECT_DIR / "docs").relative_to(PROJECT_DIR)
BUILD_DIR = DOCS_DIR / "_build"
HTML_DIR = BUILD_DIR / "html"
HOME_DIR = Path("~").expanduser()
NVIM_CONFIG_DIR = Path("~/.config/nvim").expanduser()

A: str = "══"
B: str = "──"
C: str = "┄┄"
S: str = " "
E: str = " "


class Command:
    def __init__(self, name: str, args: list[str]):
        self.name: str = name
        self.args: list[str] = args

    def __str__(self) -> str:
        return self.name + " \t= " + " ".join(self.args)


def run_live(cmd: Command, dry_run: bool):
    print(f"{B} Running {cmd}")

    if dry_run:
        return

    with subprocess.Popen(
        cmd.args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1
    ) as proc:

        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
                print(line, end="")

        _ = proc.wait(timeout=5)

        rc = proc.returncode
        print(f"{C} {cmd.name} finish with rc={rc}")
        if 0 != rc:
            raise subprocess.CalledProcessError(rc, cmd.name)


app = typer.Typer()


@app.command()
def info():
    print(f"{A} Project         = {PROJECT_NAME}")
    print(f"{B} Project dir     = {PROJECT_DIR}")
    print(f"{B} Docs dir        = {DOCS_DIR}")
    print(f"{B} Build dir       = {BUILD_DIR}")
    print(f"{B} HTML dir        = {HTML_DIR}")


@app.command()
def docs():
    print(f"{A} Building docs for {PROJECT_NAME}")
    args = ["sphinx-build", "--builder", "html", str(DOCS_DIR), str(BUILD_DIR)]
    _ = subprocess.run(args)


@app.command()
def live():
    print(f"{A} Building livedocs for {PROJECT_NAME}")
    args = ["sphinx-autobuild", "--port", "0", str(DOCS_DIR), str(HTML_DIR)]
    _ = subprocess.run(args)


@app.command()
def clean():
    print(f"{A} Cleaning docs for {PROJECT_NAME}")
    args = ["sphinx-build", "-M", "clean", str(DOCS_DIR), str(BUILD_DIR)]
    _ = subprocess.run(args)


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

    git_clean_result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return git_clean_result.stdout.strip()


def get_upstream_url() -> str:
    upstream_url = subprocess.run(
        [GIT, "remote", "get-url", REMOTE_NAME],
        capture_output=True,
        text=True,
        check=False,
    )
    return upstream_url.stdout.strip()


def get_commit_messages() -> list[str]:
    timestamp_str = datetime.now().isoformat(timespec="seconds").replace("T", "-")

    commit_sha = subprocess.run(
        [GIT, "rev-parse", "--short", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    commit_sha_long = subprocess.run(
        [GIT, "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    return [
        "-m",
        f"Docs generated at {timestamp_str} for commit {commit_sha}",
        "-m",
        f"Visit https://github.com/{GITHUB_URL}/tree/{commit_sha_long} to\n"
        "browse files in this commit.",
    ]


@app.command()
def publish(dry_run: bool = True, override_branch: str | None = None):
    print(f"{A} Publishing docs for {PROJECT_NAME}")

    if not is_git_clean():
        print(f"{E} There are un-committed changes. Please commit all changes first.")
        return

    branch = git_branch()
    if "master" != branch:
        if override_branch is not None:
            if branch == override_branch:
                print(f"{B} Running in branch '{override_branch}'")
            else:
                print(
                    f"{E} Current branch '{branch}' is not the same as"
                    f" '{override_branch}'. Specify the correct branch."
                )
                return
        else:
            print(
                f"{E} We must be on 'master' to publish docs. "
                "Pass '--override-branch=<branch-name>' to publish that branch."
            )
            return

    print(f"{B} Generating docs from '{branch}' branch")
    if not dry_run:
        docs()

    commit_msg = get_commit_messages()
    upstream_url = get_upstream_url()

    publish_cmds: list[Command] = [
        Command(
            "git_clean",
            [
                "/usr/bin/rm",
                "--recursive",
                "--force",
                "--verbose",
                str(HTML_DIR / ".git"),
            ],
        ),
        Command("git_init", [GIT, "-C", str(HTML_DIR), "init"]),
        Command("nojekyll", ["/usr/bin/touch", str(HTML_DIR / ".nojekyll")]),
        Command("add", [GIT, "-C", str(HTML_DIR), "add", "."]),
        Command("commit", [GIT, "-C", str(HTML_DIR), "commit", *commit_msg]),
        Command(
            "remote_add",
            [
                GIT,
                "-C",
                str(HTML_DIR),
                "remote",
                "add",
                REMOTE_NAME,
                upstream_url,
            ],
        ),
        Command(
            "remote_push",
            [
                GIT,
                "-C",
                str(HTML_DIR),
                "push",
                "--force",
                REMOTE_NAME,
                "master:gh-pages",
            ],
        ),
    ]

    try:
        for cmd in publish_cmds:
            run_live(cmd, dry_run)
    except subprocess.CalledProcessError as e:
        traceback.print_exc()
    except KeyboardInterrupt:
        sys.exit(0)


@app.command()
def nvim(
    dry_run: bool = True,
    nvim_config_dir: str = str(NVIM_CONFIG_DIR),
    override_nvim_branch: str | None = None,
):
    print(f"{A} Syncing with neovim config")

    nvim_cfg_dir = NVIM_CONFIG_DIR
    if nvim_config_dir is not None:
        nvim_cfg_dir = Path(nvim_config_dir)

    if not is_git_clean(str(nvim_cfg_dir)):
        print(
            f"{E} There are un-committed changes in '{nvim_cfg_dir}'"
            "Please commit all changes first before copying them into dotfiles."
        )
        return

    branch = git_branch(str(nvim_cfg_dir))
    if "master" != branch:
        if override_nvim_branch is not None:
            if branch == override_nvim_branch:
                print(
                    f"{B} Copying nvim config from current branch '{override_nvim_branch}'"
                )
            else:
                print(
                    f"{E} The current nvim config branch is '{branch}'. To copy its"
                    f" config specify that instead of '{override_nvim_branch}' as "
                    " the override."
                )
                return
        else:
            print(
                f"{E} nvim config branch must be 'master' to copy config (by default)."
                f" Pass '--override-nvim-branch={branch}' to copy from the current branch."
            )
            return

    chezmoi_nvim_dir = PROJECT_DIR / "home/dot_config/nvim"

    print(
        f"{B} Will copy nvim config from '{branch}' branch at '{nvim_cfg_dir}' to"
        f" '{chezmoi_nvim_dir}'"
    )

    print(f"{B} Removing dotfiles copy from '{chezmoi_nvim_dir}'")
    nvim_cfg_dirs = ["lua/"]
    nvim_cfg_files = ["init.lua", "lazy-lock.json", "README.rst", "stylua.toml"]

    for cfg_dir in nvim_cfg_dirs:
        dst_dir_path = chezmoi_nvim_dir / cfg_dir
        print(f"{B} Removing '{dst_dir_path.relative_to(PROJECT_DIR)}'")
        if not dry_run:
            shutil.rmtree(dst_dir_path)

    for cfg_file in nvim_cfg_files:
        dst_file_path = chezmoi_nvim_dir / cfg_file
        print(f"{B} Removing '{dst_file_path.relative_to(PROJECT_DIR)}'")
        if not dry_run:
            dst_file_path.unlink(missing_ok=True)

    print(f"{B} Copying nvim config from '{nvim_cfg_dir}' to '{chezmoi_nvim_dir}'")
    for cfg_dir in nvim_cfg_dirs:
        src_dir_path = nvim_cfg_dir / cfg_dir
        dst_dir_path = chezmoi_nvim_dir / cfg_dir
        print(
            f"{B} Copying '~/{src_dir_path.relative_to(HOME_DIR)}' to"
            f" chezmoi '{dst_dir_path.relative_to(PROJECT_DIR)}'"
        )
        if not dry_run:
            _ = shutil.copytree(src_dir_path, dst_dir_path, dirs_exist_ok=True)

    for cfg_file in nvim_cfg_files:
        src_file_path = nvim_cfg_dir / cfg_file
        dst_file_path = chezmoi_nvim_dir / cfg_file
        print(
            f"{B} Copying '~/{src_file_path.relative_to(HOME_DIR)}' to"
            f" chezmoi '{dst_file_path.relative_to(PROJECT_DIR)}'"
        )
        if not dry_run:
            _ = shutil.copy2(src_file_path, dst_file_path)


@app.command()
def init_docs():
    print(f"{A} Setting up sphinx docs structure for {PROJECT_NAME}")
    sphinx_files = [
        DOCS_DIR / "conf.py",
        DOCS_DIR / "index.rst",
        DOCS_DIR / "Makefile",
    ]
    if all([file.exists() for file in sphinx_files]):
        print(f"{E} sphinx files already exists at '{str(DOCS_DIR)}'")
        return
    args = [
        "sphinx-quickstart",
        "--quiet",
        "--no-sep",
        "--project",
        "Prateek's dotfiles",
        "--author",
        "Prateek Raman",
        "--release",
        "1.0",
        str(DOCS_DIR),
    ]
    _ = subprocess.run(args)


if __name__ == "__main__":
    app()
