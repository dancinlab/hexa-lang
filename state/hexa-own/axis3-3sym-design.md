# axis-③ 마지막 3-심볼 관문 fix 설계 (Fable·구현 c6115f2f9)

조사 완료 — 3 심볼 모두 root-cause를 in-tree 증거로 확정했습니다. 핵심 반전 두 개: **`hexa_exit`은 def가 실제로 존재하는데 `__attribute__((weak))`라서 링커의 weak-blind spot에 빠진 것**이고, **kind=42는 reader 오독이 아니라 진짜 `R_X86_64_REX_GOTPCRELX`**입니다.

---

# axis-③ 마지막 3-심볼 관문 — root-cause 확정 + fix 설계

## 선판정 요약

| 심볼 | root-cause | fix |
|---|---|---|
| `hexa_exit` kind=4 | def **존재** (`runtime_emit_full.hexa:16436` `__attribute__((weak))`) → STB_WEAK(bind=2)가 H2 resolver의 `bind==GLOBAL` 체크·fixpoint의 def-fold 양쪽에서 **비가시** | 링커에 weak-def 가시성 arm 추가 (프롬프트의 (a)(b)(c) 어느 것도 아닌 제4의 경로) |
| `__init_array_start/end` kind=42 | kind=42 = **R_X86_64_REX_GOTPCRELX (실제·psABI)** — reader 파싱은 정확. GNU ld linker-defined 심볼을 own-link가 미합성 | GOTPCREL(9)-parity로 41/42 처리 + 빈 경계 def 합성 (start==end) |

---

## (1) `hexa_exit` kind=4 — root-cause: **weak-def blind spot** (판정 확정, 프로브는 확인용)

### (a) root-cause

`git grep`으로 in-tree에서 def를 찾았습니다 — `self/runtime_emit_full.hexa:16436`:

```c
__attribute__((weak)) HexaVal hexa_exit(HexaVal code) { hxlcl_exit((int)HX_INT(code)); return hexa_void(); }
```

즉 runtime.a(runtime_core.o)에 def가 **있으나 STB_WEAK(bind=2)**입니다. 이 weak bind가 링커 3곳의 `== ELF_STB_GLOBAL`(=1) 체크를 전부 미끄러집니다:

1. **`archive_extract_fixpoint`** (`elf_x86_64.hexa:3319/:3358/:3376`): "wants pulling"과 def_names fold 모두 `s.bind == ELF_STB_GLOBAL`만 def로 인정 → weak def는 pull-측 def_names에 안 들어감. (멤버 자체는 다른 GLOBAL 심볼 — `hexa_print_val` 등 — 때문에 pull됨.)
2. **`link_elf_x86_64_ownstart` def 수집** (:1633-)은 bind 필터가 **없어서** weak def가 def_names에 들어감(def_bind=2) → **dyn census(:1770)의 name-only `ddef` 체크가 "defined"로 판정** → dynamic 라우팅에서 제외됨.
3. **H2 resolve 루프** (:2002): `def_bind[sk] == ELF_STB_GLOBAL` 실패, `def_obj[sk] == ro` 실패(def는 pull된 runtime 멤버 obj, reloc은 obj[0]=cc-self.o) → `found_idx = -1` → H1 unresolved.

이 2↔3의 비대칭(census에는 보이고 resolver에는 안 보임)이 정확히 관측된 "H1 unresolved, dyn 흡수도 안 됨"을 재현합니다. 프롬프트 가설 (a) pull 누락 — 부분적으로만 참(fixpoint가 weak를 def로 안 세지만 멤버는 어차피 pull됨), (b) exit@libc 오라우팅 — 거짓, (c) substrate 누락 — 거짓.

pod 확인 프로브 (구현 전 1줄 검산):
```bash
nm ~/.hx/runtime.a 2>/dev/null | grep -w hexa_exit    # 예상: "W hexa_exit" (weak). "T"면 가설 폐기→재진단
```

### (b) fix 스케치 — ELF-canon weak 가시성 (strong-wins)

상수 (:44 `ELF_STB_GLOBAL` 아래):
```hexa
let ELF_STB_WEAK          = 2
```

H2 resolve 루프 (:1998-2009 스캔 교체):
```hexa
            let mut found_idx = -1
            let mut sk = 0
            while sk < len(def_names) {
                if def_names[sk] == name {
                    if def_bind[sk] == ELF_STB_GLOBAL {
                        found_idx = sk
                        break
                    } else if def_bind[sk] == ELF_STB_WEAK {
                        // ELF weak canon: a weak def is globally visible but a
                        // STRONG (GLOBAL) def anywhere still wins — keep scanning.
                        if found_idx < 0 { found_idx = sk }
                    } else if def_obj[sk] == ro {
                        if found_idx < 0 { found_idx = sk }
                    }
                }
                sk = sk + 1
            }
```

