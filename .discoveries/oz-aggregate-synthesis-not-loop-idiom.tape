@V := "tape" :: spec [active]
  version = "1.2"

#
# Discovery log — RUNTIME Tier-A.1 libc-unhook (extern reduction).
#   id     = oz-aggregate-synthesis-not-loop-idiom
#   seed   = "why do _bzero/_memcpy/_memset reappear as externs at -Oz
#             even with -fno-builtin-* and #define interception?"
#   group  = RUNTIME · Tier-A.1 · extern reduction
#   cycle  = 75 (2026-05-25 · HEAD 6617e7a4 + PR #988)
#   verdict-tier-target = 🔴 FALSIFIED (old mechanism)
#                         → 🔵 root-cause correction (closed-negative)
#
# Pre-registered falsifier:
#   if -Oz reintroduces bzero/memcpy via LOOP-IDIOM recognition on byte
#   loops, then -fno-builtin-bzero OR optnone OR `#pragma optimize off`
#   MUST suppress it.
#
# Old (documented) mechanism — FALSIFIED:
#   "clang -Oz folds byte loops to memset/bzero; -fno-builtin-bzero
#   can't stop it (loop-idiom recognition fires below the #define layer)"
#   → falsified: optnone / __attribute__((no_builtin)) /
#     `#pragma optimize off` ALL FAIL to suppress the libcall —
#     inconsistent with loop-idiom recognition (those flags DO gate it).
#
# Verified mechanism — root-cause correction:
#   -Oz does NOT run loop-idiom recognition on byte loops. The libcalls
#   are compiler-SYNTHESIZED aggregate ops:
#     `char buf[N] = {0}`  → bzero/memset  (aggregate zero-init)
#     `*dst = *src` struct → memcpy        (aggregate copy)
#   These have NO textual token, so `#define bzero hxlcl_bzero` can never
#   intercept them (the preprocessor sees no `bzero` call site).
#
# Verified source-only fix (future-proof; symbols already absent @ -Oz):
#   (a) `volatile size_t i` induction var in byte-loop primitives —
#       blocks the synthesis path across ALL -O levels.
#   (b) replace large caller-side aggregate idioms (`char buf[N]={0}`,
#       `*dst=*src`) with explicit `hxlcl_bzero(...)` / `hxlcl_memcpy(...)`.
#   source-only · no build-flag change · verified across all -O levels.
#
# Finding (closed-negative + ruled-out axis):
#   ruled out the entire BUILD-FLAG axis (-fno-builtin / optnone /
#   no_builtin / #pragma) as a fix for synthesized aggregate libcalls —
#   only SOURCE-level idiom replacement works.
#   At HEAD 6617e7a4 -Oz these symbols (_bzero _memcpy _memset _strcpy
#   _strncpy _memmove) are already ABSENT from nm; the fix is
#   future-proof hardening, low priority.
#
# Provenance:
#   measured = nm aprime_cc | grep ' U _' @ 6617e7a4 = 30 externs
#              (29 post-PR#988); no str/mem aggregate symbols present.
#   doc      = RUNTIME.md Tier-A.1 _bzero/_strncpy/_strcpy entries +
#              "Extern reconciliation @ 6617e7a4" subsection.
#   next     = if reachable C surface grows (step 2/3), re-audit
#              aggregate idioms; apply (a)/(b) to new byte-loop primitives.
#

@D oz_aggregate_synthesis := "synthesized aggregate ops, not loop-idiom, re-emit bzero/memcpy at -Oz" :: discovery [closed]
  dont = "trust -fno-builtin / optnone / no_builtin / #pragma to suppress synthesized aggregate libcalls"
  do   = "fix at source — volatile-induction byte loops + explicit hxlcl_bzero/hxlcl_memcpy for aggregates"
