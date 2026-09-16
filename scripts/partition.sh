#!/usr/bin/env bash
# Partition a newly allocated regular image file, never a physical device.
set -euo pipefail
disk=${1:?image required}
[[ -f "$disk" && ! -L "$disk" ]] || { echo 'Refuse non-regular image' >&2; exit 1; }
bytes=$(stat -c %s "$disk")
((bytes % 512 == 0 && bytes > 139298 * 512)) || { echo 'Invalid image size' >&2; exit 1; }
sectors=$((bytes / 512))
cgpt create "$disk"
cgpt boot -p "$disk"
cgpt add -i 1 -t kernel -b 8192 -s 65536 -l KraneKernelA -S 1 -T 0 -P 10 "$disk"
cgpt add -i 2 -t kernel -b 73728 -s 65536 -l KraneKernelB -S 0 -T 0 -P 0 "$disk"
cgpt add -i 3 -t data -b 139264 -s "$((sectors - 139264 - 33))" -l KraneRoot "$disk"
