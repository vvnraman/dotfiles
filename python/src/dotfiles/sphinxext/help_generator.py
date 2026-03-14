import logging
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Protocol

from dotfiles.paths import SourceRootResolutionError, resolve_project_dir


class SphinxApp(Protocol):
    def connect(self, event: str, callback: Callable[[object], None]) -> int: ...


def _project_dir() -> Path | None:
    try:
        return resolve_project_dir()
    except SourceRootResolutionError as error:
        logging.warning(f"Skipping CLI help generation: {error}")
        return None


def _generated_dir(project_dir: Path) -> Path:
    return project_dir / "docs" / "generated"


@dataclass(frozen=True)
class HelpTarget:
    display_command: list[str]
    execute_command: list[str]


def _dotfiles_module_command(*args: str) -> list[str]:
    return [sys.executable, "-m", "dotfiles.main", *args]


def _help_targets(generated_dir: Path) -> dict[Path, HelpTarget]:
    return {
        generated_dir
        / "dotfiles-cli-help.txt": HelpTarget(
            display_command=["dotfiles", "--help"],
            execute_command=_dotfiles_module_command("--help"),
        ),
        generated_dir
        / "dotfiles-cli-nvim-help.txt": HelpTarget(
            display_command=["dotfiles", "nvim", "--help"],
            execute_command=_dotfiles_module_command("nvim", "--help"),
        ),
        generated_dir
        / "dotfiles-cli-publish-help.txt": HelpTarget(
            display_command=["dotfiles", "publish", "--help"],
            execute_command=_dotfiles_module_command("publish", "--help"),
        ),
    }


def _strip_stale_marker(content: str, stale_help_prefix: str) -> str:
    lines = content.rstrip("\n").splitlines()
    if lines and lines[-1].startswith(stale_help_prefix):
        _ = lines.pop()
    return "\n".join(lines)


def _mark_stale(content: str, stale_help_prefix: str) -> str:
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_content = _strip_stale_marker(content, stale_help_prefix).rstrip("\n")
    stale_line = f"{stale_help_prefix}{timestamp}"
    if base_content:
        return "\n".join([base_content, stale_line, ""])
    return "\n".join([stale_line, ""])


def _render_help(
    project_dir: Path,
    target: HelpTarget,
    stale_help_prefix: str,
    existing_content: str | None = None,
) -> str:
    proc = subprocess.run(
        target.execute_command,
        cwd=project_dir,
        capture_output=True,
        text=True,
        check=False,
    )

    if proc.returncode == 0:
        body = proc.stdout.rstrip()
        return "\n".join([f"$ {' '.join(target.display_command)}", body, ""])

    if existing_content:
        return _mark_stale(existing_content, stale_help_prefix)

    fallback = "\n".join(
        [
            f"$ {' '.join(target.display_command)}",
            "CLI help generation failed; snapshot unavailable.",
            "",
        ]
    )
    return _mark_stale(fallback, stale_help_prefix)


def _generate_cli_help(_: object) -> None:
    project_dir = _project_dir()
    if project_dir is None:
        return
    generated_dir = _generated_dir(project_dir)
    help_targets = _help_targets(generated_dir)
    stale_help_prefix = "Stale - generation failed on "

    generated_dir.mkdir(parents=True, exist_ok=True)
    for output_path, target in help_targets.items():
        existing_content = output_path.read_text() if output_path.exists() else None
        rendered = _render_help(
            project_dir,
            target,
            stale_help_prefix,
            existing_content,
        )
        if existing_content == rendered:
            continue
        _ = output_path.write_text(rendered)


def setup(app: SphinxApp) -> dict[str, object]:
    _ = app.connect("builder-inited", _generate_cli_help)
    return {
        "version": "1.0",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
