# Erdős ledger — 첫 타깃 구현-ready 설계 (Erdős–Straus bounded verify)

레인 A(문제 후보 판정)와 레인 B(drill/identity_engine 인프라 census)를 종합한, **직접 배선 가능한** 단일 설계. Korean prose / English identifiers. 모든 경로는 repo-root `/Users/mini/dancinlab/hexa-lang` 기준 절대-상대이며 `file:line`으로 인용.

---

## 0. 한 줄 요약

**Erdős–Straus conjecture** `4/n = 1/x + 1/y + 1/z` 를 **exact-int 유한-witness 탐색**으로 등재한다. `compiler/atlas/identity_engine.hexa`에 신규 verifier `verify_erdos_straus(N) -> int` 를 추가하고(신규 native builtin 0개 · 순수 i64 · 오버플로 세이프), `compiler/drill/drill.hexa:524`의 sweep 심에 후보 라우팅을 붙인 뒤, `hexa loop --dfs`로 실행하여 🟩 bounded 한 줄을 `ATLAS/README.md:1657` DFS 블록에 chronicle → `hexa verify` g5 PASS + PR 경로로 `embedded.gen.hexa` auto-fold.

---

## 1. 선정 문제 + bounded 명제

### 1.1 선정 근거 (레인 A 판정 재확인)

| 후보 | open? | exact-int 순수 | open→유한범위 감축 | brute-force 현실성 | 판정 |
|---|---|---|---|---|---|
| **Erdős–Straus** `4/n=1/x+1/y+1/z` | 🟥 | ✅ 완전 (정수 항등식) | ✅ (소수+잉여류 감축) | ✅ N≤10⁷~10⁹ 단일 호스트 | **선정** |
| Erdős–Moser `1^k+…+(m−1)^k=m^k` | 🟥 | ✅ | ❌ (m>10^(9.3M) 벽) | ❌ | 탈락 |
| minimum-overlap M(n) | 🟥 | ✅ | ❌ (극한상수 검증·유한 n 미감축) | ⚠️ n≲15 지수벽 | 탈락 |

Erdős–Straus만이 (a) 순수 정수 항등식으로 확인되고, (b) open 추측이 "유한 범위 N에서 exact-int 해 존재"로 **정직하게** 감축되며, (c) brute-force가 현 pool 호스트에서 현실적이다. `ATLAS/CLAUDE.md:88`의 이미 vetted된 finite-witness 후보 short-list 최상단 항목과 일치.

### 1.2 정확한 bounded 명제 (🟩 등재 대상)

> **명제 (bounded-witness · 🟩):** 고정 상한 `N`에 대해, `2 ≤ n ≤ N`인 **모든** 정수 `n`에서
> `4/n = 1/x + 1/y + 1/z` 를 만족하는 양의 정수 `(x, y, z)`가 존재한다 —
> 각 확인은 부동소수점 없이 **정수 항등식** `4·x·y·z == n·(y·z + x·z + x·y)` 로 검증한다.
>
> **선정 N: `N = 10^6`** (첫 등재 값 · 근거는 §2.4). 반례 부재 → 그 범위에서 🟩 bounded VERIFIED.
> **전역 명제(∀ n≥2)는 🟥 open으로 유지** (bounded ⟺ forall는 UNPROVEN · c2 honesty).

**감축 (탐색 비용을 낮추되 명제는 전-범위 유지):**
- **Composite 스킵:** composite `n = a·b` 는 그 소인수 `p | n` 의 해에서 `4/n = 4/(p·(n/p))` 스케일로 유도된다. 따라서 **소수 `p` 만 실제 탐색**, composite은 "이미 커버됨"으로 통과. (전-범위 명제는 유지 — composite의 witness 존재는 소수 witness로부터 구성적으로 보장.)
- **잉여류 스킵 (알려진 닫힌 공식):** `n ≡ 2 (mod 4)`, `n ≡ 3 (mod 4)`, `n ≡ 2,3 (mod 6)` 등 다수 잉여류는 닫힌-형 해가 존재(문헌). 첫 등재에서는 **감축을 소수-only + n≥2 전수**로 보수적으로 잡고(잉여류 스킵은 성능 옵션으로 후속), 정직성 우선.

