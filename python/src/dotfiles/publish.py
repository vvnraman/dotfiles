import configparser
import logging
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from dotfiles.git import GIT, git_branch, is_git_clean
from dotfiles.paths import package_config_path
from dotfiles.run_command import Command, run_live, run_only, run_output
from dotfiles.util import L

# Publish config precedence is: CLI flag -> environment override ->
# dotfiles-config.ini [publish] value -> builtin default below.
# These constants are the last-resort fallback when config values are absent.
DEFAULT_DOTFILES_REPO = "vvnraman/dotfiles"
DEFAULT_REMOTE_NAME = "public"
DEFAULT_GITHUB_URL = "https://github.com"
DEFAULT_PUBLISH_HOST = "https://vvnraman.github.io"

DOTFILES_REPO_OVERRIDE_ENV = "DOTFILES_REPO_OVERRIDE"
REMOTE_NAME_OVERRIDE_ENV = "REMOTE_NAME_OVERRIDE"
GITHUB_URL_OVERRIDE_ENV = "GITHUB_URL_OVERRIDE"
PUBLISH_HOST_OVERRIDE_ENV = "PUBLISH_HOST_OVERRIDE"


@dataclass(frozen=True)
class PublishArgs:
    project_dir: Path
    dry_run: bool
    override_branch: str | None
    remote_name: str | None
    dotfiles_repo: str | None
    github_url: str | None
    publish_host: str | None


@dataclass(frozen=True)
class PublishConfig:
    dotfiles_repo: str
    remote_name: str
    github_url: str
    publish_host: str


def _builtin_publish_defaults() -> PublishConfig:
    return PublishConfig(
        dotfiles_repo=DEFAULT_DOTFILES_REPO,
        remote_name=DEFAULT_REMOTE_NAME,
        github_url=DEFAULT_GITHUB_URL,
        publish_host=DEFAULT_PUBLISH_HOST,
    )


def _docs_build_dir(project_dir: Path) -> Path:
    return project_dir / "docs" / "_build"


def _docs_html_dir(project_dir: Path) -> Path:
    return _docs_build_dir(project_dir) / "html"


def _publish_config_path() -> Path:
    return package_config_path()


def _load_publish_defaults(config_path: Path) -> PublishConfig:
    """Load publish defaults with layered fault tolerance.

    Fault-tolerance levels:
    1. If the config file is missing, return builtin defaults.
    2. If one or more config values are missing, use builtin defaults per value.
    """
    defaults = _builtin_publish_defaults()
    if not config_path.exists():
        logging.warning(
            f"{L.B} Publish config file not found at '{config_path}'; using builtin defaults"
        )
        return defaults

    config = configparser.ConfigParser()
    try:
        _ = config.read(config_path)
    except configparser.Error as error:
        logging.warning(
            f"{L.E} Failed to read publish config from '{config_path}': {error}. "
            "Using builtin defaults."
        )
        return defaults

    dotfiles_repo = config.get(
        "publish", "dotfiles_repo", fallback=defaults.dotfiles_repo
    )
    remote_name = config.get("publish", "remote_name", fallback=defaults.remote_name)
    github_url = config.get("publish", "github_url", fallback=defaults.github_url)
    publish_host = config.get("publish", "publish_host", fallback=defaults.publish_host)
    return PublishConfig(
        dotfiles_repo=dotfiles_repo,
        remote_name=remote_name,
        github_url=github_url,
        publish_host=publish_host,
    )


def load_publish_defaults_for_project(project_dir: Path) -> PublishConfig:
    _ = project_dir
    return _load_publish_defaults(_publish_config_path())


def _resolve_publish_value(
    cli_value: str | None,
    env_name: str,
    default_value: str,
) -> str:
    return cli_value or os.getenv(env_name) or default_value


