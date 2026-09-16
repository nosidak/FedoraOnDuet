#!/usr/bin/env python3
"""Check firmware loading and first-network time sync in a staged Fedora root."""
import lzma
from pathlib import Path
import posixpath
import sys


def check(root, config):
    errors = []
    settings = set(config.read_text().splitlines())
    for option in ('FW_LOADER_COMPRESS', 'FW_LOADER_COMPRESS_XZ'):
        if f'CONFIG_{option}=y' not in settings:
            errors.append(f'Kernel must enable CONFIG_{option}=y')
    firmware = root / 'usr/lib/firmware'
    for name in (
        'ath10k/QCA6174/hw3.0/firmware-sdio-6.bin',
        'ath10k/QCA6174/hw3.0/board-2.bin',
        'ath10k/QCA6174/hw3.0/board.bin',
        'qca/rampatch_00440302.bin',
        'qca/nvm_00440302.bin',
    ):
        path = firmware / (name + '.xz')
        if not path.is_file():
            errors.append(f'Missing Fedora firmware: {path}')
        else:
            try:
                if not lzma.decompress(path.read_bytes()):
                    errors.append(f'Empty firmware: {path}')
            except lzma.LZMAError:
                errors.append(f'Invalid XZ firmware: {path}')
    enabled = root / 'etc/systemd/system/multi-user.target.wants/chronyd.service'
    if not enabled.is_symlink():
        errors.append('chronyd.service is not enabled')
    else:
        target = posixpath.normpath(posixpath.join(
            '/etc/systemd/system/multi-user.target.wants', str(enabled.readlink())))
        if target != '/usr/lib/systemd/system/chronyd.service' or not (
                root / target.lstrip('/')).is_file():
            errors.append('chronyd.service enablement target is invalid')
    if not (root / 'usr/sbin/chronyd').is_file():
        errors.append('chronyd executable is missing')
    chrony = root / 'etc/chrony.conf'
    lines = chrony.read_text().splitlines() if chrony.exists() else []
    active = [line.strip() for line in lines if line.strip() and not line.lstrip().startswith('#')]
    if not any(line.startswith(('pool ', 'server ')) and 'iburst' in line.split() for line in active):
        errors.append('Chrony needs an NTP source with iburst')
    if 'makestep 1.0 3' not in active:
        errors.append('Chrony must allow large initial clock corrections')
    if 'rtcsync' not in active:
        errors.append('Chrony must synchronize the RTC')
    return errors


if __name__ == '__main__':
    failures = check(Path(sys.argv[1]), Path(sys.argv[2]))
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        sys.exit(1)
    print('Fedora compressed firmware and time-sync checks passed')