`archive_extract_fixpoint` 3사이트 (:3319/:3358/:3376) 동일 패턴:
```hexa
if s.section != 0 && (s.bind == ELF_STB_GLOBAL || s.bind == ELF_STB_WEAK) {
```
(GNU ld canon: archive 멤버의 weak *definition*은 UND를 만족시키고 pull을 유발함 — weak *reference*만 pull 비유발인데 und_names는 어차피 구분 없이 모음.)

GOT FILL(:2179)은 이미 non-GLOBAL fallback이 있어 **무변경**.

### (c)(d) 삽입 지점·난이도·리스크

- 전부 `compiler/emit/elf_x86_64.hexa` 단일 파일, ~12줄. **난이도 하·리스크 하**.
- byteeq-neutral: own-emit .o는 GLOBAL/LOCAL만 emit(weak 없음) → weak arm은 runtime.a pull 경로에서만 활성. shipping link 경로 무접촉.
- 보너스: 같은 blind spot에 걸릴 예정이던 **weak libm 패밀리 전체**(`runtime_emit_full.hexa:2814-` `__attribute__((weak)) double exp/log/sqrt...`)를 클래스로 해소 — cc-flat이 수학을 쓰는 순간 터졌을 지뢰. emitter를 strong으로 바꾸는 대안은 이 클래스를 못 덮고 weak의 계층화 의도(override 허용)를 깨므로 기각. exit@libc dynamic 라우팅 대안은 polarity 역전 + `hexa_exit`은 libc 심볼이 아니라 ld.so 로드 실패 — 기각. **링커 fix가 native-canonical·최소변경.**

---

## (2)(3) `__init_array_start/end` kind=42 — root-cause 2중: 실제 GOTPCRELX + linker-defined 미합성

### (a) root-cause

**kind=42 정체**: reader(:3120-3131)는 `rtype = r_info & 0xffffffff`를 정확히 파싱합니다 — 오독 아님. 42 = **`R_X86_64_REX_GOTPCRELX`** (psABI Table 4.11 addendum; 41 = 비-REX `GOTPCRELX`). 출처는 `runtime_emit_full.hexa:87-88`:

```c
extern _hx_initfn __init_array_start[] __attribute__((weak));
extern _hx_initfn __init_array_end[]   __attribute__((weak));
```

clang이 이 weak-UND 배열 참조를 `mov r64, [rip+sym@GOTPCREL]`(REX prefix)로 컴파일 → REX_GOTPCRELX. obj[1] = pull된 runtime 멤버의 `_hx_run_init_array`(:90). own-link는 kind 42를 dyn census(2/4/9만)·resolve(9만)가 몰라서 H1로 낙하. 그리고 GNU ld가 PROVIDE로 합성하는 두 경계 심볼을 own-link는 정의하지 않음 — 프롬프트 판정 그대로.

pod 확인 프로브:
```bash
cd $(mktemp -d) && ar x ~/.hx/runtime.a               # ar x stale 주의(fresh tmpdir)
readelf -rW *.o | grep -B1 init_array                  # 예상: R_X86_64_REX_GOTPCRELX
readelf -SW *.o | grep init_array                      # SHT_INIT_ARRAY 존재+크기 → rung-D 판단(아래)
```

### (b) fix 스케치 — 2-파트

**파트 1 — kind 41/42 = GOTPCREL(9) parity.** psABI상 GOTPCRELX의 relaxation은 *optional* — 비완화 링커는 9와 동일 처리(GOT 슬롯 + disp32 패치)가 합법입니다. 상수(:63 `ELF_R_X86_64_32S` 아래) + 헬퍼:

```hexa
let ELF_R_X86_64_GOTPCRELX     = 41   // mov/test GOT load, relax-eligible (psABI B.2 addendum)
let ELF_R_X86_64_REX_GOTPCRELX = 42   // REX-prefixed form; a non-relaxing linker treats both as GOTPCREL

fn _elf_kind_is_got(k: Int) -> bool {
    return k == ELF_R_X86_64_GOTPCREL || k == ELF_R_X86_64_GOTPCRELX || k == ELF_R_X86_64_REX_GOTPCRELX
}
```

4사이트 교체:
- :1715 GOT COLLECT — `if gr.kind == 9` → `if _elf_kind_is_got(gr.kind)`
- :1753 dyn census — `dr.kind == 2 || dr.kind == 4 || _elf_kind_is_got(dr.kind)`
- :1772 stub 분류 — `if _elf_kind_is_got(dr.kind) { dyn_stub.push(0) } ...` / `else if !_elf_kind_is_got(dr.kind) { dyn_stub[dfi] = 1 }`
- :2011 resolve hoist — `if r.kind == 9` → `if _elf_kind_is_got(r.kind)`

**파트 2 — 경계 심볼 합성 (빈 배열, start==end).** `call main` rel32 패치 직후·GOT COLLECT 주석(:1699) **앞** 삽입 — dyn census보다 반드시 선행해야 census가 이 둘을 libc.so.6 dynamic으로 오라우팅하지 않음(libc는 이 심볼들을 export 안 하므로 ld.so 로드 실패가 됨):

