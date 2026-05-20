#!/usr/bin/env tape
# IDENTITY.log.tape — append-only history sibling of IDENTITY.tape
# (per tape v1.2 architecture-vs-history split, AGENTS.tape @D g_arch_vs_log_split).
#
# Architecture-current @I identity claims live in IDENTITY.tape (editable,
# latest-wins per sub-kind). This file captures identity-related runtime
# events: per-build @I version stamps, succession events, supersede records.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §Log ────────────────────────────────────────────────────────────
# (Append @A/@T/@R/@K/@H/@?/@D::decision events below this line.)
