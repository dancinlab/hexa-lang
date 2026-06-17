# F3 — `hexa_cc.c` activation runbook (cold-seed → warm-rebuild gate)

**Status**: SCAFFOLD · `hexa_cc.c=0` is a multi-session terminal goal.
**Branch**: `f3-hexa-cc-guard-scaffold-2026-05-29` (off `origin/main` @ `c1a500ce2`).
**Owner**: F3 runtime-floor closure campaign (sibling to the 59/640
svc-wrapper scale-out at `1018e1a55`).

This document defines the **3-way decision tree** for `hexa_cc.c`, the
**preconditions** that must hold before any branch can be taken, and the
**per-step verifier** that a CI / agent can run to gate a flip.

`hexa_cc.c` is NOT a runtime primitive — it has no per-fn
`HEXA_RT_SELFEMIT` guard (`grep -c HEXA_RT_SELFEMIT self/native/hexa_cc.c
= 0` at HEAD `c1a500ce2`). It is the **boot-image**: a generated
single-TU `.c` file (~28435 lines, 1850855 B) that compiles to the
stage-0 transpiler `build/hexat`. The "guard" is therefore a
**build-system gate**, not a `#ifdef`.

---

## 1 · Why the guard differs from runtime.c primitives

| primitive | activation | composition |
|-----------|------------|-------------|
| `runtime.c::rt_<fn>` (F3 class-D etc.) | per-fn `#ifdef HEXA_RT_SELFEMIT extern / #else <body> #endif` + a hexa-emitted `.o` providing the symbol | **compositional** — every fn flips independently, % activated is a scalar (59/640 at `1018e1a55`) |
| `hexa_cc.c` (boot image) | **all or nothing** — either the in-tree `.c` is used (cold), or `hexa cc --regen` regenerates it byte-identically from the 4 SSOT `.hexa` modules and the regen output is used (warm) | **monolithic** — a partial flip is meaningless |

The corresponding F3 axis for `hexa_cc.c` is therefore **fixpoint
property** (`v_n == v_{n+1}` byte-eq across cross-host {Mac arm64 + ubu
x86_64}), not a per-fn count.

---

## 2 · Three-way decision tree (the runbook)

```
                  ┌──────────────────────────────────────┐
                  │ start: build needs build/hexat       │
                  │ (stage-0 transpiler)                 │
                  └──────────────────┬───────────────────┘
                                     │
                  ┌──────────────────▼───────────────────┐
                  │ Q1: is HEXA_BOOTSTRAP_WARM=1 set?    │
                  │ (or `--prefer-regen` flag passed)    │
                  └──────┬──────────────────────────┬────┘
                       no│                       yes│
                         │                          │
        ┌────────────────▼──┐         ┌─────────────▼──────────────┐
        │ cold-seed path    │         │ warm-rebuild path           │
        │ (current default) │         │ (terminal goal)             │
        │                   │         │                             │
        │ cc self/native/   │         │ 1. ensure prior hexat       │
        │   hexa_cc.c       │         │    exists (chicken-egg)     │
        │   + runtime.c     │         │ 2. hexat → transpile 4 SSOT │
        │   → build/hexat   │         │    .hexa modules → /tmp/_*.c│
        │                   │         │ 3. merge → hexa_cc.c.new    │
        └─────────┬─────────┘         │ 4. cc hexa_cc.c.new         │
                  │                   │    + runtime.o → /tmp/      │
                  │                   │    hexat.new                │
                  │                   │ 5. fixpoint-byte-eq vs      │
                  │                   │    in-tree hexa_cc.c        │
                  │                   └────────┬────────────────────┘
                  │                            │
                  │                  ┌─────────▼───────────┐
                  │                  │ Q2: byte-eq PASS?   │
                  │                  └──┬──────────────┬───┘
                  │                  yes│           no │
                  │      ┌──────────────▼──┐  ┌────────▼───────────┐
                  │      │ use /tmp/       │  │ FALLBACK to cold-  │
                  │      │ hexat.new       │  │ seed + emit drift  │
                  │      │ (warm victory)  │  │ report (.verdicts) │
                  │      └─────────────────┘  └────────────────────┘
                  │
        ┌─────────▼─────────────────┐
        │ proceed with stage-1+     │
        │ (module_loader, driver)   │
        └───────────────────────────┘
```

The **terminal** state of the campaign is when:

- the cold-seed branch is **deleted** from `tool/build_hexa_cli.hexa`
  (Step 0 unconditional warm),
