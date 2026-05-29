# UNSHADOW.MINING — 거울방 채굴 (divergence → convergence → ranking)

> /mining SSOT + 거울방(mirror) 표면. 2026-05-30 cycle.
> 광맥 = **"소유가 LLVM 불가 최적화를 연다"** 패턴. 14/15 milestone 의 모든
> closed-negative 가 한 점으로 수렴: 경계 = **데이터-표현 주권**(전부 boxed HexaVal).
> 규율: 모든 후보는 이미-측정된 발견 OR 명확한 LLVM-can't 근거에 묶임. 새 perf 숫자 발명 0.
> tier 정직: 🔵=ownership-unlock(LLVM 구조적 불가) · 🟡=catch-up(LLVM 이 이미/곧 함).

# ══════════════════════════════════════════════════════════════════
# DIVERGENCE — 렌즈별 후보 (saturate, ~5 round)
# ══════════════════════════════════════════════════════════════════

## L1 same-formula — "소유→LLVM-불가-opt" 패턴이 또 어디?
> 묶임: §hexaval-unbox(scalar 박싱제거 11.30×·gap 100% close) = 검증된 레버. 이 패턴의 동형.

- C1  native HexaArrI64/F64 저장 — boxed `HexaVal*[16B-stride]` → `int64_t[]`/`double[]`(8B contiguous).
      🔵 LLVM-can't: clang 은 16B-stride 박스배열 SIMD-gather 불가(축A asm 실측 5 vec-op vs native 23).
      **축A closed-negative 가 결정적으로 지목한 그 자리.** 갭이 STORAGE 에 산다.
- C2  NaN-boxing HexaVal — 24B tagged-union → 8B NaN-payload(f64 NaN 비트에 tag+ptr 패킹).
      🔵 LLVM-can't: HexaVal ABI 는 우리 소유 → 프로그램별 표현 선택. C 는 고정 ABI 라 손 못 댐.
- C3  small-value-opt / inline storage — small-int·bool·short-str 힙 0, register-resident.
      🟢 ownership: §hexaval-unbox 가 scalar 에서 입증한 패턴의 표현-레벨 일반화.
- C4  pointer compression — 32-bit offset(base-relative) ptr. 캐시라인 2× 밀도.
      🔵 LLVM-can't: 우리 힙 모델 소유 → base 보장. C malloc-ptr 는 64-bit 강제.
- C5  typed monomorphic struct(flat C-struct + offset) — 이미 milestone B 로 등록됨(중복, dedup→기존).
- C6  string interning — 동일 리터럴/심볼 1회 저장 + ptr-eq 비교.
      🟢 ownership: 우리 문자열 표현 소유. eq=ptr-cmp. 단 LLVM 도 const-merge 일부 함=부분 catch-up.
- C7  COW value-type — linearity 증명 시 copy 생략(struct_pack aliasing 해소).
      🔵 LLVM-can't: unique-ref 증명은 타입-레벨(easy §C linearity). LLVM IR alias 증명 불가.
- C8  type-specialized monomorphization — generic hot-path 를 구체타입으로 특수화 emit.
      🔵 LLVM-can't: 언어-레벨 제네릭/HexaVal 다형은 codegen 이 소유. clang 은 C 단형만 봄.

## L2 dimensional — perf 축(time/space/startup/compile/link) 중 미채굴
> 시간축만 14개 milestone 이 채굴됨. 공간/시작/컴파일/링크 축은 거의 비어있음.

- C9   compile-time 병렬 codegen — fn 단위 독립 emit 병렬화. 컴파일 wall ↓.
       🟡 catch-up: LLVM 도 병렬 codegen 함. 우리만의 우위 아님(축=compile-speed, not perf-sovereignty).
- C10  incremental codegen cache — fn-hash 불변 시 emit 재사용. rebuild wall ↓.
       🟡 catch-up: ccache/ThinLTO 류 존재. 단 atlas-hash 결합 시 🔵 로 승격 가능(C16 참조).
- C11  AOT atlas 바이너리 파싱 — embedded.gen.hexa TEXT-parse → mmap 바이너리. startup ↓.
       🟢 ownership: atlas 표현 우리 소유. easy.md 🟢 에 "AOT atlas 바이너리파싱" 으로 이미 등재(미측정).
