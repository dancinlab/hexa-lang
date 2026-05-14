#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════
# PROMOTION.tape — raw-rule promotion milestones
#
# The full hash-chained log lives in ~/core/hexa-lang/.raw-audit/
# (DESIGN ledger — .PRESERVE-AS-SSOT inside `convergence/` dir).
# This tape is the milestone projection of major promotion landings.
# ══════════════════════════════════════════════════════════════

@D c1 := "promotion.atlas_bound_or_warn" :: promotion [d=2026-05-14 ok]
  text = "Every formula/constant not atlas-bound emits HX8003 warning / HX8004 error"
  proof = "compiler/intrinsics/intrinsics.hexa + atlas registration path"

@D c2 := "promotion.update_or_pr" :: promotion [d=2026-05-14 ok]
  text = "Verified contributions auto-register as new atlas L[*] nodes via promote.hexa"
  proof = ".raw-audit/ hash-chained entries"

@A raw_109_126_landing :: promotion [d=2026-04-30 ok]
  <- c1, c2
  => "raw 109..126 batch landing — cross-repo propagation arm (anima/airgenome/hive convergence)"

@A toolchain_post_fix :: promotion [d=2026-05-13 ok]
  <- raw_109_126_landing
  => "Toolchain post-fix: #12 use-graph flatten + RFC-020 A4 payload-enum codegen + fn-arena heapify-on-push + time_now_ms TAG_FN + bidi-stdio exec_stream_open/write/close_stdin + thread_channel_* rename"

@A bytes_to_str_raw_phase_2 :: promotion [d=2026-05-13 ok]
  <- toolchain_post_fix
  => "Phase 2 NUL-byte support in bytes_to_str_raw — unblocks wilson tool-image base64 collapse"
