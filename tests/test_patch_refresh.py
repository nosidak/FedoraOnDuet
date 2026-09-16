import pathlib
import unittest

PATCHES = pathlib.Path(__file__).resolve().parents[1] / 'patches/mt81'


class BluetoothRefresh(unittest.TestCase):
    def test_refresh_preserves_every_upstream_code_change(self):
        original = PATCHES / 'mt8183-fix-bluetooth.patch'
        refreshed = PATCHES / 'mt8183-fix-bluetooth-linux-7.2.2.patch'
        self.assertTrue(refreshed.is_file(), '7.2.2 context refresh is missing')
        def changes(path):
            return [line for line in path.read_text().splitlines()
                    if line.startswith(('+', '-')) and not line.startswith(('+++', '---'))]
        self.assertEqual(changes(refreshed), changes(original))
