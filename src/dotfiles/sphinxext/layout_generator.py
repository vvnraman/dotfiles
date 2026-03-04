import shlex
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[3]
DOCS_DIR = ROOT_DIR / "docs"
PROJECT_DIR = ROOT_DIR
GENERATED_DIR = DOCS_DIR / "generated"

LAYOUT_TARGETS = {
    "bash": "home/dot-bash",
    "fish": "home/dot_config/fish",
    "tmux": "home/dot-tmux",
    "git": "home/dot_config/git",
    "lazygit": "home/dot_config/lazygit",
}

STALE_LAYOUT_PREFIX = "Stale - generation failed on "


def _resolve_layout_tool() -> str:
    if shutil.which("lsd"):
        return "lsd"

    if shutil.which("tree"):
        return "tree"

    return "ls"


LAYOUT_TOOL = _resolve_layout_tool()


def _layout_command(target_dir: Path) -> tuple[list[str], str]:
    if LAYOUT_TOOL == "lsd":
        cmd = ["lsd", "--almost-all", "--tree", str(target_dir)]
        return cmd, " ".join(cmd)

    if LAYOUT_TOOL == "tree":
        cmd = ["tree", "-a", str(target_dir)]
        return cmd, " ".join(cmd)

    shell_cmd = f"ls -al {shlex.quote(str(target_dir))}/*"
    return ["/bin/sh", "-c", shell_cmd], shell_cmd


def _strip_stale_layout_marker(content: str) -> str:
    lines = content.rstrip("\n").splitlines()
    if lines and lines[-1].startswith(STALE_LAYOUT_PREFIX):
        lines.pop()

    return "\n".join(lines)


def _mark_stale_layout(content: str) -> str:
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_content = _strip_stale_layout_marker(content).rstrip("\n")
    stale_line = f"{STALE_LAYOUT_PREFIX}{timestamp}"

    if base_content:
        return "\n".join([base_content, stale_line, ""])

    return "\n".join([stale_line, ""])


def _render_layout(target_dir: Path, existing_content: str | None = None) -> str:
    cmd, display_cmd = _layout_command(target_dir)
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)

    if proc.returncode == 0:
        body = proc.stdout.rstrip()
    else:
        if existing_content:
            return _mark_stale_layout(existing_content)

        return _mark_stale_layout(
            "\n".join(
                [
                    f"$ {display_cmd}",
                    "Layout generation failed; snapshot unavailable.",
                    "",
                ]
            )
        )

    return "\n".join([f"$ {display_cmd}", body, ""])


def _generate_directory_layouts(_: object) -> None:
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)

    for name, rel_path in LAYOUT_TARGETS.items():
        target_dir = PROJECT_DIR / rel_path
        out_path = GENERATED_DIR / f"{name}-layout.txt"
        existing_content = out_path.read_text() if out_path.exists() else None
        rendered = _render_layout(target_dir, existing_content)
        if existing_content == rendered:
            continue
        out_path.write_text(rendered)


def setup(app):
    app.connect("builder-inited", _generate_directory_layouts)
    return {
        "version": "1.0",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