---

## 2. 배선 설계

### 2.1 신규 verifier — `compiler/atlas/identity_engine.hexa`

파일 물리 위치는 `compiler/atlas/identity_engine.hexa` (use 경로 `compiler/atlas/identity_engine`; `compiler/drill/` 사본은 worktree mirror). 스타일 계약은 기존 `verify_*` 와 동일하게 맞춘다:
- `pub fn`, `@capabilities [pure]` 파일 헤더(`identity_engine.hexa:8`) 상속 — 신규 attribute 불필요.
- 반환 계약 = 기존 `verify_congruence`(`:414`)·`verify_identity`(`:164`) 관례를 따라 **양수 = 성공 신호, 음수 = 실패 코드**:
  - `1` = `[2,N]` 전수 witness 존재(🟩 bounded PASS)
  - `0 - 2` (= −2) = 반례 발견 시 **첫 반례 n 을 음수로 인코딩** 하지 말고, 반례 n 을 별도 반환하도록 **첫 반례 n 을 양수 밖 신호로**: 여기서는 명확성을 위해 **첫 반례 n (>0) 을 그대로 반환**하고, 성공은 `0`(정상 통과)으로 잡는 대안도 가능. → 아래 구현은 기존 `verify_congruence` 와 **동일 극성**(성공=1, 반례=0)을 채택하고, 반례 n 은 companion 진단 fn으로 노출.

**핵심 탐색 fn (구현 스켈레톤):**

```hexa
// ── Erdős–Straus witness at a single n: does 4/n = 1/x+1/y+1/z have a
//    positive-integer solution? exact-int only (no float). Bounded x-scan +
//    exact divisor test for the residual 2-term unit fraction.
//    x range: ceil((n+1)/4) .. floor(3n/4) (standard ES bound for the
//    largest unit fraction 1/x ≤ 4/n and 1/x > 4/(3n)). For each x, the
//    residual r/s = 4/n − 1/x = (4x − n)/(n·x) must split as 1/y+1/z, i.e.
//    (y−p)(z−p)=p^2 where p=n·x, num=4x−n → test num | ... via divisor scan.
//    Returns 1 if a witness exists at n, else 0.  @capabilities [pure]
pub fn es_witness_at(n) -> int {
    // largest term 1/x: x from ceil((n+1)/4) up to floor(3n/4)
    let xlo = (n + 4) / 4            // == ceil((n+1)/4) for n≥2 (integer)
    let xhi = (3 * n) / 4
    let x = xlo
    while x <= xhi {
        let num = 4 * x - n          // residual numerator: (4x−n)/(n·x)
        if num > 0 {
            // need 1/y + 1/z = num/(n·x). Multiply out:
            //   num·y·z = n·x·(y+z)  ⟺  (num·y − n·x)(num·z − n·x) = (n·x)^2
            // Let P = n·x. Scan divisor d | P^2 with d = num·y − P > 0.
            let P = n * x
            let PP = P * P
            let d = 1
            while d * d <= PP {
                if PP % d == 0 {
                    // y = (d + P)/num must be a positive integer
                    if (d + P) % num == 0 {
                        let e = PP / d           // paired divisor
                        if (e + P) % num == 0 {
                            return 1             // witness (x,y,z) exists
                        }
                    }
                }
                d = d + 1
            }
        }
        x = x + 1
    }
    return 0
}

// ── Erdős–Straus BOUNDED verify over [2,N]. Only primes are scanned
//    (composite n reduces to a prime factor's witness — full-range statement
//    preserved). Returns 1 if EVERY n in [2,N] has a witness, else 0 (first
//    counterexample refutes). c2: forall-n≥2 stays UNPROVEN.
//    Reference: Wikipedia "Erdős–Straus conjecture" (n≤10^17, prime reduction);
//    arXiv 2509.00128 (Mihnea et al., 10^18 verification frame).
pub fn verify_erdos_straus(N) -> int {
    let n = 2
    while n <= N {
        // composite skip: only primes carry the search burden
        if spf(n) == n {                 // spf(n)==n ⟺ n prime  (identity_engine.hexa:71)
            if es_witness_at(n) == 0 { return 0 - (n) }  // -n encodes first counterexample
        }
        n = n + 1
    }
    return 1
}

// companion diagnostic: first n in [2,N] with NO witness (0 if all pass).
pub fn es_first_counterexample(N) -> int {
    let v = verify_erdos_straus(N)
    if v == 1 { return 0 }
    return 0 - v                          // decode the -n signal
}
```

