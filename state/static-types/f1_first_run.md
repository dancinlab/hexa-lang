# F1 static-types corpus census — first live run verdict

**Run**: https://github.com/dancinlab/hexa-lang/actions/runs/28675927448/job/85049207175 (PR #4508, merge 018befcc, 2026-07-03 17:48 UTC)

## Verdict: NO CENSUS DATA — the census script CRASHED on file 1 (harness bug, not a corpus verdict)

The advisory red is **not** "counts > 0" and **not** the NEUTRAL infra path. It is a `set -e` + `pipefail` interaction that kills the loop the first time a file emits **zero** HX3011/HX3016 diagnostics.

### (1) Toolchain build: SUCCESS (not NEUTRAL)
- stage-0 regen + seeds restored, hexat built (2,304,168 B)
- `build_aprime: OK -> build/aprime_cc` (2,917,168 B, ELF x86-64), smoke `exit(42)==42 PASS`
- `built=1` path taken; census step was entered.

### (2) Census output: ZERO
The step printed exactly one line then died:
```
corpus: 69 files (compiler/check/*.hexa + stdlib/*.hexa top-level)
##[error]Process completed with exit code 1.
```
No per-file `::notice`, no `════ static-types corpus census ════` summary block, no DIRTY/CLEAN verdict. Time in step: ~7.2 s (17:49:53.447 → 17:50:00.66) — consistent with exactly **one** `aprime_cc` compile of the first corpus file, then instant abort.

### (3) Root cause — job-script defect (job design gap, not corpus, not checker)
GHA's default shell is `bash -e -o pipefail`; the step also sets `set -uo pipefail`. Inside the loop:

```bash
n="$(grep -o -E 'HX301[16]' "$log" | wc -l | tr -d ' ')"
```

When a file is **clean** (0 emissions), `grep` exits 1 → with `pipefail` the whole pipeline exits 1 → the command-substitution assignment carries status 1 → under `-e` the script terminates immediately with **exit 1**. The compile line is protected with `|| true`; the grep line is not. So:
- first file compiled (~7 s), had 0 emissions, script died — before ever reaching a dirty file, the summary, or the intended `exit 0`/`exit 1` branches.
- Perversely, the job can only survive the loop if **every** file is dirty.

### (4) Exit reason
`exit 1` = `set -e` abort at the `n=` grep assignment on the first clean corpus file. **Not** the advisory `total>0` red, **not** a compiler crash, **not** a build failure.

### Dirty file list / classification
N/A — census never ran past file 1. No HX3011/HX3016 data exists yet. Cannot classify corpus-mismatch vs checker-FP vs import-noise this run.

## Next actions
1. **Fix the job (only blocker)** — make the count grep failure-tolerant, e.g.:
   ```bash
   n="$(grep -o -E 'HX301[16]' "$log" | wc -l | tr -d ' ')" || true
   ```
   or `n=$(grep -cE 'HX301[16]' "$log" || true)`. Also consider `set +e` around the loop or `shell: bash {0}` to drop the implicit `-e`, since the step already manages rc explicitly.
2. Optionally add a completed-marker assertion (the final summary echo) so a mid-loop death can never masquerade as an advisory-count red again — e.g. only `exit 1` after the summary block prints.
3. Re-run the job on PR #4508 after the fix — that re-run produces the actual F1 first census (dirty list + classification).

Positive side-finding: the census toolchain path is proven — clean-checkout stage-0 regen → aprime_cc build → smoke, end-to-end green in ~2 min on a standard ubuntu-24.04 runner, and the per-file front-end invocation (`--emit=asm --error-format=short`, 60 s timeout) executes (~7 s/file for the first file).

Log saved at /private/tmp/claude-501/-Users-mini-dancinlab-hexa-lang/2752d070-5cff-4e64-8220-bb20cb8869bf/scratchpad/f1.log (census script text at log lines 287–337; the fatal grep is the `n=` assignment).
