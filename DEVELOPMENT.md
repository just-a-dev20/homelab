# Homelab OS — Development Guide

This guide is for contributors working on the Homelab OS image itself.
For user-facing docs (install, usage, storage), see [README.md](README.md).

## Prerequisites

- [`podman`](https://podman.io/) (rootful podman needed for disk images / VM runs)
- [`just`](https://github.com/casey/just)
- `git`, `jq` (used by Just recipes)
- Optional: `shellcheck`, `shfmt` (for `just lint` / `just format`)
- QEMU + KVM (`/dev/kvm`) for `just run-vm-*` / `spawn-vm`

Base image and BIB image are pinned in [`Containerfile`](Containerfile) and [`image.env`](image.env).

## Repository Structure

```text
├── Containerfile            # Base image (ucore:stable) + build.sh invocation + bootc lint
├── build_files/
│   └── build.sh             # Packages, services, ZFS best-effort setup
├── system_files/            # Overlaid into rootfs (/etc, /usr, …)
│   ├── etc/
│   └── usr/                 # e.g. usr/lib/tmpfiles.d/homelab-webui.conf
├── disk_config/
│   ├── disk.toml            # Filesystem sizing for QCOW2 / RAW
│   └── iso.toml             # Kickstart + installer modules for bare-metal ISO
├── image.env                # IMAGE_NAME, REPO_ORGANIZATION, tags, BIB_IMAGE
├── Justfile                 # All build / disk / VM / lint recipes
└── .github/workflows/       # Image + disk builds, releases
```

## Customization

### Adding Packages

Edit [`build_files/build.sh`](build_files/build.sh) with `dnf5`:

```bash
dnf5 install -y \
    wireguard-tools \
    zfs
```

### Adding System Files & Services

Mirror the target root path under [`system_files/`](system_files/):

- `/etc/sysctl.d/99-homelab.conf` → `system_files/etc/sysctl.d/99-homelab.conf`
- `/etc/systemd/system/my-service.service` → `system_files/etc/systemd/system/my-service.service`

Then enable services inside `build_files/build.sh`:

```bash
systemctl enable my-service.service
```

### Changing the Base Image

Edit [`Containerfile`](Containerfile):

```dockerfile
FROM ghcr.io/ublue-os/ucore:stable
```

Alternatives:

- `ghcr.io/ublue-os/ucore-hci:stable` (KVM/QEMU & Libvirt)
- `ghcr.io/ublue-os/ucore:stable-nvidia` (pre-compiled NVIDIA layers)
- `quay.io/fedora/fedora-bootc:42` (vanilla Fedora bootc)

## Local Builds

```bash
# Container image
just build
# or: podman build -t homelab:latest .

# Disk images (output/…)
just build-qcow2
just build-raw
just build-iso

# Rebuild from scratch (container + disk)
just rebuild-qcow2
just rebuild-raw
just rebuild-iso
```

Disk builds use Bootc Image Builder (`$BIB_IMAGE` from `image.env`) via the private `_build-bib` recipe (`--rootfs=btrfs`, `--use-librepo=True`).

### Test in a VM

```bash
just run-vm-qcow2   # builds QCOW2 if missing, serves VNC on first free port from 8006
just run-vm-raw
just run-vm-iso

# systemd-vmspawn path (needs ./output/**/*.qcow2)
just spawn-vm
just spawn-vm rebuild=1
```

`_run-vm` launches `docker.io/qemux/qemu` with 4 cores / 8G RAM / 64G disk, TPM + GPU enabled, `/dev/kvm` passthrough.

### Chunked / Smaller Updates

```bash
just rechunk            # chunkah (max-layers 128)
just ostree-rechunk     # rpm-ostree compose build-chunked-oci (max-layers 127)
```

### Helpers

```bash
just --list                 # all recipes
just generate-default-tag
just generate-build-tags
just tag-images <img> <tag> <tags>
just clean                  # rm _build*, output/, manifests
just check / just fix       # justfile formatting
just lint                   # shellcheck *.sh
just format                 # shfmt *.sh
```

## Image Verification & Signing

Images are signed with [Cosign](https://github.com/sigstore/cosign) when `SIGNING_SECRET` is set:

1. `COSIGN_PASSWORD="" cosign generate-key-pair`
2. Repo settings → **Secrets and Variables → Actions** → new secret `SIGNING_SECRET` = contents of `cosign.key`
3. Commit `cosign.pub` to the repo root

The GitHub Actions workflow signs images on push automatically.

## CI

- `.github/workflows/` builds the container image and disk artifacts (QCOW2 + Anaconda ISO) and publishes to `ghcr.io/<org>/homelab`.
- `just build` labels images for ArtifactHub (`io.artifacthub.package.*`, `org.opencontainers.image.*`) including a versioned tag `<default_tag>.<YYYYMMDD>-<sha>` on clean trees.
