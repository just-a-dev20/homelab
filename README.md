# Homelab OS

[![Build container image](https://github.com/just-a-dev20/homelab/actions/workflows/build.yml/badge.svg)](https://github.com/just-a-dev20/homelab/actions/workflows/build.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/just-a-dev20/homelab?utm_source=oss&utm_medium=github&utm_campaign=just-a-dev20%2Fhomelab&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

**Homelab OS** is a custom, bootable container operating system image (`bootc`) built on **Fedora** and **Universal Blue ([uCore](https://github.com/ublue-os/ucore))**. It is designed for homelab servers, self-hosting, containerized microservices, and virtualization hosts.

> Contributing or building images locally? See [DEVELOPMENT.md](DEVELOPMENT.md).

---

## Features

- **Immutable & Atomic**: Powered by `bootc` and `rpm-ostree`. Transactional upgrades with fast rollback.
- **Fedora & Universal Blue Core**: Derived from Universal Blue `uCore:stable`.
- **Container-First**:
  - **Docker & Docker Compose**: Pre-installed, systemd services/sockets enabled (`docker`, `docker compose`, `docker-compose` CLI compatibility).
  - **Podman**: Installed with the system socket enabled (`podman.socket`).
- **Server Administration & Diagnostics**:
  - Web console via Cockpit (included in uCore base).
  - Pre-installed: `tmux`, `htop`, `iotop`, `smartmontools`, `rsync`, `lm_sensors`, `curl`, `wget`, `git`, `tree`.
- **Preinstalled Homelab WebUI**: frontend + backend container images ship inside the OS image (bootc logically bound images) and start automatically on boot, even with no registry access. They are refreshed atomically on `bootc upgrade`.
- **One-click updates**: Settings → Updates in the WebUI checks (`bootc upgrade --check`), stages (`bootc upgrade`), and reboots into new OS + WebUI images via the host updater (`homelab-os-update-check.timer`, `homelab-os-update-dispatcher.path`). Daily checks run automatically; auto-staging is opt-in.
- **Bootable Media Support**: Ready-made configs for bare-metal Anaconda installer ISOs and QCOW2 VM disks.
- **Automated CI/CD**: Builds and releases to GitHub Container Registry (`ghcr.io/just-a-dev20/homelab`).

---

## Quick Start

### Switching an Existing System

If you already run Fedora Atomic, Fedora CoreOS, or another Universal Blue / `bootc` distro:

```bash
sudo bootc switch ghcr.io/just-a-dev20/homelab:latest
sudo systemctl reboot
```

Rollback anytime:

```bash
sudo bootc rollback
sudo systemctl reboot
```

### Installing on Bare Metal or Virtual Machines

1. Go to the [Actions tab](https://github.com/just-a-dev20/homelab/actions/workflows/build-disk.yml).
2. Trigger the **Build disk images** workflow (pick `amd64`/`arm64`; builds `qcow2` + `anaconda-iso`).
3. Download the artifact.
4. Flash the ISO to USB or attach the QCOW2 to your hypervisor (Proxmox, KVM/QEMU, Libvirt).

---

## Container Runtimes

Docker and Docker Compose work immediately:

```bash
docker --version
docker compose version
docker-compose --version
```

To run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## Storage (Drives & Pools)

The Homelab WebUI stores **all user files and all app files on configurable storage pools** (ZFS recommended) — the OS root stays immutable.

1. Create a zpool and dataset (example):

   ```bash
   sudo zpool create tank mirror /dev/sda /dev/sdb
   sudo zfs create -o mountpoint=/mnt/tank/homelab tank/homelab
   sudo zfs set compression=lz4 tank/homelab
   sudo zfs list
   ```

2. Open the WebUI → **Settings → Storage pools** and add the pool:

   - name: `tank`, type: `zfs`, path: `/mnt/tank/homelab`, dataset: `tank/homelab`
   - enable **default for app files** and **default for user files**

3. From then on App Store installs land under `/mnt/tank/homelab/apps/<app>/` and user files under `/mnt/tank/homelab/user-files/` — checksummed, compressed, and snapshottable (`zfs snapshot tank/homelab@daily-$(date +%F)`).

Notes:

- ZFS userspace is installed on a best-effort basis and `zfs-import-cache.service` / `zfs-mount.service` are enabled when present, so pools import at boot. Without ZFS packages, follow the [OpenZFS Fedora guide](https://openzfs.github.io/openzfs-docs/Getting_Started/Fedora/) — WebUI pools keep working on any mounted filesystem in the meantime.
- Pool config persists in `/var/lib/homelab-webui`; the backend mounts `/var/lib/homelab-webui:/data` and `/mnt:/mnt`.

---

## License

Copyright (C) 2026 just-a-dev20

This program is free software: you can redistribute it and/or modify
it under the terms of the [GNU General Public License](LICENSE) as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