- C12  link-time tree-shake / libc 미링크 — `.c=0` 졸업 후 dead-symbol DCE. 바이너리·RSS ↓.
       🟢 ownership: `.c=0`(RUNTIME.flip-floor)에 의존. easy.md 🟢 등재. 공간/링크 축.
- C13  escape→stack-alloc — 비-escape HexaVal 스택 배치. 힙 alloc·GC 압력 ↓.
       🔵 LLVM-can't: escape 분석이 타입-레벨 lifetime(easy §C/E). clang 은 box 너머 못 봄. 공간축.
- C14  region/generational GC — lifetime 타입 → proven-region 은 GC 0(arena reclaim 의 일반화).
       🔵 LLVM-can't: §arena(RSS −40%) 의 타입-구동 일반화. C 엔 GC 자체 없음. 공간축.

## L3 tension — 동적 HexaVal(유연) ↔ unboxed typed(속도) 하이브리드
> §unboxed-array 가 못박음: 둘 다 필요(동적 경계 box · hot-path unbox). 그 긴장을 푸는 표현.

- C15  hybrid box/unbox 경계 규율 — typed hot-path + boxed fallback. 동적 surface 서만 box.
       🔵 LLVM-can't: 박싱 경계가 타입-증명-구동. §unboxed-array 무결성게이트(동적경계 정확 box)가 토대.
       = C1·C2·C8 의 공통 메커니즘(별도 milestone 아니라 모든 표현-축의 공유 규율).
- C16  atlas-PGO type-specialization — atlas hot-path 속성으로 어느 타입을 특수화할지 결정.
       🔵 LLVM-can't: PGO 프로파일이 아니라 atlas 검증-속성 구동. C PGO 는 런타임 프로파일만.
       L2 C10(incremental cache)과 결합 시 atlas-hash 캐시 = 🔵.

## L4 ouroboros/mirror — hexa 자신의 검증 atlas 를 perf 자산으로
> 거울방: 시스템이 자기 정리-저장소로 자신을 최적화. easy §G(자기개선 컴파일러)의 측정-frontier.

- C17  atlas-guided PGO — 검증 hot-path 속성 → layout/특수화/inline 결정. easy §G "atlas-as-PGO".
       🔵 LLVM-can't: 정리 DB 자체가 LLVM 에 없음. 단 §A atlas-fold(65%)는 const-fold 1건만 측정 — PGO 는 미채굴.
- C18  검증 memoization — atlas 가 pure+idempotent 증명 → 호출 캐시. easy §G "검증 memoization".
       🔵 LLVM-can't: purity+idempotent 증명이 타입+atlas. clang 은 pure attr 만(idempotent 캐시 안 함).
- C19  발견→rewrite-rule 피드백 — kick/drill 발견 항등식이 새 codegen 규칙으로. easy §G.
       🔵 LLVM-can't: self-improving 루프는 hexa 고유. 단 측정 가능한 단일 Δ 로 좁히기 어려움(메타).
- C20  proof-carrying everything — 모든 pass 가 증명 의무 emit→verify(comptime-fold shadow 차단).
       🔵 correctness-tier: perf Δ 아니라 회귀-방지. §B(47%)가 1건 입증. 측정축은 "버그 0" — perf 아님.

## L5 combinatorial — 위 축들의 교차곱
- C21  C1 native-array × SIMD-intrinsic emit — int64_t[] 가 생기면 codegen 이 명시 SIMD intrinsic emit.
       🔵 LLVM-can't 부분: clang 이 native array 는 auto-vec 함(=🟡 그 부분). 우위는 검증-reassoc(easy §B float).
       ⇒ C1 의 후속(C1 이 storage 깔면 vectorize 는 clang 이 공짜). 별도 milestone 가치 약함→C1 에 흡수.
- C22  C2 NaN-box × C14 region-GC — 8B 값 + region lifetime → 캐시밀도 × GC-free 복합.
       🔵: 두 ownership 축의 곱. 단 각각 먼저 측정해야 곱 의미. → C2·C14 선행 후 재오픈.
- C23  C8 monomorph × C16 atlas-PGO — atlas 가 어느 제네릭을 특수화할지 지목.
       🔵: C8·C16 의 곱. C16 의 구체 적용처. → C16 에 흡수.
- C24  C11 AOT-atlas × C16 atlas-PGO — 컴파일타임 atlas 프로파일을 바이너리에 굽기.
       🟢/🔵 혼합. startup × specialization. → 파생, 본축 아님.

