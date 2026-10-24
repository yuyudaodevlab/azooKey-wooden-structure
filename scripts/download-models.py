#!/usr/bin/env python3
"""Download pinned azooKey model resources and verify their LFS SHA-256."""

from __future__ import annotations

import hashlib
import os
import sys
import tempfile
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
TIMEOUT_SECONDS = 60
CHUNK_SIZE = 1024 * 1024

# Repository revisions and SHA-256 values are taken from Hugging Face metadata.
FILES = (
    {
        "repo": "Miwa-Keita/zenz-v3.1-small-gguf",
        "revision": "ddf6e44b2e05ab7ea9a3e31559c5e7948761365c",
        "path": Path("azooKeyMac/Resources/gguf/ggml-model-Q5_K_M.gguf"),
        "size": 73871968,
        "sha256": "4de930c06bef8c263aa1aa40684af206db4ce1b96375b3b8ed0ea508e0b14f6c",
    },
    {
        "repo": "Miwa-Keita/base_n5_lm",
        "revision": "160a305a89c033ac53a674baeac4470cf531a71b",
        "path": Path("azooKeyMac/Resources/base_n5_lm/lm_c_abc.marisa"),
        "size": 20680344,
        "sha256": "ab9cfb9b4231b1187934109776339001a9cb089a9d0fa8ed160c79508c8783a3",
    },
    {
        "repo": "Miwa-Keita/base_n5_lm",
        "revision": "160a305a89c033ac53a674baeac4470cf531a71b",
        "path": Path("azooKeyMac/Resources/base_n5_lm/lm_r_xbx.marisa"),
        "size": 3585808,
        "sha256": "f9594d23e2f15a8e6d51811f15b23e23bfc7cefd24b8b1c06f3f0366ce5bf555",
    },
    {
        "repo": "Miwa-Keita/base_n5_lm",
        "revision": "160a305a89c033ac53a674baeac4470cf531a71b",
        "path": Path("azooKeyMac/Resources/base_n5_lm/lm_u_abx.marisa"),
        "size": 9820096,
        "sha256": "6656bb6bea01f75a2156009b7b104adbd6bf897cff47635fd907215f2bc727e9",
    },
    {
        "repo": "Miwa-Keita/base_n5_lm",
        "revision": "160a305a89c033ac53a674baeac4470cf531a71b",
        "path": Path("azooKeyMac/Resources/base_n5_lm/lm_u_xbc.marisa"),
        "size": 10551760,
        "sha256": "69f43384dc45fd16f45e19cbdf242e67f5f8433168dadfe2012abb7657d38041",
    },
)


def matches(path: Path, expected_size: int, expected_sha256: str) -> bool:
    if not path.is_file() or path.stat().st_size != expected_size:
        return False
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest() == expected_sha256


def download(item: dict[str, object]) -> None:
    target = ROOT / item["path"]
    expected_size = int(item["size"])
    expected_sha256 = str(item["sha256"])
    if matches(target, expected_size, expected_sha256):
        print(f"Already verified: {target.relative_to(ROOT)}")
        return

    repo = str(item["repo"])
    revision = str(item["revision"])
    url = f"https://huggingface.co/{repo}/resolve/{revision}/{target.name}?download=true"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        request = Request(url, headers={"User-Agent": "azooKey-resource-fetcher/1.0"})
        with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            with tempfile.NamedTemporaryFile(
                mode="wb", prefix=f".{target.name}.", suffix=".part",
                dir=target.parent, delete=False,
            ) as temporary:
                temporary_path = Path(temporary.name)
                digest = hashlib.sha256()
                size = 0
                while chunk := response.read(CHUNK_SIZE):
                    temporary.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)

        actual_sha256 = digest.hexdigest()
        if size != expected_size or actual_sha256 != expected_sha256:
            raise ValueError(
                f"verification failed for {target.name}: expected {expected_size} bytes "
                f"and SHA-256 {expected_sha256}, got {size} bytes and {actual_sha256}"
            )

        os.chmod(temporary_path, 0o644)
        temporary_path.replace(target)
        print(f"Downloaded and verified: {target.relative_to(ROOT)}")
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()


def main() -> int:
    try:
        for item in FILES:
            download(item)
    except (HTTPError, URLError, TimeoutError, OSError, ValueError) as error:
        print(f"Model resource download failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
