#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Adapted from Cadmium's generate_chromebook_its.sh, originally referencing
# archlinuxarm/PKGBUILDs/core/linux-aarch64/generate_chromebook_its.sh.
set -euo pipefail
image=${1:?}
arch=${2:?}
compression=${3:?}
read -r -a dtbs
cat <<EOF
/dts-v1/;
/ {
    description = "Krane Linux kernel";
    images {
        kernel {
            description = "Linux";
            data = /incbin/("$image");
            type = "kernel_noload";
            arch = "$arch";
            os = "linux";
            compression = "$compression";
            load = <0>;
            entry = <0>;
        };
EOF
for i in "${!dtbs[@]}"; do
    cat <<EOF
        fdt-$((i+1)) {
            description = "$(basename "${dtbs[i]}")";
            data = /incbin/("${dtbs[i]}");
            type = "flat_dt";
            arch = "$arch";
            compression = "none";
            hash { algo = "sha1"; };
        };
EOF
done
cat <<'EOF'
    };
    configurations {
        default = "conf-1";
EOF
for i in "${!dtbs[@]}"; do
    compat_line=''
    read -r -a compatible <<< "$(fdtget "${dtbs[i]}" / compatible)"
    for compat in "${compatible[@]}"; do compat_line+="\"$compat\","; done
    cat <<EOF
        conf-$((i+1)) {
            kernel = "kernel";
            fdt = "fdt-$((i+1))";
            compatible = ${compat_line%,};
        };
EOF
done
printf '    };\n};\n'
