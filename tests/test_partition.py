import pathlib
import struct
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/partition.sh'


class PartitionLayout(unittest.TestCase):
    def test_linux_can_identify_gpt_and_root_partition(self):
        with tempfile.TemporaryDirectory() as directory:
            disk = pathlib.Path(directory) / 'test.img'
            with disk.open('wb') as f:
                f.truncate(128 * 1024 * 1024)
            subprocess.run(['bash', str(SCRIPT), str(disk)], check=True, capture_output=True)
            with disk.open('rb') as f:
                mbr = f.read(512)
                self.assertEqual(mbr[510:512], b'\x55\xaa')
                self.assertEqual(mbr[450], 0xee)
                f.seek(1024 + 2 * 128 + 32)
                self.assertEqual(struct.unpack('<Q', f.read(8))[0], 139264)
            output = subprocess.check_output(['parted', '-sm', str(disk), 'unit', 's', 'print'], text=True)
            self.assertIn(':gpt:', output)
            self.assertIn('3:139264s:', output)
