# r15-D11 RFC — Unicode 정규화(NFC/NFD) 정책 — `==` / hash / 명시적 normalize surface

- **Status**: design-draft (정책 명세 · 별도 surgical PR 가 본 문서의 권고를 구현)
- **Date**: 2026-05-24
- **Severity**: MEDIUM (correctness footgun · 사용자-노출 의미론 · `==`/hash 동등성 결정 필요)
- **Source**: PROBE r15 cycle-1 sweep — "D11 NFC normalization 미수행 — canonical-equivalent 텍스트가 `==` 불일치 / hash 상이 / `.char_count()` 상이"
- **선행 surface**: D9 `.len()` 3-tier 정책 RFC (#768, draft) · D10 `.graphemes()` UAX-29 cluster segmentation (#794, **MERGED** 2026-05-24)
- **Lane**: docs-only. 본 문서는 정책 명세이며 컴파일러 소스(`codegen.hexa` / `parser.hexa` / `runtime*.c`)는 **건드리지 않음**. (in-flight codegen PR 와의 충돌 회피)

---

## 1. 배경 — 현 동작 + 측정 evidence

hexa 의 문자열은 **byte-sequenced UTF-8** 이고, `==` 비교 및 map hash 는 **byte-exact**(= codepoint-exact) 이다. Unicode **정규화는 어디에서도 수행되지 않는다.**

그 결과 *canonical-equivalent* 한 텍스트 — 즉 같은 추상 문자열을 다른 codepoint 시퀀스로 쓴 것 — 이 다음 4가지 surface 에서 **서로 다르게** 취급된다:

1. `s1 == s2` 가 **false**
2. map / set 의 **hash key 가 다름** (같은 글자인데 두 엔트리)
3. `.char_count()` 가 **다름** (precomposed 1 vs decomposed 2)
4. (간접) `.graphemes()` 가 같은 cluster 로 묶더라도, count 의 기반인 codepoint 시퀀스는 여전히 다름

이는 D9(`.len()` 단위 정책)·D10(`.graphemes()` UAX-29)에 이은 **올바른 Unicode 텍스트 처리의 세 번째 다리**다. D10 이 "사람이 보는 글자 1개" 의 *세기*를 고쳤다면, D11 은 "같은 글자인가"의 *동등성*을 다룬다.

### 1.1 정규화 형태 (배경 용어)

Unicode 는 4개 정규화 형태(UAX-15)를 정의한다:

| 형태 | 의미 | 예: `é` | 예: `①` / `ﬁ` |
|---|---|---|---|
| **NFD** | Canonical Decomposition | `e` + U+0301 | (불변) |
| **NFC** | NFD 후 Canonical Composition | U+00E9 (합성) | (불변) |
| **NFKD** | Compatibility Decomposition | `e` + U+0301 | `1` / `f`+`i` |
| **NFKC** | NFKD 후 Canonical Composition | U+00E9 | `1` / `fi` |

- **canonical**(NFC/NFD): 글리프 모양 보존, 가역적. `é`(U+00E9) ↔ `e`+U+0301 은 canonical-equivalent.
- **compatibility**(NFKC/NFKD): 의미는 같으나 모양이 다를 수 있는 변형까지 통합(`①`→`1`, ligature `ﬁ`→`fi`, 전각→반각). **손실적(lossy)** · 비가역. 검색/식별자 비교용.

### 1.2 측정 evidence (probe 직접 실행)

현 main(`4c4ac4ca`, D10 #794 머지 후)의 self-hosted transpiler(`self/native/hexa_v2`)로 직접 transpile → `clang -I self ... self/runtime.c` 컴파일 → 실행. 테스트 문자열은 **literal UTF-8 byte 를 소스에 직접 임베드**(현 lexer 는 `\u{...}` escape 미지원 — D9 §Q5 와 동일 gap).

```
string                              .len()  .char_count()  .graphemes().len()
[A] precomposed e-acute  (U+00E9)      2          1                1
[B] decomposed e + U+0301              3          2                1
    A == B  ->  UNEQUAL
[C] precomposed Hangul   (U+D55C)      3          1                1
[D] conjoining L+V+T (U+1112 1161 11AB) 9          3                1
    C == D  ->  UNEQUAL
[E] precomposed o-circumflex (U+00F4)  2          1                1
[F] decomposed o + U+0302              3          2                1
    E == F  ->  UNEQUAL

map hash:  m[pre_e]=1; m[dec_e]=2;  m[pre_e] == 1   (distinct hash keys)
```

해석:

- `==` 는 **codepoint-exact** — `é`(precomposed) 와 `é`(decomposed) 가 **UNEQUAL**. 한글 precomposed `한` 과 조합형 `ᄒ+ᅡ+ᆫ` 도 UNEQUAL.
- map **hash key 가 distinct** — `m[pre_e]` 가 `dec_e` 를 같은 글자로 보지 않아 별도 엔트리(`m[pre_e]` 가 1 유지). dedup/lookup footgun.
- `.char_count()` 가 **다름** — precomposed=1, decomposed=2. (사용자가 "글자 수" 로 codepoint 를 쓰면 입력 출처에 따라 값이 흔들림.)
- **D10 의 `.graphemes()` 는 두 형태 모두 1** 로 올바르게 묶는다 ([A]=[B]=1, [C]=[D]=1). 즉 *grapheme 세기*는 정규화에 견고하지만, *equality·hash·codepoint 세기*는 여전히 형태에 종속된다. **D11 의 핵심: D10 이 cluster 세기를 고쳤어도 동등성/해시 누락은 별개로 남아 있다.**

> ground truth: [A]≡[B] (NFC(둘 다)=U+00E9) · [C]≡[D] (NFC(둘 다)=U+D55C) · [E]≡[F] (NFC=U+00F4). 셋 다 canonical-equivalent → 올바른 정규화 후 `==` 는 true 여야 한다(정규화를 켰을 때).

### 1.3 기존 normalize API 부재 확인

`grep -niE 'normaliz|nfc|nfd|nfkc|nfkd' self/codegen.hexa self/runtime*.c` 결과 Unicode 정규화 builtin **전무**(매칭은 전부 float renormalize / param normalize 등 무관). `.nfc()` / `.nfd()` / `.normalize()` surface 없음. → D11 은 *신규 surface 도입* 결정이지 기존 동작 수정이 아니다(이 점에서 D9/D10 와 다름).

---

## 2. Canonical 비교 — 타 언어의 정규화 정책

| 언어 | `==` 가 정규화? | normalize API | 기본/권장 형태 | std 포함? |
|---|---|---|---|---|
| **Rust** | **NO** (byte/codepoint-exact) | `unicode-normalization` crate — `.nfc()` `.nfd()` `.nfkc()` `.nfkd()` (iterator adapter) | 없음 (명시적) | crate (std 없음) |
| **Go** | **NO** (byte-exact) | `golang.org/x/text/unicode/norm` — `norm.NFC.String(s)` 등 | 없음 (명시적) | x/text (std 없음) |
| **Python 3** | **NO** (codepoint-exact) | `unicodedata.normalize('NFC'\|'NFD'\|'NFKC'\|'NFKD', s)` | 없음 (명시적) | **std** (`unicodedata`) |
| **Swift** | **YES** (canonical equivalence) | `s.precomposedStringWithCanonicalMapping`(NFC) / `...Compatibility...`(NFKC) (Foundation) | NFC-ish (비교 시 자동) | Foundation |
| **JavaScript** | **NO** (code-unit exact) | `s.normalize('NFC'\|'NFD'\|'NFKC'\|'NFKD')` | NFC (인자 기본) | **language** (ES6 내장) |
| **Java** | **NO** (`equals` char-exact) | `Normalizer.normalize(s, Form.NFC\|...)` | 없음 (명시적) | std (`java.text`) |

요약:

- **`==` 는 정규화 안 함 (다수파)**: Rust · Go · Python · JS · Java — 5/6. "동등성은 representation-exact, 정규화는 명시적 opt-in" 이 사실상 산업 표준.
- **`==` 가 정규화 (유일한 outlier)**: Swift — `String` 이 canonical-equivalence 로 비교. 직관적이나 (a) `==` 가 O(1) 가 아님, (b) `unicodeScalars`/`utf8` view 로 내려가야 representation-exact 비교 가능, (c) 대부분 언어 멘탈모델과 불일치.
- **explicit normalize API 는 보편**: 6/6 모두 형태 4종(NFC/NFD/NFKC/NFKD)을 명시 호출로 제공. 다만 std-내장(Python/JS/Java) vs 외부 패키지(Rust/Go)로 갈림.

hexa 는 **no-LLVM native 컴파일러 + byte-UTF-8 string** 정체성상 D9 와 동일하게 Rust/Go 진영(`==` codepoint-exact)에 가장 가깝다.

---

## 3. 제안 — 정책 + 권고

### 3.1 핵심 결정 축

| 축 | 질문 | 옵션 |
|---|---|---|
| (a) `==`/hash | 정규화할 것인가? | 정규화(Swift) vs codepoint-exact(다수파) |
| (b) explicit API | `.nfc()/.nfd()/.nfkc()/.nfkd()` 제공? | 제공 vs 미제공 |
| (c) 구현 비용 | 정규화 table 을 어디서? | full UCD table vs scoped subset vs 무 |
| (d) D9/D10 연계 | `.char_count()`/`.graphemes()` 와 상호작용 | normalize 후 세기 옵션 등 |

### 3.2 옵션 trade-off

| 옵션 | `==`/hash | normalize API | 장점 | 단점 | breaking? |
|---|---|---|---|---|---|
| **A** | **codepoint-exact 유지** | **`.nfc()/.nfd()/.nfkc()/.nfkd()` 신설** | 다수파(Rust/Go/Python/JS/Java) · `==` O(1)·O(n)예측가능 · zero-migration · "정규화는 명시적 opt-in" 멘탈모델 · 사용자가 필요 지점에서만 비용 지불 | 입문자가 precomposed≠decomposed 함정을 만날 수 있음(단 `.nfc()` 로 해소) · NFC/NFD table 구현 비용(§4) | **NO** |
| **B** | **canonical-equivalent (Swift-style)** | (선택) | "같은 글자면 같다" 직관 · dedup/lookup 안전 | `==` 가 O(n)+정규화 table 매 비교 · hash 도 정규화 후 계산(전부 O(n)) · **모든 기존 `==`/map 의미 변경**(wipe-guard급) · representation-exact 비교 surface 별도 필요 · native 진영 컨벤션 위반 · 유일 outlier | **YES (대규모)** |
| **C** | codepoint-exact 유지 | **미제공 (status-quo)** | 비용 0 | footgun 미해소 · D9/D10 와 비대칭(텍스트 정확성 3-leg 중 1개 누락) · 사용자가 직접 정규화 불가 | **NO** |

`==` 를 정규화로 바꾸면(B) `for`/`switch`/map-key/atlas-cite/테스트 단언 등 **모든 동등성 호출부 의미가 바뀐다**. D9 §3.2 의 "옵션 A 만 불일치를 0 으로 유지" 논리와 동형 — B 는 silent semantic drift 가 광범위하다.

### 3.3 권고 — **옵션 A** (`==`/hash codepoint-exact 유지 + 명시적 `.nfc()/.nfd()/.nfkc()/.nfkd()` 신설)

근거:

1. **다수파 정합 + 정체성 부합**: 6개 canonical 중 5개가 `==` codepoint-exact. hexa 의 byte-UTF-8 native 정체성(D9 권고와 동형)상 Rust/Go 진영이 least-surprise.
2. **`==` 비용 보존**: 정규화 `==`(B) 는 매 비교를 O(n)+table-lookup 으로 만들고 hash 도 정규화 후 계산해야 한다. 동등성은 hot-path(map/set/switch) → codepoint-exact O(1) 단축 비교 유지가 중요.
3. **zero-migration**: A 는 현 동작 그대로(신규 surface만 추가) → 기존 코드·atlas·테스트 불변. B/C 와 달리 wipe-guard 위험 없음.
4. **footgun 은 "동등성 정의"가 아니라 "정규화 수단 부재"**: 사용자가 입력을 dedup/검색하려면 정규화가 *필요*하다. 정답은 `==` 의미를 바꾸는 게 아니라 **명시적 `.nfc()` 를 주어** `a.nfc() == b.nfc()` 패턴(Rust/Go/Python 관용구)을 가능케 하는 것.
5. **D9/D10 와 대칭**: D9=단위(byte/cp/grapheme), D10=cluster 세기, D11=정규화 형태 — 세 leg 모두 "명시적 surface 로 노출, 기본 동작은 native-least-surprise 유지" 라는 동일 원칙.

권고 delta (구현 PR 이 할 일):

- `==` / map hash = **codepoint-exact 유지** (변경 없음).
- **신규**: `s.nfc()` · `s.nfd()` · `s.nfkc()` · `s.nfkd()` → 정규화된 새 string 반환 (Python `unicodedata.normalize` · Rust adapter 와 동형).
- (선택) `s.is_nfc()` 류 quick-check predicate — 이미 NFC 면 O(n) decompose 생략(fast-path; Unicode `quickCheck` 속성).
- (선택) D10 와의 연계: `.char_count()` 가 정규화에 종속됨을 explain/문서에 명시. **세기 자체는 정규화하지 않음**(`a.nfc().char_count()` 로 명시 opt-in) — 묵시적 정규화는 옵션 A 원칙 위반.

---

## 4. 구현 비용 / 단계 — 테이블 크기 현실

정규화는 D10 의 GraphemeBreak 보다 **테이블이 크다**. 필요한 UCD 데이터:

| 데이터 | 용도 | 규모 (UCD ~15.x) |
|---|---|---|
| Canonical Decomposition Mapping | NFD: codepoint → 분해 시퀀스 | ~수천 entry (대부분 Latin/Greek/Cyrillic 합성문자 + Hangul 알고리즘 분해) |
| Canonical Combining Class (CCC) | reorder: combining mark 정렬 | ~비-zero CCC codepoint 수천 |
| Composition Exclusions | NFC: 재합성 금지 목록 | 작은 set |
| Compatibility Decomposition | NFKD/NFKC | canonical 의 상위집합(ligature·전각·circled 등 추가 수천) |
| (algorithmic) Hangul L/V/T | 한글은 산술 분해/합성 (S=0xAC00 + (L*21+V)*28+T) | **table 불요** — 공식만 |

핵심 현실:

- **NFC/NFD canonical 부분만**으로도 GraphemeBreak(range-compressed ~수 KB)보다 큰 **decomposition + CCC table**(압축해도 수십 KB급)이 필요하다.
- **한글은 공짜**: L·V·T 조합/분해가 순수 산술(table 0). 한국어 사용자가 가장 흔히 마주칠 케이스([C]/[D])는 알고리즘만으로 정확히 처리 가능 → **Phase 1 의 cheap win**.
- **NFKC/NFKD 는 더 큼**: compatibility table 이 canonical 의 상위집합. lossy 라 검색/식별자 정규화에만 쓰임 → 우선순위 낮음.

### 권장 phasing

- **Phase 1 (cheap)**: Hangul 산술 NFC/NFD (table 0) + Latin-1/Latin-Extended 핵심 합성문자 subset decomposition(é/ô/ü 등 일상 빈출). → [A]/[B]/[C]/[D]/[E]/[F] acceptance 통과. scoped table.
- **Phase 2**: full canonical decomposition + CCC reorder + composition exclusion table (pure-hexa generated, range-compressed; D10 GraphemeBreak 와 동일 "generated table, no external dep" 철학). NFD/NFC 완전.
- **Phase 3 (선택)**: NFKD/NFKC compatibility. 별도 큰 table — 수요 확인 후.

구현 갈래는 D10 §5 와 동형: **(5-A) pure-hexa generated table**(권고 — no external dep · self-host 정합 · cross-platform byte-identical) vs **(5-B) libunicode/utf8proc(`utf8proc_NFC` 등) 링크**(정확도·버전추적 우수하나 무의존 runtime 원칙 위반). → **5-A 권고**, 단 full canonical table 크기를 감안해 **Phase 화**(위)로 분할. D9/D10 가 `.chars()` walk 위에 쌓았듯, 정규화도 기존 codepoint walk 위에 decompose→reorder→(re)compose 파이프라인만 얹으면 incremental.

---

## 5. acceptance probe set (falsifiable)

구현 PR 은 아래 표를 정확히 재현해야 한다. (literal UTF-8 임베드; `\u{}` 미지원이므로 raw byte source)

### 5.1 동등성 — 정규화 후 (Phase 1+)

| # | a | b | 기대 (정규화 전, 현 동작) | 기대 (`.nfc()` 후) |
|---|---|---|---|---|
| 1 | `é` U+00E9 | `e`+U+0301 | `a==b` **false** (불변) | `a.nfc()==b.nfc()` **true** |
| 2 | `한` U+D55C | `ᄒ`+`ᅡ`+`ᆫ` (L+V+T) | `a==b` **false** (불변) | `a.nfc()==b.nfc()` **true** (Hangul 산술) |
| 3 | `ô` U+00F4 | `o`+U+0302 | `a==b` **false** (불변) | `a.nfc()==b.nfc()` **true** |
| 4 | `한` U+D55C | `한` U+D55C | `a==b` **true** | `true` (idempotent) |

### 5.2 round-trip / 형태 단언

| # | 입력 | 단언 |
|---|---|---|
| 5 | `é` U+00E9 | `.nfd().char_count() == 2` (e + acute) · `.nfd().len() == 3` |
| 6 | `e`+U+0301 | `.nfc().char_count() == 1` · `.nfc().len() == 2` (U+00E9) |
| 7 | `한` U+D55C | `.nfd().char_count() == 3` (L+V+T) · `.nfd().len() == 9` |
| 8 | `한` (L+V+T) | `.nfc().char_count() == 1` · `.nfc() == "한"`(U+D55C) |
| 9 | NFC idempotence | `s.nfc().nfc() == s.nfc()` (모든 s) |
| 10 | NFC/NFD round-trip | `s.nfd().nfc() == s.nfc()` (canonical 가역) |
| 11 | ASCII no-op | `"hello".nfc() == "hello"` · `.nfd() == "hello"` |
| 12 | hash dedup | map 에 `é`(U+00E9) 와 `e`+U+0301 의 **`.nfc()` 키**를 넣으면 **같은 엔트리** |
| 13 | (Phase 3) NFKC | `①.nfkc() == "1"` · `ﬁ.nfkc() == "fi"` (compatibility) |

### 5.3 falsifier

- **F-EQ-UNCHANGED** (regression guard): #1–#3 의 raw `a==b` 가 **여전히 false** (옵션 A = `==` 불변).
- **F-NFC-LATIN**: #1 `é(U+00E9).nfc() == (e+U+0301).nfc()` → true.
- **F-NFC-HANGUL**: #2 한글 L+V+T `.nfc() == "한"`(U+D55C) → true (산술, table 0).
- **F-NFD-HANGUL**: #7 `"한".nfd().char_count() == 3` → true.
- **F-IDEMPOTENT**: #9 `s.nfc().nfc() == s.nfc()`.
- **F-ROUNDTRIP**: #10 `s.nfd().nfc() == s.nfc()`.
- **F-ASCII-NOOP**: #11 ASCII 불변.
- **F-NFKC** (Phase 3): #13 compatibility 통합.

probe 재현 명령 (참고):

```
# transpile + compile + run (self-hosted, byte-UTF-8 source; lexer has no \u{})
cp self/native/hexa_v2 /tmp/v2tool-d11
/tmp/v2tool-d11 /tmp/d11_probe.hexa /tmp/d11_probe.c
clang -O0 -w -I self -o /tmp/d11_probe /tmp/d11_probe.c self/runtime.c -lm
/tmp/d11_probe
```

---

## 6. D9 / D10 연계

세 RFC 가 "올바른 Unicode 텍스트 처리" 의 3-leg 을 이룬다:

| RFC | 다루는 것 | 핵심 결정 | 기본 동작 원칙 |
|---|---|---|---|
| **D9** (#768, draft) | *길이의 단위* — byte / codepoint / grapheme | `.len()`=byte 유지, T1/T2 명시 surface | native-least-surprise + 명시 opt-in |
| **D10** (#794, **merged**) | *grapheme 의 세기* — UAX-29 cluster | `.graphemes()` 진짜 cluster 분할, `.grapheme_count()` 신설 | (구현 완료) |
| **D11** (본 문서) | *문자열의 동등성* — 정규화 형태 | `==` codepoint-exact 유지, `.nfc()/.nfd()/...` 신설 | native-least-surprise + 명시 opt-in |

공통 메타-원칙: **기본 동작은 byte-UTF-8 native 의 least-surprise(byte/codepoint-exact, O(1)/예측가능)로 두고, 사람-지향 의미론(grapheme 세기·정규화 동등성)은 명시적 method 로 노출한다.** 묵시적 마법(Swift `==` 정규화·`.len()`=grapheme)을 피해 호출부에서 단위·형태를 읽을 수 있게 한다.

상호작용 주의:

- `.char_count()`(D9 T1) 는 정규화에 종속 → `a.nfc().char_count()` 로 안정화 가능. **묵시 정규화 안 함**.
- `.graphemes()`(D10 T2) 는 측정상 정규화에 견고(정규화 전/후 cluster 수 동일; §1.2 [A]=[B]=1) — 단 cluster 내부 substring 의 byte 표현은 형태 종속.
- D11 이 land 되면 D9 의 "T1 codepoint 세기" 문서에 "정규화 종속, `.nfc()` 로 안정화" 노트 추가 권장.

---

## 7. 요약 (구현 PR 용 권고 4줄)

1. `==` / map hash = **codepoint-exact 유지** (옵션 A · Rust/Go/Python/JS/Java 다수파 5/6 · O(1) hot-path 보존 · zero-migration). Swift-style 정규화 `==`(B) 거부.
2. **신규 명시 surface**: `s.nfc()` · `s.nfd()` · `s.nfkc()` · `s.nfkd()` (Python `unicodedata.normalize` 동형). 관용구 `a.nfc() == b.nfc()` 로 canonical-equivalence 비교.
3. 구현 = **pure-hexa generated table**(D10 §5-A 동형, no external dep). **Phase 화**: P1 Hangul 산술(table 0)+Latin subset → P2 full canonical decomposition+CCC reorder → P3(선택) NFKC/NFKD compatibility. **full NFC table 은 큼**(decomposition+CCC 수십 KB급)이 현실.
4. §5 acceptance(동등성 #1–#4 + round-trip #5–#13) + F-* falsifier 로 검증. `==` 불변(F-EQ-UNCHANGED)이 옵션 A 의 regression guard.

---

## 8. open questions

- **Q1**: 입문자 함정 완화용 lint/explain note — 사용자 입력을 map key/검색에 쓸 때 "정규화 미수행, `.nfc()` 고려" hint 를 줄지(diagnostics-only · codegen 비변경). noise 위험 vs 발견성. 별도 검토.
- **Q2**: 정규화 형태 4종 전부(NFC/NFD/NFKC/NFKD)를 노출할지, 아니면 NFC/NFD(canonical)만 1차 노출하고 NFKC/NFKD(compatibility, lossy)는 수요 확인 후 추가할지. → P1/P2=canonical, P3=compatibility 권장(§4).
- **Q3**: UCD 버전 pinning — D10 GraphemeBreak table 과 동일 SSOT 로 정규화 table 의 Unicode 버전을 고정/추적할지. (D10 §Q3 와 동형 · 같은 pin 으로 통합 권장.)
- **Q4**: `is_nfc()` 류 quickCheck predicate 를 1차에 포함할지 — Unicode `quickCheck` 속성으로 이미-NFC 인 흔한 경우 O(n) decompose 생략(주요 ASCII/NFC 입력 fast-path). 비용 작고 효과 큼 → 포함 권장.
- **Q5**: `==` codepoint-exact 를 유지하되, 별도 `s.canonical_eq(other)` 또는 `s.equals_canonical(other)` surface 를 줄지(`a.nfc()==b.nfc()` 보다 1회 호출·할당 절약 가능). vs surface 최소주의. 일단 `.nfc()` 조합으로 충분, 후속 검토.
- **Q6**: `\u{...}` / `\u XXXX` unicode escape 미지원 (D9 §Q5 와 동일 lexer gap — §1.2 측정 시 raw byte 임베드 필요). 정규화 테스트 작성 편의상 escape 가 있으면 좋음. 별개 lexer gap → 별도 PROBE 항목 (본 RFC 와 독립, D9 와 공유).

---

*Provenance: PROBE r15-D11 — Unicode 정규화(NFC/NFD) 정책 RFC. 측정 evidence = `self/native/hexa_v2` self-host transpile(현 main `4c4ac4ca`, D10 #794 머지 후) + `clang -I self ... self/runtime.c` 실행 (literal UTF-8 임베드 probe: precomposed vs decomposed é/ô + 한글 precomposed vs L+V+T conjoining; `==`/hash/char_count/graphemes 측정 + canonical-equivalence ground truth). canonical 비교 = Rust/Go/Python/Swift/JS/Java 정규화 정책 표. docs-only lane (컴파일러 소스 무변경 · in-flight codegen PR 충돌 회피). D9(#768)/D10(#794) 텍스트-정확성 3-leg 의 세 번째. 2026-05-24.*
