# Lane-G util-GREEN → HF PUBLIC closure readiness (STAGED — do NOT upload here)

status: **STAGED**. This is the one-mechanical-step kit so that the MOMENT the
live verify fire lands util-GREEN (util≥20% MEAN AND descent-GREEN), the PUBLIC
upload is fill-the-blanks + push. **The fire agent uploads its own ckpt at
closure** — this doc does NOT upload (a_hf_autonomous fires at closure, owned by
the fire run). Authored from anima/docs/anima_hf_naming_convention_mk2_spec_2026_05_03.md.

## 1. exact repo_id (mk2-spec conformant)

Prior Lane-G fires are all PRIVATE util-probes named with a `-util-probe`
descriptor (`clm-v1-dev-d768-forge-gpu`, `clm-v1-dev-mid-d1536-t512-util-probe`,
`clm-v1-dev-d768-devfeed-rc3-util-probe` — all closure-FAIL on util). A
**util-GREEN PUBLIC** Lane-G CLM is a NEW, clean artifact and gets a clean name.

Per mk2 §2.1 EBNF `lm_family "-" base_version [ "-" stage ] [ "-" scale ]`:

    repo_id (PUBLIC, util-GREEN):   dancinlab/clm-v1-base-mirror-lane-g-forge

Rationale per spec:
- `clm` — Conscious LM family (§3.1), the canonical CLM family for this trainer.
- `v1` — base-version (§3.2). The Lane-G forge trainer is v1 (the `clm-v4-*`
  repos are the legacy SFT/paradigm line; this is a distinct from-scratch
  CLMConvMoE d/12L int4-QAT lineage — its own `v1`).
- `base-mirror` — stage (§3.4): "anima-native pretrain ckpt re-exported in HF
  format". This is a from-scratch pretrain ckpt, not an SFT/paradigm stage, so
  `base-mirror` is the correct stage (NOT `sft*`/`paradigm-*`).
