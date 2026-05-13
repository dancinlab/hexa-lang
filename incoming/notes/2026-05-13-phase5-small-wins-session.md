# Phase 5 small wins — ubu2 bootstrap automation + HX9000 template fix

Two follow-up items from the nexus absorption project, executed
independently of the active codegen BG (no `self/codegen_*.hexa` touched).

## Item 1 — `tool/ubu_bootstrap.sh` (NEW, 198 LOC)

Automated the previously-manual ubu host bootstrap recipe documented in
`2026-05-13-final-consolidation-session.md`. Single bash script with five
subcommands; default ssh host alias `ubu2` (overridable via
`UBU_BOOTSTRAP_HOST` env or positional arg).

**Subcommands implemented:**

| sub        | side  | does                                                                       |
|------------|-------|----------------------------------------------------------------------------|
| `transpile`| Mac   | `self/native/hexa_v2 self/main.hexa /tmp/hexa_main.c` + same for `hexa_full.hexa` → `/tmp/hexa_full.c` |
| `sync <h>` | Mac   | rsync `compiler/ tool/ self/ test/` (excluding `*.dylib *.so build/ archive/` + native binaries) + scp transpiled `.c` files to `<h>:~/core/hexa-lang/build/` |
| `build <h>`| any   | gcc both `.c` files into `~/.hx/bin/hexa.real` + `build/hexa_interp` and install wrapper at `~/.hx/bin/hexa`. Accepts `--local` to run on the local machine. |
| `install <h>` | Mac | pipeline: transpile → sync → build                                         |
| `verify <h>`| any  | smoke: run `compiler/atlas/static_index_test.hexa` on target (200 s timeout, `HEXA_MEM_UNLIMITED=1`) |
| `help`     | local | print top-of-file usage banner                                             |

**Conventions:**

- `set -euo pipefail`, helper `log`/`warn`/`die`.
- The remote build script is built as a heredoc and dispatched via
  `ssh "$host" bash -s` (or `bash` locally), so the same recipe runs
  both ways without code duplication.
- gcc flags mirror the consolidation session exactly:
  - `gcc -O2 -D_GNU_SOURCE -Wno-trigraphs -I self -I . build/hexa_main.c -o ~/.hx/bin/hexa.real -lm`
  - `gcc -O2 -D_GNU_SOURCE -std=gnu11 -Wno-trigraphs -I self -I . build/hexa_full.c -o build/hexa_interp -lm -ldl`
- Wrapper script body verbatim from manual recipe.

**Smoke (Mac-side only, per task):**

```
$ rm -f /tmp/hexa_main.c /tmp/hexa_full.c
$ ./tool/ubu_bootstrap.sh transpile
[ubu_bootstrap] transpile: self/main.hexa → /tmp/hexa_main.c
OK: /tmp/hexa_main.c
[ubu_bootstrap] transpile: self/hexa_full.hexa → /tmp/hexa_full.c
OK: /tmp/hexa_full.c
[ubu_bootstrap] transpile: OK (201967 B main, 1523020 B full)
```

Outputs verified: `/tmp/hexa_main.c` (201 967 B), `/tmp/hexa_full.c`
(1 523 020 B). Exit-code paths checked (no-args → 1, unknown sub → 1,
help → 0, transpile → 0). `sync` / `build` / `install` / `verify` not
exercised end-to-end in this BG (would require a live ubu2 host).

**Result:** ✓ implemented + transpile smoke passing.

## Item 2 — `compiler/check/annotations_test.hexa` HX9000 message fix

**Failing assertions (case `(g)` only):**

```
FAIL (g): HX9000 message missing suppressed_title `atlas node not found`
FAIL (g): HX9000 message missing suppressed_severity_original `Error`
FAIL (g): HX9000 message missing suppressed_message body (looking for `missing_node`)
```

(The consolidation session note listed only two of these — the third,
`suppressed_title`, was present originally and only surfaces on a fresh
run.)

### Root cause

`compiler/diag/builder.hexa::diag_suppressed_by_grace()` correctly
populates three args on the synthesized HX9000:

- `suppressed_title`              ← `DiagSpec.title` of the real code
- `suppressed_message`            ← `_render_short_inline(real)` (contains body)
- `suppressed_severity_original`  ← `_sev_title(real.severity)` (Error/Warning/Note)

But the **catalog template** at
`compiler/diag/catalog.hexa::CATALOG[HX9000].template` only interpolated
`{file}`, `{line}`, `{error_code}`, `{until}`, `{reason}`. The three
`suppressed_*` args were attached to the diagnostic struct but never
appeared in the rendered `message` string — `_interpolate` only
substitutes keys that the template actually references.

