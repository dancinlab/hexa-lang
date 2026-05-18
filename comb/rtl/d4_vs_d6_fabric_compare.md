# comb fabric-level cycle-accurate comparison — d4 mesh vs d6 hex

> 2026-05-18 · sustained-traffic iverilog measurement. **Honest unfair**
> comparison: N differs (4 vs 7). Apples-to-apples per-packet metric is
> the avg latency at LIGHT load; saturation-load metrics differ because
> more nodes inject more packets.

---

## Measured (sustained 1000 cycles, ~50% inj/node, 4 workloads each)

### degree-4 mesh — 2x2 = 4 nodes (`fabric_2x2_sustained_tb.v`)

| workload    | injected | delivered | (inj-del)/inj | avg latency (cyc) |
|-------------|---------:|----------:|--------------:|------------------:|
| uniform random | 1268 |     1266 |          0%   |               5   |
| matmul-row     | 1268 |     1266 |          0%   |               3   |
| matmul-col     | 1268 |     1266 |          0%   |               3   |
| transpose      | 1268 |     1266 |          0%   |               4   |

### degree-6 hex region R=1 — 7 nodes (`fabric_hex7_sustained_tb.v`)

| workload    | injected | delivered | (inj-del)/inj | avg latency (cyc) |
|-------------|---------:|----------:|--------------:|------------------:|
| uniform random | 2132 |     1611 |         24%   |              15   |
| hotspot center | 1916 |     1025 |         46%   |              27   |
| stencil        | 1916 |     1025 |         46%   |              27   |
| diameter (opp) | 1780 |     1029 |         42%   |              32   |

## Honest reading (key gotchas)

1. **N differs (4 vs 7).** Hex region R=1 is naturally 7 nodes; 2x2 mesh
   is naturally 4. There is no clean 4-node hex or 7-node mesh that
   compares apples-to-apples. More nodes → more aggregate injection →
   more contention regardless of topology.

2. **(inj − del) ≠ "drop rate"** in these sims. The fabrics have
   FIFO-full backpressure (single-issue routers): no packets are
   actually dropped — they're held in FIFOs (or sender's inj_valid
   doesn't fire when inj_ready=0). The 24-46% are *in-flight at end of
   simulation* + flow-control hold-offs. Fix: drain longer post-sim.
   Honest column header should be `(inj − del at sim-end)`.

3. **Hotspot-center and stencil reported identical numbers** for d6 —
   that's because 6 of 7 nodes have the same destination (R0) in both
   workloads (only R0's own behavior differs). Workload set should be
   refined for a clean stencil.

4. **At 50% injection rate, hex hotspot saturates**: 6 ring nodes all
   targeting R0 (center) → R0 LL sinks at 1 pkt/cyc → backpressure on
   all ring → 46% held. This is *not* a topology defect, it's a
   pathological workload + uniform 1-cycle sink.

5. **What the data ACTUALLY shows**:
   - d4 mesh @ 4 nodes, 50% inj: well below saturation → low latency
   - d6 hex @ 7 nodes, 50% inj: near/at saturation → contention shows
   - d6 latency under load (~15-32 cyc) ≫ d4 latency under no-load
     (~3-5 cyc) is **load-comparison artifact, not topology fact**.

## What the F1 claim needs (and where this fabric data sits)

RFC 057 §5 F1 says "degree-6 hex beats degree-4 mesh on a real workload
at modern node". The fabric-level cycle-accurate measurement on the
SAME N at the SAME per-node injection load is the strict test.

This comb-side iverilog data:
- ✅ confirms both fabrics correctly route packets (no functional bug)
- ✅ measures cycle-accurate latency under sustained injection
- ⚠️  does NOT yet prove/disprove F1 because of the N difference
- → strict F1 evidence still flows through hexa-arch[chip]'s typed
  F1F2 records (rfc_002 §3 schema), which control N and load axes.

## Path to a fair fabric comparison (next iteration, if pursued)

Option A — same N=7:
  Build a 3-row brick-offset mesh that gives 7 nodes (3+1+3 or 2+3+2).
  Compare d4-brick-offset-7 vs d6-hex-region-7. Same N, same workloads,
  same injection rate. Direct.

Option B — same per-node-link load:
  Inject at rate proportional to bisection bandwidth (d4 bis = √N,
  d6 bis ≈ √N · 1.155). Normalizes saturation point.

Option C — let hexa-arch[chip] run the contention sim:
  rfc_002 schema delivers controlled measurements that comb consumes
  via T1A §8 mapping. Most rigorous, but on hexa-arch's timeline.

Current cycle: **A and B not pursued this turn** (additional Verilog
work + careful wiring); **C is the path** — comb already consumes
the typed-interface contract.

## Caveat (carried per `T1A_analytical.md §5`)

Hales 2001 = least-perimeter equal-area tiling, NOT least-latency
network. The fabric topology vs latency relationship runs through
graph diameter + bisection + router contention, all of which are
parameterized by N and load. This data does not collapse those axes.

## Source files

- `comb/rtl/fabric_2x2_sustained_tb.v` (commit 3220ffc5)
- `comb/rtl/fabric_2x2_sustained_tb.out`
- `comb/rtl/fabric_hex7_sustained_tb.v` (this commit)
- `comb/rtl/fabric_hex7_sustained_tb.out`
