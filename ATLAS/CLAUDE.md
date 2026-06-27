# ATLAS — 도메인 가이드 (sub-CLAUDE · 구 TECS-L, 개명 2026-06-18)

> hexa-lang **거버넌스 SSOT 는 repo-root `../CLAUDE.md`** (이 파일은 그 하위 도메인 안내일 뿐, 충돌 시 root 우선).
> 출처 참고: `dancinlab/archive-TECS-L:CLAUDE.md` 는 4줄 SPECKIT 스텁이라 박제 대신 본 가이드로 대체 (외부 리포명은 그대로 `archive-TECS-L`).

## 이 디렉터리는 무엇인가

`ATLAS/` (구 `TECS-L/`) = **범용 우주-법칙 발견 엔진**(수론·물리·우주·생명/의식 수학)의 사람용 원장.
`dancinlab/archive-TECS-L`(의식연속성 엔진 원본 코퍼스, 375+ 가설)를 hexa-lang 의
theorem atlas + `hexa verify` g5 게이트 위로 재근거화한다.

```
ATLAS/
├─ README.md        — 거시↔양자 Math System Map (단일 수학지도 · 색깔 범례 11종 + 노드그래프)
├─ hypotheses/      — 가설 문서 3074 (서브폴더 없이 평면 통합 · docs/hypotheses + math/docs/hypotheses)
│  ├─ NNN-slug.md   — 번호 체계 가설 (002-golden-zone-universality … 132-second-law)
│  └─ H-XX-NNN-*.md — 도메인 가설 (H-AI-·H-CX-·H-NT- 등)
├─ archive/         — 원천 문서 박제 (README.md + math/README.md = Math System Map 원본)
│  └─ SOURCE.md     — 출처 기록
└─ CLAUDE.md        — 이 파일
```

## 작업 규칙 (root 거버넌스 + 도메인 보강)

- **검증 atom 기계 SSOT** = `../compiler/atlas/embedded.gen.hexa` (rodata, frozen). 가설을
  "검증됨" 으로 올리려면 `hexa verify` g5 PASS → atom fold (root `verify is ambient` 룰).
- **n=6 은 노드 1개** (lattice-as-tool · 외부 영역 anchor 금지 · `../LATTICE_POLICY.md`).
  지도 중심은 거시↔양자 다리(bridges)이지 특정 숫자가 아니다.
- **정직(c2)**: 미판독 수식·미검증 모델·lattice-fit·미증명 conjecture 는 날조하지 않고
  tier(🟧/🟠/🟥 등)로 정직 표기. Golden Zone-의존 주장은 🟥 (모델 미검증 시 동반 미검증).
- **박제 문서 무수정**: `archive/`·`hypotheses/` 는 원본 faithful copy — 편집하지 말고
  새 발견·재근거화는 README 지도/atlas atom 으로 반영.
- **수학 DFS 는 `hexa loop --dfs` 로 진행** (NOVEL 축): 산술함수 항등식 공간 등의 탐색은
  root 거버넌스 `external LLM` 룰대로 **`hexa loop --dfs` 단일 surface**(예산캡 + verify 게이트)
  로 돌린다 — ad-hoc 파이썬 스크립트는 1회성 교차검증용일 뿐 정식 경로 아님. **새 발견은
  별도 .md 만들지 말고 `README.md` 의 "DFS Exploration Status" (Ralph N 연대기)에 이어 기록**
  + verify atom 은 `../compiler/atlas/embedded.gen.hexa`. 정확 정수 유한 sweep = bounded-unique
  (🟩), 전칭 ⟺ 은 증명 전까지 미주장(c2). 참고 엔진: `state/novel-dfs/` (재현·교차검증용).
  **12-fn 2-term 산술항등식 벤은 고갈**(README Ralph 369~371) — 검증기는 그 박스 밖으로
  **업그레이드됨**(Ralph 375 · `compiler/atlas/identity_engine.hexa`): ① 확장 vocab 6종(μ·λ·μ²·
  J₃·2^ω·core idx 12–17 · 부호 정확) ② arity-3(`verify_identity3` · `is_universal2/3` forall-n
  프레임). 측정 결과 = 확장 vocab universal **2 generator 전부 고전**(J₂=φ·ψ · core·rad=n) ·
  arity-3 bounded-unique 1431개 전부 2-term core 환원 → **novel=0**(정직 DRY). 생산적 벤은
  여전히 **composed/iterated 함수 기저**(Ralph 372 σ∘σ superperfect/Mersenne — 함수 합성 ≠ 값 곱).
  **직교 pivot(Ralph 376 · 2026-06-27)**: 곱셈 vocab을 떠나 **비-곱셈 생성함수/점화식 수열**(분할
  p(n) A000041 · Catalan A000108 · Bell A000110 · Fibonacci A000045 · Lucas A000032)로 전환 —
  새 identity FORM = 산술급수 **합동** `a(αn+β)≡0 (mod m)`(Ramanujan p(5n+4)≡0 mod5 = 곱셈 무유사
  canonical). native exact-int(`identity_engine.hexa`: partition_p·catalan·bell·fib·lucas + mod-m
  table + `verify_congruence`) + selftest(`drill/additive_test.hexa`) + drill 배선(`_native_additive_screen`
  → `DRILL_ADDITIVE` audit) + 참조엔진 `state/novel-dfs/additive_partition_hunt.py`. **측정**(N=4000):
  sanity 8/8 PASS(Ramanujan 3합동 재발견) · 합동 sweep RAMANUJAN=3·KNOWN-structural=752(Touchard/
  Lucas-divisibility/Deutsch–Sagan)·TAUTOLOGY=31·**NOVEL=0** · cross-seq bounded-unique=0. 직교
  도메인이되 동일하게 DRY(전부 고전 Ramanujan/Watson/Atkin/Touchard/Lucas/Deutsch–Sagan) — 정직 0
  보고(날조 금지). pivot 자체가 산출물(엔진이 비-곱셈 수열+합동 FORM을 native 표현). 합동은 [0,N]
  bounded·∀n UNPROVEN(c2). 다음 미탐 차원은 여전히 composed/iterated 함수(Ralph 372).
- 상세 history 는 `../CHANGELOG.md` + git.
