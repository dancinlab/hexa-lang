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
