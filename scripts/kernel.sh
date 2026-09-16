#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
mkdir -p "$WORK/src" "$WORK/logs"
[[ -f "$WORK/cache/linux-$VERSION.tar.xz" ]] || { echo 'Download pinned source first' >&2; exit 1; }
fingerprint=$(sha256sum "$BASE_CONFIG" "${PATCHES[@]}" \
    "$PROJECT/scripts/kernel.sh" "$PROJECT/scripts/profile.sh" | sha256sum | cut -d ' ' -f 1)
python3 "$PROJECT/scripts/kernel-cache.py" "$KERNEL" "$fingerprint"
if [[ ! -d "$KERNEL" ]]; then
    tar -xJf "$WORK/cache/linux-$VERSION.tar.xz" -C "$WORK/src"
fi
cd "$KERNEL"
if [[ ! -f .krane-patched ]]; then
    for change in "${PATCHES[@]}"; do
        patch --dry-run --fuzz=0 -p1 < "$change"
        patch --fuzz=0 -p1 < "$change"
    done
    touch .krane-patched
fi
if [[ ! -f .krane-configured ]]; then
    cp "$BASE_CONFIG" .config
    scripts/config --set-str LOCALVERSION "$LOCAL_VERSION" --disable LOCALVERSION_AUTO \
        --disable DEBUG_INFO --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
        --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --disable DEBUG_INFO_DWARF4 \
        --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_SPLIT \
        --enable IKCONFIG --enable IKCONFIG_PROC --enable ZRAM --enable ZSMALLOC
    if [[ "$KERNEL_PROFILE" == fedora ]]; then
        # Krane uses C drivers. Avoid the unrelated Rust toolchain requirement.
        # We boot USB directly without an initramfs, so storage must be built in.
        scripts/config --disable RUST --enable USB_STORAGE --enable USB_UAS \
            --enable CROS_EC_TYPEC --enable TYPEC_DP_ALTMODE
    fi
    if [[ "$KERNEL_PROFILE" == fedora ]]; then
        # Fedora ships Qualcomm Wi-Fi/Bluetooth firmware compressed with XZ.
        scripts/config --enable FW_LOADER_COMPRESS --enable FW_LOADER_COMPRESS_XZ
        scripts/config --enable AUDIT --enable SECURITY --enable SECURITYFS \
            --enable SECURITY_NETWORK --enable SECURITY_SELINUX \
            --enable DEFAULT_SECURITY_SELINUX --enable EXT4_FS_SECURITY \
            --set-str DEFAULT_SECURITY selinux \
            --set-str LSM 'landlock,lockdown,yama,integrity,selinux,bpf'
    fi
    make ARCH=arm64 LLVM=1 olddefconfig
    grep -qx CONFIG_DEBUG_INFO_NONE=y .config || { echo 'Debug information unexpectedly enabled' >&2; exit 1; }
    for required in DEVTMPFS DEVTMPFS_MOUNT SCSI BLK_DEV_SD USB_STORAGE \
        USB_XHCI_HCD USB_XHCI_MTK PHY_MTK_TPHY EXT4_FS; do
        grep -qx "CONFIG_${required}=y" .config || { echo "Missing built-in boot driver: $required" >&2; exit 1; }
    done
    touch .krane-configured
fi
printf '%s\n' "$fingerprint" > .krane-inputs
make -j"${JOBS:-20}" ARCH=arm64 LLVM=1 Image modules \
    mediatek/mt8183-kukui-krane-sku0.dtb mediatek/mt8183-kukui-krane-sku176.dtb
make -s ARCH=arm64 LLVM=1 kernelrelease > "$WORK/kernelrelease"
