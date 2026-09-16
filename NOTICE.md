# Credits and licenses

FedoraOnDuet is an independent Fedora KDE image for the original Lenovo
Chromebook Duet (MT8183, kukui-krane). It is not an official release of any
upstream project.

## postmarketOS

The MediaTek MT81 kernel configuration and patches come from
[postmarketOS pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/a7da727b274458ba2818368df1cba3dd4ca4634a/device/community/linux-postmarketos-mediatek-mt81),
revision `a7da727b274458ba2818368df1cba3dd4ca4634a`.
The package lists WeirdTreeThing as maintainer and Alicja Michalska and Ingo
Reitz as co-maintainers. Credit also belongs to the individual patch authors
whose original headers are preserved.

The original APKBUILD, kernel configuration, seven patches and published
SHA-512 checksums are retained under `config/mt81` and `patches/mt81`.
The package declares GPL-2.0-only. This builder applies the MT8183 Bluetooth
and MediaTek power-domain patches. The other patches are upstream references.
The Bluetooth copy ending in `linux-7.2.2.patch` refreshes surrounding context
for newer UART locking assertions and a const termios argument; the patch's
added and removed code is unchanged.

Local configuration changes enable direct USB root boot, SELinux and
XZ-compressed firmware support, and disable Rust and kernel debug information.
See `scripts/kernel.sh` for the complete configuration changes.

## Cadmium and boot tooling

[Cadmium](https://github.com/Maccraft123/Cadmium), revision
`e85528eeea8a2587918905420740425c27fc4d7a`, provides the reference FIT generator,
Depthcharge partition layout and vboot invocation. Its tooling is GPL-3.0;
see LICENSE and the source headers. The FIT generator retains its earlier
Arch Linux ARM upstream attribution; that credit describes the tool's origin.
ChromiumOS vboot tools supply the development signing keys used by the builder.

## Firmware

[CadmiumLinux/firmware](https://github.com/CadmiumLinux/firmware), revision
`af0ed4e25416b576285eed48128a39a17e460e4c`, supplies the MT8183 SCP firmware.
Firmware retains its separate upstream licenses; the SCP license is installed
alongside its binary. Other firmware is installed from Fedora packages with
their accompanying licenses.

## Linux, Fedora and desktop packages

[Linux](https://kernel.org/) 7.2.2 retains GPL-2.0-only and its per-file licenses.
The builder verifies the source archive against the pinned SHA-512 checksum.

The Fedora bootstrap is
[Fedora 44 ARM64 Generic Container 44-1.7](https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Container/aarch64/images/).
Its signed checksum is verified with Fedora's release key fingerprint
`36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6`, published on the
[Fedora security page](https://fedoraproject.org/security/).
Fedora, KDE Plasma, Mesa, ALSA, NetworkManager and all other installed packages
retain their respective licenses. Consult the release package manifest and
the license files installed in the image.

GPL-3.0 covers this repository's build tooling; it does not replace the
licenses of the kernel, firmware, patches or distribution packages.
