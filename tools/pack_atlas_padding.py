#!/usr/bin/env python3
"""Losslessly trim 48-frame (8 x 6) Fablewood animation atlases.

Default mode is a non-destructive audit: it never writes image files.  --apply is
required to atomically replace a source atlas, after copying every source file to
a timestamped backup directory outside the Godot project.  The runtime mapping is
written disabled in audit mode and enabled only after a successful --apply.

This tool deliberately discovers only final generated animation families.  It
never sweeps arbitrary assets, so icons, legacy sources, catalog replacements,
and intermediate art cannot accidentally enter the optimization.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from PIL import Image

COLUMNS = 8
ROWS = 6
FRAME_COUNT = COLUMNS * ROWS
MARGIN = 2
SCHEMA = 1
DEFAULT_PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_BACKUP_ROOT = Path.home() / ".cache" / "fablewood" / "atlas-padding-backups"
# Deliberately top-level and explicit: the export preset must include exactly
# `assets/template/atlas_layout.json`; no family-specific metadata is overloaded.
METADATA_RELATIVE = Path("assets/template/atlas_layout.json")
# Each pattern names final generated animation outputs only.  Worldheart and
# Thunderpyre are intentionally future-facing: any 8x6 asset under these narrow
# patterns is accepted with its actual cell size (including 512x640 and 384x288).
DISCOVERY_PATTERNS = (
    "assets/template/GuardianAnimations/illuminated_*.webp",
    "assets/template/EndpointAnimations/illuminated_*.webp",
    "assets/template/MergedAnimations/illuminated_*.webp",
    "assets/template/InvadersIlluminated/*/[NS][EW].webp",
    "assets/template/worldheart/illuminated_*.webp",
    "assets/template/Worldheart/illuminated_*.webp",
    "assets/template/Thunderpyre/illuminated_*.webp",
    "assets/template/thunderpyre/illuminated_*.webp",
)


@dataclass(frozen=True)
class AtlasPlan:
    absolute: Path
    relative: str
    source_sha256: str
    original_size: tuple[int, int]
    original_cell: tuple[int, int]
    trim_offset: tuple[int, int]
    crop: tuple[int, int, int, int]
    packed_cell: tuple[int, int]
    columns: int = COLUMNS
    rows: int = ROWS
    frames: int = FRAME_COUNT

    @property
    def original_rgba(self) -> int:
        return self.original_size[0] * self.original_size[1] * 4

    @property
    def packed_rgba(self) -> int:
        return self.packed_cell[0] * self.packed_cell[1] * self.frames * 4

    def record(self, packed_sha256: str | None = None) -> dict[str, Any]:
        result: dict[str, Any] = {
            "original_cell": list(self.original_cell),
            "trim_offset": list(self.trim_offset),
            "packed_cell": list(self.packed_cell),
            "columns": self.columns,
            "rows": self.rows,
            "frames": self.frames,
            "source_sha256": self.source_sha256,
            "original_size": list(self.original_size),
        }
        if packed_sha256:
            result["packed_sha256"] = packed_sha256
        return result


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def is_excluded(relative: str) -> bool:
    lower = relative.lower()
    excluded_parts = ("/legacy", "/catalog", "/icons/", "/icon.")
    return any(part in lower for part in excluded_parts) or Path(relative).stem.lower() == "icon"


def candidates(project_root: Path) -> list[Path]:
    selected: set[Path] = set()
    for pattern in DISCOVERY_PATTERNS:
        selected.update(project_root.glob(pattern))
    # Directional invader sheets are exactly NE/SE/NW/SW; glob pattern permits
    # no other two-character filename once this explicit check is applied.
    result: list[Path] = []
    for path in sorted(selected):
        relative = path.relative_to(project_root).as_posix()
        if not path.is_file() or is_excluded(relative):
            continue
        if "InvadersIlluminated/" in relative:
            if path.stem not in {"NE", "SE", "NW", "SW"}:
                continue
        result.append(path)
    return result


def alpha_union(image: Image.Image, cell: tuple[int, int]) -> tuple[int, int, int, int]:
    cell_w, cell_h = cell
    alpha = image.getchannel("A")
    bounds: list[tuple[int, int, int, int]] = []
    for frame in range(FRAME_COUNT):
        x = (frame % COLUMNS) * cell_w
        y = (frame // COLUMNS) * cell_h
        box = alpha.crop((x, y, x + cell_w, y + cell_h)).getbbox()
        if box is None:
            raise ValueError(f"frame {frame} has no nonzero-alpha pixels")
        bounds.append(box)
    return (
        max(0, min(box[0] for box in bounds) - MARGIN),
        max(0, min(box[1] for box in bounds) - MARGIN),
        min(cell_w, max(box[2] for box in bounds) + MARGIN),
        min(cell_h, max(box[3] for box in bounds) + MARGIN),
    )


def plan_one(path: Path, project_root: Path) -> AtlasPlan | None:
    relative = path.relative_to(project_root).as_posix()
    with Image.open(path) as raw:
        image = raw.convert("RGBA")
    width, height = image.size
    if width % COLUMNS or height % ROWS:
        # A final-family static asset or a paged atlas: intentionally not a
        # compatible 48-frame source and therefore not a candidate.
        return None
    cell = (width // COLUMNS, height // ROWS)
    if cell[0] <= 0 or cell[1] <= 0:
        return None
    crop = alpha_union(image, cell)
    packed = (crop[2] - crop[0], crop[3] - crop[1])
    if packed[0] <= 0 or packed[1] <= 0:
        raise ValueError(f"empty union after crop: {relative}")
    return AtlasPlan(
        absolute=path,
        relative=relative,
        source_sha256=sha256_file(path),
        original_size=(width, height),
        original_cell=cell,
        trim_offset=(crop[0], crop[1]),
        crop=crop,
        packed_cell=packed,
    )


def scan(project_root: Path) -> tuple[list[AtlasPlan], list[dict[str, str]]]:
    plans: list[AtlasPlan] = []
    skipped: list[dict[str, str]] = []
    for path in candidates(project_root):
        relative = path.relative_to(project_root).as_posix()
        try:
            plan = plan_one(path, project_root)
        except Exception as error:  # Preserve a readable audit result, never silently apply partial scope.
            skipped.append({"path": relative, "reason": str(error)})
            continue
        if plan is None:
            skipped.append({"path": relative, "reason": "not a 48-frame 8x6 atlas"})
        else:
            plans.append(plan)
    return plans, skipped


def manifest(plans: Iterable[AtlasPlan], enabled: bool, packed_hashes: dict[str, str] | None = None) -> dict[str, Any]:
    records: dict[str, dict[str, Any]] = {}
    for plan in plans:
        records[plan.relative] = plan.record((packed_hashes or {}).get(plan.relative))
    return {
        "schema": SCHEMA,
        "enabled": enabled,
        "generator": "optimization/pack_atlas_padding.py",
        "method": "Shared union of all nonzero-alpha pixels across 48 frames plus a 2px margin; lossless copy, no resampling or new art.",
        "atlases": records,
    }


def pack(plan: AtlasPlan) -> Image.Image:
    with Image.open(plan.absolute) as raw:
        source = raw.convert("RGBA")
    packed_w, packed_h = plan.packed_cell
    output = Image.new("RGBA", (packed_w * COLUMNS, packed_h * ROWS), (0, 0, 0, 0))
    left, top, right, bottom = plan.crop
    cell_w, cell_h = plan.original_cell
    for frame in range(FRAME_COUNT):
        source_x = (frame % COLUMNS) * cell_w
        source_y = (frame // COLUMNS) * cell_h
        # Crop/paste preserves every RGBA value in the shared union, including
        # transparent-edge RGB values; only verified-zero-alpha exterior pixels drop.
        frame_crop = source.crop((source_x + left, source_y + top, source_x + right, source_y + bottom))
        destination = ((frame % COLUMNS) * packed_w, (frame // COLUMNS) * packed_h)
        output.paste(frame_crop, destination)
    return output


def assert_lossless(plan: AtlasPlan, packed: Image.Image) -> None:
    with Image.open(plan.absolute) as raw:
        source = raw.convert("RGBA")
    cell_w, cell_h = plan.original_cell
    packed_w, packed_h = plan.packed_cell
    left, top, right, bottom = plan.crop
    for frame in range(FRAME_COUNT):
        source_x = (frame % COLUMNS) * cell_w
        source_y = (frame // COLUMNS) * cell_h
        expected = source.crop((source_x + left, source_y + top, source_x + right, source_y + bottom))
        actual = packed.crop(((frame % COLUMNS) * packed_w, (frame // COLUMNS) * packed_h,
                              (frame % COLUMNS + 1) * packed_w, (frame // COLUMNS + 1) * packed_h))
        if expected.tobytes() != actual.tobytes():
            raise AssertionError(f"RGBA mismatch after packing {plan.relative}, frame {frame}")
        alpha = source.getchannel("A").crop((source_x, source_y, source_x + cell_w, source_y + cell_h))
        # The exterior is the complement of the crop; verify it had no alpha.
        exterior = Image.new("L", (cell_w, cell_h), 0)
        exterior.paste(alpha, (0, 0))
        exterior.paste(0, (left, top, right, bottom))
        if exterior.getbbox() is not None:
            raise AssertionError(f"nonzero-alpha pixel discarded from {plan.relative}, frame {frame}")


def encode_lossless(image: Image.Image) -> bytes:
    payload = io.BytesIO()
    image.save(payload, format="WEBP", lossless=True, quality=100, method=6, exact=True)
    return payload.getvalue()


def verify_encoded(plan: AtlasPlan, encoded: bytes) -> None:
    with Image.open(io.BytesIO(encoded)) as decoded_raw:
        decoded = decoded_raw.convert("RGBA")
    expected = pack(plan)
    if decoded.size != expected.size or decoded.tobytes() != expected.tobytes():
        raise AssertionError(f"lossless WEBP decode mismatch: {plan.relative}")


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def make_backup(plans: list[AtlasPlan], backup_root: Path) -> Path:
    stamp = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_dir = backup_root / stamp
    # A collision would imply a retry in the same second; fail rather than mix restores.
    backup_dir.mkdir(parents=True, exist_ok=False)
    manifest_entries: list[dict[str, Any]] = []
    for plan in plans:
        destination = backup_dir / "files" / plan.relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(plan.absolute, destination)
        copied_hash = sha256_file(destination)
        if copied_hash != plan.source_sha256:
            raise AssertionError(f"backup hash mismatch: {plan.relative}")
        manifest_entries.append({"path": plan.relative, "sha256": copied_hash, "backup": str(destination.relative_to(backup_dir))})
    write_json(backup_dir / "restore_manifest.json", {"schema": SCHEMA, "created_utc": stamp, "files": manifest_entries})
    return backup_dir


def apply(plans: list[AtlasPlan], project_root: Path, backup_root: Path) -> Path:
    if not plans:
        raise RuntimeError("No eligible 48-frame atlas found; nothing to apply.")
    # Prepare all encoded sources before touching the project, so pixel or codec
    # failures cannot partially alter game assets.
    staged: list[tuple[AtlasPlan, bytes]] = []
    packed_hashes: dict[str, str] = {}
    for index, plan in enumerate(plans, 1):
        image = pack(plan)
        assert_lossless(plan, image)
        encoded = encode_lossless(image)
        verify_encoded(plan, encoded)
        staged.append((plan, encoded))
        packed_hashes[plan.relative] = hashlib.sha256(encoded).hexdigest()
        if index % 4 == 0 or index == len(plans):
            print(f"Verified lossless atlas {index}/{len(plans)}: {plan.relative}", flush=True)
    backup_dir = make_backup(plans, backup_root)
    temp_paths: list[tuple[Path, Path]] = []
    try:
        for plan, encoded in staged:
            handle = tempfile.NamedTemporaryFile(prefix=".atlas-padding-", suffix=".webp", dir=plan.absolute.parent, delete=False)
            try:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            finally:
                handle.close()
            temp_paths.append((plan.absolute, Path(handle.name)))
        for destination, temporary in temp_paths:
            os.replace(temporary, destination)
        write_json(project_root / METADATA_RELATIVE, manifest(plans, enabled=True, packed_hashes=packed_hashes))
    except Exception:
        for _, temporary in temp_paths:
            temporary.unlink(missing_ok=True)
        raise
    return backup_dir


def restore(project_root: Path, backup_dir: Path) -> None:
    raw = json.loads((backup_dir / "restore_manifest.json").read_text(encoding="utf-8"))
    entries = raw.get("files")
    if not isinstance(entries, list):
        raise ValueError("Invalid restore manifest")
    staged: list[tuple[Path, bytes]] = []
    for entry in entries:
        relative = entry["path"]
        source = backup_dir / entry["backup"]
        if sha256_file(source) != entry["sha256"]:
            raise AssertionError(f"backup source changed: {relative}")
        staged.append((project_root / relative, source.read_bytes()))
    for destination, content in staged:
        temporary = destination.with_suffix(destination.suffix + ".restore.tmp")
        temporary.write_bytes(content)
        os.replace(temporary, destination)
    write_json(project_root / METADATA_RELATIVE, {
        "schema": SCHEMA,
        "enabled": False,
        "generator": "optimization/pack_atlas_padding.py",
        "method": "Restored source atlases; disabled until a new explicit --apply.",
        "atlases": {},
    })


def summary(plans: list[AtlasPlan], skipped: list[dict[str, str]], applied: bool, backup_dir: Path | None = None) -> dict[str, Any]:
    original = sum(plan.original_rgba for plan in plans)
    packed = sum(plan.packed_rgba for plan in plans)
    return {
        "schema": SCHEMA,
        "mode": "applied" if applied else "dry-run",
        "applied": applied,
        "atlas_count": len(plans),
        "original_raw_rgba_bytes": original,
        "packed_raw_rgba_bytes": packed,
        "original_raw_rgba_mib": round(original / 1024 ** 2, 3),
        "packed_raw_rgba_mib": round(packed / 1024 ** 2, 3),
        "saved_raw_rgba_bytes": original - packed,
        "saving_percent": round((1.0 - packed / original) * 100.0, 3) if original else 0.0,
        "backup_directory": str(backup_dir) if backup_dir else None,
        "metadata": ("res://" + METADATA_RELATIVE.as_posix()),
        "skipped": skipped,
        "records": {plan.relative: plan.record() for plan in plans},
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--backup-root", type=Path, default=DEFAULT_BACKUP_ROOT,
                        help="outside-project source backup root used only by --apply")
    parser.add_argument("--result", type=Path, default=DEFAULT_PROJECT / "dist" / "atlas-padding-result.json")
    parser.add_argument("--apply", action="store_true", help="required to replace eligible atlas files in place")
    parser.add_argument("--restore", type=Path, metavar="BACKUP_DIR", help="restore a prior backup and disable metadata")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    if not (project_root / "project.godot").is_file():
        raise SystemExit(f"Not a Godot project root: {project_root}")
    if args.restore is not None:
        if args.apply:
            raise SystemExit("Use --restore or --apply, never both.")
        restore(project_root, args.restore.resolve())
        payload = {"schema": SCHEMA, "mode": "restored", "applied": False, "backup_directory": str(args.restore.resolve())}
        write_json(args.result.resolve(), payload)
        print(json.dumps(payload, indent=2))
        return 0
    metadata_path = project_root / METADATA_RELATIVE
    if args.apply and metadata_path.exists():
        existing = json.loads(metadata_path.read_text(encoding="utf-8"))
        if existing.get("enabled", False):
            raise SystemExit("Atlas packing is already enabled; restore the recorded originals before a new --apply.")
    plans, skipped = scan(project_root)
    # Refuse apply when a candidate is malformed rather than silently optimizing
    # only a subset of a newly delivered final family.
    if args.apply and skipped:
        raise SystemExit("Refusing --apply: review skipped candidates first: " + json.dumps(skipped))
    backup_dir = apply(plans, project_root, args.backup_root.resolve()) if args.apply else None
    # Dry-run is strictly read-only for the game project. The JSON mapping is
    # emitted only after --apply, at an export-included location, and the helper
    # safely falls back when it is absent before approval.
    payload = summary(plans, skipped, applied=args.apply, backup_dir=backup_dir)
    write_json(args.result.resolve(), payload)
    print(json.dumps({key: value for key, value in payload.items() if key not in {"records", "skipped"}}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