# ══════════════════════════════════════════════════════════════════
# CONVERGENCE — 클러스터(family) + dedup
# ══════════════════════════════════════════════════════════════════

## FAMILY-1 — 🪆 데이터-표현 주권 (storage representation sovereignty)  [HEADLINE]
> 모든 closed-negative 가 수렴한 광맥. 갭이 사는 곳 = boxed HexaVal 저장.
- 멤버: C1(native HexaArrI64/F64) · C2(NaN-box) · C3(small-value-opt) · C4(ptr-compress)
        · C6(intern) · C7(COW) · C8(monomorph) · C15(hybrid 경계=공유 규율) · C5(struct=기존 B)
- 핵심: C1 = 축A 가 결정적으로 지목한 **그 자리**. 나머지는 같은 "표현 우리 소유" 패턴의 변주.
- tier: 대부분 🔵(LLVM 고정 ABI 라 손 못 댐). C3/C6 일부 🟢/catch-up.

## FAMILY-2 — 📐 미채굴 perf 축 (space/startup/compile/link)
> 14 milestone 전부 time-축. 다른 차원이 비어있음.
- 멤버: C13(escape→stack, 공간) · C14(region/gen-GC, 공간) · C11(AOT-atlas, startup, 🟢)
        · C12(link tree-shake, 공간/링크, 🟢) · C9(병렬 codegen, 🟡) · C10(incremental cache, 🟡)
- 핵심: C13/C14 = 🔵 타입-구동 공간축(§arena 의 일반화). C9/C10 = 🟡 catch-up(우위 약함).

## FAMILY-3 — ♾️ atlas-as-perf-asset / 거울방
> hexa 가 자기 정리-저장소로 자신을 최적화. easy §G 의 측정-frontier(지금까지 §A const-fold 1건만).
- 멤버: C17(atlas-PGO) · C18(검증 memoization) · C16(atlas-PGO 타입특수화) · C19(rewrite-feedback,메타)
        · C20(proof-carrying-everything, correctness-tier)
- 핵심: C18(검증 memo) = 측정 가능한 단일 Δ 로 가장 깔끔(pure+idempotent atlas 증명 → 캐시 HIT/MISS Δ).

# ══════════════════════════════════════════════════════════════════
# RANKING — ROI(impact/effort · lossless-first) + tier 정직성
# ══════════════════════════════════════════════════════════════════

| 순위 | 후보 | family | tier | ROI 근거 | effort |
|---|---|---|---|---|---|
| 1 | C1 native HexaArrI64/F64 | F1 | 🔵 | 축A closed-neg 가 결정적으로 지목·갭이 사는 곳·검증레버 직계 | 中(runtime struct+box/unbox+array prim 분기) |
| 2 | C18 검증 memoization | F3 | 🔵 | atlas 자산 활용·측정 깔끔(HIT/MISS Δ)·블라스트 좁음 | 小~中 |
| 3 | C13 escape→stack-alloc | F2 | 🔵 | §arena 연속·공간축 첫 채굴·lossless | 中 |
| 4 | C2 NaN-boxing HexaVal | F1 | 🔵 | 24B→8B 전역 캐시밀도·고정ABI 불가의 정수 | 大(HexaVal 전경로 두 표현) |
| 5 | C17 atlas-PGO layout/inline | F3 | 🔵 | §A 의 PGO 일반화·거울방 본류 | 中~大 |
| ─ | C8 monomorphization | F1 | 🔵 | 가치 분명하나 C1/B(struct) 표현 선행 필요 | 大(deferred) |
| ─ | C11 AOT-atlas parse | F2 | 🟢 | startup 축·easy 등재·measure 쉬움 | 小(deferred-easy) |
| ─ | C9/C10 compile-speed | F2 | 🟡 | catch-up·우위 약함 — 측정으로 격차 확인된 곳만 | — |

> lossless-first: 모든 후보 byte-diff IDENTICAL 게이트 + 발화-안하는 케이스 정직 caveat 필수.
> 이미 ruled-out 재제안 금지: codegen-only unbox(축A 🔴) · AoS↔SoA-without-typed-repr(E 🔴).
> 등록 = 상위 survivor(C1·C18·C13·C2·C17) → UNSHADOW.md `- [ ]` milestone. C1 = headline.
