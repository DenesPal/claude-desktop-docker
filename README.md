# Claude Desktop in Docker

Runs the Claude Desktop Linux beta (installed from Anthropic's apt repository) in a container, displayed on your host's X server.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Debian 12 image, verifies Anthropic's signing key, installs `claude-desktop`, creates a non-root user |
| `entrypoint.sh` | Starts D-Bus + an unlocked GNOME Keyring so your sign-in persists, then launches the app |
| `compose.yaml` | X11, GPU, persistent home volume, workspace bind mount |
| `compose.cowork.yaml` | Optional override passing `/dev/kvm` and `/dev/vhost-vsock` through for Cowork |
| `.env.example` | Settings |

## Run

```bash
cp .env.example .env
sed -i "s/^HOST_UID=.*/HOST_UID=$(id -u)/; s/^HOST_GID=.*/HOST_GID=$(id -g)/" .env
mkdir -p workspace                     # create it as you, not as root
xhost +SI:localuser:$(whoami)          # let your own UID use the X display
docker compose up --build
```

On a Wayland desktop this runs through XWayland, which is the default on GNOME and KDE.

Sign-in opens Firefox inside the container. The app accepts a claude.ai subscription or your organization's SSO; Console API keys aren't supported by Desktop.

## Cowork (optional)

On the host:

```bash
sudo modprobe vhost_vsock
echo vhost_vsock | sudo tee /etc/modules-load.d/vhost_vsock.conf   # persist across reboots
echo "KVM_GID=$(getent group kvm | cut -d: -f3)" >> .env
docker compose -f compose.yaml -f compose.cowork.yaml up --build
```

Requires hardware virtualization enabled in firmware. The app checks requirements only at launch, so restart the container after changing anything.

## Update

The app doesn't update itself on Linux, and there is no apt upgrade inside a container. Rebuild instead:

```bash
CACHE_BUST=$(date +%F) docker compose build --pull && docker compose up -d
```

Settings and sign-in survive in the `claude-home` volume.

## Troubleshooting

- **"cannot open display"**: re-run the `xhost` command and check `HOST_UID` matches `id -u`.
- **Window blank or crashes on start**: set `CLAUDE_DESKTOP_FLAGS=--disable-gpu`, or remove the `/dev/dri` device if your host has none.
- **Sandbox errors (`zygote`, `setuid sandbox`, `namespace`)**: set `CLAUDE_NO_SANDBOX=1`. This disables Chromium's own sandbox, so the container becomes the only isolation layer.
- **Sign-in not remembered**: keep `KEYRING_PASSWORD` the same between runs. If you change it, delete the volume (`docker compose down -v`) and sign in again.
- **Building on Ubuntu** (`BASE_IMAGE=ubuntu:24.04`): set `WITH_BROWSER=false`, since Ubuntu ships Firefox only as a snap.

## Not available in the Linux beta

Computer Use, dictation, and Fedora/RHEL support. The Quick Entry global hotkey depends on the host's X11 session.
