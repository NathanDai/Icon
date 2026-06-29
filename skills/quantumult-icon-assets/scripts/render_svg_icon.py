#!/usr/bin/env python3
"""Render an SVG icon into a Quantumult-ready transparent PNG."""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="SVG file path or http(s) URL")
    parser.add_argument("--out", required=True, help="Destination PNG path")
    parser.add_argument("--size", type=int, default=144, help="Square output size in pixels")
    return parser.parse_args()


def fetch_source(source: str, tmpdir: Path) -> Path:
    if source.startswith(("http://", "https://")):
        target = tmpdir / "source.svg"
        request = urllib.request.Request(
            source,
            headers={
                "User-Agent": "Mozilla/5.0 (compatible; icon-renderer)",
                "Accept": "image/svg+xml,text/plain,*/*",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            target.write_bytes(response.read())
        return target
    path = Path(source)
    if not path.exists():
        raise FileNotFoundError(source)
    return path


def ensure_svg(path: Path) -> None:
    head = path.read_text(encoding="utf-8", errors="ignore")[:500].lower()
    if "<svg" not in head:
        raise ValueError(f"{path} does not look like an SVG file")


def png_dimensions(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()[:32]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def render_with_sips(source: Path, out: Path, size: int) -> None:
    sips = shutil.which("sips")
    if not sips:
        raise RuntimeError("macOS sips is required to render SVG files")

    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [sips, "-s", "format", "png", "-z", str(size), str(size), str(source), "--out", str(out)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> int:
    args = parse_args()
    out = Path(args.out)

    with tempfile.TemporaryDirectory() as tmp:
        source = fetch_source(args.source, Path(tmp))
        ensure_svg(source)
        render_with_sips(source, out, args.size)

    width, height, color_type = png_dimensions(out)
    if (width, height) != (args.size, args.size):
        raise ValueError(f"expected {args.size}x{args.size}, got {width}x{height}")
    if color_type not in (4, 6):
        raise ValueError(f"expected alpha-capable PNG, got PNG color type {color_type}")

    print(f"{out}: {width}x{height}, alpha=yes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
