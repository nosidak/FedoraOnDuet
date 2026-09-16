# Fedora KDE on Krane

This variant uses Fedora 44 ARM64 with KDE Plasma Wayland and the MT81 Krane
kernel. It is an independent device image, not an official Fedora hardware
release.

## v0.2.1 firmware and time-sync release

Current artifact: `out/krane-fedora-kde-v0.2.1.img.zst`, 12 GiB expanded.
Download it from [v0.2.1](https://github.com/nosidak/FedoraOnDuet/releases/tag/v0.2.1).
Follow [USB boot and eMMC installation](install-fedora-emmc.md) for installation.

- Enables `CONFIG_FW_LOADER_COMPRESS_XZ=y` for Fedora's compressed Qualcomm
  QCA6174 SDIO Wi-Fi and QCA Bluetooth firmware, including firmware updates.
- Explicitly installs and enables Chrony with an NTP pool, iburst,
  `makestep 1.0 3` and `rtcsync`. Network access is required for synchronization.
- Retains `cracklib-dicts` and the first-login password regression check.
- Includes rsync, gdisk, growpart and e2fsprogs for the documented migration.
- Adds a pre-image guard for kernel XZ support, required firmware integrity,
  Chrony configuration, executable and service enablement.
- Updates Fedora packages through its signature-verified repositories. The
  attached package manifest records the actual versions in this release.

The tests reproduce the original firmware/time-service omissions and reject
corrupt firmware and broken Chrony enablement. The builder tests and ShellCheck cover the Fedora build scripts.

The underlying system passed GPT CRC checks, both boot signatures (9,883,648
bytes each), ext4 checks, both panel DTBs, SELinux labels, password quality
checks, and verification of firmware and Chrony. Version 0.2.1 updates only
the offline guide for this repository. Its GPT and signed boot partitions are
byte-identical to the verified image, and its updated ext4 filesystem passes
e2fsck. Kernel and installed packages are unchanged. The raw image SHA-256 is:
`0a6da2784f92a9ea2be059b823e135d1139388c9b57185fdb837c663d26c2cda`.
The release includes the verification report and separate raw/compressed hashes.

## Build inputs

- Base: Fedora-Container-Base-Generic-44-1.7.aarch64.oci.tar.xz.
- The Fedora 44 signed checksum is verified with fingerprint
  `36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6`.
- The OCI manifest, configuration, and single rootfs layer are hash checked.
- Linux 7.2.2 with the pinned postmarketOS MT81 configuration and the MT8183
  Bluetooth and MediaTek power-domain patches credited in NOTICE.md.
- Local kernel release: `7.2.2-krane-fedora`; both Krane panel DTBs, LZMA FIT,
  built-in USB/ext4 root drivers, and SELinux enabled in the kernel.
- Native WSL build directory: `~/fedora/linuxonduet`.

Fedora's container image is only the starting filesystem. DNF installs the
systemd desktop and replaces the container identity with Fedora KDE's identity.
Package signature verification remains enabled. The live Fedora 44 repositories
make package selection time dependent: the emitted package manifest records
this build, but does not make future builds byte-for-byte reproducible.

## Desktop configuration

Consult the release package manifest for installed versions. The image includes
SDDM, NetworkManager, PipeWire/WirePlumber, Plasma Keyboard, BlueDevil, firmware,
and ALSA UCM profiles. The Krane SCP firmware and its license are also installed.

The local user is `duet`, with initial password `changeme` and a required password
change. Root is locked. Automatic login and SSH are disabled. The locale is
Australian English and the timezone is Australia/Sydney. ZRAM uses half of RAM.
NetworkManager, SDDM, firewalld and (from v0.2.1) Chrony are enabled. SELinux is configured enforcing;
its filesystem labels are applied after module installation and fstab generation.

Fedora updates do not replace the custom Krane kernel in the signed boot slots.
Rebuild this image to update its kernel during device bring-up.

## Hardware acceptance

No USB drive or internal storage is written by the builder. Hardware testing confirmed
KDE boot, login and Wi-Fi after manual firmware extraction on the earlier image.
The rebuilt kernel and automatic synchronization still need a physical retest.
Final eMMC boot and Bluetooth operation have not been confirmed.
Use a USB drive of at least 16 GB and check Plasma
startup, touch, detachable keyboard, Panfrost rendering, Wi-Fi, Bluetooth, audio,
rotation, suspend/resume, and the on-screen keyboard. Host verification alone
does not establish working hardware support.
