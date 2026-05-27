# atlas.n6 SSOT recovery + hxc retirement (2026-05-22)

## What happened
A session ran `hexa run tool/atlas_build_hxc.hexa` after `hexa atlas stats`
reported the sidecar "missing/empty". That regen reads only the LEAN
`compiler/atlas/embedded.gen.hexa` (P/C/L/E + limits ≈ 7,448 rows), so it
overwrote the canonical `dist/atlas.hxc` (the FULL n6 corpus, 15,952 rows
incl. @F/@R/@X/@S/@Q), destroying ~8,500 nodes in the working tree.

Root-cause chain:
1. `static_atlas()` resolved the sidecar **CWD-relative** → ran from another
   dir → "missing/empty".
2. The fallback hint told users to run the lossy rebuild tool.
3. The rebuild tool reads only the lean source → shrinks the SSOT. No guard.
4. Deepest: the full hxc had **no in-repo reproducible source** — the
   ground-truth `dancinlab/atlas.n6` (~4.2 MB) was gone (the `anima/n6/atlas.n6`
   symlink points at the deleted `~/core/nexus`; only a stale 1.5 MB backup
   survived). The committed `dist/atlas.hxc` was the only full copy.

## The fix: atlas.n6 as the single artifact, hxc retired
Per the "no hxc — atlas.n6 single artifact" directive:

- **Reconstructed `n6/atlas.n6`** (15,952 nodes, 3.43 MB) from the surviving
  `dist/atlas.hxc`. Each hxc row's `raw` column holds the verbatim original
  n6 source block; reconstruction = pipe-split (respecting `\|` escape) +
  unescape (`\\n`→newline, `\\"`→`"`, `\|`→`|`) + join. Validated against the
  stale backup: **9,449/9,567 overlapping nodes byte-exact (98.77%)**; the
  residual is backup staleness + comment dividers (comments are not atlas
  nodes and are intentionally not carried). Kind distribution matches the hxc
  exactly (C 5743 · E 7 · F 1268 · L 514 · P 442 · Q 83 · R 6315 · S 6 · X 1574).
  All 15,952 rows split to exactly 16 columns (no pipe-escape breakage).

- **`static_atlas()`** (compiler/atlas/static_index.hexa) now parses
  `atlas.n6` via `merger::load_atlas` — no hxc, no embedded.gen struct
  literals. Resolution: `HEXA_ATLAS_N6` (abs dir) wins; empty → merger's
  stable `~/core/hexa-lang/n6` fallback (closes the CWD footgun). The
  const-literal OOM hxc dodged is a COMPILE-TIME cost; runtime text-parsing
  n6 avoids it the same way hxc did.

- **Guard** added to `tool/atlas_build_hxc.hexa` (refuses to shrink a richer
  sidecar) protects the surviving `dist/atlas.hxc` during the transition.

## Reproduction (hxc → atlas.n6), one-shot bootstrap
```python
import re
rows=[l.rstrip('\n') for l in open('dist/atlas.hxc',encoding='utf-8',errors='surrogateescape') if l.startswith('@atlas ')]
split=lambda l: re.split(r'(?<!\\)\|', l[len('@atlas '):])
unesc=lambda s: s.replace('\\\\n','\n').replace('\\\\"','"').replace('\\|','|')
open('n6/atlas.n6','w',encoding='utf-8',errors='surrogateescape').write('\n\n'.join(unesc(split(r)[2]).rstrip() for r in rows)+'\n')
```

## Remaining (sequenced — do NOT delete hxc before redeploy)
The currently-deployed `~/.hx/bin/hexa` still uses the OLD static_atlas that
reads `dist/atlas.hxc`. So:
1. Rebuild + redeploy the toolchain (pool) with the new static_atlas.
2. Verify the new binary loads 15,952 nodes from atlas.n6 + measure startup
   parse time (hxc was an O(1) load; n6 parse cost must be acceptable).
3. THEN delete `dist/atlas.hxc`, `tool/atlas_build_hxc.hexa`,
   `compiler/atlas/hxc_loader.hexa`, and the dead `use` in static_index.hexa.
