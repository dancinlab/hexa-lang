# scripts/akida — falsifier harness

12 falsifier 측정 인프라. Witness:
`design/kick/2026-05-07_anima-nexus-akida-physical-math-limit-saturation_omega_cycle.json`

## 실행 가능 분류

| F-* | category | run mode | hardware required |
|---|---|---|---|
| F-C | architectural | now | no |
| F-L7 | QRNG entropy | now (QRNG side) | no for QRNG, yes for spike-fusion |
| F-M2 | gzip compression | now (baseline) | yes for spike trace |
| F-M3a | dispatch routing | now (after .workspace registration) | no |
| F-L1 | J/op energy | post-arrival | yes (power meter + AKD1000) |
| F-L1+ | sub-Landauer sparsity | post-arrival | yes |
| F-L6 | Lyapunov sweep | post-arrival | yes (or `--simulate` for plausibility) |
| F-M1 | Gödel-q disagreement | post-arrival | yes |
| F-M3b | Phi substrate-invariance | post-arrival | yes |
| F-M4 | trace equivalence | post-arrival | yes |
| F-A | blowup phase-7 | post-arrival | yes |
| F-B | check_* hot-loop | post-arrival | yes |

## Layout

```
validate_witness.py        F-C architectural (runs now)
qrng_entropy.py            F-L7 QRNG side
spike_compress.py          F-M2 gzip
dispatch_check.py          F-M3a routing
energy_meter.py            F-L1 + F-L1+
lyapunov_sweep.py          F-L6
godel_disagreement.py      F-M1
substrate_equiv.py         F-M3b + F-M4
nexus_workload.py          F-A + F-B
runner.py                  orchestrator (run all eligible, emit follow-up witness)
host_register.sh           ~/core/.workspace host.rpi5-akida 등재 (event-driven, refuse without evidence)
```

## Output convention

각 harness 는 `state/akida_evidence/<F-id>_<ts>.json` 으로 raw_log 를 emit.
Schema:
```json
{
  "falsifier_id": "F-L1",
  "measured_ts": "2026-05-XX...",
  "measured_value": <float|object>,
  "verdict": "PASS|FAIL|NOT-RUN",
  "raw_log_path": "<absolute>",
  "hardware_present": true,
  "command": "<argv>",
  "git_hash": "<HEAD>"
}
```

이 path 와 ts 가 follow-up witness 의 `measured_ts` + `raw_log_path` 필드를 채움
(F-C invariant: 측정 evidence 없이 PASS verdict 금지).

## 사용

```
# 즉시 실행 (hardware 불요)
python3 scripts/akida/validate_witness.py design/kick/2026-05-07_*.json
python3 scripts/akida/qrng_entropy.py --bits 10000000
python3 scripts/akida/spike_compress.py --simulate
python3 scripts/akida/dispatch_check.py --synth-route

# hexa entry (4-blocker resolve + 8 falsifier + follow-up emit)
GATE_LOCAL=1 hexa run scripts/akida/runner.hexa go

# 개별 falsifier
hexa run scripts/akida/falsifier.hexa run F-C
hexa run scripts/akida/falsifier.hexa run F-L7 --bits 200000 --spike-trace state/akida_synth/spike_trace.txt
hexa run scripts/akida/falsifier.hexa all-simulator

# 도착 후 (akida 패키지 + AKD1000 device 필요)
python3 scripts/akida/runner.py --hardware
```

## 4-blocker resolution

`runner.hexa go` 가 실행하는 4 단계:

1. **synthetic spike trace** (`spike_trace_gen.py`) — F-L7 spike-fusion half 입력
   `state/akida_synth/spike_trace.{txt,bin,meta.json}`
2. **cnn2snn emulator selftest** (`cnn2snn_emulator.py`) — F-M3b/M4 substrate hint
   substrate marker `cpu_emulator_cnn2snn_stub` (NOT promotion-eligible)
3. **simulator-mode F-L1 evidence** (`energy_meter.py --simulator`) — host_register 의 evidence 게이트 unblock
4. **host registration** (`host_register.sh SIMULATOR=1`) — `host.rpi5-akida` workspace 등재 + `low-power-inference-simulator` label

honesty: 모든 simulator/synth evidence 의 verdict prefix 가 `PARTIAL-` 또는 `PLAUSIBLE-` —
F-C 가 `PASS` 위장을 차단. 실 device 도착 후 `--simulator` 빼고 재실행하면 verdict 가
`PASS` 로 승격, F-C 통과 시 tier_1 promotion 진행.
