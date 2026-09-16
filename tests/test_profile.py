import os
import pathlib
import subprocess
import tempfile
import unittest

PROJECT = pathlib.Path(__file__).resolve().parents[1]


class Profiles(unittest.TestCase):
    def profile(self, name):
        env = {**os.environ, 'PROJECT': str(PROJECT), 'KERNEL_PROFILE': name}
        env.pop('WORK', None)
        return subprocess.run(
            ['bash', '-ec', 'source "$PROJECT/scripts/profile.sh"; printf "%s\\n" "$VERSION" "$WORK" "$COMPRESSION"'],
            env=env, text=True, capture_output=True)

    def test_default_is_fedora(self):
        result = self.profile('')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         ['7.2.2', str(pathlib.Path.home() / 'fedora/linuxonduet'), 'lzma'])

    def test_unknown_profile_is_rejected(self):
        result = self.profile('typo')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unknown kernel profile', result.stderr)

    def test_fedora_uses_isolated_work_and_mt81_boot(self):
        result = self.profile('fedora')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         ['7.2.2', str(pathlib.Path.home() / 'fedora/linuxonduet'), 'lzma'])

    def test_rejects_work_with_another_distribution(self):
        for profile, existing_id in [('fedora', 'other-distro')]:
            with self.subTest(profile=profile), tempfile.TemporaryDirectory() as work:
                etc = pathlib.Path(work) / 'rootfs/etc'
                etc.mkdir(parents=True)
                (etc / 'os-release').write_text(f'ID={existing_id}\n')
                result = subprocess.run(
                    ['bash', '-ec', 'source "$PROJECT/scripts/profile.sh"'],
                    env={**os.environ, 'PROJECT': str(PROJECT), 'WORK': work,
                         'KERNEL_PROFILE': profile}, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('another distribution', result.stderr)
