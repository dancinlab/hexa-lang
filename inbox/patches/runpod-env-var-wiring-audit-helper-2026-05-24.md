# `hexa cloud` / runpod — dispatcher → train script env-var wiring audit (G5)

> **Status (impl-in-flight):** filing PR #662 MERGED 2026-05-24. Option A 구현 (`cloud_validate_env_passthrough` + 8/8 falsifier 케이스) `feat/runpod-env-passthrough-audit-2026-05-24` 에서 LANDING 중. Sibling to PR #627 (G1-G4) — 별도 patch 로 분리 (g54 review-only 준수).

**Reporter**: anima (`dancinlab/anima` downstream consumer, LORA / R8 saga 도메인)
**Severity**: high (~$10+ sunk cost — mis-attributed axis measurements; 자연실험이 trivial identity 였음이 사후 발각)
**Affected**: `stdlib/cloud/runpod.hexa`, `hexa cloud preflight`, dispatcher ↔ train-script wiring 일반
**Siblings**:
- `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` (PR #627, OPEN) — G1 stale-code race · G2 wall-time variance · G3 OOM mis-classify · G4 fan-out aggregated SSOT
- `cloud-runpod-session-findings-anima-2026-05-23.md` — R1-R4 (R1 fixed: `runpod_list_pods()`)
- `cloud-cli-operational-improvements-anima-2026-05-20.md` — P1-P11 (still open)

## G5 — dispatcher env-var 가 train script 에 안 닿음 (silent-bypass)

**Symptom**: anima AXIS_MAP-FAN saga 의 "7-axis" fan-out 이 실제로는 **2-config 만 측정**.
dispatcher (`dispatch_p21h_v3_runpod.sh`) 의 6 axis env-var 가 train script
(`train_p21h_v3.py`) 의 argparse 에도 없고 `os.environ` 으로도 안 읽힘. 결과적으로
train script 입장에서는 "옷"만 다르게 포장된 동일 config 가 7번 실행됨. dispatcher 가
fan-out 한 7개 pod 중 **6개는 byte-equal output** (cluster X/Y/Z = trivial identity,
자연실험 = ∅).

**Root cause** (anima 측 train script 의 wiring 누락):

- `train_p21h_v3.py` (676 LoC) — `os.environ` / `getenv` / `argparse` env-axis flag = **0건**
- `dispatch_p21h_v3_runpod.sh` — env-var 정의는 있으나 train script `$CMD` 에 `--axis-foo=$FOO` 형태로 미전달
- 결과: dispatcher 의 env-var 가 무용지물 → 자연실험 결과 무효 → axis sweep 결론 unfalsifiable

**Cost impact**: R8 saga 총 ~$21.54 중 axis re-test 부분 (~$10) sunk cost.
cluster X/Y/Z byte-equality 가 자연실험이 아니라 trivial identity 였음 (cycle 15 사후 audit).

**Why this is a `hexa cloud` gap (downstream 측 wiring 만의 문제가 아님)**:

downstream 의 wiring 실수는 흔함 (휴먼). 하지만 `hexa cloud` 는 **dispatcher 가 정의한
env-var 가 실제 train command 에 전달되는지 + train script 가 그것을 consume 하는지**
를 **pod 발사 전에** 검출할 수 있는 위치에 있음. preflight 단계에서 mem-budget check
와 동급의 "config plumbing audit" 가 fan-out cost 의 자연 hedge.

## Suggested patch (hexa cloud side)

### Option A — `stdlib/cloud/runpod.hexa` 새 helper

```hexa
// stdlib/cloud/runpod.hexa
fn cloud_validate_env_passthrough(
  dispatcher_script: string,    // e.g. "dispatch_p21h_v3_runpod.sh"
  train_script:      string,    // e.g. "train_p21h_v3.py"
  env_vars:          [string],  // ["AXIS_LR", "AXIS_BSZ", ...]
) -> #{ ok: bool, missing_passthrough: [string], missing_consumption: [string] }
```

동작:

1. **parse dispatcher_script** — env-var assignment (`AXIS_LR=...`) + `$CMD` / `python ... train_script` 라인에서 `--axis-lr=$AXIS_LR` 형태 passthrough 패턴 확인
2. **parse train_script** — Python argparse (`add_argument("--axis-lr")`) 또는 `os.environ.get("AXIS_LR")` 또는 `os.getenv("AXIS_LR")` 형태 consumption 확인
3. **assert**: 모든 env-var ∈ env_vars 가 양쪽에 wired
4. **dry-run-fail 시** dispatcher 에 warning + 발사 거부 (강제 override = `--allow-unwired-env`)

### Option B — `hexa cloud preflight` sub-check 로 통합 (선호)

기존 closed-form mem-budget check 와 같은 surface 에:

```
$ hexa cloud preflight --dispatcher dispatch_p21h_v3_runpod.sh \
                       --train train_p21h_v3.py \
                       --env-axis AXIS_LR,AXIS_BSZ,AXIS_HEAD_LR
mem-budget:               ✓ 38.4 GB / 80 GB
env-var passthrough:      ✓ AXIS_LR, AXIS_BSZ
env-var consumption:      ✗ AXIS_HEAD_LR not read in train_p21h_v3.py
verdict: REFUSE (use --allow-unwired-env to override)
```

Option B 가 surface 통합도 + LLM-free closed-form check 라는 preflight contract 와 자연
부합. parse 측은 regex 수준이면 충분 (Python argparse 시그니처 + `os.environ.get`).

## Falsifier (fix landing 시 검증)

- F-G5-1: dispatcher 가 정의한 `AXIS_FOO` 가 train script 에 전달 안되면 preflight REFUSE
- F-G5-2: train script 가 `--axis-foo` argparse + `os.environ.get("AXIS_FOO")` 둘 중 하나라도 있으면 PASS
- F-G5-3: `--allow-unwired-env` override 시 warning + 발사 허용 (CI/test escape hatch)
- F-G5-4: regex parse 가 multi-line `$CMD` (line-continuation backslash) 처리
- F-G5-5: bash `${AXIS_FOO:-default}` 형태도 passthrough 로 인식

## Cross-references (downstream evidence trail)

- `dancinlab/anima` — `state/grid_3b_s187_2026_05_21/train_p21h_v3.py` (env-var 0 reads, evidence)
- `dancinlab/anima` — `HEXAD/PURE/R8_SAGA_REFRAMING_2026_05_24.md` (cycle 16 sister) — saga reframing
- `dancinlab/anima` — `HEXAD/LIFE/H_257_axis_map_fan_env_var_silent_bypass.md` (cycle 16 sister) — 가설 문서
- `dancinlab/hexa-lang` PR #627 — G1-G4 (sibling orchestration gaps)

## 1줄 요약

dispatcher 가 정의한 env-var 가 train script 에 닿는지 (passthrough + consumption)
`hexa cloud preflight` 단계에서 검출 못하면, fan-out 자연실험이 trivial identity 로
조용히 무너지고 cost 가 sunk 됨 — 동급의 closed-form audit helper 필요.
