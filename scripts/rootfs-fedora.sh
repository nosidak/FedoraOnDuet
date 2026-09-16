#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root with WORK set' >&2; exit 1; }
: "${WORK:?Set WORK}"
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
[[ "$KERNEL_PROFILE" == fedora && "$WORK" == /home/*/linuxonduet ]] || exit 1
ROOT="$WORK/rootfs"
[[ -f "$WORK/fedora-base.checksum" ]] || { echo 'Run fetch.sh first' >&2; exit 1; }
(cd "$WORK/cache" && sha256sum -c "$WORK/fedora-base.checksum")
mkdir -p "$ROOT" "$WORK/oci" "$WORK/logs"
if findmnt -rn -o TARGET | grep -q "^$ROOT/"; then echo 'Rootfs has active mounts' >&2; exit 1; fi
rm -f "$ROOT/.configured"
if [[ ! -f "$ROOT/.extracted" ]]; then
    [[ -z $(ls -A "$ROOT") ]] || { echo 'Incomplete rootfs: inspect before retrying' >&2; exit 1; }
    tar -xJf "$WORK/cache/Fedora-Container-Base-Generic-44-1.7.aarch64.oci.tar.xz" -C "$WORK/oci"
    layer=$(python3 - "$WORK/oci" <<'PY'
import hashlib, json, pathlib, sys
base = pathlib.Path(sys.argv[1])
def blob(descriptor):
    algo, digest = descriptor['digest'].split(':')
    assert algo == 'sha256' and len(digest) == 64
    int(digest, 16)
    path = base / 'blobs' / algo / digest
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
    return path
index = json.loads((base / 'index.json').read_text())
assert len(index['manifests']) == 1
manifest = json.loads(blob(index['manifests'][0]).read_text())
config = json.loads(blob(manifest['config']).read_text())
assert config['architecture'] == 'arm64' and config['os'] == 'linux'
assert len(manifest['layers']) == 1, 'Only the pinned single-layer Fedora base is supported'
print(blob(manifest['layers'][0]))
PY
    )
    bsdtar --numeric-owner -xpf "$layer" -C "$ROOT"
    touch "$ROOT/.extracted"
fi
mounts=()
cleanup() {
    local status=$? index
    for ((index=${#mounts[@]}-1; index>=0; index--)); do
        umount -R "${mounts[index]}" || status=1
    done
    return "$status"
}
trap cleanup EXIT
mkdir -p "$ROOT"/{dev,proc,sys,run,tmp}
for fs in dev proc sys; do
    mount --rbind "/$fs" "$ROOT/$fs"
    mounts+=("$ROOT/$fs")
    mount --make-rslave "$ROOT/$fs"
done
mount -t tmpfs tmpfs "$ROOT/run"
mounts+=("$ROOT/run")
rm -f "$ROOT/etc/resolv.conf"
cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"
cp "$PROJECT/scripts/configure-fedora.sh" "$ROOT/tmp/configure-fedora.sh"
chroot "$ROOT" /bin/bash /tmp/configure-fedora.sh
rm "$ROOT/tmp/configure-fedora.sh"
mkdir -p "$ROOT/usr/lib/firmware/mediatek/mt8183"
cp "$WORK/src/firmware/mediatek/mt8183/"* "$ROOT/usr/lib/firmware/mediatek/mt8183/"
touch "$ROOT/.configured"
