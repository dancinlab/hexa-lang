# r15-D9 RFC — `.len()` 바이트/코드포인트/grapheme 3-tier 문자열 길이 정책

- **Status**: design-draft (정책 명세 · 별도 surgical PR 가 본 문서의 권고를 구현)
- **Date**: 2026-05-24
- **Severity**: MEDIUM (correctness footgun · 사용자-노출 의미론 · breaking 여부 결정 필요)
- **Source**: PROBE r15 cycle-1 sweep — "D9 `.len()` returns BYTES not graphemes — 3-tier policy 필요"
- **선행 surface**: `.char_count()` / `.chars()` / `.bytes()` 이미 랜딩 (parity-gate t45b, 2026-05-19) · `.codepoints()` alias (PROBE r14, 2026-05-23) · `.graphemes()` stub (#495 / PROBE r14-U, 2026-05-23 — DEGRADED, `.chars()` 로 alias)
- **Lane**: docs-only. 본 문서는 정책 명세이며 컴파일러 소스(`codegen.hexa` / `parser.hexa` / `runtime*.c`)는 **건드리지 않음**. (in-flight codegen PR 와의 충돌 회피)

---

## 1. 배경 — 현 동작 + 측정 evidence

hexa 의 문자열은 **byte-sequenced UTF-8** 이다 (`HX_STR`/`HX_STRLEN` = raw byte buffer; `runtime_core.c:4785`). 현재 길이/iteration surface 는 이미 4종이 존재한다:

| method | 의미 | 구현 | 정의 위치 |
|---|---|---|---|
| `.len()` | **bytes** | `hexa_len` → `HX_STRLEN` | `runtime_core.c:2240` · `codegen.hexa:3696` |
| `.char_count()` | **codepoints** | `hexa_str_char_count` (UTF-8 lead-byte walk) | `runtime_core.c:4802` · `codegen.hexa:3719` |
| `.chars()` / `.codepoints()` | codepoint 배열 (1-cp string element) | `hexa_str_chars` | `runtime_core.c:4547` · `codegen.hexa:3699/3703` |
| `.bytes()` | byte 배열 (octet element) | `hexa_str_bytes` | `codegen.hexa:4035` |
| `.graphemes()` | **(현재) codepoint 배열 — STUB** | `.chars()` 로 alias | `codegen.hexa:3711` |

핵심 deviation: **`.graphemes()` 가 진짜 grapheme cluster 가 아니라 codepoint 를 센다.** `codegen.hexa:3706-3712` 의 주석이 이를 명시한다 — "DEGRADED: aliases to `.chars()` ... for ZWJ/RI/marks/Hangul L+V+T it returns codepoint count, NOT canonical UAX-29 cluster count."

### 1.1 측정 evidence (probe 직접 실행)

현 main 의 self-hosted transpiler (`self/native/hexa_v2`) 로 직접 transpile → `clang -I self ... self/runtime.c` 컴파일 → 실행. 테스트 문자열은 **literal UTF-8 byte 를 소스에 직접 임베드** (현 lexer 는 `\u{...}` escape 미지원 — 그 자체로 별개 gap, §8 참고).

```
test string                       .len()  .char_count()  .chars().len()  .bytes().len()  .graphemes().len()
[1] "hello"          (ASCII)         5          5               5               5                5
[2] "héllo"  (precomposed é=U+00E9)  6          5               5               6                5
[3] e + U+0301  (combining acute)    3          2               2               3                2   ← 틀림
[4] "😀"        (U+1F600)            4          1               1               4                1
[5] "👨‍👩‍👧"   (ZWJ family)         18          5               5              18                5   ← 틀림
[6] "한"  (precomposed U+D55C)       3          1               1               3                1
```

해석:

- `.len()` 은 일관되게 **bytes** (`é`=2B, 😀=4B, ZWJ family=18B). 시스템-레벨 least-surprise.
- `.char_count()` ≡ `.chars().len()` ≡ codepoints. 일관.
- `.bytes().len()` ≡ `.len()`. 일관 (둘 다 byte).
- **`.graphemes().len()` 은 codepoint 를 반환** — case [3] 은 2 (정답 1), case [5] 는 5 (정답 1). **이것이 footgun.** 사용자가 "user-perceived character 개수" 를 원해서 `.graphemes()` 를 부르면 ZWJ emoji family 에서 5 를 받는다.

> UAX-29 정답 (Unicode Text Segmentation, extended grapheme cluster):
> [1]=5 · [2]=5 · [3]=**1** · [4]=1 · [5]=**1** · [6]=1.

---

## 2. Canonical 비교 — 타 언어의 `.len()` 의미론

| 언어 | `.len()` / 기본 길이 | codepoint 세기 | grapheme cluster 세기 | 비고 |
|---|---|---|---|---|
| **Rust** | `str::len()` = **bytes** | `.chars().count()` | std 없음 — `unicode-segmentation` crate `.graphemes(true).count()` | 시스템 canonical; "len=bytes" 가 명시적 |
| **Go** | `len(s)` = **bytes** | `utf8.RuneCountInString(s)` | std 없음 — `x/text` 또는 `uniseg` | Rust 와 동일 철학 |
| **Python 3** | `len(s)` = **codepoints** | `len(s)` (동일) | std 없음 — `regex \X` 또는 `grapheme` PyPI | str = codepoint 시퀀스 추상화 |
| **Swift** | `s.count` = **grapheme clusters** | `s.unicodeScalars.count` | `s.count` (기본) | **유일한 outlier**; `Character` = extended grapheme cluster |
| **JavaScript** | `s.length` = **UTF-16 code units** | `[...s].length` (spread) | `Intl.Segmenter` (ES2022+) | (참고) BMP 밖 surrogate pair 함정 |
| **Java** | `s.length()` = **UTF-16 code units** | `s.codePointCount(...)` | `BreakIterator` | (참고) JS 와 동일 함정 |

요약:

- **bytes**: Rust, Go — 시스템/네이티브 진영. "len 은 메모리 크기" 직관, O(1).
- **codepoints**: Python — 추상화 진영. UTF-16/UTF-8 표현 은닉.
- **grapheme clusters**: Swift — "사람이 보는 글자 1개" 직관, 가장 비싸고 (UAX-29 table 필요) breaking 위험.
- **UTF-16 code units**: JS/Java — 역사적 부채 (hexa 비대상; UTF-8 native 이므로).

hexa 는 **no-LLVM native 컴파일러 + byte-UTF-8 string** 이라는 정체성상 Rust/Go 진영에 가장 가깝다.

---

## 3. 제안 — 3-tier 정책

### 3.1 세 tier 의 unambiguous 명명

| Tier | 의미 | 권고 canonical surface | 기존 alias (유지) |
|---|---|---|---|
| **T0 bytes** | UTF-8 octet 개수 | `.len()` | `.bytes().len()` |
| **T1 codepoints** | Unicode scalar 개수 | `.char_count()` | `.chars().len()` · `.codepoints().len()` |
| **T2 graphemes** | UAX-29 extended grapheme cluster 개수 | `.graphemes().len()` (→ §5 에서 진짜 구현) | (신규 `.grapheme_count()` 권고 — §3.3) |

원칙: **각 tier 는 정확히 하나의 의미만** 갖고, "len" 이라는 단어는 byte 에 고정한다 (Rust/Go canonical). codepoint·grapheme 은 명시적 method 이름으로만 노출 → 사용자가 "어느 단위인지" 를 호출부에서 읽을 수 있다.

### 3.2 옵션 trade-off

`.len()` 의 의미를 무엇으로 둘 것인가가 핵심 결정이다. 세 옵션:

| 옵션 | `.len()` 의미 | 장점 | 단점 | breaking? |
|---|---|---|---|---|
| **A** | **bytes** (현 동작 유지) | Rust/Go canonical · O(1) · 현 동작과 일치 (zero-migration) · slicing/byte-IO 와 index 일관 | 비-ASCII 입문자 함정 (`"한".len()==3`) — 단 `.char_count()` 가 해소 | **NO** |
| **B** | **graphemes** (Swift-style) | "사람이 보는 글자수" 직관 · 가장 안전한 멘탈모델 | O(n) + UAX-29 table 필요 · `.len()` ≠ byte index ↔ slicing 함정 폭증 · **모든 기존 `.len()` 호출부 의미 변경** · native 진영 컨벤션 위반 | **YES (대규모)** |
| **C** | **codepoints** (Python-style) | byte 표현 은닉 · `"한".len()==1` 직관 | O(n) · 여전히 grapheme≠len (ZWJ 함정 잔존) · `.len()` ≠ byte index · 기존 호출부 의미 변경 | **YES (대규모)** |

추가 고려 — `.len()` 이 byte index 와 align 되어야 하는 이유: `.byte_at(i)` / `.char_substring` / slicing 류가 모두 byte 또는 codepoint 단위 index 를 받는다. `.len()` 을 grapheme 으로 바꾸면 `for i in 0..s.len()` 패턴이 index 와 단위 불일치 → silent OOB/오프바이. 옵션 A 만 이 불일치를 0 으로 유지한다.

### 3.3 권고 — **옵션 A (`.len()` = bytes 유지) + `.graphemes()` 진짜 구현 + `.grapheme_count()` 신설**

근거:

1. **least-surprise for systems**: hexa 는 byte-UTF-8 native 컴파일러다. Rust/Go 와 동일하게 `.len()`=bytes 가 정체성에 부합하고, byte-index API 와 단위가 일관된다.
2. **zero-migration**: 옵션 A 는 현 동작 그대로라 기존 코드/atlas/테스트가 안 깨진다. B/C 는 모든 `.len()` 호출부의 의미를 바꿔 wipe-guard 급 위험.
3. **footgun 은 `.len()` 이 아니라 `.graphemes()` 에 있다**: 측정 evidence([3]/[5])가 보여주듯 진짜 버그는 `.graphemes()` 가 codepoint 를 세는 것. `.len()` 의 의미를 바꿔도 이 버그는 안 고쳐진다. 옳은 fix 는 `.graphemes()` 를 UAX-29 로 완성하는 것 (§5).
4. **3-tier 가 이미 거의 갖춰짐**: `.len()`(byte) / `.char_count()`(cp) / `.graphemes()`(grapheme) 세 surface 가 존재. 남은 건 T2 의 정확도뿐.

권고 delta (구현 PR 이 할 일):

- `.len()` = bytes **유지** (변경 없음).
- `.char_count()` = codepoints **유지** (canonical T1).
- `.graphemes()` 를 **진짜 UAX-29 cluster 분할로 교체** (§5) — 현 `.chars()`-alias stub 제거.
- T2 의 count-only fast-path 로 **`.grapheme_count()` 신설** (배열 할당 없이 cluster 개수만; `.char_count()` 와 대칭).
- (선택) 입문자 함정 완화용 **lint/explain note**: `"한국어".len()` 처럼 비-ASCII literal 에 직접 `.len()` 산술이 붙으면 "len=bytes; codepoint 는 `.char_count()`" hint (codegen 비변경, diagnostics-only — 별도 검토).

---

## 4. acceptance probe set (falsifiable)

구현 PR 은 아래 표를 정확히 재현해야 한다. (literal UTF-8 임베드; `\u{}` 미지원이므로 raw byte source. tier 별 기대값)

| # | string (UTF-8) | desc | `.len()` (T0 bytes) | `.char_count()` (T1 cp) | `.graphemes().len()` / `.grapheme_count()` (T2) |
|---|---|---|---|---|---|
| 1 | `hello` | ASCII | **5** | **5** | **5** |
| 2 | `héllo` | precomposed é (U+00E9) | **6** | **5** | **5** |
| 3 | `e` + U+0301 | combining acute (decomposed) | **3** | **2** | **1** ← stub 은 2 (FAIL) |
| 4 | `😀` | U+1F600 | **4** | **1** | **1** |
| 5 | `👨‍👩‍👧` | ZWJ family (man+ZWJ+woman+ZWJ+girl) | **18** | **5** | **1** ← stub 은 5 (FAIL) |
| 6 | `한` | precomposed Hangul U+D55C | **3** | **1** | **1** |
| 7 | `ᄒ`+`ᅡ`+`ᆫ` | Hangul L+V+T (U+1112 U+1161 U+11AB, 조합형) | **9** | **3** | **1** ← UAX-29 L·V·T 규칙 |
| 8 | `🇰🇷` | regional-indicator pair (KR flag) | **8** | **2** | **1** ← RI pair 규칙 |
| 9 | `a` + U+0301 + U+0323 | 다중 combining mark stack | **5** | **3** | **1** |

falsifier:

- **F-T0** (regression guard): #1–#9 의 `.len()` 열이 위 byte 값과 정확히 일치 (옵션 A = 불변).
- **F-T1** (regression guard): #1–#9 의 `.char_count()` 열 일치.
- **F-T2-zwj**: `"👨‍👩‍👧".graphemes().len() == 1` (현 stub: 5 → FAIL = 구현 미완 증명).
- **F-T2-comb**: `("e" + combining acute).graphemes().len() == 1` (현 stub: 2 → FAIL).
- **F-T2-ri**: KR flag `.graphemes().len() == 1`.
- **F-T2-lvt**: Hangul L+V+T `.graphemes().len() == 1`.
- **F-symmetry**: `.grapheme_count() == .graphemes().len()` for #1–#9 (count-only fast-path 일치).

probe 재현 명령 (참고):

```
# transpile + compile + run (self-hosted, byte-UTF-8 source)
cp self/native/hexa_v2 /tmp/hxcc
/tmp/hxcc /tmp/strlen_probe.hexa /tmp/strlen_probe.c
clang -O0 -w -I self -o /tmp/strlen_probe /tmp/strlen_probe.c self/runtime.c -lm
/tmp/strlen_probe
```

---

## 5. `.graphemes()` 완성 방안 (UAX-29)

현 stub (`codegen.hexa:3711`, `.chars()` alias) 을 진짜 extended grapheme cluster 분할로 교체. 두 갈래:

### 옵션 5-A: pure-hexa GraphemeBreak property table (권고)

- UAX-29 `GraphemeBreakProperty.txt` 의 codepoint→class 매핑을 **생성된 hexa table** 로 임베드 (`Control / CR / LF / Extend / SpacingMark / Prepend / ZWJ / RI / L / V / T / LV / LVT / Extended_Pictographic`).
- 분할 알고리즘 = UAX-29 §3.1 GB1–GB999 boundary rule 의 직접 구현 (state machine; ~15 rule). ZWJ emoji sequence (GB11: `\p{Extended_Pictographic} (Extend* ZWJ \p{Extended_Pictographic})`), RI pair (GB12/GB13), Hangul L·V·T·LV·LVT (GB6–GB8), combining mark (GB9/GB9a) 처리.
- table 은 range-compressed (대부분 Extend/Pictographic 가 연속 block) → binary-search lookup. atlas/codegen 와 동일한 "generated table, no external dep" 철학.
- **장점**: no external dependency · self-host 빌드와 정합 · no-LLVM/no-C-transpile 정체성 부합 · cross-platform byte-identical 유지.
- **단점**: table 생성 step (UCD 파싱 1회) + table 크기 (~수 KB compressed) + 정확도 = 임베드한 UCD 버전에 종속.

### 옵션 5-B: libunicode / ICU dependency

- 외부 C 라이브러리 (ICU `ubrk_*` 또는 utf8proc `utf8proc_grapheme_break`) 링크.
- **장점**: UAX-29 정확도 검증된 구현 · 버전 추적 자동.
- **단점**: external native dependency (현 runtime 은 libm/libdl 외 무의존) · cross-platform 빌드 복잡도 · self-host/atlas 철학과 충돌 · 배포 footprint 증가.

→ **권고: 5-A (pure-hexa table).** hexa 의 "no LLVM · no C-transpile · generated-table" 정체성과 atlas/codegen 의 자족 빌드 모델에 부합. 5-B 는 정확도는 좋으나 무의존 runtime 원칙을 깬다. table 은 `.chars()` walk (이미 존재) 위에 GraphemeBreak class lookup + GB rule state machine 만 얹으면 되어 incremental.

구현 시 분리 권장: (1) `.graphemes()` = 배열 (cluster 별 substring), (2) `.grapheme_count()` = count-only (배열 미할당). `.char_count()` ↔ `.chars()` 대칭과 동일 패턴.

---

## 6. 요약 (구현 PR 용 권고 4줄)

1. `.len()` = **bytes 유지** (옵션 A · Rust/Go canonical · zero-migration · byte-index 일관). breaking 변경 안 함.
2. 3-tier 명명 고정: **T0 `.len()`=byte · T1 `.char_count()`=codepoint · T2 `.graphemes()`=UAX-29 cluster**.
3. footgun fix = **`.graphemes()` stub 을 진짜 UAX-29 로 교체** (현재 codepoint 를 셈 → ZWJ/combining 에서 오답). pure-hexa GraphemeBreak table (옵션 5-A).
4. T2 count fast-path **`.grapheme_count()`** 신설 (`.char_count()` 대칭). §4 acceptance probe 9-row 으로 검증.

---

## 7. open questions

- **Q1**: 입문자 함정 완화용 lint/explain note (`"비ASCII".len()` 산술 시 hint) 를 넣을지 — diagnostics-only 라 codegen 비변경이지만 noise 위험. 별도 검토.
- **Q2**: UAX-29 외에 **legacy grapheme cluster** (extended vs legacy) 구분 surface 가 필요한지 — 대부분 extended 만 노출하면 충분 (Swift/Rust 컨벤션). 일단 extended only 권고.
- **Q3**: UCD 버전 pinning 정책 — 임베드 table 의 Unicode 버전을 atlas 처럼 SSOT 로 고정/추적할지. (emoji 신규 sequence 추가 시 table regen.)
- **Q4**: `.width()` (terminal display column, East-Asian Wide / 0-width) 는 4번째 tier 인가 별개 RFC 인가 — grapheme≠display-width (`한`=1 grapheme but 2 columns). 본 RFC 범위 밖, 후속 분리 권고.
- **Q5**: `\u{...}` / `\u XXXX` unicode escape 미지원 (현 lexer 가 `\u{0301}` 를 literal `u{0301}` 로 둠 — §1.1 측정 시 확인). 별개 lexer gap → 별도 PROBE 항목으로 file 권고 (본 RFC 와 독립).

---

*Provenance: PROBE r15-D9 — `.len()` byte/codepoint/grapheme 3-tier 정책 RFC. 측정 evidence = `self/native/hexa_v2` self-host transpile + `clang -I self ... self/runtime.c` 실행 (literal UTF-8 임베드 probe, 6 strings + UAX-29 ground truth). docs-only lane (컴파일러 소스 무변경 · in-flight codegen PR 충돌 회피). 2026-05-24.*
