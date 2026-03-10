#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils gnused gnugrep findutils nix jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="$SCRIPT_DIR/flake.nix"

# Read the version from the flake using nix eval
VERSION=$(nix eval "$SCRIPT_DIR#version.x86_64-linux" --raw)

if [[ -z "$VERSION" ]]; then
    echo "Error: Could not evaluate version from flake"
    exit 1
fi

echo "Found version: $VERSION"
echo ""

# Compute hash for fetchzip with stripRoot=true (the default).
# nix store prefetch-file --unpack strips root, matching fetchzip's default.
prefetch_hash_strip_root() {
    local url="$1"
    nix store prefetch-file --unpack --json "$url" 2>/dev/null | jq -r .hash
}

# Compute hash for fetchzip with stripRoot=false.
# Neither nix-prefetch-url --unpack nor nix store prefetch-file --unpack can
# disable root stripping, so we ask Nix to evaluate the actual fetchzip
# derivation with a fake hash and extract the correct hash from the error.
prefetch_hash_no_strip_root() {
    local url="$1"
    local output
    output=$(nix-build --no-out-link --expr "
      with import <nixpkgs> {};
      fetchzip {
        url = \"$url\";
        sha256 = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";
        stripRoot = false;
      }
    " 2>&1 || true)
    echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+'
}

# Function to update a hash for a given URL comment marker.
# Pass "no-strip" as $3 for fetchzip entries with stripRoot = false.
update_hash() {
    local url_marker="$1"
    local hash_marker="$2"
    local strip_mode="${3:-strip}"

    # Extract the URL line and parse out the URL template
    local url_line=$(grep "# $url_marker\$" "$FLAKE_NIX")
    if [[ -z "$url_line" ]]; then
        echo "Warning: Could not find marker # $url_marker"
        return
    fi

    # Extract the URL from the line (it's between quotes after url =)
    # The URL contains ${version} which we need to substitute
    local url_template=$(echo "$url_line" | sed -E 's/.*url = "([^"]+)".*/\1/')

    # Substitute ${version} with the actual version
    local url=$(echo "$url_template" | sed "s/\${version}/$VERSION/g")

    echo "Fetching: $url"

    local hash
    if [[ "$strip_mode" == "no-strip" ]]; then
        hash=$(prefetch_hash_no_strip_root "$url")
    else
        hash=$(prefetch_hash_strip_root "$url")
    fi

    if [[ -z "$hash" ]]; then
        echo "Error: Failed to fetch hash for $url"
        return 1
    fi

    echo "  Hash: $hash"

    # Update the hash in flake.nix
    # Find the line with the hash marker and replace the hash value
    sed -i -E "s|(hash = \")sha256-[^\"]+(\"; # $hash_marker)|\1${hash}\2|" "$FLAKE_NIX"
}

# Update all hashes
# Pass "no-strip" for fetchzip entries that use stripRoot = false
echo "Updating nix-tarball hashes..."
update_hash "nix-tarball-x86_64-url" "nix-tarball-x86_64-hash" no-strip
update_hash "nix-tarball-aarch64-url" "nix-tarball-aarch64-hash" no-strip

echo ""
echo "Updating server-tarball hashes..."
update_hash "server-tarball-x86_64-url" "server-tarball-x86_64-hash" strip
update_hash "server-tarball-aarch64-url" "server-tarball-aarch64-hash" no-strip

echo ""
echo "Updating screenshotter-tarball hashes..."
update_hash "screenshotter-tarball-x86_64-url" "screenshotter-tarball-x86_64-hash" no-strip
update_hash "screenshotter-tarball-aarch64-url" "screenshotter-tarball-aarch64-hash" no-strip

echo ""
echo "Updating runner-bin-dir hashes..."
update_hash "runner-bin-dir-x86_64-url" "runner-bin-dir-x86_64-hash" no-strip
update_hash "runner-bin-dir-aarch64-url" "runner-bin-dir-aarch64-hash" no-strip

echo ""
echo "Updating frontend hash..."
update_hash "frontend-url" "frontend-hash" no-strip

echo ""
echo "Done!"
