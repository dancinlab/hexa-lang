# 발견: hexa `chr(n)` 바이트 절단 — GPT-2/Qwen byte-level BPE round-trip 손상

> upstream gap: `chr(n>255)` 가 code point 가 아니라 byte 로 절단 (`chr(288) == chr(32)`).
> flame-P2b 의 실 Qwen round-trip 을 막는 진짜 잔여 blocker (trim #1527 보다 깊음).

## 한 줄

`self/ml/tokenizer_bpe.hexa` 의 `build_byte_to_char` 는 비-출력 바이트를 `chr(256 + i)` 로 **구별되는 단일 char** 에 매핑해야 GPT-2 byte-level 인코딩이 성립하나, hexa `chr` 이 `n & 0xFF` 로 절단해 `chr(256+i) == chr(i)` → 256 distinct char 불가 → 공백·비-ASCII round-trip 손상.

## 실측 (self-judge 아님 · commons g73 준수)

ubu-2 Linux, `#1527`+`#1533` 컴파일러, 로컬 Qwen vocab(151643)/merges(151388):

```
# 진단 probe (일반 hexa, tokenizer 불요):
len(chr(288))            = 1
char_code(chr(288), 0)   = 32      ← chr(288) 이 byte 32 (== 288 & 0xFF). 구별 char 아님

# 실 Qwen round-trip (flame_bpe_corpus_lib / bpe_load):
vocab_size = 151643      load 222ms      encode 141ms      all ids in [0,V): true
round-trip match: FALSE              decoded=[consciousness!emerges!from!cells]
                                              ↑ 공백(0x20) 손상
```

toy vocab (V=4, ASCII, 공백 없음) 은 round-trip PASS (`flame_bpe_corpus_test` 10/10) — 공백/비-ASCII 가 트리거. **실-규모 검증(③)이 toy 가 놓친 결함을 잡음.**

## 근본 원인

GPT-2 byte-level 스킴은 256 바이트값 ↔ 256 distinct char 전단사가 필수. 비-출력 바이트(0-32·127-160·173 등)를 code point 256+ 영역의 단일 char 로 옮겨 단일-char 토큰성을 유지함. hexa `chr` 이 byte-only(≤255)면 이 영역을 표현 불가 → `chr(256+i)` 가 `chr(i)` 로 붕괴 → 공백 byte-char 가 리터럴 0x20 과 충돌 → Qwen 의 `Ġ`(U+0120) 토큰과 불일치 → round-trip 손상.

## 요청 (택1)

1. **`chr`/`char_code` Unicode 화 (권장 · 근본)**: `chr(n)` 이 n>255 면 code point 로 보고 UTF-8 인코딩한 문자열 반환; `char_code` 는 code point 디코드. runtime(`self/rt/string` · `runtime.c`)의 chr/char_code + slice/len 의 code-point semantics 정합 필요 (현 `len(chr(288))==1` 은 이미 code-point 단위라 부분 정합). blast radius: byte-chr 에 의존하는 기존 호출 검토.
2. **tokenizer_bpe 재설계 (대안)**: byte-char 를 chr>255 대신 다른 표현(예: 비-출력 바이트용 2-char ASCII escape, 또는 string-char 대신 int-array byte 표현)으로 — chr Unicode 불요하나 tokenizer 내부 변경 큼.

## 차단 여부

⚠ flame-P2b 의 **CORRECT Qwen 토큰화** 차단. 와이어링(loader, anima #1537)은 land 됨 + `flame_bpe_roundtrip` 가드가 이 결함을 정확히 검출(false 반환 → fire 금지)하므로 가짜 closure 아님. 3B Qwen hexa-native 학습은 본 fix 후 정상화.

## 병행 결함 — `self/ml/qwen_bpe.hexa` 도 비기능 (2026-05-27)

위 chr 결함 회피를 위해 `from_char_code`(UTF-8-aware) 기반의 **별도 모듈** `self/ml/qwen_bpe.hexa` (1030L, HF tokenizer.json 전용 BPE) 가 존재 — toy fixture 검증 시도 결과:

```
# mini macOS arm64, post-#1549 t53 path-fix:
[qwen_bpe] module loaded
[qwen_bpe] read 6486 bytes in 0 ms
[qwen_bpe] parsed 3 added_tokens in 0 ms
[qwen_bpe] parsing vocab... · vocab progress: 50 · 100 · 150 · 200
Segmentation fault: 11
```

vocab 파싱 #200 직후 SIGSEGV — toy fixture(6.5KB) 도 통과 못 함. ubu-2 Linux 실 7MB tokenizer.json 도 240s 타임아웃/무응답(perf 또는 hang).

= flame-P2b ③ correct Qwen 토큰화 **양쪽 후보 모듈 모두 실측 결함**:

| 모듈 | macOS arm64 | Linux C 백엔드 |
|---|---|---|
| `tokenizer_bpe` (chr 기반) | (동일 chr 결함 예상) | round-trip FALSE — 공백 손상 |
| `qwen_bpe` (from_char_code 기반) | **Segfault 11** (vocab #200) | 7MB 240s 타임아웃 |

## 잔여 (maintainer 영역)

1. `qwen_bpe` vocab 파서 메모리 안전성 — vocab #200 부근 SIGSEGV 디버깅 (Mac arm64 실측)
2. `qwen_bpe` Linux 실 tokenizer.json (V=151643, merges=151388) perf — O(n²) `get_merge_rank` linear-scan 추정
3. `tokenizer_bpe` chr 우회 (본 문서 §1 chr Unicode 또는 byte-domain 재설계)

세 잔여 중 하나라도 풀리면 anima #1537 loader 의 round-trip 가드가 자동 통과 → 3B Qwen hexa-native 학습 unblock.

## 차단 여부

⚠ flame-P2b 의 **CORRECT Qwen 토큰화** 차단. 와이어링(loader, anima #1537)은 land 됨 + `flame_bpe_roundtrip` 가드가 양 결함을 정확히 검출(false 반환 → fire 금지)하므로 가짜 closure 아님. 3B Qwen hexa-native 학습은 본 fix 후 정상화.

## 참조

- #1527 (free-fn trim codegen) — flame-P2b 첫 blocker, fix 됨
- #1533 (bootstrap regen) — #1527 라이브
- #1549 (t53 fixture path typo) — qwen_bpe 검증 unblock
- anima #1537 — flame BPE corpus loader (가드가 본 결함들 검출)
- `GPU.md` flame-P2b 라인 · `inbox/notes/anima-decoder-moe-toy-pass-gates-flame-p2b-qwen-bpe.md`