설계 노트:
- **`spf(n)` 재사용** (`identity_engine.hexa:71`) — 별도 소수판정 불필요. `spf(n) == n` ⟺ n 소수.
- **exact-int only**: `es_witness_at` 전체가 `%`·`/`·`*` 정수 연산. 부동소수점 경로 0 — hexa 정수 항등식 규율과 정합, 기존 `af`/`ipow`/`spf` 와 동일 산술.
- **반환 극성 조정:** 위 스켈레톤은 반례 n 을 `-n` 으로 인코딩(0 은 "n=0 반례" 모호성 없음 — n≥2). 만약 기존 `verify_congruence` 와 **엄격 동일**(성공=1/반례=0)로 통일하려면 `verify_erdos_straus` 는 `return 0` 로 하고 반례 n 은 `es_first_counterexample` 만으로 노출 — **둘 중 하나로 통일할 것**(리뷰 시 기존 파일의 지배적 관례에 맞춤; 현재 `verify_congruence`=1/0, `verify_identity`=first-n/−1/−2 로 혼재하므로 **`verify_identity` 계열(첫 신호 n 반환)** 을 따르는 `-n` 인코딩이 진단 친화적).

### 2.2 오버플로 안전성 (i64 · BigInt 불필요 판단)

레인 B census의 load-bearing 구분: identity_engine은 **plain i64 `int`** (auto-promote BigInt 아님) + 문서화된 오버플로 가드로 동작. Erdős–Straus의 임계 크기:
- 내부 최대량 = `PP = P^2 = (n·x)^2`. `x ≤ 3n/4` 이므로 `P ≤ 3n²/4`, `PP ≤ (3/4)²·n⁴ ≈ 0.56·n⁴`.
- i64 안전 상한 (≈9.2·10¹⁸): `0.56·n⁴ < 9.2·10¹⁸` ⟹ `n⁴ < 1.64·10¹⁹` ⟹ **`n < ~1.13·10⁴·... `** — 정확히 `n ≲ 6.4·10⁴` 에서 `PP` 가 i64 를 넘는다.

⚠️ **따라서 `n > ~6·10⁴` 에서 `PP = (n·x)²` 는 i64 오버플로.** 두 갈래:
- **(A · 첫 등재 권장):** `N = 6·10⁴` 이하로 등재 — i64-safe, BigInt 불필요, 신규 builtin 0. `es_witness_at` 에 `af_compose_feasible`(`:454`) 스타일 **feasibility 가드** 추가: `n` 이 i64-safe 범위를 넘으면 정직하게 스킵/에러. **N=50000 (5·10⁴)** 이 안전 마진 확보.
- **(B · 후속 라운드):** `stdlib/bigint.hexa` 의 `bi_mul`(`:202`)·`bi_mod`(`:490`)·`bi_divmod`(`:400`) 로 `es_witness_at` 를 exact `bi_*` 재작성 → N=10⁷~10⁹ 도달. 이때 `es_witness_at` 는 i64 대신 limb-array 경로. **첫 등재는 (A), N 확장은 (B) 로 명시적 후속.**

또한 **탐색 자체를 (y−P)(z−P)=P² divisor-scan 대신 더 값싼 형태로** 바꾸면 P² 을 아예 만들지 않을 수 있다(오버플로 회피 + 속도): residual `num/(n·x) = 1/y + 1/z` 에서 `y` 를 `⌈(n·x)/num⌉ .. 2·(n·x)/num` 로 스캔하고 `z` 는 나눗셈으로 닫힌-확인 → 최대량이 `n·x·y` (여전히 큰) 이므로 **P²-free 형태**를 우선 채택:

