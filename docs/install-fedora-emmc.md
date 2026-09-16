# Install Fedora on the original Duet's eMMC

For **Lenovo Chromebook Duet MT8183 / kukui-krane only**. This replaces
ChromeOS and all local data on the selected internal disk. Back up your files
and prepare ChromeOS recovery media first. Keep Developer Mode enabled.

This procedure copies a working Fedora USB installation, including its user
password, settings and firmware repairs. It does not copy a mounted root
filesystem as a raw disk image. The external drive remains your fallback.
Partition setup, filesystem copying and kernel comparisons have been tested.
Final eMMC boot validation is pending.

## 1. Boot and check Fedora on USB

Download the new image and SHA-256 files from
[v0.2.1](https://github.com/nosidak/FedoraOnDuet/releases/tag/v0.2.1).
On Linux, from the download directory:

```bash
sha256sum -c krane-fedora-kde-v0.2.1.img.zst.sha256
zstd -d krane-fedora-kde-v0.2.1.img.zst
sha256sum -c krane-fedora-kde-v0.2.1.img.sha256
```

Use Rufus to write the extracted `.img` to a USB drive of at least 16 GB.
Use raw/DD mode if asked. Writing erases that USB. Cancel any Windows offer
to format its Linux partitions afterward.

With Developer Mode and external boot enabled, boot the USB using Ctrl+U.
First login: Ctrl+Alt+F3, user `duet`, password `changeme`; complete the password
change there, then reboot to sign into KDE. Check keyboard, display and Wi-Fi.
Connect Wi-Fi and confirm the date with `timedatectl` before using DNF.
If necessary, inspect `chronyc tracking`; do not bypass TLS verification.

The new image includes the migration tools.

An offline copy of this guide is included at
`/usr/share/doc/linuxonduet/install-fedora-emmc.md`.

For an older image, install the tools before leaving the desktop:

```bash
sudo dnf install rsync gdisk cloud-utils-growpart e2fsprogs
```

Finish all package transactions. Switch to Ctrl+Alt+F3, log in, then stop KDE:

```bash
sudo systemctl stop sddm
lsblk -o NAME,PATH,SIZE,MODEL,TYPE,FSTYPE,MOUNTPOINTS
findmnt -no SOURCE /
```

**Do not continue unless the devices match the following example exactly:**

| Purpose | Example device |
| --- | --- |
| External Fedora drive | `/dev/sda` |
| Running Fedora root | `/dev/sda3`, mounted at `/` |
| Internal eMMC | `/dev/mmcblk0`, about 116.5 GiB for the 128 GB model |

The external drive must have partitions 1 and 2 of 32 MiB each and partition
3 containing Fedora. Every eMMC partition must be unmounted, and no eMMC
partition may be used as swap (`swapon --show`). Disk names can change. If
anything differs, stop and resolve the source/target identities first.
Never write to `mtdblock0`, `mmcblk0boot0`, or `mmcblk0boot1`.

## 2. Replace the eMMC partition layout

**From here, the commands destroy ChromeOS on `/dev/mmcblk0`.** Run commands
one at a time; stop on any error. Keep power connected and do not reboot until
the final verification succeeds. `-o` is a hyphen and the letter o, not zero.

```bash
sudo sgdisk --replicate=/dev/mmcblk0 /dev/sda
sudo sgdisk --move-second-header --randomize-guids /dev/mmcblk0
sudo blockdev --rereadpt /dev/mmcblk0
sudo growpart /dev/mmcblk0 3
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

Check that eMMC now has two 32 MiB boot partitions and a third partition
occupying the remaining space, all unmounted. Fedora must still be running
from `/dev/sda3`. Randomized GUIDs prevent confusion with the external disk.

## 3. Create and copy the root filesystem

```bash
sudo mkfs.ext4 -L FedoraRoot -m 0 /dev/mmcblk0p3
sudo mkdir -p /mnt/emmc
sudo mount /dev/mmcblk0p3 /mnt/emmc
findmnt -no SOURCE --target /mnt/emmc
```

The last command **must print `/dev/mmcblk0p3`**. If mounting fails, do not
run rsync: it could fill the external root instead.

```bash
sudo rsync -aHAXx --numeric-ids --info=progress2 --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found' / /mnt/emmc/
echo $?
```

Wait for the prompt. The exit code must be **0**. The options preserve hard
links, permissions, numeric ownership, ACLs and extended attributes (including
SELinux labels). `-x` prevents copying mounted virtual filesystems. Every
`--exclude` above includes an equals sign. Do not run applications, updates or
other writes while copying. If rsync reports vanished/changing files, finish
or stop the application involved and rerun the same copy until it succeeds.
Do not format again when retrying rsync.

## 4. Copy the signed kernels and update fstab

Only these small, static boot partitions are copied with dd:

```bash
sudo dd if=/dev/sda1 of=/dev/mmcblk0p1 bs=4M conv=fsync status=progress
sudo dd if=/dev/sda2 of=/dev/mmcblk0p2 bs=4M conv=fsync status=progress
sudo cmp /dev/sda1 /dev/mmcblk0p1
echo $?
sudo cmp /dev/sda2 /dev/mmcblk0p2
echo $?
```

Each dd must copy 33,554,432 bytes (32 MiB). Each cmp must print nothing and
return 0. The capital **M** in `4M` matters. These kernels locate partition 3
relative to their own boot slot, so no bootloader installation is needed.

For the project's standard image, fstab has only one root entry. If you added
other disks or filesystem entries, preserve those instead of replacing fstab
with the single-root command below.

```bash
sudo cp /mnt/emmc/etc/fstab /mnt/emmc/etc/fstab.usb-backup
sudo sh -c 'printf "UUID=%s / ext4 defaults,noatime 0 1\n" "$(blkid -s UUID -o value /dev/mmcblk0p3)" > /mnt/emmc/etc/fstab'
cat /mnt/emmc/etc/fstab
sudo blkid /dev/mmcblk0p3
```

Check that fstab's nonempty `UUID=` exactly matches blkid's **filesystem UUID**,
not its PARTUUID. The command starts and ends with a single quote around the
shell script. A `>` continuation prompt means a quote is unfinished: Ctrl+C
and re-enter the command. Do not rerun rsync after editing fstab, since it would
restore the external drive's entry.

## 5. Verify and boot internally

```bash
sudo chroot /mnt/emmc restorecon /etc/fstab
sudo sgdisk --verify /dev/mmcblk0
sync
sudo umount /mnt/emmc
sudo e2fsck -fn /dev/mmcblk0p3
echo $?
```

Unmount must succeed before e2fsck. Require a clean filesystem check (exit 0)
and no GPT problems. Stop and investigate any failure rather than powering off.
Then:

```bash
sudo poweroff
```

After the machine is completely off, disconnect the external drive. Power on
and choose **Boot from internal disk**, or Ctrl+D at the Developer Mode screen.
Do **not** re-enable OS verification.

After Fedora starts:

```bash
findmnt -no SOURCE /
df -h /
timedatectl
```

The root source must be `/dev/mmcblk0p3`, with the expanded capacity. Test Wi-Fi
and let time synchronize online. If internal boot fails, reconnect the original
external drive and boot it with Ctrl+U to inspect the eMMC installation.

Normal `dnf upgrade` does not update this project's signed Chromebook kernel
slots. Use project kernel/image releases for those updates; don't assume a
generic Fedora kernel installation changes the kernel being booted.

References: [sgdisk](https://manpages.debian.org/testing/gdisk/sgdisk.8.en.html),
[rsync](https://rsync.samba.org/ftp/rsync/rsync.1),
[Chromium Developer Mode](https://www.chromium.org/chromium-os/developer-library/guides/device/developer-mode/).
