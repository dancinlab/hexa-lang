# kernels/logic_synth/ — ①a logic-synthesis kernel (demiurge design.md D72)

Domain-agnostic RTL logic-synthesis kernel. The SEVENTH kernel
extracted under the D72 2-layer STDLIB restructure (after
`kernels/graph/`, `kernels/fem/`, `kernels/orbital/`,
`kernels/wave_optics/`, `kernels/mc_transport/` and
`kernels/noc_sim/`).

Like `noc_sim`, this is a **hexa-native** kernel: six interdependent
`.hexa` modules absorbed clean-room under rfc_006 from Yosys. The
2-layer restructure relocates the domain-independent synthesis
engine here; the chip-domain CLI + §5 gate-runner stay in
`stdlib/yosys/` as the ①b adapter.

| file | role |
|---|---|
| `rtlil.hexa` | Yosys RTLIL IR data model — `Design` / `Module` / `Cell` / `Wire`; constructors + design-merge helpers. |
| `read_verilog.hexa` | clean-room Verilog frontend — parse a Verilog subset into RTLIL. |
| `passes.hexa` | synthesis passes — `hierarchy` / `proc` / `flatten` / `opt` / `techmap` / `dfflibmap` / `opt_clean`. |
| `liberty.hexa` | Liberty (`.lib`) parser + cell-area aggregation. |
| `abc_map.hexa` | ABC technology-mapping bridge (D18 absorbed bounded-subprocess substrate). |
| `write_verilog.hexa` | RTLIL → Verilog backend (gate-level netlist emit). |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No SKY130 router_d4/d6
  area oracle, no rfc_006 §5 gate vocabulary — pure "Verilog in →
  RTLIL → mapped gate-level netlist + area out". Reusable by any
  RTL→netlist flow.
- **①b adapter** — `stdlib/yosys/yosys.hexa` (the `hexa yosys` CLI:
  `read-verilog` / `write-verilog` / `synth`) and
  `stdlib/yosys/gate_record.hexa` (the rfc_006 §5 gate-runner that
  scores the chip area oracle: d4 ≈ 61762.99 µm² · d6 ≈ 93608.53 µm²
  · ratio 1.5156×). Each owns the chip gate vocabulary + honesty
  caveats and calls this kernel for the synthesis math.

## Why

`chip+synthesize` rides the full hexa-native synthesis pipeline
(read_verilog → passes → liberty → abc_map → write_verilog).
Extracting the shared kernel means a future second synthesis
consumer shares 1 engine (N×M → N+M). The day the engine + the
ABC substrate close the rfc_006 §5 measurement gate, `absorbed=true`
flips HERE — once — instead of in every domain adapter.

## Honesty (g3)

Every engine module carries its own clean-room provenance header —
the public surface of the named Yosys file re-derived by inspection
only, no upstream code copied. ABC is an external bounded
subprocess (D18); `abc_map.hexa` fails loud if the binary is absent.
The §5 measurement-gate honesty (`measurement_gate`, `absorbed`,
`scope_caveats`, the SKY130 area oracle) lives in the ①b adapter,
NOT here.

## Callers

- `stdlib/yosys/yosys.hexa` — `hexa yosys` CLI dispatcher
  (demiurge `chip+synthesize`).
- `stdlib/yosys/gate_record.hexa` — rfc_006 §5 gate-runner record.

Both adapters import the kernel via `use "stdlib/kernels/
logic_synth/<module>"` (repo-root-relative), so the demiurge
`hexa run yosys.hexa` spawn resolves regardless of cwd — the
adapter paths are unchanged, so no Producer/Loader change is needed.
