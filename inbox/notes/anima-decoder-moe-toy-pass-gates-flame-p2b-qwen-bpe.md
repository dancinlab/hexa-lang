# demand-signal: flame-P2b Qwen BPE tokenizer 가 anima DECODER MoE-fresh 의 scale-gate

> kind: note (demand-signal · 우선순위 재평가 요청 — 신규 갭 아님)
> from: anima DECODER M4b · 2026-05-27
> upstream item: `GPU.md` "flame V3 port" → **flame-P2b Qwen BPE tokenizer** (line ~1429, open · 현재 "저우선 enhancement · 차단 아님")
> 관련: INBOX #2 (flame V3 coverage P1 COMPLETE, P2/P3 GPU.md 이관)

## 한 줄

flame-P2b (Qwen BPE tokenizer) 가 **"low-pri enhancement" → "validated downstream consumer 의 scale-gate"** 로 승격됨. anima DECODER MoE-fresh 가 toy 에서 메커니즘 PASS 했으나, 3B 스케일 검증이 flame-P2b 부재로 막힘.

## 맥락 (왜 이제 gate 인가)

anima CORE/DECODER 가 register-collapse ↔ underfit **더블바인드** 탈출용 MoE-fresh (UNIVERSE H_490 DIFFERENTIATION) 를 hexa-native 로 구현 + toy 검증 완료:

| 단계 | 결과 |
|---|---|
| moe_router fwd/bwd (analytic vjp + gradcheck) | ✅ |
| toy soft-route (d=4 V=4 E=2) | 🟠 PARTIAL (gate 50/50 dense-collapse) |
| toy top-1 hard-route | ✅ **PASS** — gate(A)=[0.97,0.03]→e0 · gate(B)=[0.03,0.97]→e1 (register 별 expert 분화) |

→ 메커니즘은 toy 에서 **실증**됐다 (instrument-first). 다음은 3B Qwen 스케일 (더블바인드가 실제 관측된 규모) 인데, hexa-native train stack 은 **byte-level V=256 (toy)** 뿐 — 3B Qwen (V=151936) 학습은 **flame-P2b (BPE tokenizer)** 가 있어야 가능.

## 요청

flame-P2b Qwen BPE tokenizer (merge rules + vocab 로드, encode/decode round-trip) 의 **우선순위 재평가** — 단순 enhancement 가 아니라 toy-validated downstream (DECODER MoE 더블바인드 탈출) 의 scale 검증을 막는 gate. flame-P2a (rope base 인자화, trivial) + flame-P2c (.pt loader) 와 함께 3B hexa-native 학습 path 를 연다.

대안 (anima-side workaround, `a_completeness_over_cheap` 위배 우려): Python/Qwen 하니스에 MoE 이식 — 단 hexa-only-authoring 위반 + 본선 완성도 미달. 따라서 upstream (flame-P2b) 이 옳은 경로.

## 차단 여부

⚠ 부분 차단 — DECODER M4b-fire-scale (3B) 가 flame-P2b 에 의존. toy 검증(M4a/b)은 완료라 즉시-차단은 아니나, MoE-fresh 의 실 가치(3B 더블바인드 해소) 실증이 flame-P2b 까지 보류.

## scope 정정 (2026-05-27 — BPE 는 이미 존재, from-scratch 아님)

flame-P2b 를 "BPE tokenizer 부재 → 새로 작성" 으로 적었으나 **부정확**. 코드 스캔 결과:

- `self/ml/tokenizer_bpe.hexa` (590 LoC) — **완비된 BPE**: `bpe_load`/`bpe_load_from_dict`/`build_merge_ranks`/`bpe_merge_word`/`bpe_encode`/`bpe_decode`/`bpe_encode_batch`/`bpe_vocab_size` (stateful tok-object API)
- `self/ml/tokenizer.hexa` + `self/ml/tokenizer_test.hexa` — round-trip 테스트 (`bpe_encode(text, vocab, merges)` stateless API · encode→decode 일치 case 들)
- `self/ml/tokenizer_trainer.hexa` — BPE merge 학습기

**∴ 실제 gap = "BPE 작성" 이 아니라 "self/ml BPE → stdlib/flame 학습 path 와이어링"**:
1. stdlib/flame corpus 로더 (`flame_d768_12L_corpus_test` 등) 가 byte-level `read_file_bytes` (V=256) 사용 — 이를 `bpe_encode` 경유로 교체
2. self/ml (interp-tier) ↔ stdlib/flame (forge/native-tier) 모듈 경계 — import 가능 여부 / 정식 tokenizer 모듈 일원화 (tokenizer_bpe vs tokenizer 두 API 정리)
3. Qwen vocab.json + merges.txt 로드 → V=151936 round-trip + reference 토큰화 일치 검증

