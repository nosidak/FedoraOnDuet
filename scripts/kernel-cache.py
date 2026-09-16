#!/usr/bin/env python3
"""Preserve stale kernel trees and make changed inputs trigger a fresh build."""
import pathlib
import re
import sys
import tempfile

tree = pathlib.Path(sys.argv[1])
fingerprint = sys.argv[2]
if not re.fullmatch(r'[0-9a-f]{64}', fingerprint):
    raise SystemExit('Invalid kernel input fingerprint')
if tree.is_symlink():
    raise SystemExit('Refuse a symlink kernel source directory')
if tree.exists():
    stamp = tree / '.krane-inputs'
    if not stamp.is_file() or stamp.read_text().strip() != fingerprint:
        archive = pathlib.Path(tempfile.mkdtemp(prefix=tree.name + '-previous-', dir=tree.parent))
        tree.rename(archive / 'source')
        print(f'Kernel inputs changed; previous source preserved in {archive}/source')
