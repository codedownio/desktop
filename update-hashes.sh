#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils gnused gnugrep findutils nix

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

# Function to update a hash for a given URL comment marker
update_hash() {
    local url_marker="$1"
    local hash_marker="$2"

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

    # Use nix-prefetch-url to get the hash (--unpack for tarballs used with fetchzip)
    local hash=$(nix-prefetch-url --unpack "$url" 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri)

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
echo "Updating nix-tarball hashes..."
update_hash "nix-tarball-x86_64-url" "nix-tarball-x86_64-hash"
update_hash "nix-tarball-aarch64-url" "nix-tarball-aarch64-hash"

echo ""
echo "Updating server-tarball hashes..."
update_hash "server-tarball-x86_64-url" "server-tarball-x86_64-hash"
update_hash "server-tarball-aarch64-url" "server-tarball-aarch64-hash"

echo ""
echo "Updating screenshotter-tarball hashes..."
update_hash "screenshotter-tarball-x86_64-url" "screenshotter-tarball-x86_64-hash"
update_hash "screenshotter-tarball-aarch64-url" "screenshotter-tarball-aarch64-hash"

echo ""
echo "Updating runner-bin-dir hashes..."
update_hash "runner-bin-dir-x86_64-url" "runner-bin-dir-x86_64-hash"
update_hash "runner-bin-dir-aarch64-url" "runner-bin-dir-aarch64-hash"

echo ""
echo "Updating frontend hash..."
update_hash "frontend-url" "frontend-hash"

echo ""
echo "Done!"
