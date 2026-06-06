#!/bin/bash
# ddp_rent_lib.sh — HEXA-DDP M2 multi-GPU rent helpers (WIP skeleton).
#
# Canonical, sourceable shim that parametrizes the vast/runpod rent path
# so a DDP dispatch can request num_gpus >= 2 ON ONE NODE (DDP needs 2+
# GPUs sharing a NUMA/NVLink fabric, not 2 separate single-GPU pods).
#
# WIP — body filled in subsequent commits.
