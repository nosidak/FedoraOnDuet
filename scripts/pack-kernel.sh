#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
: "${WORK:?Set WORK}"
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
stage=${1:?Empty output directory required}
mkdir -p "$stage"
cp "$KERNEL/arch/arm64/boot/dts/mediatek/mt8183-kukui-krane-"*.dtb "$stage/"
cd "$stage"
if [[ "$COMPRESSION" == lzma ]]; then
    xz --format=lzma --stdout "$KERNEL/arch/arm64/boot/Image" > Image.lzma
else
    lz4 -z --best "$KERNEL/arch/arm64/boot/Image" Image.lz4
fi
printf '%s\n' "$stage/mt8183-kukui-krane-sku0.dtb $stage/mt8183-kukui-krane-sku176.dtb" | \
    bash "$PROJECT/scripts/generate-fit.sh" "$stage/Image.$COMPRESSION" arm64 "$COMPRESSION" > kernel.its
mkimage -D '-I dts -O dtb -p 2048' -f kernel.its kernel.fit
dd if=/dev/zero of=bootloader.bin bs=512 count=1 status=none
for slot in A B; do
    offset=2
    [[ "$slot" == B ]] && offset=1
    printf 'console=ttyS0,115200 console=tty1 rootwait rw root=PARTUUID=%%U/PARTNROFF=%s\n' "$offset" > cmdline
    vbutil_kernel --pack "kernel-$slot.bin" --version 1 --vmlinuz kernel.fit --arch arm \
        --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
        --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
        --config cmdline --bootloader bootloader.bin
    vbutil_kernel --verify "kernel-$slot.bin" --signpubkey /usr/share/vboot/devkeys/kernel_subkey.vbpubk
    [[ $(stat -c %s "kernel-$slot.bin") -le 33554432 ]] || { echo 'Kernel partition overflow' >&2; exit 1; }
done