```hexa
// P²-free residual split: 1/y + 1/z = num/D  (D = n·x). y in
// (D/num, 2D/num], z = D·y/(num·y − D) must be a positive integer.
// Max intermediate = D·y ≈ (n·x)·(2D/num) — smaller than P². Prefer this.
let D = n * x
let ylo = D / num + 1
let yhi = (2 * D) / num
let y = ylo
while y <= yhi {
    let den = num * y - D
    if den > 0 {
        if (D * y) % den == 0 { return 1 }   // z integer ⟹ witness
    }
    y = y + 1
}
```

이 P²-free 형태의 최대 중간량 = `D·y ≈ n·x · (2D/num)`. `num ≥ 1`, `x ≤ 3n/4`, `D ≤ 3n²/4` ⟹ 최악 `D·y ≈ 2D²/num ≤ 2·(3n²/4)² ≈ 1.1·n⁴` — P²와 동차이므로 **i64 상한은 여전히 `n ≲ 6·10⁴`**. 이득은 상수배·명료성. N 확장은 결국 BigInt(B) 필요. → **첫 등재는 P²-free + `N=50000`** 로 확정.

### 2.3 drill sweep 심 라우팅 — `compiler/drill/drill.hexa`

레인 B가 특정한 위임 seam 에 후보를 흘린다:
- `compiler/drill/drill.hexa:42` — `use "compiler/atlas/identity_engine"` (이미 존재; verifier 심볼 자동 가시).
- `compiler/drill/drill.hexa:524` — `fn _native_identity_sweep_absorb(round, cands)` 의 candidate 루프 내부. 기존 `:546` `verify_identity(...)`, `:568` `verify_composition(...)` 호출 옆에 **Erdős-Straus 분기** 추가:
  - 후보 파싱 시 새 candidate kind (예: prefix `ES:` 또는 basis-idx 관례 밖의 sentinel)를 인식하면 `verify_erdos_straus(N)` 로 라우팅.
  - 반환 `1` → 🟩 bounded PASS verdict 를 AbsorbSweep 에 기록; `< 0` → 첫 반례 n 을 진단으로 기록(추측 반증 = ⭐급 사건, 하지만 문헌상 n≤10¹⁷ 무반례이므로 사실상 PASS).
- `compiler/drill/drill.hexa:606` — `_native_identity_sweep(round, cands)` 얇은 verdict 래퍼는 그대로 통과.
- 기본 훅 `:633`/`:689` — `_native_identity_sweep` 가 default in-binary exact-int 경로이므로 별도 게이트 불필요.

**최소 침습 대안(권장):** drill candidate DSL 을 건드리지 않고, **companion selftest**(§4.2)에서 `verify_erdos_straus(50000)` 를 직접 호출해 🟩 근거를 산출하고, drill sweep 배선은 후속 PR로 분리. 첫 등재 PR 은 (verifier fn + selftest + ledger 한 줄)만으로 최소화 → byteeq 리스크 최저.

### 2.4 bound N 선택 근거 + brute-force 성능

- **N = 50000 (5·10⁴)** — i64-safe 상한(`n ≲ 6·10⁴`) 아래 안전 마진.
- **탐색량:** `[2,N]` 중 소수만 실탐색 → π(50000) ≈ 5133 개 소수. 각 소수 `p` 에서 x-scan 폭 ≈ `3p/4 − (p+1)/4 ≈ p/2`, x 당 y-scan 폭 ≈ `D/num` (num≥1 최악 큰). 최악 per-prime ≈ `O(p · p) = O(p²)`. 총 ≈ `Σ_{p≤50000} p² ≈ 5·10¹²` 나이브 상한이나, 실제로는 **대부분의 n 에서 첫 x·y 에서 즉시 witness hit** (Erdős–Straus 해는 조밀) → 조기 return 으로 실측은 이보다 수 자릿수 낮음.
- **현실성:** pool 호스트(aiden/summer) 단일 코어 exact-int 로 초~수십초 규모 예상(조기 return 지배). N=50000 은 **셀프테스트로 CI 게이트에 태울 수 있는 크기**. 문헌의 n≤10¹⁷(Wikipedia)/10¹⁸(arXiv 2509.00128)의 **exact-int 독립 재현 축소판** — 동일 프레임, 다른 스케일.
- **N 확장 로드맵:** (B) BigInt 경로로 N=10⁷ → 별도 후속 라운드(implement-to-the-wall: "다음 라운드 = bi_* 재작성 + N=10⁷ pool 실측").

