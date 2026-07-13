# axis-③ own-link perf — Fable root-cause + fix 설계 (2026-07-11)

# axis-③ own-link >85min 벽 — root-cause 판정

**결론 먼저**: 벽은 코드 구조상 확정된 **O(relocs × defs) 전-선형스캔 3중첩**입니다. `link_elf_x86_64_ownstart`는 def 심볼 해시 인덱스가 전혀 없고, ~95,674개 reloc(측정: PLT32 57,741 + PC32 37,933, GOTPCREL 별도 미상) 각각이 def_names(~수만 엔트리, 추정 4–5만) 병렬배열을 **매번 처음부터 문자열 비교로 선형탐색**합니다. 게다가 같은 파일 뒤쪽(.o-emit 경로)에는 **정확히 같은 병으로 이미 한 번 죽었다가 1024-bucket FNV로 고친 전례가 주석으로 박제**되어 있습니다 (`elf_x86_64.hexa:4504` "#self-emit-oom — np·O(distinct) ≈ 10^10 runtime string-compares and the pack phase never finishes"). 링커는 그 처방을 안 받은 채 남은 마지막 스테이지입니다.

---

## 1. `link_elf_x86_64_ownstart` 복잡도 — O(relocs × defs) 확정 (코드 구조상)

reloc당 선형스캔이 **한 번이 아니라 최대 3~4번** 겹칩니다 (모두 `compiler/emit/elf_x86_64.hexa`, origin/main 8765f524f 기준):

| 패스 | 위치 | reloc당 비용 |
|---|---|---|
| GOT COLLECT | `:1779-1781` | kind-9 reloc마다 `got_syms` 선형스캔 |
| DYN-UND CENSUS | `:1817-1819` | kind 2/4/9 reloc마다(= 사실상 전 reloc) `def_names` 전-선형스캔 |
| reloc RESOLVE | `:2113-2131` | 전 reloc마다 `def_names` H2 scoped 선형스캔 |
| GOT FILL | `:2297-2305` | got_sym마다 `def_names` 선형스캔 (n_got × defs) |

악화 요인 세 가지:

- **LOCAL/WEAK는 조기탈출 불가**: H2 스캔(`:2117-2129`)은 GLOBAL만 `break`하고, WEAK·owned-LOCAL 매치는 "뒤에 GLOBAL 동명이 있나" 계속 스캔 → own-emit의 `.LCstrN`/`g<id>` STB_LOCAL 참조는 reloc당 **def_names 전체(풀 n)** 를 돕니다.
- **GOTPCREL은 def 스캔이 순수 낭비**: `:2113`의 H2 스캔이 kind 판별(`:2133`)보다 **먼저** 돌지만, kind-9 분기 안에서 `found_idx`는 한 번도 안 쓰입니다. GOTPCREL reloc은 def 전-스캔 비용을 공짜로 내고 버립니다.
- **reloc당 이름 재조립**: `:2096-2103`(그리고 census `:1809-1815`, collect `:1771-1778`에서 또) `name = name + from_char_code(b)` — 불변문자열 concat이라 이름당 O(L²) 복사 + 이름당 ~L회 할당. 같은 심볼을 참조하는 reloc이 몇 개든 매번 재조립 (메모이제이션 0). kind-9 reloc은 최대 3회 조립.

**정량 (측정치 기반 산술, 상수는 추정)**: 95,674 reloc × (census 평균 ~2.5만 + resolve 평균 2.5~5만) ≈ **5~7×10⁹회 문자열 비교 반복**, 반복당 boxed array-get + string-eq(gen2 C-emit HexaVal 경로). 반복당 ~0.5–1µs면 40–120분 — 관측된 >85min timeout과 자릿수가 정확히 맞습니다. `:4504` 전례가 같은 패턴을 "10^10 compares = never finishes"로 이미 실측 박제한 것과도 일치.

## 2. `archive_extract_fixpoint` — fixpoint 루프 자체보다 **시드 dedupe가 quadratic**

