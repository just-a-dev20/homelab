#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ to /
if [ -d "/ctx/system_files" ]; then
    cp -avf "/ctx/system_files"/. /
    rm -f /etc/.gitkeep /usr/.gitkeep
fi

### Install packages
# Core homelab administration, diagnostics, and container management utilities
dnf5 install -y \
    tmux \
    htop \
    iotop \
    smartmontools \
    rsync \
    curl \
    wget \
    git \
    tree \
    lm_sensors \
    moby-engine \
    docker-compose \
    docker-compose-switch \
    docker-buildx

### Enable system services
systemctl enable podman.socket
systemctl enable docker.socket
systemctl enable docker.service

### ZFS storage support (best-effort: OpenZFS is not in the default Fedora repos)
# The WebUI stores all app + user files on configurable pools (Settings → Storage),
# typically ZFS datasets mounted under /mnt. Install userspace tools when available
# so `zfs`/`zpool` work on the host; pool auto-import/mount units are enabled when present.
if dnf5 install -y zfs 2>/dev/null; then
    echo "ZFS userspace installed from default repos"
else
    echo "ZFS not in default repos, trying OpenZFS release package"
    if dnf5 install -y "https://zfsonlinux.org/fedora/zfs-release-2-5$(rpm -E %dist).noarch.rpm" 2>/dev/null \
        && dnf5 install -y zfs 2>/dev/null; then
        echo "ZFS userspace installed from OpenZFS repo"
    else
        echo "WARNING: ZFS packages unavailable; continuing without host ZFS tools."
        echo "Pools still work on any mounted filesystem; add ZFS later per README."
    fi
fi
for unit in zfs.target zfs-import.target zfs-import-cache.service zfs-mount.service zfs-zed.service; do
    if systemctl cat "$unit" >/dev/null 2>&1; then
        systemctl enable "$unit"
    fi
done

### Homelab WebUI quadlet services
# NOTE: Quadlet units (.container/.network/.volume/...) generate transient
# systemd services (foo.container -> foo.service, foo.network -> foo-network.service),
# so they MUST NOT be enabled with `systemctl enable` (it fails with
# "Unit ... does not exist" / "transient or generated").
# Instead, the quadlet generator auto-enables them at boot from their
# [Install] WantedBy= sections. Just ensure the files are present under
# /etc/containers/systemd (copied above) and carry an [Install] section.
# Validate keys with:
#   QUADLET_UNIT_DIRS=/etc/containers/systemd \
#     /usr/lib/systemd/system-generators/podman-system-generator --dryrun
# (valid [Container] pull key is `Pull=`, not `PullPolicy=`; valid [Network]
# keys include Driver/NetworkName/DisableDNS/Internal — no `IPAMConfig=`.)
#
# `AutoUpdate=registry` in the .container files needs this timer to actually
# pull updates in the background (boot itself uses `Pull=missing` from cache).
for unit in podman-auto-update.timer firewalld.service; do
    if systemctl cat "$unit" >/dev/null 2>&1; then
        systemctl enable "$unit"
    fi
done

### Configure firewall for Homelab WebUI
firewall-offline-cmd --zone=public --add-service=homelab-webui

### Clean cache to minimize image layer size
dnf5 clean all