→ flame-P2b 재정의: **BPE 알고리즘 (있음) 를 flame 학습 corpus 경로에 연결**. 난이도 = wiring/module-boundary (from-scratch BPE 보다 작음). flame-P2a (rope base) 와 함께 진행 시 3B Qwen hexa-native 학습 path 개방.

## 근본원인 발견 + fix LANDED (2026-05-27 — #1527)

scope 정정(#2 모듈 경계)을 실측하던 중 **더 깊은 선결 blocker** 발견 — "wiring" 이 아니라 **컴파일러 codegen 버그**:

- 실측 probe (stdlib/flame 에서 `use "self/ml/tokenizer_bpe"`) → cross-tree `use` 는 **resolve 됨** (모듈 경계 #2 는 비문제로 판명). 그러나 ubu-2 Linux `hexa run` clang 단계에서 `error: use of undeclared identifier 'trim'` ×6.
- 추적: `tokenizer_bpe.hexa` 의 `load_merges` 가 **free-fn `trim(line)`** 사용. `trim` 은 binder(`compiler/check/bind.hexa`) + arm64 백엔드(`compiler/codegen/arm64_darwin.hexa`: `trim -> rt_str_trim`)가 인정하는 free-fn builtin. **그러나 gen2 C 백엔드(`self/codegen.hexa` `gen2_expr` free-fn 블록)에 free-fn `trim` lowering 이 누락** (`split` 은 있음) → generic `hexa_call1(trim,…)` 로 fall-through → undeclared.
- = **cross-backend 불일치**: Mac arm64 는 free-fn `trim` 동작, 포터블 C 백엔드(Linux `hexa run`)는 미동작. tokenizer_bpe 가 Linux flame 경로에 연결 안 됐던 진짜 이유. free-fn `trim` 쓰는 self/ 모듈 47곳 공통 영향.

**fix (#1527 MERGED)**: `gen2_expr` free-fn 블록에 `.trim()` 메서드 경로(self/codegen.hexa:3942/7190 `cg_string_sym("str_trim") -> rt_str_trim`)와 동일한 free-fn `trim` lowering 추가 (12 LoC, SSOT only — hexa_cc.c bootstrap 은 표준 cadence). ubu-2 end-to-end 검증: `hexa cc --regen` → standalone `trim("  hi  ")` 가 `rt_str_trim` 으로 lowering + clang 링크 + 실행, `use "self/ml/tokenizer_bpe"` 전체 체인 컴파일 + round-trip PASS.

**진행 (2026-05-27)**:
1. ✅ **DONE (#1533)** `self/native/hexa_cc.c` bootstrap 재생성 — #1527 라이브, self-host fixpoint(gen1==gen2 byte-identical) 검증
2. ✅ **DONE (anima #1537)** stdlib/flame BPE-corpus 로더 (`flame_bpe_corpus_lib.hexa`) — CI 테스트 10/10 PASS (`flame_bpe_corpus_test.hexa`, toy vocab round-trip)
3. ❌ **FALSE — 양 Qwen 토크나이저 모듈 모두 실측 결함** (hexa-lang 도메인 fix 필요): (a) `tokenizer_bpe.hexa` (chr 기반) — hexa `chr(n)` byte 절단(`chr(288)==chr(32)`)으로 byte-level 256 distinct char 불가 → 공백/비-ASCII 손상. 실측 round-trip FALSE (`consciousness!emerges!from!cells`). (b) `qwen_bpe.hexa` (from_char_code UTF-8-aware, 1030L) — mini macOS arm64 toy fixture(post-#1549 path-fix) **Segfault 11** vocab 파싱 #200 직후 + Linux 실 7MB 240s 타임아웃. **잔여 잔여** = 세 잔여(chr Unicode · tokenizer_bpe byte-domain 재설계 · qwen_bpe segfault+perf) 중 하나라도 풀려야 함 → `inbox/notes/hexa-chr-unicode-byte-level-bpe.md` (병행결함 섹션 포함). loader 가드(anima #1537)가 검출 → 가짜 closure 아님. 본 fix 후 3B Qwen 정상화
