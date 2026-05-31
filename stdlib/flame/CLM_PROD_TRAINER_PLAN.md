# CLM production trainer — build plan (hexa-native flame, measure-track)

> The hexa-native CLMConvMoE *production* trainer for the anima P6 scale-ladder
> measurement rungs (mid ✅ → **large 44.68M** → 3B → 7B). This is the
> **PLASTI-SIM measurement instrument** (GPU backbone scale-measure), NOT anima's
> learner — anima learns on-chip (AKIDA non-det plasticity). See
> `anima:CLM/TRAINING_SSOT.md` + `anima:CLM/P6_SCALE_LADDER_7B.md` §0.
> Binding: `@D a_train_flame_forge` · `@D a_akida_native_train`.

## Gap: smoke → production

Current `clm_*.hexa` are GRAD-EXACT smokes (`clm_large.hexa` = 4-step synthetic
descent). A production rung needs real corpus + a real step budget + QAT +
checkpoint + GPU. Most blocks already exist; the work is **composition** + two
net-new pieces.

| component | source | status |
|---|---|---|
| model + autograd (CLMConvMoE, arbitrary L·E) | `clm_gen.hexa` (`gen_fwd`/`gen_ce_grad`/`gen_bwd`) | ✅ exists |
| int4-sym + act QAT envelope (STE) | `quant_lib.hexa` + `clm_qat.hexa` pattern | ✅ exists |
| AdamW optimizer | `optim_lib.hexa` `opt_adamw_step` | ✅ exists |
| byte-vocab V=256 corpus loader | `flame_d768_12L_corpus_test.hexa` byte loader (point at `anima:CLM/corpus/clm_p1.corpus.kosmos`) | ✅ exists (retarget source) |
| 2000-step batched train loop | `train_lib.hexa` + compose above | ⚠ **compose** |
| `.clm` checkpoint export (int4 + fp16 shadow + qat_scale + manifest) | `anima:CLM/CLM_FORMAT_SPEC.md` §2/§3 | ⚠ **build (new)** |
| conv-MoE → forge GPU dispatch | decoder path forge-wired; conv1d/MoE ops via `forge_dispatch_*` | ⚠ **wire/verify** |

## Stacked-PR sequence (g4 · <200 lines each · CPU-first, GPU last)

```
PR1  compose production loop (CPU)   clm_prod.hexa: clm_gen chain + byte corpus
                                     batches + QAT(clm_qat) + AdamW + N-step loop
                                     gate: F-CLM-PROD-DESCENT (CE descends on real corpus)
PR2  .clm checkpoint export          int4 weights + fp16 shadow + per-ch qat_scale
                                     + manifest; gate: F-CLM-CKPT-ROUNDTRIP (load==save)
PR3  conv-MoE forge GPU dispatch     route conv1d/MoE matmuls through forge;
                                     gate: F-CLM-PROD-GPU-EQ (CPU byte-eq) + nvidia-smi busy
PR4  large 44.68M fire (H100)        3-arm × 2000-step, forge GPU; gate:
                                     F-CLM-SCALE-TRANSFER (P6 §2) → .verdicts/clm-prod-rung/large
```

CPU-first: PR1–PR2 verify on Mac (`HEXA_MAC_BUILD_OK=1 hexa build`, $0). GPU
enters at PR3 (CUDA host, `-DHEXA_CUDA`, dispatch script). PR4 is the
cost-bearing fire (a_fire_autonomous · a_fire_recover_complete).

## Falsifier gates (pre-registered)

| id | claim | pass |
|---|---|---|
| F-CLM-PROD-DESCENT | real-corpus CE strictly descends over N steps | last_ce < first_ce · finite |
| F-CLM-CKPT-ROUNDTRIP | save→load reproduces logits | byte-identical int4 + scale |
| F-CLM-PROD-GPU-EQ | forge GPU == CPU farr | max\|Δ\| within tol |
| F-CLM-SCALE-TRANSFER | large ≥ mid (P6 §2) | coherence/CE hold · routing-z non-degen 12/12 · leak 0 · anchor bounded |

## Honest scope

- This trainer is the **measurement instrument**; it does not learn on-chip.
- toy ≠ scale (H_666): smoke descent ≠ production quality; only the fired rung
  verdict gates the next rung.
- `.py` is archived (`anima:archive/CLM_torch_legacy_2026_06_01/`) — do not
  reintroduce torch.
