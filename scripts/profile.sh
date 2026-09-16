#!/usr/bin/env bash
# shellcheck disable=SC2034
export KERNEL_PROFILE=${KERNEL_PROFILE:-fedora}
[[ "$KERNEL_PROFILE" == fedora ]] || { echo "Unknown kernel profile: $KERNEL_PROFILE" >&2; exit 1; }
VERSION=7.2.2
WORK=${WORK:-$HOME/fedora/linuxonduet}
BASE_CONFIG="$PROJECT/config/mt81/config-postmarketos-mediatek-mt81.aarch64"
PATCHES=(
    "$PROJECT/patches/mt81/mt8183-fix-bluetooth-linux-7.2.2.patch"
    "$PROJECT/patches/mt81/mtk-pmdomain.patch"
)
COMPRESSION=lzma
LOCAL_VERSION=-krane-fedora
IMAGE_NAME=krane-fedora-kde.img
export WORK
KERNEL="$WORK/src/linux-$VERSION"
if [[ -f "$WORK/rootfs/etc/os-release" ]]; then
    grep -Eq '^ID="?fedora"?$' "$WORK/rootfs/etc/os-release" || {
        echo 'WORK contains another distribution; use a separate directory' >&2; exit 1;
    }
fi
if [[ -f "$WORK/kernelrelease" ]]; then
    case $(cat "$WORK/kernelrelease") in
        "$VERSION$LOCAL_VERSION") ;;
        *) echo 'WORK contains another kernel profile; use a separate directory' >&2; exit 1 ;;
    esac
fi
