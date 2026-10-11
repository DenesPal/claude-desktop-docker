#!/usr/bin/env bash
# Starts a D-Bus session and an unlocked GNOME Keyring, then launches
# Claude Desktop. Without an unlocked keyring the app can't save the
# sign-in and asks you to log in on every launch.
set -euo pipefail

if [ "$(id -u)" = "0" ]; then
  echo "Claude Desktop must not run as root; run the container as a regular user." >&2
  exit 1
fi

# Re-exec inside a private D-Bus session bus.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  exec dbus-run-session -- "$0" "$@"
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# Unlock (or create on first run) the login keyring with KEYRING_PASSWORD.
# The keyring lives in the persisted home volume.
: "${KEYRING_PASSWORD:=claude}"
eval "$(printf '%s' "$KEYRING_PASSWORD" | gnome-keyring-daemon --unlock --components=secrets)"
eval "$(gnome-keyring-daemon --start --components=secrets)"
export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK 2>/dev/null || true

# Force libsecret: with no recognised desktop environment in the
# container, Electron would otherwise fall back to a plain-text store.
flags=(--password-store=gnome-libsecret)

# Escape hatch if Chromium's sandbox can't start under your container runtime.
if [ "${CLAUDE_NO_SANDBOX:-0}" = "1" ]; then
  flags+=(--no-sandbox)
fi

# Extra flags, space-separated (e.g. "--disable-gpu").
extra=()
if [ -n "${CLAUDE_DESKTOP_FLAGS:-}" ]; then
  read -r -a extra <<< "$CLAUDE_DESKTOP_FLAGS"
fi

exec claude-desktop "${flags[@]}" "${extra[@]}" "$@"
