#!/usr/bin/env python3
# CANONICAL PyPhi reference for the IIT Phi of a documented small system.
# PyPhi discrete-TPM IIT over the standard 3-node network (OR/AND/XOR), the
# documented example from Mayner et al. 2018 "PyPhi: A toolbox for integrated
# information theory" (PLoS Comput Biol; arXiv 1712.09644). Independent,
# published reference for IIT Phi on a tiny (n=3) system.
import os
os.environ['PYPHI_WELCOME_OFF'] = 'yes'

def main():
    import numpy as np
    import pyphi
    pyphi.config.PROGRESS_BARS = False
    pyphi.config.PARALLEL_CONCEPT_EVALUATION = False
    pyphi.config.PARALLEL_CUT_EVALUATION = False
    pyphi.config.PARALLEL_COMPLEX_EVALUATION = False

    network = pyphi.examples.basic_network()
    state = (1, 0, 0)
    print("=== CANONICAL PyPhi discrete-TPM IIT reference ===")
    print("network: pyphi.examples.basic_network() — 3-node OR/AND/XOR")
    print("state  :", state)
    print("TPM shape:", np.array(network.tpm).shape)

    subsystem = pyphi.Subsystem(network, state, (0, 1, 2))
    bigphi = pyphi.compute.phi(subsystem)
    print("subsystem big-Phi (compute.phi) =", bigphi)
    print("pyphi version:", pyphi.__version__)

if __name__ == '__main__':
    import multiprocessing as mp
    mp.freeze_support()
    main()
