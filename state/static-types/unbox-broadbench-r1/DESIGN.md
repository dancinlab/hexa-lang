# L4 unbox broad-bench r1 — HEXA_UNBOX_HIR_CALLTYPE global default-ON flip gate

## Why

`HEXA_UNBOX_HIR_CALLTYPE` is **merged** (#4875, default-OFF). The r1 measure
(`state/static-types/unbox-hir-calltype-r1/measure.sh`) proved the lever fires on
ONE kernel — `k6_callres` = `xs.len() * i` — at **0.750× CPU (25% faster)** with
`k1_sum` as the byte-identical call-less control. A single-kernel win does **not**
justify the GLOBAL default-ON flip. This round is the **breadth grid** that the
flip decision needs: does the flip (a) never regress code it should not touch, and
(b) fire across varied builtin-method call-results — hoistable, non-hoistable, and
a real compiler hot-loop proxy?

## What it measures

The **only** toggled variable is `HEXA_UNBOX_HIR_CALLTYPE` (OFF vs ON) on ONE
`aprime_cc` built from `$BR` (default `origin/main`). `HEXA_UNBOX_NATIVE` (the
native ALU path) is held default-ON in both arms so the sole delta is the
call-result type stamp.

### Kernels (`*.hexa`, committed alongside)

| group | kernels | expectation |
|---|---|---|
| CONTROL (flip unreachable) | `k1_sum`, `k2_branch`, `k3_arridx` | OFF `.o` == ON `.o` byte-identical (broad-regression safety proof) |
| TARGET · hoistable | `k4_arrlen` (== r1 anchor), `k5_strlen`, `k6_idxof` | ON `<` OFF call-count; ratio < 1.0 |
| TARGET · non-hoistable | `k7_byteat`, `k8_charcode` | dynamic call arg (`i%n`) → not liftable; stamp must still fire |
| REAL-WORKLOAD proxy | `k9_scan` | lexer inner loop; also probes let-binding type propagation (coverage boundary) |

`k3_arridx` (array **index**, not a method call) is the tight neighbour of the
TARGET group and guards against the stamp widening from method calls to
subscripts. `k9_scan` binds call results to a `let` before use — if ON shows no
call-count drop there while k4-k8 do, the flip's coverage is inline-use only and
the next round is named (let-binding type propagation), a finding not a failure.

## Gates & verdict

Per kernel: **G1** control-byteeq (BLOCKING for CONTROL), **G2** call-count lever,
**G3** median-CPU ratio ON/OFF (`-nostartfiles` link — runtime.a owns `_start`),
**G4** parity (BLOCKING, all kernels), **G5** ship smoke. The script prints a
summary table + a `FLIP-READY` / `FLIP-NOT-READY` verdict:

> FLIP-READY (local probe) ⟺ all CONTROL G1 PASS ∧ all G4 PASS ∧ TARGET geomean
> ratio < 1.0 ∧ no TARGET kernel ratio > 1.02.

The authoritative ship gate remains PR-CI **byteeq 3-target GREEN + shipping
smoke** — this harness is the local no-regression probe that decides whether to
open that flip PR.

## Run (pool — NOT mini)

```
scp state/static-types/unbox-broadbench-r1/measure.sh <host>:~/l4_broadbench_measure.sh
ssh <host> 'nohup bash ~/l4_broadbench_measure.sh >~/l4_broadbench.nohup 2>&1 &'
# harvest: ssh <host> 'cat ~/l4_broadbench_RESULT.txt'
```

Adapted 1:1 from `state/static-types/unbox-hir-calltype-r1/measure.sh` +
`state/unbox-native-r{5,6}/measure*.sh` (same seed-prep, CPU-runtime.a locate,
load-gate, single-SSH detached discipline).
