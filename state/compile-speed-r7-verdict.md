
## PHASE-1 MEASURED (summer · HEAD 22fcd094 · gcc-13 · 2026-06-26) — split-ccache JUSTIFIED

whole-build wall=273.3s · CPU User+Sys=273.3s(concurrency-immune) · smoke hexa v0.263.2 GREEN.
per-$CC census (amalgam=hexa_cc.c 1.8MB · emitted=stage1 main.c/module_loader):

| 컴파일 | out | hexa_cc.c sha | wall |
|---|---|---|---|
| hexat #1 | hexat | b6a993c0a4 | 20.7s |
| hexat #2 (converge p1) | hexat | ceea71ef85 | 25.9s |
| hexat #3 (converge p2) | hexat | 8e3a4ef53f | 26.4s |
| hexa_v2 | hexa_v2 | **8e3a4ef53f** | 25.4s |
| module_loader | emitted | 9d30d241fe | 0.4s |
| 최종 ./hexa | emitted | 3481c43df7 | 19.4s |

**(a)** amalgam 컴파일 N=**4** · emitted=2 · **(b)** distinct amalgam sha=**3**(seed가 converge서 변형)
**(c)** gcc 시간: amalgam=98.4s · emitted=19.8s · ALL $CC=**121.6s** (전체 273s의 ~44%)

CONVERGE AUDIT: seed-converge 2 pass, seed 변형(2075098B→2150643B), FIXPOINT after 2 passes.

### 판정
- **lever-A split-ccache = JUSTIFIED**: cold 빌드 = **hexa_v2(sha 8e3a4ef53f) ← hexat#3(동일 sha) ccache HIT** = 4개 중 1개 amalgam compile 절감 ~25s(~9%). **warm 재빌드(소스 불변) = 4 amalgam+2 emitted 전부 HIT ~118s(~43%)** — pool 호스트 반복빌드의 실이득. byteeq-safe by construction(ccache same-input⇒same-.o · transpiler emit C는 source의 함수).
- **lever-B pre-converged seed = NO-GO(measured)**: seed가 converge서 변형 → skip하면 emit 변경 = byteeq-unsafe. (prep 예측 확인.)
- 교훈: 단순기준 "distinct=1"이면 hexa_v2←hexat#3 동일sha 쌍을 놓쳤을 것 — per-compile sha census가 in-build HIT 지점을 실측으로 드러냄.

### PHASE-2 (다음): split-ccache 구현(HEXA_CCACHE=1 default-OFF) → OFF vs ON-warm 측정(emit-sha OFF==ON 게이트+wall/CPU+smoke) → pr-cycle.

## PHASE-2 MEASURED — GO (summer · gcc13.3 · ccache4.9.1 · 2026-06-26 · HEAD 7da67fd7)

HEXA_CCACHE=1 default-OFF split-ccache(`_r7_cc_compile_link` 헬퍼·5 site: hexat amalgam+converge·hexa_v2·module_loader·최종main.c).

| | wall | cpu | ccache | emit main.c | module_loader | 최종 ./hexa bin |
|---|---|---|---|---|---|---|
| OFF | 141.2s | 141.1s | - | 61516cd2 | ed6e5d58 | e8f7617f |
| ON-cold | 93.4s | 93.4s | 0/4 (0%) | 61516cd2 | ed6e5d58 | e8f7617f |
| ON-warm | **21.7s** | 21.7s | **4/4 (100%)** | 61516cd2 | ed6e5d58 | e8f7617f |

- **emit+bin sha 3-way IDENTICAL**(최종 ./hexa 바이너리까지) = **byteeq-safe 측정증명** ✅
- **OFF→ON-warm = 84.6% 빠름**(141.2→21.7s) — pool 반복빌드 실이득(예상~43%보다 큼·전 amalgam+emitted warm HIT).
- smoke 3-way GREEN. GATE: sha=YES·warm<off=Y·smoke=GREEN → **GO**.
- 정직노트: ON-cold도 OFF보다 빠름(141→93·ccache 0hit) = 디스크캐시 워밍/빌드순서 효과 추정, 게이트 무관(byteeq+warm 통과).
- default-OFF release-safe 머지. default-ON flip=follow-up(3타깃 byteeq CI + ccache 호스트 가용성).