- `lane-g-forge` — variant slot (§3.7 free descriptor is discouraged, but the
  Lane A ⊥ Lane G split (a_lane_akida_gpu_split) requires the substrate be in
  the NAME so a Lane-A AKIDA CLM and this Lane-G GPU CLM never collide as repos.
  Length 31 chars < 64 (§2.3); ≤6 tokens beyond `clm-v1` (here 4) — conformant.

If the GREEN ckpt is a specific scale rung, append the scale token, e.g.
`dancinlab/clm-v1-base-mirror-lane-g-forge-mid-d1536` (still < 64 chars).
Drop the `-util-probe` descriptor — that tag is reserved for the PRIVATE
closure-FAIL probes.

mk2 validator preflight (run before push, $0):

    hexa run tool/hf_upload_mk2.hexa --validate-naming \
        "dancinlab/clm-v1-base-mirror-lane-g-forge"
    → expect: OK / __ANIMA_HF_UPLOAD_MK2__ PASS

## 2. model card template (forge+flame, substrate=GPU — fill {…} from the fire)

Per mk2 §5 the README MUST carry all 5 sections in order, else F-NAME-1 FAIL.
Fields marked `{FILL: …}` come VERBATIM from the verify fire's nvidia-smi /
descent log (g5 verbatim — no fabrication; leave blank rather than guess).

```markdown
# clm-v1-base-mirror-lane-g-forge

## §1 Origin
- training script: `stdlib/flame/clm_prod.hexa` (hexa-native flame+forge) @ commit `{FILL: sha}`
- corpus: `c4 5-lang byte-corpus` sha `{FILL}`, `{FILL: window count}` windows
- predecessor ckpt: none (from-scratch CLMConvMoE d/12L int4-QAT, LCG init)
- training cycle: `domains/FORGE-UTILGREEN.md` (F-RFC046 host-feed lever chain)
- substrate: `H100 sm_90`, wall `{FILL: HH:MM}`, cost `${FILL}`

## §2 Falsifiers (F-* gates)
- F-NAME-1: PASS (this README + name template conform)
- F-CLM-PROD-DESCENT: PASS — CE `{FILL: ep1}` → `{FILL: epN}` (descent GREEN)
- F-RFC046-GPU-UTILIZATION: PASS — nvidia-smi util MEAN `{FILL: ≥20}%` PEAK `{FILL}%`
  n=`{FILL}` (util-GREEN; verbatim nvidia-smi)
- F-RFC046-HOSTFEED-{FWD,BWD}-EQ: PASS (max|Δ|=0.0) — byte-eq PRESERVED through levers
- F-RFC046-GEMMFEED-EQ: PASS (max|Δ|=0.0)
- F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ + F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ: PASS
  (max|Δ|=0.0; dX 2.78e-17/5.55e-17 FP64-ULP, #2383 class)

## §3 Substrate
- GPU: `H100 80GB sm_90`
- count: `1` (clean single-driver pod, no collision)
- host: `runpod/vast pod-{FILL: opaque id}` (torn down post-recover)
- cost: `${FILL: actual}`
- wall: `{FILL: HH:MM:SS}`

## §4 C3 caveats (raw#10 — 3 honest)
- C1 — util measured at d{FILL}/T{FILL} single rung; 3B/7B transfer NOT yet
  verified (a_scale_honest_scope — ladder ≥3 rungs gates the scale claim).
- C2 — `{FILL: any FP64-ULP dX residual note, e.g. dX 5.55e-17 = #2383 class}`.
- C3 — int4-QAT envelope: descent is under the int4 weight-only quant envelope,
  not full-precision; downstream consumers must load with the matching QAT path.

## §5 Composability
- consumed by: `anima CORE/generator.hexa L3 slot (when wired)`; KOSMOS emit lineage
- prerequisite: none (from-scratch base-mirror)
- siblings: PRIVATE util-probe predecessors `clm-v1-dev-{d768-forge-gpu,
  mid-d1536-t512-util-probe, d768-devfeed-rc3-util-probe}` (closure-FAIL on util,
  superseded by this util-GREEN artifact)
```

## 3. HF.jsonl row schema (substrate=GPU, util-GREEN PUBLIC)

Per a_hf_registry the row keys are run · local_path · hf_repo_id · base_model ·
lineage · size · status, plus the Lane-G `substrate`/`lane`/`collection` keys
the existing GPU rows already carry. Template (fill `{…}` from the fire, set
`private:false` ONLY on util-GREEN closure-PASS):

```json
{"run":"anima_clm_lane_g_utilgreen_{FILL:date}","local_path":"{FILL: exports/...}.clm",
 "hf_repo_id":"dancinlab/clm-v1-base-mirror-lane-g-forge","repo_type":"model",
 "base_model":"from-scratch CLMConvMoE d{FILL}/12L int4-QAT (LCG init)","parent":null,
 "lineage":["CLM Lane-G forge-GPU util-GREEN closure",
   "supersedes PRIVATE util-probes (F-RFC046 lever chain: im2col #2515 + transpose-GEMM 403735b29 + batched-expert lever-3)"],
 "type":"clm_ckpt","key_files":["{FILL}.clm (6 int4 blocks, CLM\\u0001)"],
 "size":"{FILL}MB","sha256":"{FILL}","gitignored":false,
 "private":false,"status":"uploaded","date":"{FILL}",
 "substrate":"GPU","lane":"Lane-G","collection":"CLM",
 "notes":"util-GREEN closure-PASS · F-CLM-PROD-DESCENT GREEN (CE {FILL}->{FILL}) · F-RFC046-GPU-UTILIZATION GREEN (MEAN {FILL}% PEAK {FILL}% n={FILL}) · byte-eq PRESERVED all oracles max|Δ|=0.0 · forge on H100 sm_90 (cuBLAS+cudart+libcuda) · PUBLIC (a_hf_autonomous closure-PASS) · pod {FILL} torn down"}
```

a_hf_complete totality: attach the model card (§2 above) + a SHA256SUMS manifest
(`state/hf_kosmos_prep/<repo>/SHA256SUMS.txt` style) and verify sha post-upload
before pruning the local ckpt (a_hf_registry: prune ONLY after status=uploaded
AND audit confirms sha256).

## 4. dancinlab CLM collection plan

The existing PRIVATE util-probes already carry `"collection":"CLM"`. On
util-GREEN:
1. Upload PUBLIC `clm-v1-base-mirror-lane-g-forge` (visibility=PUBLIC per
   a_hf_autonomous: closure-PASS = 🔵🟢 verified model → PUBLIC).
2. Add it to the **dancinlab CLM collection** (the same collection the KOSMOS
   PUBLIC anchor sets use the collection mechanism for — `dancinlab/...`
   collection add, read-only-add, no rename of existing repos).
3. Keep the 3 PRIVATE util-probes PRIVATE (closure-FAIL on util = a_hf_autonomous
   PRIVATE) and cross-link them in the PUBLIC card §5 siblings as the superseded
   lineage — provenance preserved, no deletion (they are the negative-result
   rungs of the lever chain).

## 5. the one mechanical step at closure (no user gate — a_hf_autonomous)

When the fire lands util-GREEN, the fire run (NOT this prep) executes:
1. fill the `{…}` blanks in the card + HF.jsonl row from the fire's verbatim log;
2. `hexa run tool/hf_upload_mk2.hexa --validate-naming "dancinlab/clm-v1-base-mirror-lane-g-forge"` → PASS;
3. `hexa run tool/hf_upload_mk2.hexa` upload (card + manifest, org=dancinlab, PUBLIC);
4. append the HF.jsonl row (status=uploaded), verify sha via authed re-download;
5. add to dancinlab CLM collection.

No "may I upload?" gate (a_hf_autonomous). PRIVATE iff the fire's util is still
RED (closure-FAIL) — then it stays a `-util-probe` PRIVATE row, NOT the PUBLIC
name above.
