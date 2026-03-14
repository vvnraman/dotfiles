from pathlib import Path


def _candidate_directories(anchor: Path) -> list[Path]:
    anchor_path = anchor.resolve()
    base_dir = anchor_path if anchor_path.is_dir() else anchor_path.parent
    return [base_dir, *base_dir.parents]


def resolve_project_dir(*anchors: Path) -> Path:
    marker_names = (".chezmoiroot", ".git")
    seen: set[Path] = set()

    for anchor in anchors:
        for candidate_dir in _candidate_directories(anchor):
            if candidate_dir in seen:
                continue
            seen.add(candidate_dir)

            if any(
                (candidate_dir / marker_name).exists() for marker_name in marker_names
            ):
                return candidate_dir

    raise RuntimeError(
        "Could not resolve project root. Run from repository root or set a valid anchor."
    )