- fixpoint 본체(`:3502-3555`)는 맞습니다: `while changed`로 **전 멤버 재스캔** 반복이고 멤버당·심볼당 `_aef_has`(`:3412-3420`, 선형) 2회. 다만 runtime.a 멤버 수가 작으면(추정 수~수십) 라운드 수도 작아 부차적.
- **진짜 비용은 시드 Pass 1** (`:3471-3483`): 프로그램 GLOBAL def 심볼마다 `!_aef_has(def_names, nm)` dedupe 선형스캔 → def_names가 수만으로 자라며 **O(defs²)**. GLOBAL def ~2만이면 ~2×10⁸, ~4만이면 ~8×10⁸ 비교 (추정) — ownstart 진입 **전에** 이미 분 단위를 태웁니다.
- 부가: `_aef_all_member_defs`(`:3432`)가 전 멤버를 fixpoint와 **별도로 한 번 더 parse** — 주석 스스로 "negligible"이라 하나 cc-self 규모에선 재검토 대상 (추정: 수십 초 이하, 부차).

즉 답: "멤버마다 전체 재스캔 fixpoint인가?" → 예, 하지만 지배항은 그 루프가 아니라 **이름-집합 멤버십이 전부 선형(`_aef_has`)이라는 것**이고, 최악 지점은 시드입니다.

## 3. 최대 단일 레버 — def_names 1024-bucket FNV 인덱스 (기존 idiom 이식)

