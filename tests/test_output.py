"""Catch accidental overwrites and device writes before privileged build work."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts' / 'build.sh'


class OutputSafety(unittest.TestCase):
    def check(self, path):
        return subprocess.run(['bash', str(SCRIPT), 'check-output', str(path)],
                              capture_output=True, text=True)

    def test_existing_file_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / 'old.img'
            target.write_bytes(b'keep me')
            result = self.check(target)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('refuse', result.stderr.lower())
            self.assertEqual(target.read_bytes(), b'keep me')

    def test_devices_are_rejected(self):
        result = self.check('/dev/null')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('refuse', result.stderr.lower())

    def test_dangling_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / 'link.img'
            target.symlink_to(pathlib.Path(directory) / 'missing')
            result = self.check(target)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('refuse', result.stderr.lower())
            self.assertFalse((pathlib.Path(directory) / 'missing').exists())

    def test_new_image_path_is_accepted_without_creating_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / 'new.img'
            result = self.check(target)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main()
