# kernels/circuit/ — circuit-simulation kernel (demiurge design.md D72)

Domain-agnostic circuit-simulation kernel — SPICE `.lib` parsing,
device-physics DC modelling, and TCAD drift-diffusion bridging.
Extracted under the D72 2-layer STDLIB restructure, alongside
`kernels/noc_sim/` and `kernels/logic_synth/`.

Like `noc_sim` and `logic_synth`, `circuit` is a **hexa-native**
kernel: interdependent `.hexa` modules absorbed clean-room (no `.py`
wrapper). The 2-layer restructure relocates the domain-independent
circuit engine here; the SiC power-domain CLI surface stays in
`stdlib/sscb/` as the ①b adapter.

| file | role |
|---|---|
| `wolfspeed.hexa` | SPICE `.lib` lexer + `.SUBCKT … .ENDS` parser; `.PARAM` resolver; `.MODEL` reader (VDMOS / D / Q kind preserved). Domain-agnostic SPICE-syntax front end. |
| `vdmos.hexa` | hexa-native VDMOS Level-1 (Shichman-Hodges square-law) DC device model + 1-D Newton operating-point solvers for R_DS(on) / V_GS(th). Zero subprocess — pure hexa arithmetic. |
| `devsim.hexa` | DEVSIM TCAD bridge — generates + spawns a DEVSIM Python script for a 1-D Si PN-diode drift-diffusion I-V sweep, parses the rows. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No SSCB 600 V / 100 A
  topology, no snubber sizing, no F1F2-record schema — pure "SPICE
  `.lib` / device parameters in → typed AST / DC operating point /
  I-V curve out". Reusable by any circuit study.
- **①b adapter** — `stdlib/sscb/` (`sscb.hexa` dispatcher,
  `ngspice.hexa` SSCB hard-switching transient producer,
  `wolfspeed_parity.hexa` C3M0021120K datasheet-parity orchestrator).
  Each owns the SSCB domain topology + fixtures + honesty caveats and
  calls this kernel for the circuit math.

## Why

`sscb+analyze` and `sscb+verify` both ride the same SPICE-parser /
VDMOS-DC / DEVSIM engine modules. Extracting the shared kernel means
N studies share 1 engine. The day the hexa-native circuit engine
passes a transient SPICE parity round, `absorbed=true` flips HERE —
once — instead of in every domain adapter.

## Honesty (g3)

Every engine module carries its own clean-room provenance header
(SPICE syntax is public — Berkeley 1973; DEVSIM is Apache-2.0). No
upstream `.lib` bytes or simulator source is copied. The
measurement-gate honesty + datasheet fixtures live in the ①b adapter
`stdlib/sscb/`, NOT here.

## Callers

- `stdlib/sscb/sscb.hexa` — `sscb` CLI dispatcher.
- `stdlib/sscb/vdmos_test.hexa` / `devsim_test.hexa` /
  `wolfspeed_test.hexa` — engine selftests (kept beside the SSCB
  datasheet fixtures they consume).

All callers import the kernel via `import "stdlib/kernels/circuit/
<module>"` (repo-root-relative). The SSCB adapter paths
(`stdlib/sscb/ngspice.hexa` etc.) are unchanged, so no demiurge
Producer/Loader change is needed.
