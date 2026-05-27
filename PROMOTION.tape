#!/usr/bin/env tape
# PROMOTION.tape — promotion criteria (architecture SSOT)
#
# This .tape captures the current promotion-gate policy (what counts as
# "promoted"). Major promotion landings (toolchain post-fixes, stdlib
# module promotions) are appended to PROMOTION.log.tape.

@V := "tape" :: spec [active]
  version = "1.2"

@I id001 := "hexa-lang.promotion" :: identity-claim [d=2026-05-15 active]
  kind = "atlas promotion gate stack"
  brief = "stdlib / atlas promotion criteria — what must hold for a verified contribution to auto-register as an atlas L[*] node"
  parent = "dancinlab/hexa-lang"
  sibling-log = "PROMOTION.log.tape"

# ─── §Criteria ───────────────────────────────────────────────────────

@D c1 := "promotion.atlas_bound_or_warn" :: promotion [d=2026-05-14 ok]
  text = "Every formula/constant not atlas-bound emits HX8003 warning / HX8004 error"
  proof = "compiler/intrinsics/intrinsics.hexa + atlas registration path"

@D c2 := "promotion.update_or_pr" :: promotion [d=2026-05-14 ok]
  text = "Verified contributions auto-register as new atlas L[*] nodes via promote.hexa"
  proof = "compiler/discover/promote.hexa registration path"
