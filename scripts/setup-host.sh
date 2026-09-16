#!/usr/bin/env bash
# Ubuntu 26.04 build dependencies, run inside WSL2.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y build-essential clang lld llvm bc bison flex libssl-dev \
    libelf-dev libncurses-dev dwarves device-tree-compiler u-boot-tools \
    vboot-kernel-utils cgpt parted e2fsprogs dosfstools qemu-user qemu-user-binfmt \
    binfmt-support curl ca-certificates git rsync \
    libarchive-tools xz-utils lz4 zstd patch python3 shellcheck gnupg
sudo /usr/lib/systemd/systemd-binfmt
grep -q '^enabled' /proc/sys/fs/binfmt_misc/qemu-aarch64
echo 'ARM emulation handler enabled.'
