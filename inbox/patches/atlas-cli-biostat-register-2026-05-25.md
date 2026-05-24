---
slug: atlas-cli-biostat-register-2026-05-25
status: open
severity: P1
discovered: 2026-05-25
discoverer: claude/demiurge LPA cycle 6 M12
filed_from: demiurge (cross-domain: LPA · ISR · DAPTPGX · HERPES · NOREFLOW)
related: PR #709 (verify_cli biostat impl · MERGED 2026-05-25)
---

# atlas_cli.hexa::_recompute_register — biostat dispatch missing (L2 wall)

## Summary

PR #709 (verify_cli biostat impl) added `nnt`, `arr`, `ln_hr_to_hr` to
`tool/verify_cli.hexa::_recompute_float`. The `hexa verify --expr` path
now works: 🟢 SUPPORTED-NUMERICAL achieved across 5 demiurge domains.

But `hexa atlas register --from-verify <biostat_fn>` still returns
🟠 INSUFFICIENT — `_recompute_register` in `tool/atlas_cli.hexa` has its
own dispatch table that wasn't touched by PR #709. So 🟢 cannot promote
to 🔵 (atlas-registered closed-form) — the **L2 atlas-register wall**.

## Symptom (verbatim, post-PR #709 binary rebuild)

```
$ hexa verify --expr nnt 4 25
verify --expr nnt(4)=25
  calc   = 25  ≈ expected 25  (|Δ|=0.0 ≤ ε=1e-9)
  tier   = 🟢 SUPPORTED-NUMERICAL  (hexa-native libm-class recompute, TECS-L n6-rep Tier2)

$ hexa atlas register --from-verify nnt 4 25 --auto-pr
hexa atlas register --from-verify nnt(4) = 25
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'nnt'
  gap    = extend tool/atlas_cli.hexa::_recompute_register (계산기시스템 개선 후보)
```

Same gap message as pre-PR #709 — but now the cause is `atlas_cli`-side
(not `verify_cli`-side). L1 wall resolved · L2 wall remains.

## Two-layer wall structure

```
사용자 claim
    ↓
hexa verify --expr <bio_fn>     L1: calc fn wall
    ↓                           ✅ PR #709 resolved nnt/arr/ln_hr_to_hr
🟢 SUPPORTED-NUMERICAL ─────────────────────────────────┐
    ↓                                                    │
hexa atlas register --from-verify   L2: register wall   │
    ↓                           ❌ STILL BLOCKED         │
🟠 INSUFFICIENT                                          │
    ↓                                                    │
🔵 SUPPORTED-FORMAL unreachable (atlas 미등록)           │
                                                         │
This patch ──────────────────────────────────────────────┘ unblocks L2
```

## Cross-domain confirmation (5 domains stuck on L2)

| Domain | claim count blocked | next-cycle 🔵 unlock estimate |
|---|---|---|
| LPA | 4 (nnt · arr · ln_hr_to_hr · IVW) | +4-6 |
| ISR | 5-7 (per V1 inventory) | +5-7 |
| DAPTPGX | 3-4 (PM/HBR/ICER) | +3-4 |
| HERPES | 3-5 | +3-5 |
| NOREFLOW | 4-6 (Schoenfeld · NNT 등) | +4-6 |
| **누적** | **~19-28** | **+19-28 🔵 promotion** |

## Suggested fix (mirror PR #709 pattern, atlas-side)

`tool/atlas_cli.hexa::_recompute_register` likely has an `is_known_fn`
gate + dispatch similar to `tool/verify_cli.hexa::_recompute_float`.
Add the same 3 biostat fns + future-proof for the bio Phase 2 set:

```hexa
// In tool/atlas_cli.hexa, mirror verify_cli pattern:
fn _is_register_eligible(fn_name: string) -> bool {
    return /* existing number-theory + bio Phase 1 + bio Phase 2 */
        || fn_name == "nnt"
        || fn_name == "arr"
        || fn_name == "ln_hr_to_hr"
        // also: hill, cheng_prusoff, fick1, laplace, stokes_einstein
        // (bio Phase 2 from concurrent PR aa8a691f — same L2 wall)
}

fn _recompute_register(fn_name: string, args: [float], expected: float) -> RegisterResult {
    // delegate to verify_cli._recompute_float (DRY), then wrap as
    // RegisterResult { atom_id, witness_kind: F, claim, tier: 🔵 }
    let calc = _recompute_float_external(fn_name, args)
    if abs(calc - expected) < EPS {
        return _build_witness_shard(fn_name, args, calc, expected)
    }
    return RegisterResult.insufficient
}
```

## Test plan (post-fix)

```bash
# Pre-fix (current): 🟠
hexa atlas register --from-verify nnt 4 25 --auto-pr  # → 🟠

# Post-fix expected: 🔵 + auto-PR for witness shard
hexa atlas register --from-verify nnt 4 25 --auto-pr
# → calc=25 ≈ 25 (|Δ|=0.0)
# → tier = 🔵 SUPPORTED-FORMAL
# → atlas.append.witness-<ts>-F-nnt.n6 staged
# → gh PR opened for daily-aggregate fold
```

## Acceptance

- [ ] `hexa atlas register --from-verify nnt 4 25` returns 🔵
- [ ] `hexa atlas register --from-verify arr 20 16 4` returns 🔵
- [ ] `hexa atlas register --from-verify ln_hr_to_hr -0.342490 0.7100002193522448` returns 🔵
- [ ] same for hill/cheng_prusoff/fick1/laplace/stokes_einstein (bio Phase 2)
- [ ] CI smoke test added

## Cross-reference

- `demiurge/LPA/M12_binary_verify.md` — L2 wall first demonstrated
- `demiurge/LPA/verify/V2_formal_identities.md` — original V2 attempt
  (Before PR #709 · 0/8 due to L1 wall)
- hexa-lang PR #665 — original inbox note (LPA IVW MR formula request)
- hexa-lang PR #709 — L1 resolution (verify_cli biostat impl, MERGED)
- This patch — L2 resolution proposal (atlas_cli biostat register)
