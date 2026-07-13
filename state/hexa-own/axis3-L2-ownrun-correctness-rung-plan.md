## Next rung: **(a) L2 OWN-RUN correctness gate** — own-emit + own-link the full compiler, then prove the own-built compiler byte-reproduces the clang-built one's output

### 1. Why (a), and why the others wait

L1 (#4854) proved the own pipeline is a *pure deterministic function*. It said nothing about whether that function is *correct*. The default-flip gate stack is: determinism ✅ (#4854) → **correctness ⟵ open** → byteeq 3-target → flip. The RUN-correctness memory note (`project_hexa_axis3_selfemit_run_correctness`) explicitly flags this as the open frontier: UND-93 recon is done, "NEXT = actual link measurement." Nothing else on the axis can be trusted until an own-emitted+own-linked binary demonstrably computes the same thing as its clang-built twin — and the strongest, cheapest-to-assert instance is the compiler itself, because #4854's T2 makes any output diff attributable to *cc_self's computation*, never to link noise.

- **Reject (b)**: determinism-at-scale is already implied by transitivity (the gate header itself argues this — `tool/ownlink_determinism_gate:4-8`); re-proving it on cc-flat costs ~6× and unblocks nothing.
- **Reject (c)**: static-floor ET_EXEC is multi-rung, converges with axis-② on its own schedule, and is *not* a flip blocker — the gate's T4 already treats dynamic ET_EXEC as the sanctioned shape for libc-floor-dep programs (`tool/ownlink_determinism_gate:69-79`).

### 2. Verification recipe (pool: aiden or summer, linux-x86_64, fresh worktree at origin/main)

**Step 0 — build the reference twin + flatten** (existing tool, stages 1–5 must PASS first):

```bash
bash tool/build_native_linux_x86_64 -r "$PWD"     # cc-flat.hexa (:86-88) + gcc-built cc_native (:162) + hi rc-7 smoke (:171-199)
W=$PWD/build/lx8664
```

**Step 1 — produce `cc_self`: own-emit + own-link the FULL flattened compiler** (fuses stage-6 self-emit `tool/build_native_linux_x86_64:203-213` with the gate's own-link invocation `tool/ownlink_determinism_gate:50-51`):

```bash
mkdir -p "$W/noatlas"
export HEXA_LANG="$PWD" HEXA_PREBUILT_RUNTIME="$PWD/build/runtime.a"
/usr/bin/time -v env HEXA_ATLAS_EMBED="$W/noatlas" \
  "$W/cc_native" _drv.hexa --backend=native --emit=exec --linker=hexa \
  --target=x86_64-linux-gnu --ignore-errors -o "$W/cc_self" "$W/cc-flat.hexa" \
  > "$W/selflink.log" 2>&1
grep -c ENCODE-MISS "$W/selflink.log"   # must stay 0 (campaign SSOT)
```

Expected budget: ~79s emit (perf 🏁) + ~106s own-link (#4851 def-index, `compiler/main.hexa:1594-1825`); watch Max-RSS against the 19.87 GB frontend wall (this step is the only heavy one).

**Step 2 — THE assertion: cc_self byte-reproduces cc_native's output** on a graded fixture set:

```bash
T="$W/lx8664-test"
for f in "$T/hi.hexa" self/test/ownlink_determinism/rt_pull.hexa self/test_flatten.hexa; do
  b="$W/$(basename "$f" .hexa)"
  "$W/cc_native" _drv.hexa --backend=native --emit=obj --target=x86_64-linux-gnu -o "$b.ref.o" "$f"; r1=$?
  "$W/cc_self"   _drv.hexa --backend=native --emit=obj --target=x86_64-linux-gnu -o "$b.own.o" "$f"; r2=$?
  [ "$r1" = "$r2" ] && cmp -s "$b.ref.o" "$b.own.o" && echo "EQ  $(basename $f)" || echo "DIVERGE $(basename $f) rc=$r1/$r2"
done
```

**Step 3 (stretch, same session if 2 is GREEN) — own fixpoint**: `cc_self` re-emits `cc-flat.hexa` → `cmp` vs cc_native's stage-6 `cc-self.o`. This is gen3≡gen4 *through the own pipeline* — the terminal L2 statement. (Heavy: this re-hits the 19.87 GB wall inside an own-emitted binary; treat OOM as an infra note, not a correctness RED.)

**PASS**: cc_self exists, runs without signal, ENCODE-MISS=0, and all step-2 fixtures are rc-equal + `.o` byte-identical. **FAIL**: any divergence — then minimize the fixture (bisect functions) and file the miscompile class; that minimized repro *is* the next rung.

Key emit-path anchors on origin/main: `compiler/main.hexa:468` (backend=native routing) · `:1063` (x86_64-linux ELF .o write) · `:822-831` (exec-path native carrier + `--linker=hexa` own-start branch) · `compiler/emit/elf_x86_64.hexa:2466` (`serialize_elf_x86_64`) · `:3948` (#4790 label buckets).

### 3. Gate class + risk

**One-off pool measurement FIRST** — the memory note gives real prior odds of RED, and a gate that's born red is noise. On first GREEN, promote to `tool/ownemit_correctness_gate` as an **advisory CI job** cloning #4854's structure exactly (infra→exit-2 neutral `::warning::`, true divergence→exit-1; extension-less filename — the sidecar hook blocks `.sh`). Release-integrity class: **measurement-only** — every flag is opt-in (`--backend=native`, `--linker=hexa`), zero shipping-path bytes change, so no byteeq-3-target obligation for this rung; the gate itself later becomes a *precondition* of the default-flip PR, which is where byteeq 3-target + shipping smoke re-enter.

**Where cc_self will most plausibly diverge** (watch order): ① try/catch setjmp — the pool-reg rollback / return-in-try class from the native-trycatch memory; the compiler exercises it for real, unlike hi.hexa; ② HexaVal boxed ABI + the x86_64 string-print ABI residual from N5; ③ multi-fn-alias resolution; ④ the exit/flush tail (the `exitflush_sigsegv_ab_inconclusive` state note — cc_self must survive its own exit path after writing the `.o`); ⑤ i64→BigInt promotion paths in constant folding. One caveat to record in the log: stage-6 uses `--ignore-errors` — capture the frontend error count so a silently-skipped function body can't masquerade as a byte-diff.

**This becomes next session's first move:** step 0–2 on aiden/summer, verbatim.
