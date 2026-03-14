import logging
import shlex
import shutil
import subprocess
from collections.abc import Callable
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
        logging.warning(f"Skipping directory layout generation: {error}")
        return None


def _generated_dir(project_dir: Path) -> Path:
    return project_dir / "docs" / "generated"


def _layout_targets() -> dict[str, str]:
    return {
        "bash": "home/dot-bash",
        "fish": "home/dot_config/fish",
        "tmux": "home/dot-tmux",
        "git": "home/dot_config/git",
        "lazygit": "home/dot_config/lazygit",
    }


def _resolve_layout_tool() -> str:
    if shutil.which("lsd"):
        return "lsd"

    if shutil.which("tree"):
        return "tree"

    return "ls"


def _layout_command(layout_tool: str, target_dir: Path) -> tuple[list[str], str]:
    if layout_tool == "lsd":
        cmd = ["lsd", "--almost-all", "--tree", str(target_dir)]
        return cmd, " ".join(cmd)

    if layout_tool == "tree":
        cmd = ["tree", "-a", str(target_dir)]
        return cmd, " ".join(cmd)

    shell_cmd = f"ls -al {shlex.quote(str(target_dir))}/*"
    return ["/bin/sh", "-c", shell_cmd], shell_cmd


def _strip_stale_layout_marker(content: str, stale_layout_prefix: str) -> str:
    lines = content.rstrip("\n").splitlines()
    if lines and lines[-1].startswith(stale_layout_prefix):
        _ = lines.pop()

    return "\n".join(lines)


def _mark_stale_layout(content: str, stale_layout_prefix: str) -> str:
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_content = _strip_stale_layout_marker(content, stale_layout_prefix).rstrip("\n")
    stale_line = f"{stale_layout_prefix}{timestamp}"

    if base_content:
        return "\n".join([base_content, stale_line, ""])

    return "\n".join([stale_line, ""])


def _render_layout(
    layout_tool: str,
    target_dir: Path,
    stale_layout_prefix: str,
    existing_content: str | None = None,
) -> str:
    cmd, display_cmd = _layout_command(layout_tool, target_dir)
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)

    if proc.returncode == 0:
        body = proc.stdout.rstrip()
    else:
        if existing_content:
            return _mark_stale_layout(existing_content, stale_layout_prefix)

        return _mark_stale_layout(
            "\n".join(
                [
                    f"$ {display_cmd}",
                    "Layout generation failed; snapshot unavailable.",
                    "",
                ]
            ),
            stale_layout_prefix,
        )

    return "\n".join([f"$ {display_cmd}", body, ""])


def _generate_directory_layouts(_: object) -> None:
    project_dir = _project_dir()
    if project_dir is None:
        return
    generated_dir = _generated_dir(project_dir)
    layout_targets = _layout_targets()
    layout_tool = _resolve_layout_tool()
    stale_layout_prefix = "Stale - generation failed on "

    generated_dir.mkdir(parents=True, exist_ok=True)

    for name, rel_path in layout_targets.items():
        target_dir = project_dir / rel_path
        out_path = generated_dir / f"{name}-layout.txt"
        existing_content = out_path.read_text() if out_path.exists() else None
        rendered = _render_layout(
            layout_tool,
            target_dir,
            stale_layout_prefix,
            existing_content,
        )
        if existing_content == rendered:
            continue
        _ = out_path.write_text(rendered)


def setup(app: SphinxApp) -> dict[str, object]:
    _ = app.connect("builder-inited", _generate_directory_layouts)
    return {
        "version": "1.0",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
