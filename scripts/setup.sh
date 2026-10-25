#!/usr/bin/env bash
set -euo pipefail
destination="${1:-.deps/verilator}"
version=5.052
checksum=580b7b6d4a8932dcd65a552e01ce4bcfc15851e3c5e354caca17f83564377225
if [[ -x "$destination/bin/verilator" ]] && "$destination/bin/verilator" --version | grep -q "Verilator $version "; then
    exit 0
fi
if [[ "$(uname -s)/$(uname -m)" != Linux/x86_64 ]]; then
    echo "The pinned bundle requires Linux x86_64. Use a Linux container or the Questa flow." >&2
    exit 1
fi
mkdir -p "$destination"
archive="$(dirname "$destination")/verilator-$version.tar.gz"
curl --fail --location --retry 3 \
    "https://github.com/EDAPack/verilator-bin/releases/download/v$version/verilator-manylinux_2_28_x86_64-$version.tar.gz" \
    --output "$archive"
printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
tar -xzf "$archive" --strip-components=1 -C "$destination"
"$destination/bin/verilator" --version