```hexa
    // ── linker-defined __init_array_start/__init_array_end (GNU ld PROVIDE
    // parity). _hx_run_init_array (runtime_emit_full) references the two
    // boundary symbols via REX_GOTPCRELX; GNU ld synthesizes them at the
    // .init_array bounds. This own-link drops SHT_INIT_ARRAY at parse (Pass A
    // pools PROGBITS/NOBITS only) -> the array is EMPTY here: register both at
    // the SAME data-blob offset so start==end and the ctor loop is zero-trip.
    // MUST precede the dyn census — libc.so.6 does not export these.
    def_names.push("__init_array_start")
    def_seg.push(1)
    def_off.push(len(data_bytes))
    def_bind.push(ELF_STB_GLOBAL)
    def_obj.push(-1)
    def_names.push("__init_array_end")
    def_seg.push(1)
    def_off.push(len(data_bytes))
    def_bind.push(ELF_STB_GLOBAL)
    def_obj.push(-1)
```

흐름 검증: def 등록 → census가 defined로 스킵 → GOT COLLECT(파트 1)가 reloc에서 이름 수집·슬롯 할당 → resolve hoist가 disp32→슬롯 패치 → GOT FILL이 슬롯에 `data_vaddr_base + def_off`(둘 다 동일 vaddr, 당시 data blob 끝 = 유효 RW 주소) 기입 → `for (f = start; f < end; ...)` 0회. 기존 arm 전부 재사용, 새 resolve arm 불필요.

### (c)(d) 삽입 지점·난이도·리스크

- 파트 1 ~10줄 + 파트 2 ~14줄, 단일 파일. **난이도 하-중·리스크 하**.
- byteeq-neutral: kind 41/42와 이 두 심볼은 clang-컴파일 runtime.a 멤버에서만 등장 → own-emit-only 정적 링크·shipping 경로 바이트 무변화. def 등록 자체는 출력 바이트 비기여(ET_EXEC symtab 미직렬화).
- 유의: 파트 1은 defined 심볼의 kind-42 GOT-load에도 적용되는데, hoist 브랜치가 def/dyn 동일 수식(G+GOT+A−P)이라 자동 정합.

---

## ⚠️ 정직 공시 — "빈 init_array"는 링크 관문만 여는 것 (rung-D를 명명)

runtime substrate에 **실제 ctor 2개**가 존재합니다: `runtime_emit_full.hexa:63` `__attribute__((constructor(101)))` (env-capture) · `:15228` `__attribute__((constructor))` (`_hexa_ctor_init_fn_shims` — TAG_FN carrier 배선, ":15224 주석 — bare native main은 `hexa_set_args`를 안 부르므로 ctor가 유일한 init 경로"). reader Pass A(:2925)는 `SHT_PROGBITS`/`SHT_NOBITS`만 pool하므로 **SHT_INIT_ARRAY(type 14) 섹션 내용은 parse에서 drop**되고, start==end 합성은 이 ctor들을 영구 skip합니다. 게다가 own-start 스텁은 `_hx_start_c`가 아닌 `main` 직행이라 애초에 배열을 순회할 코드도 안 탑니다.

예상 결과: **링크 rc=0 도달, run에서 다음 벽 후보** = carrier `not callable: tag=0`(cc-flat이 fn-carrier를 쓰면) + `hxlcl_environ=NULL`(getenv 사수) + raw `syscall 60` exit의 stdio 미flush. 이는 이미 명명된 **rung-2 "environ-store + exit@libc (§F getenv/flush)"**와 같은 영토입니다. 자연스러운 통합 해법(rung-D): own-start 스텁을 `_hx_start_c`(runtime.a에 이미 존재 — env 저장→init_array 순회→`hxlcl_exit(main(...))` flush/atexit drain 포함) 경유로 전환 + reader에 SHT_INIT_ARRAY pool(slot 신설, 경계 심볼이 실제 배열을 span). 이번 라운드가 아니라 링크 GREEN 후 run-correctness 라운드.

---

## Rung 순서 (최소변경 우선)

1. **Rung A** — weak-def 가시성 (상수 + H2 arm + fixpoint 3사이트): `hexa_exit` 계열 해소, 단독 PR 가능 크기.
2. **Rung B** — kind 41/42 GOT-parity + `__init_array_start/end` 경계 합성: 나머지 해소. A와 같은 PR로 묶어도 됨(같은 파일·독립 diff).
3. **Rung C (verify·pod 1회 rent)** — 프로브 3종(`nm | grep hexa_exit` = W 확인 · `readelf -rW` = 42 확인 · `readelf -SW` = .init_array 크기) → own-link 재실행: 예상 **25→0 unresolved, link rc=0** → cc-self-bin run. run rc≠0이면 rung-D 영토 진입 신호(위 3후보로 진단).
4. **Rung D (명명만)** — `_hx_start_c` 경유 entry + SHT_INIT_ARRAY pooling = env/ctor/flush 3벽 통합 해소.

설계 문서로 남기시려면 `state/hexa-own/`에 박제하고 구현은 pool에서 진행하면 됩니다.