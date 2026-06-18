#!/usr/bin/env python3
"""Helper to check which files contain Korean text."""
import os
import re

hypothesis_dir = "/Users/ghost/Dev/logout/docs/hypotheses"
pattern = re.compile(r'[가-힣]')

files = sorted(os.listdir(hypothesis_dir))
target_files = [f for f in files if re.match(r'^0[01][0-9]-|^1[0-9][0-9]-', f) and f.endswith('.md')]

for fname in target_files:
    fpath = os.path.join(hypothesis_dir, fname)
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    has_korean = bool(pattern.search(content))
    print(f"{'[KO]' if has_korean else '[EN]'} {fname}")