def _resolve_publish_config(
    args: PublishArgs, defaults: PublishConfig
) -> PublishConfig:
    return PublishConfig(
        dotfiles_repo=_resolve_publish_value(
            args.dotfiles_repo,
            DOTFILES_REPO_OVERRIDE_ENV,
            defaults.dotfiles_repo,
        ),
        remote_name=_resolve_publish_value(
            args.remote_name,
            REMOTE_NAME_OVERRIDE_ENV,
            defaults.remote_name,
        ),
        github_url=_resolve_publish_value(
            args.github_url,
            GITHUB_URL_OVERRIDE_ENV,
            defaults.github_url,
        ),
        publish_host=_resolve_publish_value(
            args.publish_host,
            PUBLISH_HOST_OVERRIDE_ENV,
            defaults.publish_host,
        ),
    )


def _build_docs(project_dir: Path) -> None:
    docs_dir = project_dir / "docs"
    build_dir = _docs_build_dir(project_dir)
    args = ["sphinx-build", "--builder", "html", str(docs_dir), str(build_dir)]
    run_only(args)


def _get_publish_upstream_remote_url(remote_name: str) -> str:
    return run_output([GIT, "remote", "get-url", remote_name])


def _get_publish_commit_messages(dotfiles_repo: str, github_url: str) -> list[str]:
    timestamp_str = datetime.now().isoformat(timespec="seconds").replace("T", "-")

    commit_sha = run_output([GIT, "rev-parse", "--short", "HEAD"])

    commit_sha_long = run_output([GIT, "rev-parse", "HEAD"])

    return [
        "-m",
        f"Docs generated at {timestamp_str} for commit {commit_sha}",
        "-m",
        f"Visit {github_url}/{dotfiles_repo}/tree/{commit_sha_long} to\n"
        "browse files in this commit.",
    ]


def publish_docs(
    project_dir: Path,
    dry_run: bool,
    publish_config: PublishConfig,
) -> None:
    commit_msg = _get_publish_commit_messages(
        dotfiles_repo=publish_config.dotfiles_repo,
        github_url=publish_config.github_url,
    )
    upstream_url = _get_publish_upstream_remote_url(publish_config.remote_name)
    html_dir = _docs_html_dir(project_dir)

    publish_cmds: list[Command] = [
        Command(
            "git_clean",
            [
                "/usr/bin/rm",
                "--recursive",
                "--force",
                "--verbose",
                str(html_dir / ".git"),
            ],
        ),
        Command("git_init", [GIT, "-C", str(html_dir), "init"]),
        Command("nojekyll", ["/usr/bin/touch", str(html_dir / ".nojekyll")]),
        Command("add", [GIT, "-C", str(html_dir), "add", "."]),
        Command("commit", [GIT, "-C", str(html_dir), "commit", *commit_msg]),
        Command(
            "remote_add",
            [
                GIT,
                "-C",
                str(html_dir),
                "remote",
                "add",
                publish_config.remote_name,
                upstream_url,
            ],
        ),
        Command(
            "remote_push",
            [
                GIT,
                "-C",
                str(html_dir),
                "push",
                "--force",
                publish_config.remote_name,
                "master:gh-pages",
            ],
        ),
    ]

    for cmd in publish_cmds:
        run_live(cmd, dry_run)


def publish_with_config(args: PublishArgs) -> None:
    config_path = _publish_config_path()
    defaults = _load_publish_defaults(config_path)
    publish_config = _resolve_publish_config(args, defaults)

    if not is_git_clean():
        logging.warning(
            f"{L.E} There are un-committed changes. Please commit all changes first."
        )
        return

    branch = git_branch()
    if "master" != branch:
        if args.override_branch is not None:
            if branch == args.override_branch:
                logging.info(f"{L.B} Running in branch '{args.override_branch}'")
            else:
                logging.warning(
                    f"{L.E} Current branch '{branch}' is not the same as"
                    f" '{args.override_branch}'. Specify the correct branch."
                )
                return
        else:
            logging.warning(
                f"{L.E} We must be on 'master' to publish docs. "
                "Pass '--override-branch=<branch-name>' to publish that branch."
            )
            return

    logging.info(f"{L.B} Generating docs from '{branch}' branch")
    if not args.dry_run:
        _build_docs(args.project_dir)

    publish_docs(
        project_dir=args.project_dir,
        dry_run=args.dry_run,
        publish_config=publish_config,
    )
