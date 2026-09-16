#!/usr/bin/env bash
set -euo pipefail
check_output() {
    local path=${1:?output image path required} resolved
    if [[ -e "$path" || -L "$path" ]]; then
        echo "Refuse existing output: $path" >&2; return 1
    fi
    resolved=$(realpath -m -- "$path")
    case "$resolved" in
        /dev/*|/proc/*|/sys/*) echo 'Refuse device or virtual filesystem output' >&2; return 1 ;;
    esac
    [[ "$resolved" == *.img ]] || { echo 'Refuse output without .img suffix' >&2; return 1; }
}
if [[ ${1:-} == check-output ]]; then check_output "${2:?}"; exit; fi
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
output=${1:-$WORK/out/$IMAGE_NAME}
check_output "$output"
output=$(realpath -m -- "$output")
bash "$PROJECT/scripts/fetch.sh"
bash "$PROJECT/scripts/kernel.sh"
sudo env WORK="$WORK" KERNEL_PROFILE="$KERNEL_PROFILE" bash "$PROJECT/scripts/rootfs-fedora.sh"
sudo env WORK="$WORK" KERNEL_PROFILE="$KERNEL_PROFILE" bash "$PROJECT/scripts/image.sh" "$output"