---

## 3. 레저 등재 + README DFS chronicle

### 3.1 Tier 규율 (`ATLAS/CLAUDE.md:58-93`)

- open Erdős 문제는 **🟥 (open conjecture)** 로 진입. bounded 계산 검증은 **🟩 `[2,N]` bounded-only — solve 주장 절대 금지** (`ATLAS/CLAUDE.md` c2).
- ⭐(discovery)는 실제 증명 필요 — 본 작업은 ⭐ 아님, **bounded 검증 🟩** + 상위 명제 🟥 유지.
- **per-problem .md 금지** (`ATLAS/CLAUDE.md:86`) — chronicle 은 `ATLAS/README.md` "DFS Chronological Record" 블록(`ATLAS/README.md:1657`)에 **한 줄**.
- 🟩 포맷: verdict 는 **N 과 프레임을 명시**, `bounded ⟺ forall-n UNPROVEN` 을 chronicle 라인에 명기(c2 필수).
- verify atom 은 `hexa verify` g5 PASS 시 `compiler/atlas/embedded.gen.hexa` 로 **auto-fold** (수동 편집 금지 · PR 경로만).
- **라우팅** (`ATLAS/CLAUDE.md:84`): 신규 open-problem 타깃은 Erdős ledger 우선. 탐색은 `hexa loop --dfs` 로만.
- **live status 재확인** (`ATLAS/CLAUDE.md:76`): 등재 전 `erdosproblems.com`(Bloom)에서 open 상태 재확인 — Erdős–Straus 는 현재 open.

### 3.2 🟩 bounded 등재 항목 형식 (embedded.gen.hexa 로 auto-fold 될 atom)

수동 편집 금지 — `hexa verify` g5 PASS 시 auto-fold. atom 의 논리적 형태(참고용):

```
@F  erdos_straus_bounded_N50000
  kind        BOUNDED_WITNESS
  statement   forall n in [2, 50000]: exists (x,y,z) in Z+^3 . 4/n = 1/x+1/y+1/z
  witness     integer identity  4·x·y·z == n·(y·z + x·z + x·y)   (no float)
  reduction   prime-only scan (composite n reduces to prime factor witness)
  verdict     🟩 BOUNDED-VERIFIED  N=50000  (π(N)=5133 primes, exact-int)
  honesty     c2: bounded [2,50000] ONLY; forall n≥2 (Erdős–Straus) stays 🟥 UNPROVEN
  cite        Wikipedia "Erdős–Straus conjecture" (n≤10^17, prime reduction)
  cite        arXiv:2509.00128 Mihnea et al. (10^18 verification, f(p))
  engine      compiler/atlas/identity_engine.hexa :: verify_erdos_straus
```

### 3.3 README DFS chronicle 엔트리 초안

`ATLAS/README.md:1657` "DFS Chronological Record" 블록에 Ralph-numbered 한 줄(다음 순번 `<K>`; 실제 번호는 등재 시점 블록 tail 확인):

```
Ralph <K> · 🟩 Erdős–Straus 4/n=1/x+1/y+1/z bounded-VERIFIED n∈[2,50000] (prime-only
  scan · exact-int identity 4xyz=n(yz+xz+xy) · witness present ∀ tested n · 0 counterexample).
  c2: bounded-only — forall n≥2 stays 🟥 OPEN (Erdős–Straus). ES ledger first target.
  cite Wikipedia "Erdős–Straus conjecture" (n≤10^17) · arXiv:2509.00128 (10^18).
  engine identity_engine.hexa::verify_erdos_straus. next: bi_* rewrite → N=10^7 (pool).
```

