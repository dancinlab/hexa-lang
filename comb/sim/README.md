# comb/sim — minimal hexa-native graph-level NoC sim harness

> 2026-05-18 · comb-internal · T1-B 의 **그래프 레벨** 부분.
> Decoupling 재정의: comb 가 안 하는 것 = **외부 EDA 흡수** (Yosys/OpenROAD/
> BookSim2/SKY130/...) — 그건 별도 repo `~/core/hexa-arch[chip]` 책임.
> comb 가 *하는* 것 = T1-A 의 그래프-기하 예측을 **자체 검증**하는 최소
> hexa-native 측정 harness (modern-node wire model 없음 — 그건 T1-B-full 이
> hexa-arch[chip] sim 으로).

---

## 무엇을 측정하나 (지금 가능, sim-free 수치 + hexa 소스)

T1-A 예측: `D_hex / D_mesh -> 1/√3 ≈ 0.5774` asymptotic, `avg_dist` 동일 비율,
`hop reduction -> 0.8453 √N`. 본 harness 는 concrete N 에서 이 예측을 산출
하고, 측정 table 로 영구화 (`T1A_verify.txt`).

## Files

- `T1A_verify.txt` — **측정 결과** (elementary arithmetic, N=64..10000). Ratio
  가 작은 N 에서 0.66 부터 시작해 N 증가 시 0.5774 (= 1/√3) 로 단조 수렴.
  T1A_analytical.md §2 asymptotic 주장 확인.
- `noc_distance.hexa` — 같은 계산의 **hexa-native 소스 스펙** (DRAFT, parse
  게이트 통과 후 확정). 향후 hexa-arch[chip] sim 의 *oracle* 로도 사용
  (sim 출력이 본 graph-level 예측과 일치해야 sim 자체가 옳다).

## 무엇을 안 하나 (decoupling 명확화)

- 외부 BookSim2/gem5-Garnet 흡수 — hexa-arch[chip] 책임 (HANDOFF §5).
- modern-node wire model (RC, link-length, router-port-area) — hexa-arch[chip].
- RTL 합성/P&R — hexa-arch[chip] (Yosys/OpenROAD/SKY130).
- comb 자체에서 cycle-accurate packet sim 구현 — 안 함 (oracle level 만).

## T1-B 분할 (refined)

| sub-step | 범위 | 위치 | 상태 |
|---|---|---|---|
| T1-B-oracle | 그래프-기하 측정 (diameter·avg dist·hop reduction) | **comb/sim/** (여기) | 완료 (T1A_verify.txt) |
| T1-B-full | 모던 노드 wire model + router port + traffic | hexa-arch[chip] | blocked (별도 repo) |

T1-B-oracle 완료로 F1 부등식 §3 **좌변(이득)** 은 측정 고정.
**우변(비용)** 만 hexa-arch[chip] sim 출력 대기. F1/F2 verdict 는 우변 시
즉시 결판.

## T1-B-full input expectation (cited — hexa-arch[chip] producer-owned)

T1-B-full 측정 (modern-node wire model + router cost + traffic-driven
latency/throughput) 은 본 harness 가 *수행하지 않는다* — hexa-arch[chip]
가 producer 다 (RFC 057 §6 T1; COMB.tape `comb_ultimate.decouple`). 본
절은 comb 가 producer 출력을 *어디서 / 어떤 모양으로* 읽는지의 계약을
인용한다.

### 계약

- **typed-interface RFC**: `~/core/hexa-arch/proposals/
  rfc_002_f1f2_export_interface.md` §3 (스키마) · §4 (provenance) · §5
  (path convention).
- **스키마 (human reference)**: `~/core/hexa-arch/exports/chip/noc/f1f2/
  schema/v1_0.md`.
- **carrier**: HXC v2 byte-canonical wire (`AGENTS.tape @D g_hxc`);
  JSON of the same keyset = interim parse path until hexa-arch 의 HXC
  tool 이 lands (rfc_002 §9).

### 읽기 경로 (absolute, producer-owned per D7 — no symlink, no copy)

comb 의 harness 는 다음 절대경로에서 read-only 로 record 를 소비한다:

```
~/core/hexa-arch/exports/chip/noc/f1f2/records/<id>.{hxc,json}
~/core/hexa-arch/exports/chip/noc/f1f2/pair_verdicts/<id>.{hxc,json}
```

`<id>` 는 producer 가 발행한 dated identifier (예: `2026-05-18_d4_mesh_
tornado_22nm_4ghz`). Pair verdict 는 baseline + candidate record 쌍을
`shared` / `differing` / `headline_metrics` 로 집계한다 (스키마 doc §D).

### 입력-쪽 기대 (consumer contract)

각 record 가 다음을 보장한다고 가정하고 harness 를 짠다 (rfc_002 §4
producer-enforced):

- `interface` ∈ {`hexa-arch:chip:noc:F1F2-record`, `hexa-arch:chip:noc:
  F1F2-pair-verdict`}.
- `schema_version` semver MAJOR.MINOR — comb 는 본 README 작성 시점의
  MAJOR 에 pin (rfc_002 §6 compatibility window 가 마지막 두 MAJOR 를
  유지).
- `leighton_oracle.status == "PASS"` — FAIL record 는 producer 가
  emit 자체를 막음 (rfc_001 §7.3 exit 91).
- `provenance.consumer_target == "hexa-lang:comb:RFC_057:F1F2"`
  — producer 가 본 consumer 로 향한 record 임을 확정.
- `provenance.absorbed == false` 가 **기본값** (`measurement_gate`
  closure 전); harness 는 record 를 *capture-only* 로 다루고
  "absorbed" 주장을 만들지 않는다 (g3 + rfc_002 §8).

### Harness 행동 (계약-에지)

- record 가 위 보장을 위반 → harness 는 reject + log; verdict 산출 안 함.
- pair verdict 의 `verdict.{f1,f2}` ∈ {PASS, FAIL, INCONCLUSIVE} 를
  그대로 comb-side verdict 로 채택 — 재산출 금지 (계약-경계 존중, g3).
- `T1A_analytical.md` §8 의 §3 RHS 매핑 표가 record 필드 → 부등식 변수
  의 대응을 가진다 (이중 정의 금지; 본 README 는 mapping 재진술 안 함).
