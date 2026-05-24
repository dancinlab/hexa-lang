# N70 → N91 cycle closure summary

date: 2026-05-21
final outcome: **PARTIAL — gaps A+B closed, gap C newly diagnosed**

## chain progression

| cycle | event                                                         | commit       |
|-------|---------------------------------------------------------------|--------------|
| N70   | First fire — kernel hung, 2 gaps (A, B) diagnosed             | baseline     |
| N71-A | gpu_warp_shuffle_xor → shfl.sync.bfly.b32 wiring               | 9d21356c     |
| N71-A | re-apply target.hexa hunk after staging conflict (BUT wiped   | 7671d7db     |
|       | both PTX_OP_SHFL_SYNC_BFLY_B32 const AND N71-C div edits)     |              |
| N71-C | integer / → div.s64/.s32 wiring                                | 9652fd5e     |
| N81   | re-fire attempt → driver build FAIL; BFLY const wipe diagnosed| (BLOCKED)    |
| N81   | restore PTX_OP_SHFL_SYNC_BFLY_B32 const                       | 842d6565     |
| N91   | this re-fire — silicon-reached but gap C surfaced              | (this cycle) |

## what N91 closed

1. **F-RFC071-E2E-DRIVER-BUILD PASS** — driver builds on main HEAD after the
   N81 BFLY restore AND a local re-restore of the N71-C div edits (mirror-class
   wipe; uncommitted per task constraint).
2. **F-RFC071-E2E-PTX-EMIT-CLEAN PASS** — emitted PTX contains
   `shfl.sync.bfly.b32` (1×) and `div.s64` (3×) with zero honest-stub
   `// unsupported binop` markers. Pure ASCII (driver-JIT safe).
3. **GAP-A closed** — gpu_warp_shuffle_xor → shfl.sync.bfly.b32 mnemonic
   wiring works at the codegen-emission level.
4. **GAP-B closed** — integer `/` → div.s64 wiring works at the
   codegen-emission level.

## what N91 surfaced (new — GAP-C)

```ptx
shfl.sync.bfly.b32 %r18, %r9, %r16, 0x1f, 0xffffffff;
add.s32            %r19, %fd9, %r18;
mov.f64            %fd9, %r19;
```

ptxas rejects with:
```
line 78; error : Arguments mismatch for instruction 'shfl'
line 78; error : Unknown symbol '%r9'
line 78; error : Unknown symbol '%r16'
```

**Root cause**: `_nvptx_lower_stmt` `gpu_warp_shuffle_xor` arm uses
`_nvptx_reg_u32(local_id)` → `%r<id>` regardless of source-operand kind.
When the kernel passes an FP64 `sum` (declared `%fd9`), the lowering still
spells it `%r9`, picking a slot in the u32 bank that was never declared.

The fixture's design note (L22-25) had anticipated this:
> [NOT WIRED — XOR butterfly variant of existing gpu_warp_shuffle(v, lane)
>  idx-mode; FP64-shuffle would compose from 2× u32 halves per PTX ISA
>  §9.7.13.4]

N71-A wired the PTX mnemonic but did NOT add the FP64 → 2× u32 split +
shfl + recompose wrapper. The "3-gap-chain" task assumption (N70 = A+B+C
with A and B closed by N71-A+N71-C and C implicit) was off-by-one — gap C
is a distinct piece of work.

## costs

| dimension       | value                                                |
|-----------------|------------------------------------------------------|
| USD             | $0 (ptxas-reject before kernel launch)               |
| wall (minutes)  | ~5 (env + builds + emit + scp + nvcc + fire + docs)  |
| silicon-fires   | 1 (RTX 5070, JIT rejected at module-load)            |

## follow-on cycles (out of N91 scope)

1. **Commit the N71-C div re-restore** to compiler/codegen/nvptx_target.hexa
   (mirrors 842d6565 in spirit). 1-cycle, trivial.
2. **Close GAP-C** (FP64-shuffle composition): extend
   gpu_warp_shuffle_xor lowering to detect FP64 src and synthesize hi/lo
   u32 split + 2× shfl.sync.bfly.b32 + recompose per PTX ISA §9.7.13.4.
   Reusable across any future FP64 reduce/scan kernels.

## related patterns (memory entries)

- `reference_runtime_c_deploy_regen_wipe` — same wipe class. 7671d7db's
  silent N71-C drop is the codegen sibling of the runtime.c `\uXXXX`
  3-time landing pattern.
- `feedback_worktree_merge_silent_filedrop` — a manual conflict repair
  quietly dropped a load-bearing edit; pre-fire diff check is the
  countermeasure.
- `reference_hexa_basename_sigkill_workaround_2026_05_19` — used
  `/tmp/hexac` shim (hexa/hexa.real SIGKILL via wilson-pool).
- `reference_hexa_module_loader_env_2026_05_20` — 4-env-var setup applied.
- `reference_gpu_fire_infra` — pure-ASCII PTX + cuModuleLoadDataEx (not
  standalone ptxas) + plain `ssh ubu-2` (no SIDECAR_NO_POOL).
