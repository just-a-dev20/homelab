# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image: Universal Blue uCore (Fedora-based bootc image designed for homelab and server workloads)
FROM ghcr.io/ublue-os/ucore:stable

# Image Metadata Labels
LABEL org.opencontainers.image.title="homelab" \
      org.opencontainers.image.description="Fedora & Universal Blue bootc OS distribution for homelab servers" \
      org.opencontainers.image.url="https://github.com/just-a-dev20/homelab" \
      org.opencontainers.image.source="https://github.com/just-a-dev20/homelab" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

### MODIFICATIONS
## Run custom build modifications and package installations via build.sh
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are bootc-compliant
RUN bootc container lint
