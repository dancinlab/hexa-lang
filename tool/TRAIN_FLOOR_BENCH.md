# 🐢 train_floor_bench — HEXA-TRAIN-FLOOR M5 A/B 측정대

hexa-native 학습기의 **step-rate**(step/s · s/step)를 **동일 모델/설정**에서
PyTorch baseline과 A/B로 비교하는 측정대(harness)다. `tool/unshadow_bench.hexa`
(UNSHADOW A/B 측정대)와 같은 패턴 — 두 arm, 같은 호스트, 같은 workload, 나란히
공정 비교, 페어드 ledger row.

- arm H **hexa-native** : anima 디코더 트레이너 (`train_v3_moe_longtrain.hexa`,
  DECODER M5 `STEP_RATE_LOG` 포맷 생산자).
- arm P **pytorch** : 동일 (d, layers, batch, seq)의 HuggingFace-Trainer
  causal-LM baseline. `hexa dojo llm` 으로 payload(`train.py`)를 굽는다.

> **이 측정대는 GPU를 직접 돌리지 않는다.** 비용 + cross-repo infra 때문에
> 라이브 측정은 honest defer (verdict 🟠). 측정대는 **로그를 파싱**해서 ledger를
> 만든다 — 실제 GPU fire가 두 arm 로그를 채운 *뒤에* 돌린다.

---

## 두 가지 모드

### 1. `--plan` — dispatch 명령만 출력 (GPU 안 돌림)

GPU pod에서 사람이 붙여넣을 두 arm의 cloud-dispatch 명령 한 세트를 출력한다.
**pod를 rent하지 않고, 비용도 안 든다.**

```
hexa run tool/train_floor_bench.hexa --plan \
    --d 64 --layers 1 --batch 1 --seq 512 \
    --host ubu-2 --slug tfb-d64
```

출력에는 ① d16 free import dry-run, ② arm H `hexa cloud nohup` 디스패치,
③ arm P `hexa dojo llm` emit + `bash run.sh`, ④ 로그 harvest + ledger 명령이
순서대로 들어있다.

### 2. `--ledger` — 두 arm 로그 파싱 → A/B ledger (측정 경로)

실제 GPU fire가 두 로그를 만든 *뒤에* 돌린다.

```
hexa run tool/train_floor_bench.hexa --ledger \
    --hexa-log /tmp/h.log --pytorch-log /tmp/p.log \
    --d 64 --layers 1 --batch 1 --seq 512 \
    --prod-steps 0 \
    --out state/perf/train_floor_ab.md \
    --jsonl state/perf/train_floor_ab.jsonl \
    --tag d64-h100
```

---

## 로그 포맷 (STEP_RATE_LOG 호환)

두 arm 모두 아래 토큰 중 하나로 step-rate를 로그에 남기면 측정대가 파싱한다
(**마지막 occurrence**가 steady-state로 채택됨):

| 지표 | 인식 토큰 (둘 중 아무거나) |
|---|---|
| step/s | `<n> step/s`  ·  `step_rate=<n>` |
| s/step | `<n> s/step`  ·  `sec_per_step=<n>` |
| peak RSS (MB) | `RSS <n>MB`  ·  `peak_rss_mb=<n>` |

DECODER 트레이너의 기존 `STEP_RATE_LOG` 출력(`<n> step/s`, `<n> s/step`)이
그대로 호환된다. PyTorch arm은 dojo payload에 `print(f"{sps} step/s ...")` 한 줄을
넣으면 된다 (payload re-emit 시 추가).

---

## Ledger 포맷

markdown 표 + JSONL row 동시 출력:

```
| backend     | step/s | s/step | peak RSS (MB) | GPU-days (prod) |
|-------------|--------|--------|---------------|-----------------|
| hexa-native | 0.280  | 1.990  | n/a           | n/a             |
| pytorch     | 12.500 | 0.080  | n/a           | n/a             |

Δ (pytorch_step/s ÷ hexa_step/s) = 44.642×  (>1 → PyTorch faster)
```

- **GPU-days (prod)** = `prod_steps / (step_per_s × 86400)`.
  `--prod-steps`(production token-presentation 예산)를 주면 환산되고, 0이면 생략(`n/a`).
- **Δ** = `pytorch_step/s ÷ hexa_step/s` (×). >1 = PyTorch가 빠름, <1 = hexa-native가 빠름.
- 두 arm 중 하나라도 step/s를 못 파싱하면 ledger는 **SKELETON**으로 표시되고
  `⚠ 🟠 INCOMPLETE` 가 찍힌다 (harness는 검증됐고, 실측만 대기 중).

baseline 참조값 (HEXA-TRAIN-FLOOR M1, DECODER STEP_RATE_LOG):
hexa-native **0.28 step/s (1.99 s/step) · 77~122 GPU-days · GPU util 0~8% · 🔴 INFEASIBLE**.
PyTorch 참조값은 동일 config 첫 fire에서 측정 후 ledger에 기록.

---

## GPU pod에서 돌리는 법 (env)

1. **import dry-run (FREE, d16)** — cost-bearing launch 전에 pod에 import만 확인:
   ```
   pool on ubu-2 'python3 -c "import torch, transformers, datasets"'
   ```
2. **arm H 디스패치** — pod에서 트레이너 빌드 후 background:
   ```
   hexa cloud nohup ubu-2 train.hexa.log -- \
       hexa run train_v3_moe_longtrain.hexa --d 64 --layers 1 --batch 1 --seq 512
   ```
3. **arm P 디스패치** — 동일 config payload emit 후:
   ```
   hexa dojo llm tfb-d64 '{"batch_size":1,"max_steps":200,"host":"ubu-2"}'
   cd exports/llm/dojo/tfb-d64 && bash run.sh
   ```
4. **harvest + ledger**:
   ```
   hexa cloud copy-from ubu-2 train.hexa.log /tmp/h.log
   hexa cloud copy-from ubu-2 train.tfb-d64.log /tmp/p.log
   hexa run tool/train_floor_bench.hexa --ledger --hexa-log /tmp/h.log --pytorch-log /tmp/p.log --d 64 --batch 1
   ```

`hexa cloud …`/`hexa dojo …`/`pool on …` 디스패치는 전부 pool 라우팅을 그대로
탄다. GPU pod는 `hexa cloud rent`(vast/runpod) 또는 ubu-2 RTX 5070.

---

## verdict

🟠 **harness-only — 미측정.** 측정대 코드 + 사용법은 완성됐고 로그 파싱은
self-test로 검증됐으나, 라이브 GPU 측정은 비용·infra 이유로 defer. 실제 fire가
두 arm 로그를 채우면 `--ledger`로 terminal verdict(🟢 Δ measured)로 전환.