- `self/native/hexa_cc.c` is **removed** from the repo,
- and the build still succeeds cross-host because the warm path is
  proven to always reach byte-eq fixpoint from **a previously-built
  hexat** (or a stage-(-1) seed delivered out-of-band, e.g. `hx
  install` ships a host-specific `hexat` and never `hexa_cc.c`).

---

## 3 · Preconditions (gate the flip)

The warm-only flip MUST NOT happen until ALL of these are **measured
green** at HEAD:

| # | precondition | how to check |
|---|---|---|
| P1 | self-host fixpoint: `gen1.s ≡ gen2.s` byte-eq, cross-host (Mac arm64 + ubu x86_64) | already PROVEN at `d1994dfea` (#1533, gen1==gen2). re-verify per-PR via `cc --regen` byte-eq gate (already enforced — RUNTIME.md L2092) |
| P2 | warm-rebuild succeeds on Mac arm64 **without kill-storm** under the standard 4096 MB memcap (`HEXA_MEM_CAP_MB`) | NOT YET MEASURED at HEAD on a fresh worktree (see §5). probe via `verifier_cc_regen_byte_eq.hexa` (delivered this PR) once `build/hexat` exists |
| P3 | warm-rebuild succeeds on ubu x86_64 (no Mac-only `-fbracket-depth` traps; gcc parity) | LIKELY GREEN — CI `bootstrap.yml` runs equivalent flow. needs explicit `--prefer-regen` CI lane |
| P4 | the F3 runtime-floor `runtime.c` self-emit campaign reaches a documented closure tier (currently 59/640 ≈ **9.2%** at `1018e1a55`) | OPEN — multi-session grunt. NOT a strict blocker for `hexa_cc.c` flip (orthogonal axis), but a precondition for `runtime.c` shrinkage that the warm path benefits from |
| P5 | a stage-(-1) seed strategy is decided: **either** (a) `hx install` ships a host-specific prebuilt `hexat` binary (no `.c` seed), **or** (b) cold-seed `hexa_cc.c` is replaced by a much smaller hand-bootstrap `.hexa → .c` snippet, **or** (c) Go-1.4-style multi-host distro lane | OPEN DESIGN |

P1 is the **hard gate**. P5 is the **policy gate**. P2/P3 are
**measurement gates**. P4 is **orthogonal** (it shrinks runtime.c, not
hexa_cc.c, but accelerates the floor).

---

## 4 · Per-step verifier

The verifier is `tool/verify_hexa_cc_regen.hexa` (this PR), invoked as:

```
hexa-run tool/verify_hexa_cc_regen.hexa --probe        # honest probe
hexa-run tool/verify_hexa_cc_regen.hexa --byte-eq      # gen1≡gen2 gate
hexa-run tool/verify_hexa_cc_regen.hexa --drift-class  # categorize drift
```

Output classes (deterministic):

| class | meaning | action |
|-------|---------|--------|
| `BYTE-EQ` | sha256(hexa_cc.c.new) == sha256(in-tree hexa_cc.c) | warm path SAFE; proceed |
| `LINE-EQ-WHITESPACE` | line count equal, sha256 differs, but whitespace-only diff | regenerate SSOT pretty-printer (low risk) |
| `LINE-EQ-CODEGEN` | line count equal, sha256 differs, real codegen drift | requires SSOT module review |
| `LINE-DIFF-MINOR` | ≤±100 line delta | likely benign generator update; review |
| `LINE-DIFF-MAJOR` | >±100 line delta | likely a real SSOT module change shipped without regen — STOP, regen + re-commit hexa_cc.c per the 2026-05-26 PR-#1533 pattern |
| `BUILD-FAIL` | merged C failed to compile via clang | SSOT regression — STOP |
| `HOST-REFUSED` | Mac kill-storm / OOM / memcap exceeded | run on `mini` or `ubu-2` via `pool on <host>` |

---

## 5 · Honest measurement @ HEAD `c1a500ce2`

**hexa_cc.c metadata** (this branch, fresh worktree):
- path: `self/native/hexa_cc.c`
- bytes: 1850855
- lines: 28482 (note: HEAD count vs prior memo of "28435" reflects post-#1533 regen drift — see RUNTIME.md L2092 byte-eq gate is the canonical authority)
- md5: `a1ebff02a1bbf0fb293a52a39cd6aa5c`
- `grep -c HEXA_RT_SELFEMIT self/native/hexa_cc.c` = **0**

**`hexa cc --regen` invocability** (Mac arm64, this session):
- prereqs in fresh worktree: `build/hexat` **MISSING**, `self/runtime.o`
  **MISSING**.
- a full `--regen` therefore requires Step 0 bootstrap of `build/hexat`
  first (≈18-26 s `cc` of hexa_cc.c per `cmd_cc` comment, but this is
  also exactly the heavy work the Mac kill-storm gate
  (`_refuse_local_on_mac`) was added to refuse — see
  `tool/build_hexa_cli.hexa` L117-133 + memory
  `project-build-hexa-cli-hexa-port-2026-05-23`).
- **Decision**: do NOT execute `--regen` from this scaffold session.
  Document the runbook + ship the probe driver. The first MEASURED
  `--probe` run happens on `mini` / `ubu-2` in a follow-up.

---

## 6 · Multi-session sequence to `.c=0`

| session | step | est cost | gate |
|---------|------|----------|------|
| this | scaffold (runbook + probe + smoke flag) | 1 | landed in this PR |
| +1 | run `--probe` on `mini` and `ubu-2`, capture `BYTE-EQ` / drift class verdict at HEAD | 1 | P2 + P3 measurement |
| +2 | wire `--prefer-regen` lane to actually invoke warm path (still with cold fallback), capture cross-host measurement on every PR via a GHA matrix | 2-3 | CI green on both hosts |
| +3..+N | drive F3 runtime.c svc-wrapper to ≥X% (X TBD, ~30% suggested) — orthogonal but shrinks the floor | many | P4 partial |
| +K | decide P5 (the stage-(-1) seed strategy) — ship `hx install` host-binary OR design hand-bootstrap snippet | 1 design + 1 land | P5 |
| +K+1 | flip the build to warm-only (delete cold branch in `_do_build`) + delete `self/native/hexa_cc.c` | 1 | full P1-P5 green |

Total realistic span: **5-8 multi-session cycles**, dominated by P4
(runtime.c self-emit, multi-month per existing notes) — **but P4 is
not strictly on the critical path for `hexa_cc.c=0`** if P5(a)
(host-binary distro) is chosen.

---

## 7 · Honest blockers (measured / known)

1. **Mac kill-storm refuse-gate (HARD)**: `tool/build_hexa_cli` refuses
   to run on Darwin without `LOCAL_BUILD=1` (per 2026-05-23 incident
   memory). The standard `hexa cc --regen` is the heavy step. Probe
   must run via `pool on mini` / `ubu-2`.
2. **`pool route` + `hexa.real` SIGKILL bypass** (memory
   `reference-hexa-basename-sigkill-workaround-2026-05-19`): if a
   probe lane uses `hexa cc --regen` literally, external matchers may
   kill it. Use `hexa-run tool/verify_hexa_cc_regen.hexa`
   (hyphenated argv[0]) which dispatches the same logic.
3. **stale shared-worktree branch hazard** (memory
   `feedback-hexa-lang-shared-worktree-branch-hazard`): this scaffold
   landed via isolated worktree off `origin/main` to avoid the
   8-session-shared-dir staleness.
4. **runtime.c svc-wrapper campaign is multi-month** (current 59/640 =
   9.2% at `1018e1a55`): this is the F3 grunt lane and runs in parallel
   under other agents. Touching `runtime.c` here is explicitly OUT OF
   SCOPE for this PR (per the task spec).
5. **No issue numbered `#152` for runtime work**: the task referenced
   "ROI #152" but the gh search shows #152 is the autograd vjp PR
   (#152 MERGED). This document treats the F3 runtime.c campaign as
   the live parallel agent owner — checking
   `git log --oneline | grep "floor(F3)"` is the canonical progress
   surface.

---

## 8 · References

- `tool/build_hexa_cli.hexa` Step 0 (lines 288-302): the current
  cold-seed bootstrap call site.
- `self/main.hexa::cmd_regen_cc` (line 1703-): the SSOT for `hexa cc
  --regen`.
- `self/main.hexa::cmd_cc` (line 1268-): the rebuild step (compiles
  in-tree `hexa_cc.c`).
- PR #1533 `d1994dfea`: the last `hexa_cc.c` full regen + fixpoint
  proof.
- RUNTIME.md L2092: "`cc --regen` byte-eq after each Tier-A sub-phase"
  — the byte-eq gate is the canonical Tier-A acceptance.
- `git log --oneline | grep "floor(F3)"`: live progress of the parallel
  F3 runtime.c svc-wrapper agent (do not touch from this branch).
