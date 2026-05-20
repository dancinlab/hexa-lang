# hexa-arch → hexa-lang handoff: rfc_006 Yosys §4 + booksim push + seam context

> **TRIAGED 2026-05-20**: handoff item ② processed in commit `97e6c9db` (`docs(inbox): rfc_006 yosys §4 rtlil handoff — already-landed no-op cycle`); §5 absorption iter PRs #145 / #149 / #158 / #166 also landed downstream

**Date:** 2026-05-19
**Source repo:** `~/core/hexa-arch/` (commit `c98a3af`, main, pushed)
**Target repo:** `~/core/hexa-lang/` (branch `rfc043-hexa-torch`)
**Status:** HANDOFF — forward action items for a hexa-lang session. No
hexa-lang source modified by this note (PATCHES.yaml entries + this
note only).
**Mode:** filed from the hexa-arch session per the user's "inbox
넣었어?" request. D19 boundary respected: hexa-arch designs the RFCs;
hexa-lang owns/implements/pushes the `stdlib/` modules.

## 0. TL;DR

Three items a hexa-lang session needs to action. ① and ② are the
real work; ③ is a g3 correction of an earlier mis-statement.

- **① PUSH the booksim absorb.** `d5a63a82`
  `feat(stdlib/booksim): absorb NoC-sim re-derivation modules from
  hexa-arch (rfc_003)` is on LOCAL HEAD of `rfc043-hexa-torch`
  (branch ahead 17), **UNPUSHED**. 14 files / +4005, pure
  `stdlib/booksim/` (leaf, transpile-only). Now tracked:
  `PATCHES.yaml` id `stdlib-booksim-rederive-from-hexa-arch-rfc003`,
  status `pending`. Needs: review + push + `inbox_sync` verify.
- **② IMPLEMENT rfc_006 Yosys §4 modules.** hexa-arch drafted
  `proposals/rfc_006_yosys_absorption.md` (design only). Per D19 the
  7 modules belong in **`hexa-lang/stdlib/yosys/`** (hexa-lang's
  tree, like booksim). Spec the hexa-lang session works against =
  rfc_006 §4 (module list) + §5 (the measured gate).
- **③ g3 correction.** `61866308` `docs(comb): cite hexa-arch
  rfc_002` is **already PUSHED** to origin (docs-only, comb/, 5
  files). Earlier hexa-arch logs called it "unpushed" — wrong;
  corrected here and in hexa-arch PLAN.md. Tracked as `PATCHES.yaml`
  id `comb-cite-hexa-arch-rfc002-f1f2`, status `applied`, no action.

## 1. Item ① — booksim push (small, do first)

`d5a63a82` re-derives BookSim2 NoC-sim clean-room into
`stdlib/booksim/` (6 `.hexa` modules + 6 `.stub` + README). It was
absorbed FROM hexa-arch into hexa-lang/stdlib per hexa-arch
`design.md` D15 (stdlib is hexa-lang's exclusively; hexa-arch is the
consumer). hexa-arch `rfc_003` already points at this hexa-lang
location. Action: `git push` the `rfc043-hexa-torch` branch (or
cherry-flow per your branch policy), then `tool/inbox_sync.hexa` to
flip the PATCHES entry toward `applied`.

## 2. Item ② — rfc_006 Yosys §4 implementation

Read `~/core/hexa-arch/proposals/rfc_006_yosys_absorption.md`. Key
constraints already decided on the hexa-arch side (do NOT re-litigate
— they are committed decisions, cited):

- **Target location:** `hexa-lang/stdlib/yosys/` (hexa-arch D15/D19;
  same pattern as `stdlib/booksim/`). hexa-arch will *reference*, not
  carry, these modules.
- **Module list:** rfc_006 §4 — `rtlil`, `read_verilog`, `passes`,
  `liberty`, `abc_map`, `write_verilog`, `yosys` (dispatcher). Each:
  `#!hexa strict`, clean-room provenance header, per-fn `// CLEAN-
  ROOM`, `fn main()` self-test, `exit(91)` fail-loud (rfc_003 idiom).
- **ABC path (hexa-arch D18):** `(7a) bounded-subprocess` — re-derive
  the Yosys flow hexa-native but invoke **ABC** as a documented
  absorbed-substrate subprocess, fail-loud (rfc_048/D14 hybrid g5
  exception). Do NOT attempt full ABC clean-room re-derivation now
  (hexa-arch D18 rejected 7b explicitly).
- **Measured gate (rfc_006 §5, g3):** "Yosys absorbed" may be claimed
  ONLY when the flow synthesizes comb `router_d{4,6}.v` against
  SKY130 `sky130_fd_sc_hd` and reproduces the cited area oracle
  (d4 ≈ 61,763 µm², d6 ≈ 93,609 µm², ratio 1.516× ± ~5%), filed with
  numbers. Until then: GATE-style, no "absorbed" claim.
- Toolchain limits to expect (rfc_003 finding): no `match`, enum-
  equality broken, no tuples — use int/struct idioms + dispatcher.

## 3. Context — Phase 3 seams now exist (FYI, not an action)

hexa-arch has since drafted two typed chain seams a hexa-lang session
may want to be aware of (no hexa-lang action required — they are
hexa-arch-side consumption contracts, v0, records empty by design):

- `rfc_007` materials→chip seam — consumes upstream material-property
  records. hexa-matter's absorption SSOT = hexa-lang (hexa-arch D17);
  if/when hexa-lang emits material-property records they should
  validate against hexa-arch `exports/seams/materials_to_chip/
  schema/v0.md`. Pin to v1.0 only when a real record validates.
- `rfc_008` chip→component seam — internal to hexa-arch domains.

## 4. Provenance / boundary

This note + the two `PATCHES.yaml` entries are the ONLY changes filed
from the hexa-arch session. No `stdlib/`, `self/`, `compiler/` files
touched here. Implementation of ② is a hexa-lang-session task (D19).
hexa-arch side is at `c98a3af` (pushed, public). g3: nothing is
claimed absorbed/wired — ① is unpushed, ② is unimplemented, the
rfc_006 gate is OPEN.
