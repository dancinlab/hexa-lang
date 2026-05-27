# source this script (don't exec)
export BETE_NET_ROOT=~/local/bete-net/BETE-NET
source ~/local/bete-net/venv/bin/activate
python3 -c "
import sys
try:
    import torch, torch_geometric, e3nn, ase
    print(f'[OK] torch={torch.__version__} torch_geometric={torch_geometric.__version__}')
except ImportError as e:
    print(f'[FAIL] {e}', file=sys.stderr); sys.exit(1)
"
