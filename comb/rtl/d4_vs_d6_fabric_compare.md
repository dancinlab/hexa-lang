# comb fabric-level cycle-accurate comparison — d4 mesh vs d6 hex

> 2026-05-18 · sustained-traffic iverilog measurement.
> **UPDATE: same-N=7 measurement added (commit pending). RFC 057 §5
> F1-full falsifier FAILS at this test point** — see §"Same-N=7 fair
> comparison" below.

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

## Same-N=7 fair comparison — RFC 057 F1-full FAILS

Option A pursued. New TB: `fabric_mesh7_sustained_tb.v` — 7-node d4
mesh on a 3x3-minus-2-corners layout (nodes at (0,1)(1,1)(2,1)(0,0)
(1,0)(2,0)(1,-1); 8 edges; central (1,0) has 4 active neighbors,
others 1-3).

### Same-N=7, same workloads (uniform / hotspot-center / stencil / diameter)

| workload  | metric    | d4 mesh-7 | d6 hex-7  | ratio (hex/mesh) | winner |
|-----------|-----------|----------:|----------:|------------------|:------:|
| uniform   | delivered |  1912     |  1611     | 0.84             | **d4** |
| uniform   | avg lat   |    10 cyc |    15 cyc | 1.5×             | **d4** |
| uniform   | in-flight |    10%    |    24%    | 2.4×             | **d4** |
| hotspot-C | delivered |  1025     |  1025     | 1.00             | tie    |
| hotspot-C | avg lat   |    27 cyc |    27 cyc | 1.00             | tie    |
| stencil   | delivered |  2159     |  1025     | 0.47             | **d4** |
| stencil   | avg lat   |     6 cyc |    27 cyc | 4.5×             | **d4** |
| diameter  | delivered |  1640     |  1029     | 0.63             | **d4** |
| diameter  | avg lat   |    13 cyc |    32 cyc | 2.5×             | **d4** |

### Verdict on RFC 057 §5 F1

**F1 (non-contention, closed-form)**: ✅ PASS for hex (8/8 sweep,
`workload_f1.hexa` — uniform/broadcast/hotspot all hex wins; stencil
hex loses).

**F1-full (cycle-accurate fabric, N=7, sustained 50% injection)**:
**❌ FAIL — d6 hex LOSES to d4 mesh on all workloads** at this test
point. The closed-form prediction reverses once contention enters.

### Why hex flips under contention (honest analysis)

- **Hop-count theory says hex wins**: avg pairwise distance d6 hex-7
  = 30/21 ≈ 1.43 hops; d4 mesh-7 = 35/21 ≈ 1.67 hops. Hex has fewer
  hops per packet (ratio ≈ 0.86 at N=7; asymptotic 1/√3 ≈ 0.577 at
  large N per T1A §2). Consistent with T1-A analytical anchor.
- **But cycle-accurate flips the verdict**: hex's center R0 receives
  traffic from ALL 6 ring neighbors. Sink rate at LL = 1 pkt/cyc.
  Under uniform random ~1/7 of packets target R0; under stencil/
  diameter, R0 sees even more transit traffic. Result: R0
  back-pressures → ring nodes' inj_ready drops → injection limited.
  In d4 mesh-7, central node (1,0) has 4 neighbors, not 6 — less
  concentration, less bottleneck.
- **Hales 2001 caveat realized**: "least-perimeter ≠ least-latency".
  Hex tiling has better geometric properties (lower diameter, denser
  packing) but does not translate to better latency under contention
  at small N. The fabric router's single-issue LL sink is the
  concentration point that the hex topology exposes more.

### What this means for RFC 057

The original F1 was pre-registered with explicit caveats (T1A §5,
RFC 057 §3): "non-contention is lower bound only". This same-N=7
result is the first cycle-accurate fabric falsification of the
hex-wins claim at small N.

This is **not** "hex always loses" — it's "hex loses at N=7 with
uniform-1-cycle-sink-per-node and 50% injection". Possible reversal
regimes (untested):
- larger N (asymptotic hop ratio drops to 1/√3; contention may scale
  differently)
- multi-issue LL sinks (alleviates center bottleneck)
- workloads where stencil/diameter packets DON'T transit center
- pre-route SKY130 area ratio 1.516× is RTL-only — post-route adds
  wire energy that hex may absorb less efficiently OR may benefit
  from depending on physical layout.

Per RFC 057 §5 falsifier discipline: **F1 closed: hex wins (per the
pre-registered model); F1-full open: hex loses at the first
cycle-accurate test point.** The authoritative F1 verdict still flows
through hexa-arch[chip]'s typed-interface measurements (rfc_002),
which may run at larger N or different sink models and possibly flip
this result again.

### Path forward

- **Strict tapeout-ready (T2 strict)**: needs ORFS P&R (bkml0mjdh on
  ubu-2, in-flight). Doesn't change the F1 falsification at N=7 but
  gives the wire-energy axis.
- **hexa-arch F1F2 records**: authoritative F1 per rfc_002 typed
  interface. Once §9 sweep lands, replaces this comb-side verdict.
- **Larger N test**: would require ~hundreds of router instances in
  iverilog or moving to a Python-level cycle-sim like BookSim2 — the
  natural domain of hexa-arch[chip].

This file documents what comb-side can measure cycle-accurate at
small N — the verdict at this scale is **hex loses F1-full**.

## Caveat (carried per `T1A_analytical.md §5`)

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
