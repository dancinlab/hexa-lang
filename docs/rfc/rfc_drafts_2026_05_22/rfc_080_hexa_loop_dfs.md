# RFC 080 — `hexa loop --dfs`: TECS-L DFS+LLM atlas expansion

- status: draft (Phase A-G landed, F-partial, H test written, I docs, J pending)
- author: hexa loop campaign, 2026-05-22
- SSOT companion: this RFC is the canonical plan; the former root `TECS-L.md` (18-axis brainstorm + 13 risks) was repurposed 2026-05-25 (PR #994) to the n=6 number-theory domain — RFC-080 content survives here + git history
- supersedes nothing; extends RFC 065 (`hexa loop` self-growing atlas)
- branch: `rfc-080-dfs` (worktree `/Users/ghost/core/hexa-lang-rfc080`)

## 1. Motivation

`hexa loop` (RFC 065) applies 36 baked lenses in one breadth pass and emits
candidate atlas nodes to `archive/atlas_candidates/`. It never calls an LLM —
every hypothesis is hexa-native lens output, one level deep.

archive-TECS-L (`dancinlab/archive-TECS-L`) discovered new mathematics with a
suite of strategies, the central one being `dfs_engine.py` — a depth-first
descent that takes a finding and recursively "타고타고 내려간다" (follows the
chain deeper), pruning by error threshold. RFC 080 ports that descent into
`hexa loop` as an **opt-in LLM-companion mode**: a lens candidate becomes a
DFS seed; a pluggable external LLM proposes children one level deeper;
verified children become the next-depth frontier.

## 2. CLI surface

```
hexa loop --dfs --llm-cmd <cmd> [--depth N] [--beam K]
          [--llm-budget <USD>] [--llm-calls <N>] [--llm-time <s>]
          [--llm-families <a,b,c>] [--no-cache] [--allow-llm]
hexa loop --option        # alias = --dfs --depth 3 --beam 2 --llm-cmd $HEXA_LLM_CMD
```

- All flags default off → bare `hexa loop` is byte-for-byte unchanged.
- `--llm-cmd` is **pluggable** (axis 2c): any shell command that reads a
  prompt on stdin and writes a markdown response on stdout. Works with
  `claude -p`, `codex`, a local llama wrapper, or a test stub — no vendor
  lock-in.
- `--allow-llm` gates real command execution. Without it, `--dfs` builds and
  counts prompts but never spawns the command and emits nothing (a safe dry
  plan — protects against accidental cost, R1).

## 3. Architecture (stdlib/loop/dfs.hexa)

```
seeds (surviving lens candidates)
  └─ dfs_run  (iterative, beam-capped, depth-bounded)
       for each depth 0..N-1:
         for each parent in frontier (within --llm-families):
           budget check (3-way AND: calls / wall-time / USD-estimate)
           dfs_build_prompt(parent, view, beam)      # axis 9a/b/d/e
           cache lookup  sha256(prompt+cmd)            # axis 14
           dfs_llm_invoke(prompt, cmd)  via stdin file # axis 2c, R12/R13
           dfs_parse_children(resp)                    # markdown front-matter
           for each child:
             dfs_verify_child  -> ""|reason            # axis 10
             emit archive/atlas_candidates/dfs_<parent>/<child>.md  # axis 8b
             chain.jsonl + llm_calls.jsonl append
             carry to next frontier if !fire_needed && frontier<cap
```

### Output contract (axis 3b — markdown front-matter mirror)

The LLM is asked to emit the same shape the lens system already speaks, so
emitted children are drop-in for human PR review:

```
## <child-slug>
- family: <one of 9 RFC 065 families>
- fire_needed: <true|false>
- cite: [<atlas-node-id>, ...]

<one-paragraph English proposal>
---
(next child)
```

### Verify gate (axis 10 — `dfs_verify_child`)

Returns `""` to accept, or a short drop reason logged to
`state/loop/llm_drops.jsonl` (no retry — R2/10g):

| reason | rule |
|---|---|
| `empty-slug` | slug missing |
| `no-cite` | cite list empty (10b) |
| `cite-not-in-atlas` | no cite id resolves to a real P/L node (10c) |
| `trivial-body` | proposal < 50 chars (10e) |
| `non-english` | CJK/Hangul detected (10f) — `LC_ALL=C grep '[\xe4-\xed]'` byte-class oracle; allows Greek/Latin math (2-byte) but rejects CJK (3-byte) |

### Budget (axis 6 — 3-way AND)

`--llm-calls N` (hard count) · `--llm-time S` (wall epoch diff) ·
`--llm-budget USD` (estimate). Any one hitting short-circuits the walk and
the remaining frontier is dropped. Empty flag = 0 = disabled.

> **Honest caveat:** the pluggable command returns no token usage, so the
> USD figure is a char/4 over-estimate (`DFS_USD_PER_MTOK = 5.0`), not a
> billed cost. `--llm-calls` is the trustworthy cap.

### Cache (axis 14 — `dist`/state content-addressed)

`state/loop/<cwd>/llm_cache/<sha256(prompt+cmd)>.resp`. A cache hit skips the
command entirely ($0 rerun). `--no-cache` opts out. MVP is a file cache; HXC
sidecar consolidation (RFC 066 pattern) is a follow-up.

## 4. Governance — proposed `@D g_llm_pluggable`

RFC 080 introduces the **first LLM call inside the hexa toolchain**. To keep
that consistent with the atlas-binary-builtin discipline, the following gate
is proposed for ratification (CLAUDE.md `@D` / AGENTS.tape):

```
g_llm_pluggable = "hexa loop --dfs is the only path that may invoke an
  external LLM. It is opt-in (default off), requires a pluggable --llm-cmd
  (no vendor baked in), gates real exec behind --allow-llm, and MUST enforce
  a budget cap and the dfs_verify_child gate (cite-required + English-only).
  LLM output lands ONLY in archive/atlas_candidates/** (PR-only, per
  g_atlas_binary_builtin) — it MUST NEVER write compiler/atlas/embedded.gen
  or compiler/lenses/embedded.gen directly."
```

Existing gates honored: `g_atlas_binary_builtin` (PR-only emit),
`g6` (cite enforced — the verify gate), `g_interp_deprecated` (compiled
path), `g_plan_consolidation` (compiler/PLAN.md entry per cycle),
`project_hexa_lang_english_only` (verify 10f).

## 5. Phase status

| Phase | scope | state |
|---|---|---|
| A | CLI flags + `--option` alias (VERSION 0.1.0) | landed `17211a25` |
| B | `dfs_llm_invoke` pluggable shellout | landed `d8257dd6` |
| C | prompt / parse / `dfs_run` + `cycle_dfs` stage + `build_atlas_view` | landed `d8257dd6` |
| D | verify gate + drop log | landed `d8257dd6` |
| E | 3-way AND budget + `--allow-llm` exec gate | landed `d8257dd6` |
| F | chain/telemetry landed; `--resume` + `dfs_frontier.jsonl` persist | **partial** |
| G | sha256 content cache | landed `d8257dd6` |
| H | `tests/loop/dfs_test.hexa` (parse + verify + run + budget) | landed `a4a7cd9c` |
| I | this RFC + PLAN entry + governance proposal | landed `a4a7cd9c` |
| J | **behavioral validation — compiled (`hexac build`), 14/14 PASS on Mac arm64** | **landed `3264dcdd`** |
| K | **atlas overlay absorption — verified children auto-flow to `atlas.overlay.n6` (drill-shared)** | this PR |

## 5a. Phase K — auto-absorption to the unified discovery stream

The DFS engine's emitted children land in `archive/atlas_candidates/dfs_*/`
(PR-only) AND auto-append a tape-format `@P` entry to
`<HX_DATA_DIR>/atlas.overlay.n6`, the *same* overlay file
`compiler/drill/round.hexa::_cand_to_n6` writes (drill round discoveries).
This unifies the two discovery streams into one corpus that the existing
"discovery → 3+ hits → promote into baked atlas" pipeline already governs.

Tape format mirrors drill's, adapted for the proposal-bearing Candidate:

```
@P <child-slug> :: dfs [3?]
  <- <cite_id>, <cite_id>
  => "<one-paragraph English proposal>"
```

Grade `[3?]` = tier-3 hypothesis pending verification (cf.
`tool/verify_cli.hexa` rubric — 🔵/🟡/🟠/⚪). The `dfs` source tag
distinguishes from drill's `smash`/`free`/`absolute`/etc.

**Governance preserved.** `compiler/atlas/overlay.hexa` documents the
overlay as EXPORT-ONLY — its runtime load path is retired-to-empty, so
`build_atlas_view` does NOT pick up new overlay entries; the binary atlas
(`embedded.gen`) is still the only runtime source of truth. Auto-absorption
feeds the PROMOTION pipeline (which is human/PR-gated), not the runtime
view. `@D g_atlas_binary_builtin` stays intact.

**Implementation note.** `_dfs_absorb_to_overlay` writes directly via
`exec("printf … >> $(overlay_path)")` rather than calling
`overlay_append_lines`. Same on-disk format; bypasses
`overlay.hexa`'s `_g_overlay_meta` module-level cache, which corrupts
under repeated calls in the compiled binary (SIGSEGV reproduced; the
direct-write path is what `_dfs_chain_append` already uses for chain.jsonl).

## 6. Validation

- `hexa parse` (local, OOM-free): dfs.hexa + cycle.hexa + dfs_test.hexa all PASS.
- **Behavioral (compiled), DONE:** `hexac build tests/loop/dfs_test.hexa` →
  Mach-O arm64 binary → **14/14 checks PASS**. Covers markdown parse (2
  children), verify gate (accept good + drop no-cite/cite-not-in-atlas/
  trivial/non-english), `dfs_run` emit (2 children to
  `archive/atlas_candidates/dfs_<parent>/`), budget cap (`--llm-calls 1` stops
  after one call), and chain.jsonl persistence (parent_slug/depth/cost).
  Stub LLM (`cat <fixture>`), $0.
  - **Host constraint:** the RUNTIME.md hexa-native syscall layer
    (`runtime.c` `#if defined(__aarch64__)` + Darwin `svc #0x80`) is
    macOS-arm64-only, so this builds only on an arm64 Mac — x86_64 Linux
    (ubu-1/ubu-2) physically cannot link it.
  - **Bug caught by behavioral testing (Phase J):** `_dfs_has_cjk` used
    `grep -c '[\xe4-\xed]'`, but plain grep does not interpret `\xHH`; under
    sh+BSD grep the bracket matched ASCII letters, rejecting ALL English
    proposals. Fixed to a portable `tr -d '\0-\177' | wc -c` non-ASCII count.
- **Real-LLM oracle, DONE:** the full `hexa loop` binary
  (`hexac build stdlib/loop/cycle.hexa`) ran
  `--dfs --allow-llm --llm-cmd "claude -p" --llm-calls 1 --depth 1 --beam 2`
  on the real atlas: 153 lens seeds → **1 real Claude call → 2 verified
  children emitted**, 152 frontier seeds saved for `--resume`. Estimated
  cost ~$0.003. Sample child (parent
  `empty_space.unmapped_axis.grade_distribution`):
  `empty_space.unmapped_axis.ungraded_pair_isolate` (family
  `counterexample_mine`, cite `[n]`) — "isolate the 2 ungraded P entries;
  determine structurally-exempt vs merely-unscored" — a coherent,
  cited, deeper hypothesis. Confirms the TECS-L depth-first descent works
  with a live model end-to-end.
- Note: `resume` is a transpiler reserved word — the DfsConfig field is
  `do_resume` (the `hexa parse` checker accepts `resume` as an identifier
  but the codegen transpiler does not; caught only at compiled build).

## 7. Non-scope (follow-up RFCs)

`--resume` + frontier persistence (F remainder) · Convergence engine
(`--converge`, 3+ domain) · Bridge Explorer → `cross_pollinate` LLM mode ·
Texas Sharpshooter p-value → `falsify_self` · Proof Tier 0-3 via cite-chain
depth · multi-LLM quorum · parallel rate-limited calls · nearest-atlas-
neighbor cite graph · HXC cache consolidation.

## 8. Lexer note (implementation hazard)

A stray **NUL byte (0x00)** inside a hexa string literal silently terminates
the C-string at the lexer layer and swallows the rest of the file to EOF
(manifests as `expected RParen, got Eof`). Detect with `cat -v` (shows `^@`).
hexa string literals must be pure ASCII for emitted content; non-ASCII in
comments is tolerated but discouraged. This bit the first dfs.hexa draft.