The intent — spelled out repeatedly in the builder comments and the
test docstring — is that HX9000's message inlines the *full* rendered
text of what is being silenced (SPEC.yaml
`opt_out.ai_native_warn_policy.suppressed_diagnostic_inlining`,
`args_keys: [suppressed_title, suppressed_message, suppressed_severity_original]`).
The producer side was already correct; only the template was missing
the three placeholders.

### Fix

`compiler/diag/catalog.hexa` lines 335–336 (2 lines changed):

- `template` gains a single inline segment
  `Suppressed [{suppressed_severity_original}]: {suppressed_title} — {suppressed_message}.`
  injected between the existing `Reason: "..."` clause and the
  `This is a TEMPORARY debt …` tail.
- `explain` clarifies the new segment and cross-references the SPEC
  `args_keys` so future readers see why the placeholders exist.

The `_check_grace` site that produces the in-place HX9000 (no real
diagnostic matched) already populates the three slots with neutral
placeholders (`"n/a"`, `"no diagnostic emitted at this site (pre-emptive
@grace)"`, etc.), so the new template segment renders sensibly in *both*
the pre-emptive and the matched-suppression paths.

### Verification

```
$ HEXA_LANG=$PWD hexa run compiler/check/annotations_test.hexa
…
── case (g) apply_grace_suppression HX1042 ─────
input diagnostics:  1
result diagnostics: 1
  [0] HX9000 (warning runtime) @ test.hexa:23:5
        msg:     ai-native: @grace at test.hexa:23 suppresses HX1042 until 2099-12-31. Reason: "atlas-migration". Suppressed [Error]: atlas node not found — test.hexa:23:5 HX1042 error: atlas abc123 has no L node `missing_node`. This is a TEMPORARY debt — …
PASS: 8 cases — 0 / HX8010×1 / HX9001+HX9000 / HX9000×1 / HX9002×1 / 0 / HX9003×1 / inline-HX9000.
```

All assertions pass. Cases (c) and (d) now also surface the
`Suppressed [n/a]: no diagnostic emitted at this site (pre-emptive
@grace) — …` segment, which is the desired pre-emptive view.

### Regression check

- `compiler/honesty/check_test.hexa` → `RESULT: PASS` (16 PASS lines).
- `compiler/atlas/static_index_test.hexa` runs (long-tail drill test —
  in the consolidation session this took >180 s; not exercised to
  completion in this BG, but the only edit was a string in a `let`
  catalog table that downstream code reads through `_spec_for`, so a
  template-text change cannot regress logic anywhere).
- Search for other consumers of `suppressed_title|suppressed_message|
  suppressed_severity_original` outside the catalog/builder pair
  returned zero hits — the args are produced and consumed only via
  catalog template interpolation. No other render path needs updating.

**Result:** ✓ fixed. 2 LOC delta in `compiler/diag/catalog.hexa`.

## Findings — hexa-lang diag pipeline (Item 2 side)

- The `_interpolate` helper is the *only* mechanism that promotes
  `diag_arg(…)` values into the final `Diagnostic.message`. Args
  attached without a matching `{key}` in the catalog template are
  silently dropped from the rendered text but survive on the
  `Diagnostic` struct (no consumer reads them today — args are flat
  `"key=val"` strings in `DiagBuilder.args`, but `Diagnostic` doesn't
  carry the array forward; only the rendered `message` is exposed).
  → Practical consequence: if a future check pass adds new arg keys it
    *must* also extend the catalog template, or the data is invisible.
- The `diag_suppressed_by_grace` / `apply_grace_suppression` pair
  cleanly separates the "swap a real diag for a paired HX9000" rewrite
  step from per-pass emission, which makes the spec mapping easy to
  audit. The bug here was purely a template-template-skew mismatch, not
  a logic flaw in the rewrite layer.

## Hard-constraint compliance

- Not committed.
- Nexus untouched (already archived).
- `self/codegen_*.hexa` untouched (active codegen BG territory).
- English-only code/comments.
- Default ssh_host = `ubu2` for the bootstrap script.

## Total LOC delta

| file                                            | added | removed |
|-------------------------------------------------|-------|---------|
| `tool/ubu_bootstrap.sh` (NEW)                   | 198   | 0       |
| `compiler/diag/catalog.hexa`                    | 2     | 2       |
| `incoming/notes/2026-05-13-phase5-small-wins-session.md` (NEW) | ~150 | 0 |

Source-code delta excluding the new script and this note: **+2 / −2**.

## Items halted

None.
