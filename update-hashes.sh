#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils gnused gnugrep findutils nix jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="$SCRIPT_DIR/flake.nix"

# Read the version from the flake using nix eval
VERSION=$(nix eval "$SCRIPT_DIR#version" --raw)

if [[ -z "$VERSION" ]]; then
    echo "Error: Could not evaluate version from flake"
    exit 1
fi

echo "Found version: $VERSION"
echo ""

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

    local hash
    hash=$(nix store prefetch-file --unpack --json "$url" 2>/dev/null | jq -r .hash)

    if [[ -z "$hash" ]]; then
        echo "Error: Failed to fetch hash for $url"
        return 1
    fi

    echo "  Hash: $hash"

    # Update the hash in flake.nix
    # Find the line with the hash marker and replace the hash value
    sed -i -E "s|(hash = \")sha256-[^\"]+(\"; # $hash_marker)|\1${hash}\2|" "$FLAKE_NIX"
}

echo "Updating tarball hash..."
update_hash "tarball-url" "tarball-hash"

echo ""
echo "Done!"
