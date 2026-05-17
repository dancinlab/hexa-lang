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
