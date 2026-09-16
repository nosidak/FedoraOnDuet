"""Check actual generated FIT mappings with device-tree tools."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/generate-fit.sh'

class FitMapping(unittest.TestCase):
    def test_each_panel_variant_maps_to_its_own_device_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            kernel = root / 'Image'
            kernel.write_bytes(b'kernel fixture')
            dtbs = []
            for sku in (0, 176):
                source = root / f'{sku}.dts'
                source.write_text('/dts-v1/; / { compatible = '
                                  f'"google,krane-sku{sku}", "google,krane"; }};')
                dtb = root / f'{sku}.dtb'
                subprocess.run(['dtc', '-I', 'dts', '-O', 'dtb', '-o', str(dtb), str(source)], check=True)
                dtbs.append(dtb)
            result = subprocess.run(['bash', str(SCRIPT), str(kernel), 'arm64', 'none'],
                                    input=' '.join(map(str, dtbs)) + '\n', text=True,
                                    capture_output=True, check=True)
            its = root / 'kernel.its'
            its.write_text(result.stdout)
            fit = root / 'kernel.fit'
            subprocess.run(['mkimage', '-f', str(its), str(fit)], check=True, capture_output=True)
            for number, expected in ((1, 'google,krane-sku0 google,krane'),
                                     (2, 'google,krane-sku176 google,krane')):
                node = f'/configurations/conf-{number}'
                compatible = subprocess.check_output(['fdtget', str(fit), node, 'compatible'], text=True).strip()
                self.assertEqual(compatible, expected)
                fdt = subprocess.check_output(['fdtget', str(fit), node, 'fdt'], text=True).strip()
                self.assertEqual(fdt, f'fdt-{number}')

if __name__ == '__main__':
    unittest.main()
