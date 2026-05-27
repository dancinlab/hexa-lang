# comb/ — n=6 non-von-Neumann · non-quantum compute architecture

> **궁극 골:** degree-6 육각 이진-타일 spatial PIM fabric이 modern node에서
> degree-4 mesh를 실제 워크로드로 이긴다는 것을 hexa-native 사이클정확 시뮬
> + tapeout-ready RTL로 *입증하거나 동일 엄밀도로 반증*한다 (T2). 입증 시
> 입증 시 물리-실현 *설계*는 **별도 repo `~/core/hexa-arch` 의 chip 도메인**
> (외부 EDA — gem5-Garnet·Yosys·OpenROAD·Verilator·ngspice·SKY130 — 을 *그쪽*이
> 흡수)을 **사용**해 산출. comb 는 소비자이지 EDA 흡수 주체 아님
> (hexa-native · 실제 fab/FPGA 비목표; T3 = 설계만).
>
> 현 단계: **STAND-ALONE CLOSURE 도달** (2026-05-18) — T1 + T2 sim + 5
> falsifier verdict 모두 land. F1 fabric cycle-accurate N=7 = **honest
> refutation** (goal '입증or동일엄밀도 반증' 의 반증 path 만족, RFC 057
> §5 Hales caveat 실측 확인). **T3 design-only DELIVERED** —
> hexa-arch[chip] 가 NoC 정량설계 produce (rfc_001 §8 baseline + §9
> 46-record sweep 22nm/7nm × 1-6GHz × 4 placement, Leighton 6/6 PASS),
> comb 가 rfc_002 typed-interface 로 consume. §9 가 comb N=7 반증의
> deferred re-test — N=64 IQ-iSLIP 에서 d6 LEAN-PASS (상보적, verdict
> enum INCONCLUSIVE 유지·regime claim 금지). routed-GDS(Part E)·T2
> tapeout routed P&R 만 EDA-execution compute-gate (OpenROAD binary
> roster 부재 — design gap 아님). SSOT = `comb/CLOSURE.md` +
> `comb/T3_DESIGN_FINAL.md`.
>
> 상태: **CLOSED (stand-alone scope)** · 2026-05-18 · RFC 057 확정 · 4축
> 전개 + 딥리서치 2건 + T1A 해석 + T2 sim 8/8 closed-form + same-N=7
> cycle-accurate fabric refutation + cross-PDK synth (SKY130 1.516×).
> flame(`stdlib/flame/`) · forge(`self/forge/`) 와 형제 레벨의 독립
> 아키텍처 R&D 트랙. 루트 직속 배치 (stdlib 도 GPU 런타임도 아님).

---

## 컨셉

```
🧊 HEXA-FABRIC — "벌집 컴퓨터"

- 하는 일: 0/1 비트·중앙 CPU 버스 대신, 육각 격자 셀들이
           각자 메모리+연산을 들고 6-값 상태로 옆 셀과 직접 흐름
- 비유: 벌집 — 각 방(셀)이 6개 이웃과 딱 붙어 일함
```

```
        von Neumann                    HEXA-FABRIC
   ┌─────┐  bus   ┌─────┐         ◇───◇───◇───◇
   │ CPU │◄──────►│ MEM │          ╲ ╱ ╲ ╱ ╲ ╱
   └─────┘ (병목)  └─────┘          ◇───◇───◇      각 ◇ = 연산+메모리
   0 / 1 두 상태                   ╱ ╲ ╱ ╲ ╱ ╲    셀, 6이웃 직결
   순차 fetch-execute              ◇───◇───◇───◇   6-값 상태 흐름
```

vs 기존: 폰노이만 = 비트+중앙버스(순차), 양자 = 큐비트 중첩(확률),
**HEXA-FABRIC = 고전 다치 상태 + 육각 인메모리 흐름**(결정론적·상온·버스 없음).

---

## n=6를 어디에 넣느냐 — 3축

