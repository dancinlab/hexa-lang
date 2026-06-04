# `hexa run` build-cache keys on entry-file hash only — stale binary on dep edit

## Symptom
Editing a stdlib module that is a TRANSITIVE `use` dependency of an entry script,
WITHOUT touching the entry script, makes `hexa run <entry>` reuse a STALE cached
binary (`~/.hexa-cache/hexa_run.<hash>_*-dispatch`). The edit is silently ignored.

## Repro (observed 2026-06-05, qforge converged-CaH6 work)
1. `hexa run stdlib/qforge/fixtures/cah6_fullbz_xval.hexa ...` (compiles + caches by entry hash)
2. edit `stdlib/qforge/pw_frontend.hexa` (a `use` dep of the fixture) — change a fn body + a printf
3. re-run the SAME fixture → OLD behavior + OLD strings; the printf marker never appears
4. `hexa cache clean --prune --older-than=0` prunes 0 (age filter, not content)
5. touching/editing the ENTRY file busts it (entry hash changes → full recompile picks up the dep)

## Root cause
The cache key is a hash of the ENTRY file content only, not the closure of its
`use` dependency graph. A dep change does not invalidate the entry's cached binary.

## Fix options
- fold every transitively-`use`d module's content hash into the dispatch cache key
- OR a mtime/hash check over the resolved dep set before reusing a cached binary
- OR a `hexa run --fresh` / `HEXA_NO_CACHE=1` escape hatch (minimum viable)

## Impact
Silent wrong results during iterative stdlib dev — a correctness footgun, not just perf.