정답지가 같은 파일에 있습니다: `_symh_hash/_symh_get`(`elf_x86_64.hexa:4514-4550`, 1024-bucket) = codegen `_x86_strtab_hash`(`x86_64_linux.hexa:1461`, #4773/#4454-class)의 확장. 이걸 링커 def 테이블에 그대로 이식하되, **값을 def 인덱스로** 넣고 버킷 내에서 기존 H2 bind/scope 판정을 그대로 수행하면 인덱스 선택이 byte-identical합니다 (같은 이름의 엔트리는 버킷 안에서도 삽입순 보존 + H2 판정은 동명 def끼리만 상호작용하므로).

```hexa
// ── linker def-index: 1024-bucket FNV-1a (#4773 _x86_strtab / _symh_* idiom).
// 버킷 값 = def_names 인덱스(삽입순). 동명 homonym은 같은 버킷에 삽입순으로
// 쌓임 → 버킷 내 H2 판정 결과 == 기존 전역 선형스캔과 동일 인덱스 (byteeq).
fn _ldx_hash(s: string) -> i64 {
    let mut h: i64 = 2166136261
    let mut i = 0
    let n = len(s)
    while i < n {
        h = (h ^ s.char_code_at(i)) * 16777619
        h = h % 4294967296
        i = i + 1
    }
    let mut b = h % 1024
    if b < 0 { b = b + 1024 }
    return b
}

fn _ldx_add(bn: [[string]], bi: [[Int]], name: string, idx: Int) {
    let b = _ldx_hash(name)
    bn[b].push(name)
    bi[b].push(idx)
}
```

배선 (3곳):

1. **def 등록 사이트 7곳**에서 `def_names.push(name)` 직후 `_ldx_add(ldx_n, ldx_i, name, len(def_names)-1)` — obj 수집 루프(`:1668/:1683/:1693`), init_array(`:1740/:1745`), 스텁 합성(`:1927`). 스텁이 census **후** resolve **전**에 추가되므로 인덱스는 증분 유지가 맞습니다(1회 빌드 불가).
2. **resolve H2 스캔 교체** (`:2113-2131`):

```hexa
let b = _ldx_hash(name)
let bn = ldx_n[b]
let bi = ldx_i[b]
let mut found_idx = -1
let mut sk = 0
while sk < len(bn) {
    if bn[sk] == name {
        let di = bi[sk]
        if def_bind[di] == ELF_STB_GLOBAL { found_idx = di; break }
        else if def_bind[di] == ELF_STB_WEAK { if found_idx < 0 { found_idx = di } }
        else if def_obj[di] == ro { if found_idx < 0 { found_idx = di } }
    }
    sk = sk + 1
}
```

3. **census 존재판정** `:1819` 도 같은 인덱스로 (아무 동명 엔트리 발견 = ddef — 기존 semantics와 동일), **GOT FILL** `:2297` 도 동일 probe. `got_syms` 스캔(`:1781/:2145/:2348`)은 GOTPCREL 개수 실측 후 동일 idiom 적용 (dyn_names는 ~129 규모라 선형 유지 무방).

동반 레버 2개 (공짜·같은 PR):
- **kind-9 hoist**: `:2133`의 GOT 분기를 def-lookup **위로** 올려 GOTPCREL의 무의미한 def 스캔 제거 (`found_idx` 미사용이므로 semantics 무영향).
- **obj당 sym-name 1회 조립**: obj 루프 진입 시 `sym_names: [string]`을 한 번 만들고 (이미 있는 `_symh_name_at(:4556)` 재사용) census/resolve에서 `sym_names[r.sym_idx]`로 참조 — reloc당 O(L²) concat 제거. fixpoint 쪽은 `_aef_has`를 같은 bucket-set으로 교체 (시드 quadratic 동시 해소).

**예상 배수 (추정, 실측 필수)**: 지배항이 reloc당 ~2.5–5만 비교 → 버킷당 ~50 비교(5만 defs/1024)로, 스캔 성분 **~500–1000×**. 전체 링크 페이즈는 고정비(ar parse·7MB 바이트 push·serialize) 포함 **>5400s(미완주) → 분 단위 이하** 예상. byteeq-neutral 논거: (a) own-link는 opt-in 경로라 shipping 바이트 무영향, (b) own-link 출력 자체도 인덱스 선택 동일성으로 byte-identical — ARC_E2E=PASS_BYTEID 오라클로 재검증 가능. 아울러 링크 페이즈에 `HEXA_CG_PROFILE` 마크(fixpoint/census/resolve/write)가 지금 0개라 이번에 심는 것을 권합니다 — 다음 측정에서 즉시 국소화됩니다.

## 4. own-link 필요성 판정

- **no-LLVM 불변식과는 무관 — 맞습니다.** 불변식은 LLVM backend/IR 금지이고 system-ld(binutils)는 LLVM이 아니므로, system-ld 유지가 불변식을 건드린다는 주장은 성립하지 않습니다. "clang-0"(C 컴파일러 제거)만이 목표라면 ld는 clang과 독립 패키지라 own-link 없이도 달성됩니다.
- **그러나 own-link의 근거는 다른 축에 있습니다**: CLAUDE.md 헌장이 "linked by `hexa_ld` — byte-identical self-host fixpoint"를 명시하고, axis-③ Road A의 목표가 zero-binutils self-containment(출력 바이트 전체가 own-toolchain 결정)입니다. 즉 own-link는 "필요해서"가 아니라 **선언된 canonical 극성**(native-canonical-default)이며, 그 극성 하에서도 release-integrity 최상위 원칙에 따라 shipping은 system-ld, own-link는 `--linker=hexa` opt-in 유지가 현행대로 정당합니다.
- **결정적으로 이 벽은 measured wall이 아니라 구현 아티팩트입니다.** 실제 링커(GNU ld/mold)는 동일 입력(7MB .o, 9.5만 reloc)을 초 단위에 처리하고(사용자 측정: system-ld = 초), 링크는 본질적으로 해시 기반 O(relocs+syms)입니다. 같은 리포에서 같은 병을 #4773 idiom으로 두 번 고친 전례까지 있으므로, "own-link 포기/벽 선언"의 근거는 없습니다. **판정: shipping=system-ld 유지(정당), own-link=유지하되 §3 해시 라운드로 벽 제거 후 summer에서 재실측** — 그것이 implement-to-the-wall이 요구하는 다음 라운드입니다.