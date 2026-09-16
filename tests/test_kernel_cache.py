import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/kernel-cache.py'


class KernelCache(unittest.TestCase):
    def test_same_inputs_keep_the_compiled_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            tree = pathlib.Path(directory) / 'linux'
            tree.mkdir()
            (tree / '.krane-inputs').write_text('a' * 64 + '\n')
            (tree / 'built').write_text('keep')
            subprocess.run(['python3', str(SCRIPT), str(tree), 'a' * 64], check=True)
            self.assertEqual((tree / 'built').read_text(), 'keep')

    def test_changed_inputs_preserve_old_tree_but_force_a_fresh_build(self):
        with tempfile.TemporaryDirectory() as directory:
            tree = pathlib.Path(directory) / 'linux'
            tree.mkdir()
            (tree / '.krane-inputs').write_text('a' * 64 + '\n')
            (tree / 'built').write_text('old kernel')
            subprocess.run(['python3', str(SCRIPT), str(tree), 'b' * 64], check=True, capture_output=True)
            self.assertFalse(tree.exists())
            preserved = list(pathlib.Path(directory).glob('linux-previous-*/source/built'))
            self.assertEqual(len(preserved), 1)
            self.assertEqual(preserved[0].read_text(), 'old kernel')