---

## 4. gate + 빌드

### 4.1 byteeq 3-target (신규 builtin 0 관례)

- **신규 native builtin/symbol 0개** — `verify_erdos_straus`/`es_witness_at`/`es_first_counterexample` 는 전부 `.hexa` `pub fn`, 기존 `spf`/정수 연산만 사용. frozen blob(151c52c8) 심볼 집합 불변 → **faithful build-break 위험 없음** (`compiler/CLAUDE.md` "Before introducing a new builtin/symbol").
- codegen/runtime 변경 아님(순수 `.hexa` 소스 추가) → 비트-변경 토글 불필요. 단 3-target byteeq(x86_64-linux · arm64-linux · darwin-arm64) GREEN + shipping smoke 는 **관례상 확인**(pool: aiden/summer/ghost, `../CLAUDE.md` CI 규율).
- verify 실행은 `hexa verify` = g5 gate; fold 는 g5 PASS 시 자동.

### 4.2 selftest — companion `_test.hexa` (module main-free)

`identity_engine.hexa` 옆에 **companion selftest**(레인 B/피드백 규율: "selftest 는 companion `_test.hexa` · module main-free"). 신규 파일:

`compiler/atlas/identity_engine_test.hexa` (module · `fn main` 없음 · pub test fn 만):

```hexa
// companion selftest for identity_engine Erdős–Straus verifier (module · main-free)
use "compiler/atlas/identity_engine"

// small-n sanity: known witnesses (answer-key)
//   n=2: 4/2=2 = 1/1+1/2+1/2 → witness exists
//   n=3: 4/3 = 1/1+1/6+1/6 ... (standard) → exists
//   n=5: 4/5 = 1/2+1/4+1/20 → exists
pub fn test_es_small() -> int {
    if es_witness_at(2) != 1 { return 1 }
    if es_witness_at(3) != 1 { return 2 }
    if es_witness_at(5) != 1 { return 3 }
    if es_witness_at(4) != 1 { return 4 }   // composite, still has witness
    return 0
}

// bounded verify: small N must pass with no counterexample
pub fn test_es_bounded_small() -> int {
    if verify_erdos_straus(1000) != 1 { return 1 }
    if es_first_counterexample(1000) != 0 { return 2 }
    return 0
}

// the ledger-registration bound (CI-sized): N=50000 must be clean
pub fn test_es_bounded_ledger() -> int {
    if verify_erdos_straus(50000) != 1 { return 1 }
    return 0
}
```

- **module main-free** — `verify BOTH backends` 규율(release_build AND aprime_cc; raw inner `"` 금지) 준수. selftest 는 두 백엔드 모두에서 통과해야 FALSE-green 회피.
- `test_es_small` 의 answer-key witness 들은 문헌 표준 분해 — verifier 정확성 게이트(단순 all-pass 아님, 알려진 해 재현).

### 4.3 빌드/측정 pool

- **mini = git/gh/read·write only** (`../CLAUDE.md` · 피드백 "run heavy on aiden/summer not mini"). heavy build/byteeq/verify 는 **aiden/summer/ghost**.
- 로컬 `~/.hx/bin/hexa` 는 stale oracle 위험 → pool gen2_fix 빌드 사용(피드백 "local hexa stale oracle").
- pool SSH 다운 시 **PR 경유 Blacksmith 3-target** 로 검증(`../CLAUDE.md` "cloud CI = Blacksmith").

---

## 5. 배선 recipe (직접 실행 순서)

