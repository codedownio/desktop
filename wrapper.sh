#!/bin/bash

CODEDOWN_BIN="@out@/lib/codedown/codedown"
NIX_HASH="$(basename "@out@" | cut -d- -f1)"
PROFILE_NAME="codedown-nix-$NIX_HASH"
PROFILE_PATH="/etc/apparmor.d/$PROFILE_NAME"

apparmor_restricts_userns() {
  [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = "1" ]
}

profile_is_current() {
  [ -f "$PROFILE_PATH" ] && grep -qF "$CODEDOWN_BIN" "$PROFILE_PATH"
}

cleanup_stale_profiles() {
  for f in /etc/apparmor.d/codedown-nix-*; do
    [ -f "$f" ] || continue
    [ "$f" = "$PROFILE_PATH" ] && continue
    # Extract the store path from the profile and check if it still exists
    local store_path
    store_path="$(sed -n 's|.*profile codedown-nix-[^ ]* \(/nix/store/[^/]*\)/.*|\1|p' "$f")"
    if [ -n "$store_path" ] && [ ! -d "$store_path" ]; then
      sudo rm -f "$f"
      sudo apparmor_parser -R "$f" 2>/dev/null || true
    fi
  done
}

install_apparmor_profile() {
  if ! command -v apparmor_parser >/dev/null 2>&1; then
    echo "WARNING: apparmor_parser not found; cannot install AppArmor profile." >&2
    return 1
  fi
  echo "This system's AppArmor policy restricts unprivileged user namespaces." >&2
  echo "CodeDown needs to install an AppArmor profile to enable sandboxing." >&2
  echo "This is a one-time setup that requires sudo." >&2
  sudo tee "$PROFILE_PATH" > /dev/null <<EOPROFILE
abi <abi/4.0>,
include <tunables/global>

profile $PROFILE_NAME $CODEDOWN_BIN flags=(unconfined) {
  userns,
}
EOPROFILE
  sudo apparmor_parser -r "$PROFILE_PATH"
  cleanup_stale_profiles
}

if apparmor_restricts_userns && ! profile_is_current; then
  if ! install_apparmor_profile; then
    echo "WARNING: Could not install AppArmor profile. Sandboxing may not work." >&2
    echo "You can manually fix this with: sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0" >&2
    exec "$CODEDOWN_BIN" --no-sandbox "$@"
  fi
fi

# Fallback for systems without user namespace support at all
if ! command -v unshare >/dev/null 2>&1 || ! unshare --user --pid echo >/dev/null 2>&1; then
  echo "WARNING: unprivileged user namespaces are not available; running with --no-sandbox" >&2
  exec "$CODEDOWN_BIN" --no-sandbox "$@"
fi

exec "$CODEDOWN_BIN" "$@"
