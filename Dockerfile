# syntax=docker/dockerfile:1
#
# Claude Desktop (Linux beta) in a container.
# Base must be Debian 12+ or Ubuntu 22.04+ (amd64 or arm64).
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG USER_NAME=claude
ARG USER_UID=1000
ARG USER_GID=1000
# true  = install recommended packages (QEMU/OVMF/virtiofsd) so Cowork can run
# false = smaller image, Chat + Claude Code only
ARG WITH_COWORK=true
# Browser used for the sign-in flow. firefox-esr exists on Debian only;
# set to false when building on an Ubuntu base.
ARG WITH_BROWSER=true
# Anthropic's published signing-key fingerprint
ARG CLAUDE_KEY_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
# The app doesn't self-update on Linux. Change this value (e.g. a date)
# to force a fresh package download on rebuild.
ARG CACHE_BUST=0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base tooling: repo setup, D-Bus + GNOME Keyring for saved sign-in,
# xdg-utils for opening links, fonts and Mesa for rendering.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      dbus dbus-x11 gnome-keyring libsecret-1-0 \
      xdg-utils desktop-file-utils \
      fonts-noto-core fonts-noto-color-emoji \
      libgl1-mesa-dri libegl1 \
      procps \
 && rm -rf /var/lib/apt/lists/*

# Add Anthropic's apt repository, refusing to continue if the key's
# fingerprint doesn't match the published one.
RUN curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
      https://downloads.claude.ai/claude-desktop/key.asc \
 && gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc \
      | awk -F: '$1=="fpr"{print $10}' | grep -x "${CLAUDE_KEY_FPR}" >/dev/null \
 && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
      > /etc/apt/sources.list.d/claude-desktop.list

# Install Claude Desktop (+ optional browser for sign-in).
RUN echo "cache-bust: ${CACHE_BUST}" \
 && apt-get update \
 && if [ "${WITH_COWORK}" = "true" ]; then \
      apt-get install -y claude-desktop; \
    else \
      apt-get install -y --no-install-recommends claude-desktop; \
    fi \
 && if [ "${WITH_BROWSER}" = "true" ]; then \
      apt-get install -y --no-install-recommends firefox-esr; \
    fi \
 && rm -rf /var/lib/apt/lists/*

# Non-root user (the app refuses to run as root). UID/GID should match
# the host user so X11 access and the workspace bind mount just work.
RUN if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
 && if ! getent group "${USER_GID}" >/dev/null; then groupadd -g "${USER_GID}" "${USER_NAME}"; fi \
 && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USER_NAME}" \
 && mkdir -p "/home/${USER_NAME}/workspace" "/home/${USER_NAME}/.local/share/keyrings" \
 && chown -R "${USER_UID}:${USER_GID}" "/home/${USER_NAME}"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/workspace
ENV HOME=/home/${USER_NAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
