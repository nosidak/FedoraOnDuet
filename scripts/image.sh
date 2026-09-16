#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Depthcharge layout and FIT packaging derived from Cadmium (see NOTICE.md).
set -euo pipefail
: "${WORK:?Set WORK to the native Linux build directory}"
[[ $EUID == 0 ]] || { echo 'Run with sudo' >&2; exit 1; }
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
output=${1:?output image required}
bash "$PROJECT/scripts/build.sh" check-output "$output"
ROOT="$WORK/rootfs"
[[ -f "$ROOT/.configured" && -f "$WORK/kernelrelease" ]] || { echo 'Kernel/rootfs not ready' >&2; exit 1; }
# Fail if an earlier chroot still has mounts: do not copy host virtual filesystems.
if findmnt -rn -o TARGET | grep -q "^$ROOT/"; then echo 'Rootfs has active mounts' >&2; exit 1; fi
release=$(cat "$WORK/kernelrelease")
make -C "$KERNEL" ARCH=arm64 LLVM=1 INSTALL_MOD_PATH="$ROOT" modules_install
depmod -b "$ROOT" "$release"
mkdir -p "$ROOT/boot" "$(dirname -- "$output")"
cp "$KERNEL/.config" "$ROOT/boot/config-$release"
cp "$KERNEL/arch/arm64/boot/Image" "$ROOT/boot/Image-$release"
cp "$WORK/inputs.sha256" "$ROOT/etc/krane-inputs.sha256"
printf '%s\n' "$release" > "$ROOT/etc/krane-kernel-release"
stage=$(mktemp -d "$WORK/image.XXXXXXXX")
trap 'echo "Image staging retained at $stage"' EXIT
bash "$PROJECT/scripts/pack-kernel.sh" "$stage"
cd "$stage"
# Build partition content as files; no physical block devices or loop mounts.
sectors=$((12 * 1024 * 1024 * 1024 / 512))
root_start=139264
root_sectors=$((sectors - root_start - 33))
truncate -s "$((sectors * 512))" disk.img
bash "$PROJECT/scripts/partition.sh" disk.img
root_uuid=$(cgpt show -i 3 -u disk.img)
printf 'PARTUUID=%s / ext4 defaults,noatime 0 1\n' "$root_uuid" > "$ROOT/etc/fstab"
if [[ "$KERNEL_PROFILE" == fedora ]]; then
    install -Dm644 "$PROJECT/docs/install-fedora-emmc.md" \
        "$ROOT/usr/share/doc/linuxonduet/install-fedora-emmc.md"
    chroot "$ROOT" /bin/bash -s < "$PROJECT/scripts/check-fedora-password.sh"
    python3 "$PROJECT/scripts/check-fedora-runtime.py" "$ROOT" "$KERNEL/.config"
    # Label after all files (including modules and fstab) have been installed.
    # mkfs.ext4 -d preserves the resulting security.selinux extended attributes.
    grep -qx CONFIG_SECURITY_SELINUX=y "$KERNEL/.config"
    chroot "$ROOT" /usr/sbin/setfiles -F \
        /etc/selinux/targeted/contexts/files/file_contexts /
fi
root_blocks=$((root_sectors / 8))
truncate -s "$((root_blocks * 4096))" root.ext4
mkfs.ext4 -F -L KraneRoot -m 0 -d "$ROOT" root.ext4
e2fsck -fn root.ext4
dd if=kernel-A.bin of=disk.img bs=512 seek=8192 conv=notrunc status=none
dd if=kernel-B.bin of=disk.img bs=512 seek=73728 conv=notrunc status=none
dd if=root.ext4 of=disk.img bs=4M seek=71303168 oflag=seek_bytes conv=notrunc,sparse status=progress
cgpt show disk.img > partitions.txt
# noclobber prevents replacing an output created while the build was running.
(set -o noclobber; : > "$output")
cp --sparse=always disk.img "$output"
sha256sum "$output" > "$output.sha256"
cp partitions.txt "$output.partitions.txt"
cp "$ROOT/etc/krane-package-manifest.txt" "$output.packages.txt"
echo "Created $output"
