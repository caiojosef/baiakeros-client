#!/usr/bin/env python3
"""Build and verify the Baiakeros OTC LZMA updater payload."""

from __future__ import annotations

import argparse
import hashlib
import json
import lzma
import re
import shutil
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


ROOT_FILES = ("cacert.pem", "config.ini", "environment.lua", "init.lua", "otclientrc.lua")
ASSET_DIRS = ("data", "mods", "modules")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pack_one(
    source: Path,
    localfile: str,
    package_root: Path,
    package_name: str,
    source_bytes: bytes | None = None,
) -> dict:
    raw = source.read_bytes() if source_bytes is None else source_bytes
    packed = lzma.compress(raw, format=lzma.FORMAT_ALONE)
    target = package_root / Path(package_name)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(packed)

    restored = lzma.decompress(target.read_bytes(), format=lzma.FORMAT_ALONE)
    if restored != raw:
        raise RuntimeError(f"LZMA verification failed: {localfile}")

    return {
        "localfile": localfile,
        "packedhash": sha256(packed),
        "packedsize": len(packed),
        "url": f"packages/{package_name}",
        "unpackedhash": sha256(raw),
        "unpackedsize": len(raw),
    }


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--executable", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument(
        "--revision",
        type=int,
        help="Explicit revision override. By default the published revision is incremented automatically.",
    )
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    source = args.source.resolve()
    executable = args.executable.resolve()
    destination = args.destination.resolve()
    expected_destination = (source.parent / "site-update" / "downloads" / "client").resolve()
    if destination != expected_destination:
        raise RuntimeError(f"Refusing unexpected destination: {destination}")
    if not executable.is_file():
        raise FileNotFoundError(executable)

    revision = args.revision
    if revision is None:
        manifest_path = destination / "client.windows.json"
        previous_revision = 0
        if manifest_path.is_file():
            previous_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            previous_revision = int(previous_manifest.get("revision", 0))
        revision = previous_revision + 1
    if revision < 1:
        raise ValueError("Revision must be greater than zero")

    started = time.monotonic()
    destination.mkdir(parents=True, exist_ok=True)
    for child in destination.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
    package_root = destination / "packages"
    package_root.mkdir()

    client_jobs: list[tuple[Path, str, str, bytes | None]] = []
    for name in ROOT_FILES:
        # The source tree deliberately keeps environment.lua on localhost for
        # development. Every updater payload must ship the production profile.
        path = source / ("environment.production.lua" if name == "environment.lua" else name)
        if not path.is_file():
            raise FileNotFoundError(path)
        if name == "environment.lua":
            environment = path.read_text(encoding="utf-8")
            if "https://www.baiakeros.com/login.php" not in environment:
                raise RuntimeError("Production login endpoint is missing from environment.production.lua")
            if "127.0.0.1" in environment or "localhost" in environment:
                raise RuntimeError("Refusing to package a local login endpoint for production")
        source_bytes = None
        if name == "init.lua":
            init_source = path.read_text(encoding="utf-8")
            init_source, replacements = re.subn(
                r"(?m)^CLIENT_UPDATE_REVISION\s*=\s*\d+\s*$",
                f"CLIENT_UPDATE_REVISION = {revision}",
                init_source,
            )
            if replacements != 1:
                raise RuntimeError("Could not embed CLIENT_UPDATE_REVISION in init.lua")
            source_bytes = init_source.encode("utf-8")
        client_jobs.append((path, name, f"{name}.lzma", source_bytes))
    client_jobs.append((executable, "otclient.exe", f"otclient.exe.r{revision}.lzma", None))

    asset_jobs: list[tuple[Path, str, str, bytes | None]] = []
    for dirname in ASSET_DIRS:
        directory = source / dirname
        for path in sorted(p for p in directory.rglob("*") if p.is_file()):
            localfile = path.relative_to(source).as_posix()
            asset_jobs.append((path, localfile, f"{localfile}.lzma", None))

    def execute(job: tuple[Path, str, str, bytes | None]) -> dict:
        return pack_one(job[0], job[1], package_root, job[2], job[3])

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        client_files = list(pool.map(execute, client_jobs))
        asset_files = list(pool.map(execute, asset_jobs))

    client_files.sort(key=lambda item: item["localfile"])
    asset_files.sort(key=lambda item: item["localfile"])
    client_manifest = {
        "revision": revision,
        "version": "15.11",
        "files": client_files,
        "executable": "otclient.exe",
        "generation": "1511",
        "variant": "Baiakeros",
    }
    assets_manifest = {"files": asset_files, "version": revision}
    write_json(destination / "client.windows.json", client_manifest)
    write_json(destination / "assets.windows.json", assets_manifest)

    # The launcher updates itself from the same endpoint before checking the
    # client manifests. Publish it together with every complete client build.
    launcher = source.parent / "baiakeros-launcher" / "build" / "bin" / "BaiakerosLauncher.exe"
    if not launcher.is_file():
        raise FileNotFoundError(launcher)
    published_launcher = destination / launcher.name
    shutil.copy2(launcher, published_launcher)
    (destination / f"{launcher.name}.sha256").write_text(
        f"{sha256(published_launcher.read_bytes())}  {launcher.name}\n", encoding="ascii"
    )

    all_files = client_files + asset_files
    original_bytes = sum(item["unpackedsize"] for item in all_files)
    packed_bytes = sum(item["packedsize"] for item in all_files)
    report = {
        "format": "lzma-alone",
        "files": len(all_files),
        "originalBytes": original_bytes,
        "packedBytes": packed_bytes,
        "compressionRatio": round(packed_bytes / original_bytes, 6),
        "durationSeconds": round(time.monotonic() - started, 3),
        "source": str(source),
        "destination": str(package_root),
        "revision": revision,
        "verified": True,
    }
    write_json(destination / "compression-report.json", report)
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
