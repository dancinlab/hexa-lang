# CLM_PROD_DEVRESIDENT frozen-train — root-cause + fix verdict (2026-06-25)

## 결론 (RESOLVED · verify GREEN)
`CLM_PROD_DEVRESIDENT` device-resident 학습의 loss 4.79899 고정(frozen-train) 버그를 근본수정.
DEVRESIDENT epoch-3 **4.79899 frozen → 3.5508434859818907 == REF byte-eq**(aiden CUDA13 실측).
branch `fix/devresident-forward-w-coherence`.

## 진단 (machine/CUDA 무관 결정적 — "layout-sensitive" 가설 FALSIFIED)
3 깨끗한 빌드가 전부 동일하게 DEVRESIDENT frozen·DEVFEED 정상:

| 빌드 | REF | DEVRESIDENT | DEVFEED | CUDA |
|---|---|---|---|---|
| aiden (fresh) | 3.55084 | **4.79899 ❌** | 3.55084 | 13.0 |
| summer (fresh) | 3.55084 | **4.79899 ❌** | 3.55084 | 12.9 |
| vast 42456483 (fresh) | 3.55084 | **4.79899 ❌** | 3.55084 | 13.0 |
| ~~vast 42422962 (오염 증분빌드)~~ | 3.55084 | 3.55084 | 4.79899 | 13.0 |

- 3머신·2 CUDA 메이저 일관 ⇒ **machine/CUDA/메모리레이아웃 무관 결정적 소스버그.** 앞 세션의
  "build-layout-sensitive flip"(빌드마다 frozen 경로 뒤바뀜) 판정은 **오염 pod 42422962
  증분빌드 아티팩트**(stale build/cuda 객체) 단일관측에 과적합 → falsified.
- compute-sanitizer initcheck/memcheck/racecheck **전부 0**(메모리에러·OOB·race 아님).
- device-glue 9-op reference-match QA(workflow): **전부 source-faithful**(개별 커널 math 버그 아님).

## ROOT CAUSE
host `opt_adamw_step` → `hexa_adamw_step` 빌트인(frozen `self/runtime.c` 151c52c8)이 host
param `P[i]`를 제자리 갱신하지만 `dirty_host=1`을 **안 켠다**(host-write 정답경로 `hexa_farr_set`은
켬). W 엔트리는 직전 step int4_quant `_h2d`로 `loc=FARR_MIRRORED, dirty_host=0` 상태 →
다음 step `_h2d(w)`가 RFC056 §6.1 H2D-skip(`!dirty_host && live d_buf && len-match`) 적중 →
갱신 W 미업로드 → device int4 fake-quant(`_fq`→`forge_dispatch_int4_quant`)이 **STALE device W
재양자화** → forward가 옵티마이저 갱신 못 봄 → frozen.

**#3918 무효 확정**: 주석의 "host opt_adamw_step → hexa_farr_set → dirty_host=1"은 **factually
FALSE** (opt_adamw_step은 hexa_farr_set 미경유 → dirty_host 영영 안 켜짐). 그래서 #3918(host-adam
라우팅)이 3 clean build 전부서 무효였다 — 앞 검증은 오염 pod의 false-green에 의존.

## FIX
`tool/restore_frozen_seeds` 후처리 awk(OP-37/38·ING-82 선례)가 frozen runtime.c의
`hexa_adamw_step` + `hexa_adamw_step_mixed` AdamW 갱신 루프 직후(루프닫기 brace) `#ifdef HEXA_CUDA`
가드로 주입:
```c
{ HexaFarrEntry* _pe = &_hx_farr_table[p_id]; if (_pe->d_buf) { _pe->dirty_host = 1; _pe->dirty_dev = 0; } }
```
= `hexa_farr_set`의 device-mirror dirty 계약 복제. 주입은 P[i]-= 직후 brace로 바운드(`_mixed`는
`return hexa_int`이라 `return hexa_void` 앵커 누출 방지). gawk 이식성: awk print서 `&`는 리터럴
(`\&` 금지 — linux gawk가 백슬래시 보존해 stray-`\` 컴파일에러).

## 검증 (verify-done · aiden CUDA13)
| config | epoch-1 → epoch-3 | 판정 |
|---|---|---|
| REF | 4.73603 → 3.55084 | 기준 |
| DEVRESIDENT | 4.73603 → **3.55084** | ✅ REF byte-eq RESTORED (was 4.79899 frozen) |
| DEVFEED | 4.73603 → 3.55084 | ✅ 불변 |

runtime.c marker=2(양쪽 adam 주입) · LINK YES.

## byte-eq-safe / 릴리스 무영향
- 비-CUDA(default/REF/CPU 출하)는 전처리기가 `#ifdef HEXA_CUDA` 통째 제거 → 바이트동일.
- DEVFEED(host-resident W)는 무해 no-op. opt-in default-OFF.
- frozen `self/runtime.c` 151c52c8 IMMUTABLE — post-restore awk는 OP-37/38 동형(tracked diff =
  `tool/restore_frozen_seeds`만). byteeq 3타깃 = PR CI 게이트.

## flame/forge parity와 직교 (재측정 불필요)
이 버그는 **device-resident 학습 루프 고유**(가중치 device상주 dirty_host=0 skip + adam→forward
전파 cross-step). single-shot GEMM(forge)·host-authoritative 매-step 재업로드 학습(flame 기본)·
CPU byte-eq 오라클은 그 skip 경로를 안 밟아 미경유. forge/forge per-kernel cuBLAS parity는
유효·무관. util 10% 천장(ING #21)도 별개(작은-GEMM launch-bound decode, 이 fix 무관).

## 잔여 follow-on (정직 기록)
- DEVFEED는 별도 클래스(device-adam freeze + im2col conv 수치) 혼재 가능 — 이번 fix는 DEVFEED
  미접촉(scoped). DEVFEED 안정화는 별도 follow-on.
- device-resident DECODE byte-exact 발산(anima 세션 관측)은 inference forward 경로(optimizer 없음)
  = 이 adam-coherence fix와 별개. forward residency 정합성 후속 조사 대상.