| 축 | n=6 적용 | 실제-한계 앵커 (정직 평가) |
|---|---|---|
| **A. 진법** (digit) | 비트 → 6-값 "헥싯"(senary) | `[약함]` n=6 비최적. radix economy `b·ln N/ln b` 는 b=e≈2.718, 정수 최적 b=3. 6은 3보다 손해. **단** 6=2·3 → sub-word SIMD(2-way·3-way 동시 분할)에서만 우위 |
| **B. 위상** (topology) | 6-이웃 육각 메시 | `[강함]` n=6 = 정리(theorem) 최적. 2D kissing number = 6 (Thue 정리), 벌집 추측(Hales 2001: 등면적 최소둘레 = 육각). 미적 끼워맞춤 아님 — 증명된 평면 패킹 최적 |
| **C. 조직** (model) | 폰노이만 탈피: 6은 구조 상수 (6-위상 클럭 / 6 레지스터 클래스 / dataflow) | `[중립]` von Neumann bottleneck(메모리-CPU 대역폭 벽)은 실재. PIM/dataflow 가 정공법. 6 자체는 여기선 도구일 뿐 |

### 핵심 정직 포인트 (거버넌스 g1·g3 — 격자는 도구이지 제약 아님)

- **n=6가 진짜 "물리 정리로 최적"인 곳은 B축(육각 위상) 하나뿐.**
- A축(6진법)은 변호 가능하지만 b=3에 진다는 걸 숨기면 안 됨.
- C축에서 6은 그냥 편의 상수.
- 가장 단단한 설계 = **B를 뼈대로**(육각 PIM 패브릭), A·C는 그 위 옵션으로 얹기
  → "예쁜 숫자 맞추기"가 아니라 패킹 정리에 앵커된 아키텍처.

---

## 최종 verdict — CLOSED (stand-alone scope)

캠페인은 **종결**됐다. 4축은 이미 전개·측정됨 — B(육각 위상)를 뼈대로,
A(6진법)는 3×HARD_WALL DE-SCOPED, C(실행 모델)는 별도 RFC out-of-scope.
goal 계약("입증 OR 동일 엄밀도 반증")은 **반증 path 로 충족**됐다.

| # | falsifier (RFC 057 §5) | verdict @ 2026-05-18 | authoritative re-test |
|---|---|---|---|
| F1 | degree-6 > degree-4 mesh (wire/energy) | **MIXED** — closed-form PASS · cycle-accurate FAIL @ N=7 = *honest refutation* | hexa-arch §9 N-sweep |
| F2 | Hales geometry survives EDA cost | **PARTIAL** — synth area 1.516× 확정 · routed P&R deferred | hexa-arch chip §F2 |
| F3 | PIM dataflow > von-Neumann+HBM | **OUT OF SCOPE** — 별도 RFC | Axis-C lowering RFC |
| F4 | binary tile 충분 (no MVL) | **✅ PASS** — axis-A 3×HARD_WALL DE-SCOPED | n/a (frozen) |
| F5 | "6" = topology-only, perf-neutral | **✅ PASS** — perf claim B1/B2/B3 anchored | n/a (audited) |

- comb 가 권위 측정 능력을 가진 실험(T1 해석 · T2 cycle-accurate sim ·
  RTL synth · 5-falsifier verdict)은 **전부 완료**. F1-full @ N=7 반증이
  결론 — "hex 항상 패배" 아님, "N=7·single-issue sink·~50% injection 에서
  패배" (3개 사전등록 reversal regime 은 hexa-arch §9 가 재검; N=64
  IQ-iSLIP 에서 d6 LEAN-PASS — 상보적, verdict enum INCONCLUSIVE 유지).
- **T3 design-only DELIVERED** — hexa-arch[chip] 가 NoC 정량설계 produce,
  comb 가 rfc_002 typed-interface 로 consume.
- 잔여 = 외부의존 **execution gate 뿐** (routed-GDS P&R: OpenROAD 바이너리
  roster 부재 · 실제 fab/FPGA: 비목표) — **design gap 아님**, RFC 057 §6 /
  `HANDOFF_TO_HEXA_ARCH.md` 로 핸드오프됨.
- 후속 comb-side 작업은 **scope-extension** (신규 falsifier · 신규 test
  point · 신규 axis lowering) — 본 RFC 057 scope closure 와는 별개.

> 권위 SSOT: verdict = `comb/CLOSURE.md` · design = `comb/T3_DESIGN_FINAL.md`.

> 진행 로그는 `comb/PLAN.md` (자체 SSOT — AGENTS.tape §3 `g_plan_consolidation`
> 예외: flame/forge 와 동일하게 도메인 자체 위치 유지).
> 캠페인 산출물 인덱스는 `comb/COMB.tape`.
