import importlib.util
import lzma
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'fedora_runtime', Path(__file__).resolve().parents[1] / 'scripts/check-fedora-runtime.py')
runtime = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime)


class FedoraRuntime(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / 'kernel.config'
        self.config.write_text('CONFIG_FW_LOADER_COMPRESS=y\nCONFIG_FW_LOADER_COMPRESS_XZ=y\n')
        for name in ('ath10k/QCA6174/hw3.0/firmware-sdio-6.bin',
                     'ath10k/QCA6174/hw3.0/board-2.bin',
                     'ath10k/QCA6174/hw3.0/board.bin',
                     'qca/rampatch_00440302.bin', 'qca/nvm_00440302.bin'):
            path = self.root / 'usr/lib/firmware' / (name + '.xz')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(lzma.compress(b'firmware payload'))
        enabled = self.root / 'etc/systemd/system/multi-user.target.wants/chronyd.service'
        enabled.parent.mkdir(parents=True)
        unit = self.root / 'usr/lib/systemd/system/chronyd.service'
        unit.parent.mkdir(parents=True)
        unit.write_text('[Service]\nExecStart=/usr/sbin/chronyd\n')
        enabled.symlink_to('/usr/lib/systemd/system/chronyd.service')
        executable = self.root / 'usr/sbin/chronyd'
        executable.parent.mkdir(parents=True)
        executable.touch()
        (self.root / 'etc/chrony.conf').write_text(
            'pool 2.fedora.pool.ntp.org iburst\nmakestep 1.0 3\nrtcsync\n')

    def test_accepts_readable_firmware_with_compatible_kernel_and_ntp(self):
        self.assertEqual(runtime.check(self.root, self.config), [])

    def test_rejects_original_kernel_without_xz_support(self):
        self.config.write_text('CONFIG_FW_LOADER_COMPRESS=y\n# CONFIG_FW_LOADER_COMPRESS_XZ is not set\n')
        self.assertIn('Kernel must enable CONFIG_FW_LOADER_COMPRESS_XZ=y',
                      runtime.check(self.root, self.config))

    def test_rejects_corrupt_wifi_firmware(self):
        path = self.root / 'usr/lib/firmware/ath10k/QCA6174/hw3.0/firmware-sdio-6.bin.xz'
        path.write_bytes(b'not an xz archive')
        self.assertTrue(any('Invalid XZ firmware' in error
                            for error in runtime.check(self.root, self.config)))

    def test_rejects_missing_time_service(self):
        (self.root / 'etc/systemd/system/multi-user.target.wants/chronyd.service').unlink()
        self.assertIn('chronyd.service is not enabled', runtime.check(self.root, self.config))

    def test_rejects_dangling_time_service_link(self):
        (self.root / 'usr/lib/systemd/system/chronyd.service').unlink()
        self.assertIn('chronyd.service enablement target is invalid',
                      runtime.check(self.root, self.config))

    def test_rejects_config_that_cannot_step_bad_initial_clock(self):
        (self.root / 'etc/chrony.conf').write_text('pool 2.fedora.pool.ntp.org iburst\nrtcsync\n')
        self.assertIn('Chrony must allow large initial clock corrections',
                      runtime.check(self.root, self.config))
