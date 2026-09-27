"""Refresh the prepared r30 payload after the final equipment validation.

Uses the existing release packager and preserves its production client files.
Every manifest entry is checked after packing, including unchanged assets.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import lzma
import shutil
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1]
STAGING = SOURCE.parent / "site-update"
DESTINATION = STAGING / "downloads" / "client"


def main() -> None:
    spec = importlib.util.spec_from_file_location("packager", SOURCE.parent / "tools" / "build_client_update.py")
    packager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    client = json.loads((DESTINATION / "client.windows.json").read_text())
    assets = json.loads((DESTINATION / "assets.windows.json").read_text())
    if client["revision"] != 30 or assets["version"] != 30:
        raise ValueError("Expected the unpublished r30 staging payload")
    entries = {entry["localfile"]: entry for entry in assets["files"]}
    changed = []
    for dirname in ("data", "modules", "mods"):
        for path in sorted((SOURCE / dirname).rglob("*")):
            if not path.is_file():
                continue
            localfile = path.relative_to(SOURCE).as_posix()
            payload = path.read_bytes()
            if localfile in entries and hashlib.sha256(payload).hexdigest() == entries[localfile]["unpackedhash"]:
                continue
            entry = packager.pack_one(path, localfile, DESTINATION / "packages", localfile + ".lzma", payload)
            entries[localfile] = entry
            target = STAGING / entry["url"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(DESTINATION / entry["url"], target)
            changed.append(localfile)
    assets["files"] = [entries[key] for key in sorted(entries)]
    all_entries = client["files"] + assets["files"]
    for entry in all_entries:
        packed = (DESTINATION / entry["url"]).read_bytes()
        restored = lzma.decompress(packed, format=lzma.FORMAT_ALONE)
        if len(packed) != entry["packedsize"] or hashlib.sha256(packed).hexdigest() != entry["packedhash"]:
            raise ValueError(f"Packed verification failed: {entry['localfile']}")
        if len(restored) != entry["unpackedsize"] or hashlib.sha256(restored).hexdigest() != entry["unpackedhash"]:
            raise ValueError(f"Unpacked verification failed: {entry['localfile']}")
        if hashlib.sha256((STAGING / entry["url"]).read_bytes()).hexdigest() != entry["packedhash"]:
            raise ValueError(f"Mirrored package verification failed: {entry['localfile']}")
    original = sum(entry["unpackedsize"] for entry in all_entries)
    packed = sum(entry["packedsize"] for entry in all_entries)
    report = json.loads((DESTINATION / "compression-report.json").read_text())
    report.update(files=len(all_entries), originalBytes=original, packedBytes=packed,
                  compressionRatio=round(packed / original, 6), verified=True, refreshedFiles=changed)
    manifest_report = {
        "verified": True, "revision": 30, "clientFiles": len(client["files"]),
        "assetFiles": len(assets["files"]), "totalFiles": len(all_entries),
        "executable": "otclient.exe",
        "executableSha256": next(e["unpackedhash"] for e in client["files"] if e["localfile"] == "otclient.exe"),
        "manifestsMirrored": True, "refreshedFiles": len(changed),
    }
    for directory in (DESTINATION, STAGING):
        packager.write_json(directory / "assets.windows.json", assets)
        packager.write_json(directory / "client.windows.json", client)
        packager.write_json(directory / "compression-report.json", report)
        packager.write_json(directory / "manifest-report.json", manifest_report)
    print(json.dumps(manifest_report))


if __name__ == "__main__":
    main()
