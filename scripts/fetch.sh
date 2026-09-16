#!/usr/bin/env bash
set -euo pipefail
PROJECT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=profile.sh
source "$PROJECT/scripts/profile.sh"
mkdir -p "$WORK/cache" "$WORK/src" "$WORK/gnupg" "$WORK/logs"
chmod 700 "$WORK/gnupg"
cd "$WORK/cache"
fetch() {
    local name=$1 url=$2
    if [[ ! -f "$name" ]]; then
        curl -fL --retry 3 -o "$name.part" "$url"
        mv "$name.part" "$name"
    fi
}
fetch "linux-$VERSION.tar.xz" "https://cdn.kernel.org/pub/linux/kernel/v${VERSION%%.*}.x/linux-$VERSION.tar.xz"
echo '6ca338fd2f9d2224b9187ba1cad18c05417c0504771917203a023467a8ac3a34e346bd3bc5a3f5716aa9810381a28c730ea5fc3726773dca36d75a4677178b13  linux-7.2.2.tar.xz' | sha512sum -c -
(cd "$PROJECT/config/mt81" && sha512sum -c SHA512SUMS)
base=Fedora-Container-Base-Generic-44-1.7.aarch64.oci.tar.xz
url=https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Container/aarch64/images
fetch "$base" "$url/$base"
fetch Fedora-Container-44-1.7-aarch64-CHECKSUM "$url/Fedora-Container-44-1.7-aarch64-CHECKSUM"
fetch fedora.pgp https://fedoraproject.org/fedora.pgp
gpg --homedir "$WORK/gnupg" --import fedora.pgp
# Use only the pinned Fedora 44 signing key, not every imported release key.
gpg --homedir "$WORK/gnupg" --export 36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6 > "$WORK/fedora44.gpg"
gpgv --keyring "$WORK/fedora44.gpg" Fedora-Container-44-1.7-aarch64-CHECKSUM
grep "^SHA256 ($base) = " Fedora-Container-44-1.7-aarch64-CHECKSUM > "$WORK/fedora-base.checksum"
sha256sum -c "$WORK/fedora-base.checksum"
if [[ ! -d "$WORK/src/firmware/.git" ]]; then
    git clone https://github.com/CadmiumLinux/firmware.git "$WORK/src/firmware"
fi
git -C "$WORK/src/firmware" checkout --detach af0ed4e25416b576285eed48128a39a17e460e4c
sha256sum "linux-$VERSION.tar.xz" "$base" > "$WORK/inputs.sha256"
sha256sum "$BASE_CONFIG" "${PATCHES[@]}" >> "$WORK/inputs.sha256"