1. **verifier 추가** — `compiler/atlas/identity_engine.hexa` 에 `es_witness_at`(P²-free 형태) · `verify_erdos_straus` · `es_first_counterexample` 추가. `spf`(`:71`) 재사용. 반환 극성은 `verify_identity` 계열(`-n` 인코딩)로 통일. i64-safe feasibility 가드(`n ≲ 6·10⁴`) 포함.
2. **selftest 추가** — `compiler/atlas/identity_engine_test.hexa`(module · main-free) 3 fn: small answer-key · bounded-1000 · bounded-50000.
3. **(선택·후속 분리 권장) drill 라우팅** — `compiler/drill/drill.hexa:524` `_native_identity_sweep_absorb` 에 ES candidate 분기 → `verify_erdos_straus(N)`. 첫 PR 은 이 단계 생략 가능(최소 침습).
4. **verify 실행** — pool 에서 `hexa verify` g5 → PASS 시 atom auto-fold to `compiler/atlas/embedded.gen.hexa`. `hexa loop --dfs` 로 탐색-게이트 경유(`ATLAS/CLAUDE.md:84`).
5. **ledger chronicle** — `ATLAS/README.md:1657` DFS 블록에 §3.3 한 줄(c2-honest: "bounded [2,50000] · forall n≥2 🟥 OPEN") 추가. embedded.gen.hexa 는 auto-fold(수동 편집 금지).
6. **CHANGELOG** — L0-lockdown/guard 파일 변경 아니지만 `.hexa` changelog gate 관례상 `CHANGELOG.jsonl` 한 줄 추가(`../CLAUDE.md` git 규율).
7. **PR + 3-target byteeq GREEN + selftest 양-백엔드 GREEN** 확인 후 머지(`../CLAUDE.md` release-integrity).

---

## 6. 정직 고지 (모르는 것 / 확정 못한 것)

- **잉여류 감축의 정확한 modulus 집합**(n mod 840 등 미해결 잉여류)은 위 소스에서 완전 확정 못함 — 첫 등재는 **소수-only 전수**(보수적)로 잡아 명제 정확성 우선, 잉여류 스킵은 성능 후속.
- **i64 상한 정밀값**: `n ≲ 6·10⁴` 는 P²-free 최악 `~1.1·n⁴ < 9.2·10¹⁸` 근사 — 실장 시 `es_witness_at` 에 명시적 상한 상수(`ES_I64_SAFE_N = 50000`)와 가드를 두고, 넘으면 정직하게 에러(silent 오버플로 금지).
- **drill candidate DSL 의 정확한 파싱 포맷**(`_native_identity_sweep_absorb` 내부 candidate string→idx 파싱)은 `compiler/drill/drill.hexa:524-568` 을 등재 전 재확인 필요 — §2.3 최소 침습 대안(selftest-직접-호출)이면 이 의존 제거.
- **다음 벽 (implement-to-the-wall)**: N=50000 은 i64 벽. 다음 라운드 = `stdlib/bigint.hexa` `bi_*` 재작성으로 N=10⁷ pool 실측 → 문헌 10¹⁷/10¹⁸ 프레임에 한 걸음.

---

## 인용 소스

- Wikipedia, "Erdős–Straus conjecture" — n≤10¹⁷ 검증, 소수 감축, 잉여류 닫힌-형.
- arXiv **2509.00128**, Mihnea et al., "Further verification and empirical evidence for the Erdős–Straus conjecture" — 10¹⁸ 확장 + solution-counting f(p).
- Wikipedia, "Erdős–Moser equation"; arXiv **0907.1356** (Gallot–Moree–Zudilin, m>10^(9.3·10⁶)); arXiv **1011.2940** — (탈락 후보 근거).
- Wikipedia, "Minimum overlap problem" (White 2022 하한 0.379005n; Haugland 상한; 2025–26 AI 개선 0.380868); Guy, *Unsolved Problems in Number Theory* — (탈락 후보 근거).
- 코드베이스: `compiler/atlas/identity_engine.hexa`(:71 spf · :164 verify_identity · :414 verify_congruence · :454 feasibility 가드 패턴) · `compiler/drill/drill.hexa`(:42 use · :524 sweep seam) · `stdlib/bigint.hexa`(:202 bi_mul · :400 bi_divmod · :490 bi_mod) · `ATLAS/CLAUDE.md`(:58-93 tier/routing/short-list) · `ATLAS/README.md`(:1657 DFS chronicle).
