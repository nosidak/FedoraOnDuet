#!/usr/bin/env bash
# Runs inside the signed Fedora ARM64 base under QEMU.
set -euo pipefail
export LC_ALL=C
# Container defaults omit documentation and some language data. Install a normal
# systemd desktop explicitly, retaining Fedora package signature verification.
dnf -y --releasever=44 upgrade
dnf -y --releasever=44 install \
    systemd systemd-udev systemd-networkd systemd-resolved \
    fedora-release-kde plasma-desktop plasma-workspace plasma-nm plasma-pa bluedevil \
    powerdevil kscreen kinfocenter systemsettings dolphin konsole firefox sddm \
    plasma-keyboard qt6-qtvirtualkeyboard qt6-qtwayland xorg-x11-server-Xwayland \
    NetworkManager NetworkManager-wifi pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
    alsa-utils alsa-ucm linux-firmware mesa-dri-drivers mesa-vulkan-drivers \
    sudo nano zram-generator glibc-langpack-en langpacks-en \
    selinux-policy-targeted policycoreutils audit shadow-utils passwd cracklib-dicts \
    kbd tzdata e2fsprogs util-linux firewalld chrony rsync gdisk cloud-utils-growpart
if rpm -q fedora-release-container >/dev/null 2>&1; then
    dnf -y --releasever=44 swap --allowerasing \
        fedora-release-container fedora-release-identity-kde-desktop
fi
cat > /etc/chrony.conf <<'EOF'
# Correct even a wildly inaccurate RTC once the first network is available.
pool 2.fedora.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
systemctl enable NetworkManager sddm firewalld chronyd
systemctl set-default graphical.target
systemctl disable systemd-networkd systemd-resolved sshd 2>/dev/null || true
mkdir -p /etc/sddm.conf.d /etc/sudoers.d /etc/NetworkManager/conf.d
cat > /etc/sddm.conf.d/10-krane.conf <<'EOF'
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
[Users]
RememberLastSession=true
EOF
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = lzo
EOF
printf '[main]\ndns=default\n' > /etc/NetworkManager/conf.d/10-dns.conf
echo krane > /etc/hostname
echo LANG=en_AU.UTF-8 > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
if ! id duet >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,input -s /bin/bash duet
    echo 'duet:changeme' | chpasswd
    chage -d 0 duet
fi
passwd -l root
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel
mkdir -p /home/duet/.config /var/lib/AccountsService/users
cat > /home/duet/.config/kwinrc <<'EOF'
[Wayland]
InputMethod[$e]=/usr/share/applications/org.kde.plasma.keyboard.desktop
VirtualKeyboardEnabled=true
EOF
chown -R duet:duet /home/duet/.config
cat > /var/lib/AccountsService/users/duet <<'EOF'
[User]
Session=plasma
XSession=plasma
SystemAccount=false
EOF
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
dnf clean all
rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > /etc/krane-package-manifest.txt
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
mkdir -p /var/lib/dbus
ln -s /etc/machine-id /var/lib/dbus/machine-id
