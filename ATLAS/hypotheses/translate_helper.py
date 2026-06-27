#!/usr/bin/env python3
"""Helper to check which files contain Korean text."""
import argparse
import os
import re

parser = argparse.ArgumentParser(description="Helper to check which files contain Korean text.")
parser.add_argument("hypothesis_dir", help="Path to the hypotheses directory")
args = parser.parse_args()

hypothesis_dir = args.hypothesis_dir
pattern = re.compile(r'[가-힣]')

files = sorted(os.listdir(hypothesis_dir))
target_files = [f for f in files if re.match(r'^0[01][0-9]-|^1[0-9][0-9]-', f) and f.endswith('.md')]

for fname in target_files:
    fpath = os.path.join(hypothesis_dir, fname)
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    has_korean = bool(pattern.search(content))
    print(f"{'[KO]' if has_korean else '[EN]'} {fname}")