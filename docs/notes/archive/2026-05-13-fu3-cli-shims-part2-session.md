# FU3 — CLI fn main() shims, part 2 (20 remaining modules)

Date:    2026-05-13
Branch:  main (uncommitted)
Status:  20/20 wired; 20/20 smoke PASS

## Scope

Completes the CLI fn main() shim coverage started in commit b27eb850
(18 modules + shared `compiler/_cli_args/parse.hexa` helper). Same
pattern, no commits.

## Modules wired (20)

Drill variant (1):
- compiler/revive/revive.hexa

HW probes (3):
- compiler/hw_probes/qmirror.hexa
- compiler/hw_probes/akida.hexa
- compiler/hw_probes/qrng.hexa

Bridges (16):
- compiler/bridges/{codata,oeis,arxiv,gw,horizons,cmb,nanograv,simbad}.hexa
- compiler/bridges/{icecube,nist_atomic,wikipedia,openalex,gaia,lhc,pubchem,uniprot}.hexa

After this part, every verb listed in self/main.hexa dispatch_absorbed
(38 total = 18 part-1 + 20 part-2) has a `fn main()` shim.

## Non-standard / notable signatures

- `revive_run(max_iter, consec_fail_cap, apply, quiet) -> ReviveResult`
  has NO seed parameter. Spec asked for `--seed`; the shim accepts and
  silently absorbs it (`let _seed = …`), forwarding only the four real
  args. Output shape: {iters_completed, consecutive_fail,
  final_verdict, exit_code}.

- HW probes (qmirror/akida/qrng) use `_run(sub: string, extra: [string])`
  rather than `_run(args)`. The shim takes positional 0 as `sub`
  (default "status" / "probe"), and pushes remaining positionals into
  `extra`. qrng additionally passes inline `--bits=N` tokens through
  because qrng_fallback parses that form natively.

- Bridges with no-arg `_run(_args: [string])` (codata, gw, cmb,
  nanograv, icecube, gaia, lhc) still build the same passthru shape
  for uniformity; the bridge body discards it.

All other bridges take `args[0]` as the search/query/accession/CID/seq
identifier.

## Pattern

Each fn main() block:
1. `use "compiler/_cli_args/parse"` after a block-comment header.
2. `cli_args()` → flag/positional extraction.
3. Call public `_run(...)`.
4. Print JSON with {ok, stdout, stderr, exit_code} for bridges/HW, or
   the natural result struct for revive.
5. JSON-escape stdout/stderr inline (backslash, double-quote, newline).
   `escape_json_string` is NOT in scope and not introduced here.

## Sample verifications (all PASS)

```
HEXA_FORCE_FALLBACK=1 hexa run compiler/bridges/wikipedia.hexa "Perfect_number"
  → {"ok":true,"stdout":"{\"tool\":\"wikipedia\",\"source\":\"fallback:frozen-cache\",…}",…}

hexa run compiler/revive/revive.hexa --max-iter 5 --quiet
  → {"iters_completed":3,"consecutive_fail":0,"final_verdict":"l0_reached","exit_code":0}

HEXA_FORCE_FALLBACK=1 hexa run compiler/hw_probes/qmirror.hexa
  → {"ok":true,"stdout":"{ tool: qmirror, mode: fallback-deterministic, closure: 8/8 PASS … }",…}

HEXA_FORCE_FALLBACK=1 hexa run compiler/bridges/oeis.hexa "A000396"
  → {"ok":true,"stdout":"{ tool: oeis, source: fallback:frozen-cache, seq: A000396, first6: [6,28,496,8128,33550336,8589869056] }",…}

HEXA_FORCE_FALLBACK=1 hexa run compiler/bridges/pubchem.hexa 962
  → {"ok":true,"stdout":"{ tool: pubchem, source: fallback:frozen-cache, data: { cid:962, name: Water, formula: H2O, … } }",…}

HEXA_FORCE_FALLBACK=1 hexa qmirror status         (top-level dispatch)
  → same output as the run form above

HEXA_FORCE_FALLBACK=1 hexa wikipedia "Perfect_number"   (top-level dispatch)
  → same JSON as the run form
```

Bulk smoke (`hexa run <file>` for every module, ok:true / l0_reached):
**20/20 PASS**.

## LOC delta

```
20 files changed, 489 insertions(+)
```

Per-file averages:
- revive:           +26
- hw_probes (×3):   +36..+43 (heavier — needs sub/extra arg split)
- bridges  (×16):   +21..+23

No edits to any pub fn surface; no test files touched; self/main.hexa
unchanged.

## Hard-constraint compliance

- Uncommitted (working tree dirty): YES
- pub fn surfaces unmodified:        YES
- test files unmodified:             YES
- self/main.hexa unmodified:         YES
- English comments only:             YES
- usage-on-empty path (rc 0):        YES (revive accepts no required arg; bridges/HW have sensible defaults so they print a default JSON instead of usage — matching the established bridge behavior in `_run`)
- mirrors b27eb850 shape:            YES (block comment + use + fn main + flag parse + API call + JSON output)
