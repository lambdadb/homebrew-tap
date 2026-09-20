#!/usr/bin/env python3
"""Verify every pinned migration archive without executing foreign binaries."""

import hashlib
import json
import os
from pathlib import Path
import re
import struct
import tarfile
import tempfile
import urllib.request


def download(url, destination):
    request = urllib.request.Request(url, headers={"User-Agent": "lambdadb-tap-verification"})
    if url.startswith("https://api.github.com/") and (token := os.environ.get("GH_TOKEN")):
        # Authenticate metadata only; never forward this header on redirects.
        request.add_unredirected_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def main():
    formula = (Path(__file__).resolve().parents[1] / "Formula/lambdadb-migration.rb").read_text()
    version = re.search(r'^  version "([0-9]+\.[0-9]+\.[0-9]+)"$', formula, re.M)
    require(version, "Expected an explicit stable X.Y.Z version")
    version = version[1]
    entries = re.findall(r'url "([^"]+)"\s+sha256 "([0-9a-f]{64})"', formula)
    require(len(entries) == 4, "Expected four pinned archives")
    base = f"https://github.com/lambdadb/lambdadb-migration/releases/download/v{version}"
    expected = {f"lambdadb-migration_{version}_{os}_{arch}.tar.gz": (os, arch)
                for os in ("darwin", "linux") for arch in ("amd64", "arm64")}
    require({url.rsplit('/', 1)[-1] for url, _ in entries} == set(expected),
            "Expected exactly macOS/Linux x amd64/arm64")
    with tempfile.TemporaryDirectory(prefix="migration-release-") as temp:
        temp = Path(temp)
        metadata_path = temp / "release.json"
        download(f"https://api.github.com/repos/lambdadb/lambdadb-migration/releases/tags/v{version}",
                 metadata_path)
        metadata = json.loads(metadata_path.read_text())
        require(metadata["tag_name"] == f"v{version}" and not metadata["draft"]
                and not metadata["prerelease"], "Release must be published and stable")
        sums_path = temp / "checksums.txt"
        download(f"{base}/checksums.txt", sums_path)
        sums = {}
        for line in sums_path.read_text().splitlines():
            digest, name = line.split()
            require(name not in sums, f"Duplicate checksum: {name}")
            sums[name] = digest
        for url, pinned in entries:
            name = url.rsplit("/", 1)[-1]
            require(url == f"{base}/{name}", f"Unexpected release URL: {url}")
            require(pinned == sums.get(name), f"Formula differs from release checksums: {name}")
            archive = temp / name
            download(url, archive)
            actual = hashlib.sha256(archive.read_bytes()).hexdigest()
            require(actual == pinned, f"Downloaded archive checksum mismatch: {name}")
            assets = [asset for asset in metadata["assets"] if asset["name"] == name]
            require(len(assets) == 1, f"Expected one published asset: {name}")
            if assets[0].get("digest"):
                require(assets[0]["digest"] == f"sha256:{actual}", f"GitHub digest mismatch: {name}")
            with tarfile.open(archive, "r:gz") as contents:
                member = contents.getmember("lambdadb-migration")
                require(member.isfile() and member.mode & 0o111, f"Missing executable: {name}")
                binary = contents.extractfile(member).read(32)
                os, arch = expected[name]
                if os == "darwin":
                    require(binary[:4] == b"\xcf\xfa\xed\xfe", f"Expected 64-bit Mach-O: {name}")
                    cpu = struct.unpack("<I", binary[4:8])[0]
                    require(cpu == {"amd64": 0x1000007, "arm64": 0x100000c}[arch],
                            f"Mach-O architecture mismatch: {name}")
                else:
                    require(binary[:6] == b"\x7fELF\x02\x01", f"Expected little-endian ELF64: {name}")
                    cpu = struct.unpack("<H", binary[18:20])[0]
                    require(cpu == {"amd64": 62, "arm64": 183}[arch], f"ELF architecture mismatch: {name}")
                for license_file in ("LICENSE", "NOTICE"):
                    require(contents.getmember(license_file).isfile(), f"Missing {license_file}: {name}")
            print(f"Checksum and binary header verified (not executed): {name} {actual}")


if __name__ == "__main__":
    main()
