#!/bin/bash
# Build BETE-NET venv with all deps.
set -e
VENV_DIR=~/local/bete-net/venv
BETE_ROOT=~/local/bete-net/BETE-NET
[ -d "$BETE_ROOT" ] || { echo "[ERROR] $BETE_ROOT missing — run git clone first"; exit 1; }
[ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install torch torch_geometric torch_scatter torch_cluster e3nn ase pymatgen || {
  echo "[ERROR] pip install failed — see README.md 'Known issues' for arm64 troubleshooting"
  exit 2
}
echo "[setup] venv ready at $VENV_DIR · BETE-NET at $BETE_ROOT"
