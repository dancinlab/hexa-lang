# comb T1 — NoC F1/F2 실험 명세 (pre-registered, consumer-side)

> 2026-05-18 · RFC 057 §6 T1 · falsifier F1/F2 operationalize.
> comb 가 *정의*, 실행은 별도 repo `~/core/hexa-arch` 의 chip 도메인 NoC sim.
> comb 는 sim 흡수/구현 안 함 (RFC 057 decouple). 해석적 앵커는 comb-side
> 에서 지금 산출 가능 (sim 불요).

---

## 목적

RFC 057 은 F1–F5 를 pre-register 했다. 본 문서는 그 중 F1/F2 를 *돌릴 수
있는 측정 프로토콜*로 변환한다 (Popperian: 가설을 반증가능한 실험으로).

- **F1** — degree-6 hex 가 degree-4 mesh 를 modern node 에서 wire-distance/
  energy 로 이긴다 → 반증조건 구체화.
- **F2** — Hales 기하 이득이 EDA(P&R) 비용을 견디고 살아남는다 → 반증조건.

## 두 위상 (정밀 정의)

| | baseline | target |
|---|---|---|
| 위상 | degree-4 2D mesh | degree-6 hex axial |
| 좌표 | (x,y), √N×√N | (q,r), s=−q−r |
| 이웃 | {(±1,0),(0,±1)} | {(±1,0),(0,±1),(+1,−1),(−1,+1)} |
| routing | XY dimension-order | hex dimension-order (deflection 옵션) |
| 경계 | 직사각 | brick-offset 행 (`axis_b_topology.md`) |

동일 N · 동일 노드당 연산/메모리(이진-타일 고정, 다치 금지) · 동일 traffic.

## modern-node wire model (변수만 고정 — 임의수 금지, g3)

`P` process node ∈ {7nm,5nm,…} · `r_w` wire RC/mm · `a_p(d)` router
port-area(degree) · `L(topology,placement)` link length · RC delay ∝ `L²`.
**모든 수치는 hexa-arch[chip] sim + 실 PDK(SKY130/SG13G2) 실측 입력.**
본 문서는 변수만 선언 (측정 안 된 수 기록 금지).

## 해석적 앵커 (T1-A — 완료; 정확본은 `T1A_analytical.md`)

> 본 표는 요약. 정확 상수 derive + 산술 확인 + 출처 + caveat 체크리스트는
> `comb/T1A_analytical.md` (T1-A 완료, sim 불요, 표준 NoC 문헌 인용).

| metric | degree-4 mesh | degree-6 hex | 비고 |
|---|---|---|---|
| degree d | 4 | 6 | router port cost ∝ d (~1.5×) |
| diameter | ~2√N | < 2√N (3-axis 단축) | 정확 상수 = T1-A derive + `hexa verify` |
| bisection BW | ~√N | ≥ √N | 조밀 연결 |
| per-link wire | placement 의존 | placement 의존 | Hales = *둘레* bound, latency 아님 |

degree-6 승리 조건: `(diameter·energy 이득) > (port-area ~1.5× + wire-RC 비용)`.
**이 부등식의 해소는 sim 만 가능** — 해석은 frame 만 제공
(least-perimeter ≠ least-latency caveat 유지, RFC 057 §2).

## F1/F2 operationalized (pass/fail)

- **F1 반증** if: ≤7nm wire model 에서 net energy/latency 이득 ≤ 0
  (router port-area 비용 차감 후).
- **F2 반증** if: hex P&R 오버헤드 ≥ UC-Davis-class 이득(−17~21%, 65nm 2012)
  → 기하 이득이 EDA 비용에 잠식.
- metric: avg packet latency · energy/bit · total wire length · bisection-
  limited throughput · router area.
- traffic: uniform-random + transpose + hotspot.

## hexa-arch[chip] 인터페이스 (decoupling 준수)

이 인터페이스는 producer-side 에서 typed contract 로 정형화됨. 본 절은
*인용*만 한다 (citation-enforced strict-lint, `AGENTS.tape @D g6`; 중복-
정의 금지, `@D g3`).

- **계약 SSOT** (producer): `~/core/hexa-arch/proposals/
  rfc_002_f1f2_export_interface.md` §3 (스키마) + §4 (provenance / no-
  over-claim 필수 필드) + §5 (path convention) + §6 (semver 규칙).
- **스키마 문서** (human reference): `~/core/hexa-arch/exports/chip/noc/
  f1f2/schema/v1_0.md` — JSON 으로 렌더한 키셋; 머신 carrier 는 같은
  키셋의 HXC v2 byte-canonical wire (`AGENTS.tape @D g_hxc`).
- **인터페이스 이름** (type carrier): `hexa-arch:chip:noc:F1F2-record`
  (단일 run) + `hexa-arch:chip:noc:F1F2-pair-verdict` (pair-aggregated).
- **방향**: comb 는 본 계약의 **소비자** (RFC 057 §6 T1; COMB.tape
  `comb_ultimate.decouple`). sim 흡수/구현 안 함; record 만 읽음.

위 계약이 정의하는 RHS 출력이 본 문서 §3 (modern-node wire model) 변수와
T1A_analytical.md §3 승리 부등식 우변을 충전한다 — `T1A_analytical.md` §8
"T1-B input contract" 가 필드 매핑을 가진다.

## 상태 / 다음

- **T1-A (해석적 앵커)** — comb-side, 지금 가능. Leighton degree-d
  bisection/diameter 상수 derive → `hexa verify` 로 검증 (sim 불요).
- **T1-B (sim 측정)** — blocked-on-hexa-arch[chip] NoC sim 흡수
  (`~/core/hexa-arch/HANDOFF.md` §9 step1).
- 다음 comb 액션 = T1-A 표 정밀화 (해석 상수 + 검증). over-claim 금지:
  T1-A 는 frame, 결론 아님.
