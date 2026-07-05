# zero-c #29 · floor→0 — endgame 실행 SSOT

**작성 2026-07-03** · HEAD `8bbd2eb0d` · verified in-tree.
3-lane census(LANE1 reduction-lever · LANE2 residual nm-UND class · LANE3 dependency/gate) 를 **하나의 실행 시퀀스**로 통합.
선행 3 audit 과 정합 — `zeroc-29-goal-terminal-verdict`(진짜 바닥 판정) · `zeroc-29-terminal-front-reduction`(FLIP-6/7 게이트) · `zeroc-29-dlopen-wall-breakthrough`(S1/S2/S3 옵션표) 를 대체하지 않고 **execution-order 로 합성**.

**정직 스코프**: ∅ 판정축 = **Linux ELF canonical `runtime.a` nm-UND**(github-hosted faithful-nobaseline CI). 로컬/ad-hoc pool `runtime.a` nm 은 FALSE-CLEAN 또는 over-count(census L17/L21) — 권위 수치는 CI 만. darwin = ∅-축 밖(dyld/XNU truly-static Mach-O 거부, `hexa_ld.hexa:56-57`).

---

## 1. 현 상태 스냅샷 (레버별)

| 레버 | merged? | default | 심볼 실제 drop? (linux canonical) | PR# | 게이트 종류 |
|---|---|---|---|---|---|
| **glob** `HEXA_RT_GLOB_NATIVE` | ✅ | **linux ON** | ✅ glob·globfree drop | feat #4443 · flip #4449 | opt-in→flip 완료 |
| **fgets** `HEXA_RT_STREAM_NATIVE_READ` | ✅ | **linux ON** | ✅ fgets drop | feat #4444 · flip #4450 | opt-in→flip 완료 |
| **qsort** `HEXA_RT_ARRAY_SORT_NATIVE` | ✅ | **linux ON** (flip #4452) | ✅ qsort drop | feat #4447 · flip #4452 | flip 완료 |
| **regex** `HEXA_REGEX_NATIVE` | ✅ | **OFF** (`#ifndef`) | ❌ regcomp/regexec/regfree 유지 | #4445 | bit-changing · 3-target |
| **strtod-tail** `HEXA_RT_STRTOD_TAIL_NATIVE` | ✅ | **OFF** (`#ifdef`) | ❌ strtod U 유지 (finite 는 #4200 이후 native) | #4448 | bit-changing · 3-target |
| **rand/srand** `HEXA_ZEROC_RAND_NATIVE` | ✅ | **linux ON** | ✅ rand·srand drop | #4441 | 완료 |
| **mkstemp/mkdtemp** `HEXA_ZEROC_OWN_MKTEMP` | ✅ | **linux ON** | ✅ drop | #4441 | 완료 |
| **ns-syscall** (getppid/setsid/mount/umount2/unshare/setns/flock/sigset) | ✅ | **ON** (FRAG-REGEN) | ✅ drop | #4428/#4430 | faithful 3/3 완료 |
| **S1 dl\*** FFI floor-partition (`runtime_ffi_dyn` TU) | ✅ **MERGED** | n/a (byteeq-neutral · ungated) | ✅ dlopen/dlsym/dlerror 구조적 이탈(canonical runtime.a nm-UND 부재 확증 · CI run 28678730603) | #4481 | byteeq-neutral · 구조 완료 |
| **PR-2** codegen 조건부-링크 (`HEXA_FFI_DYN_TU`) | ✅ **MERGED** | n/a (byteeq-neutral) | n/a (프로그램측 조건부-링크) | #4487 | byteeq-neutral · 구조 완료 |
| **own-start** environ+atexit (FLIP-7) | ❌ OPEN | OFF (byte-neutral) | ❌ atexit·environ 유지 | #4409 (CONFLICTING) | bit-changing · 3-target + install-smoke |
| **WALL-2 free** `HEXA_RT_NATIVE_FREE` | ✅ merged | **OFF** (`${…:-0}`) | ❌ __libc free 유지 | #4242 | byteeq-neutral 3-target + faithful DROP |
| **WALL-2 calloc** `HEXA_RT_NATIVE_CALLOC` | ✅ merged | **OFF** | ❌ __libc calloc 유지 | #4244 | 동상 (FLIP-6) |
| **WALL-2 realloc** `HEXA_RT_NATIVE_REALLOC` | ✅ merged | **OFF** | ❌ __libc realloc 유지 | #4244 | 동상 (FLIP-6) |
| **RT-NATIVE str\* ×5** `HEXA_RT_NATIVE_{STRCMP,STRNCMP,STRCHR,STRSTR,STRDUP}` | ✅ merged | **ON (auto)** 3-target | ✅ strcmp·strncmp·strchr·strstr·strdup drop (isolated frozen seed) | #4591(strcmp)+#4592 | **byteeq 3-target GREEN + SELFEMIT smoke 복구** · 4겹결함 순차수정(errno-격리·shim가드·co-drop·dangling directive) |
| **S2** self-symtab `HEXA_SELF_SYMTAB` | ❌ NONE | — | — | — (S1 뒤) | default-OFF→byteeq→flip |
| **S3** own loader `HEXA_OWN_DLOPEN` (RFC070 G7-C) | ❌ NONE | — | — | — (S1·G7-B 뒤) | default-OFF→falsifier(RFC070 §4.1)→byteeq 3-target→flip |

**net: 현재 linux canonical `runtime.a` 에서 실제 drop 된 것** = glob·globfree·fgets·rand·srand·mkstemp·mkdtemp·ns-syscall군(getppid/setsid/mount/umount2/unshare/setns/flock/sigaddset/sigemptyset)·**strcmp·strncmp·strchr·strstr·strdup(#4591+#4592, isolated frozen seed default-ON 3-target)**.
**merged-but-OFF(flip 대기)** = regex·strtod-tail·free·calloc·realloc. (qsort = flip #4452 완료로 linux ON.)
**not-merged(open)** = atexit/environ own-start(#4409, CONFLICTING · rebase 선결). (dl*×3 = S1 #4481 MERGED로 구조적 이탈 완료 · PR-2 #4487 MERGED.)

> ⚠️ 프롬프트 census 중 정정: qsort=**#4447**(≠#4452), regex=**#4445**(≠#4458). FLIP-6(WALL-2 default-ON linux flip) 는 **미실시** — #4242/#4244 는 메커니즘 merge 일 뿐 default-ON flip PR 은 없음. Route-C native body 는 x86_64-linux-only(`stage_resolve_runtime_a:1930` non-x86_64-linux 무시) = arm64/darwin fp-ABI 커버리지가 FLIP-6 블로커.

---

## 2. 순서화된 endgame DAG

canonical `runtime.a` nm-UND 를 sanctioned-only WALL 까지 줄이는 실행 순서. **byteeq-neutral(ungated) 먼저 → bit-changing(3-target 게이트) 뒤** 로 분리 배치(release-integrity: bit-neutral 먼저 착지시켜 리스크 격리).

```
┌─ PHASE A · byteeq-neutral (ungated, 구조 파티션) ─────────────────┐
│                                                                    │
│  A1  S1 (#4481)  ── FFI TU 축출: hexa_ffi_dlopen/dlsym →           │
│      runtime_ffi_dyn TU. canonical runtime.a nm-UND 에서           │
│      dlopen·dlsym·dlerror 구조적 이탈(필터 없이).                   │
│      게이트: byteeq-neutral(gen 바이트 불변) · CI 종료 대기.        │
│      Δ: dlopen·dlsym·dlclose·dlerror·dladdr  (−5)                  │
│         └ dep: 없음 (진행 중). 나머지 전부 이것 뒤.                 │
│                                                                    │
│  A2  PR-2  ── codegen HEXA_FFI_DYN_TU 신호 + 프로그램 조건부       │
│      링크(strict-fp 선례 1:1 복제 codegen.hexa:1503 / main.hexa:1580).│
│      게이트: byteeq-neutral(non-FFI 프로그램 링크라인 불변) ·       │
│              vendor-FFI 프로그램만 smoke.                          │
│      Δ: 0 (floor 유지 · 프로그램측 최적화)                          │
│         └ dep: A1 (물어갈 runtime_ffi_dyn.o 존재해야 함).           │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─ PHASE B · bit-changing (3-target byteeq RECONVERGE 게이트) ───────┐
│  (서로 독립 병렬 — 순서강제 없음. 각자 byteeq 3-target GREEN +      │
│   nm DROP 캡처 후 default-ON flip)                                  │
│                                                                    │
│  B1  reducible-CAMPAIGN flip (qsort·regex·strtod-tail)             │
│      #4447/#4445/#4448 를 default-ON linux flip.                    │
│      게이트: bit-changing · byteeq 3-target GREEN · faithful nm DROP.│
│      Δ: qsort·regcomp·regexec·regfree·strtod  (−5)                 │
│      부수효과: regex/qsort ON → __libc_calloc·__libc_free 의       │
│                마지막 caller 소멸 준비.                             │
│                                                                    │
│  B2  FLIP-6 (WALL-2: calloc·free·realloc default-ON)               │
│      #4242/#4244 를 linux default-ON.                              │
│      게이트: byteeq-neutral-태그이나 실제 flip 은 3-target +        │
│              faithful DROP + arm64/darwin fp-ABI 커버리지 해소       │
│              (stage_resolve_runtime_a:1930/2084/2131 else-arm).     │
│      Δ: __libc_calloc·__libc_free·__libc_realloc  (−3)             │
│         └ B1 과 병렬(독립). 블로커=arm64/darwin xmm fp-ABI.         │
│                                                                    │
│  B3  FLIP-7 (own-start: environ+atexit default-ON)                 │
│      #4409 rebase(현 CONFLICTING) → 착지 → default-ON.              │
│      게이트: bit-changing → byteeq 3-target + **install.sh          │
│              consumer smoke**(bit-neutral 아님 · 과거 #4408 revert).│
│      Δ: atexit·environ  (−2)                                      │
│         └ environ/atexit 공동 번들(독립 flip 불가). B1/B2 와 병렬.  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─ PHASE C · 구조 후속 (S1 이후, 잔여 표면 축소 · 선택적) ───────────┐
│  C1  S2 self-symtab (HEXA_SELF_SYMTAB)                             │
│      dlopen(NULL)/@link self-handle resolve → .hexa.symtab FNV     │
│      bsearch(hexa_ld + #4462 재사용). FFI TU/드라이버 잔여 dl* 축소.│
│      게이트: default-OFF → byteeq → flip.  dep: A1(S1).             │
│  C2  S3 own loader (HEXA_OWN_DLOPEN · RFC070 G7-C)                 │
│      hexa-산 fat.so 만 로드(hxlcl_mmap PT_LOAD + R_*_RELATIVE +     │
│      1-export lookup + mprotect · hexa_ld read_elf_relocs 재사용).  │
│      게이트: default-OFF → RFC070 §4.1 falsifier(arm64 IC IVAU·     │
│              W^X 2-phase self-test) → byteeq 3-target → flip.       │
│      dep: A1(S1) + G7-B ✅(완료) + hxlcl_mmap raw-svc(존재).        │
│      ※ vendor glibc .so 를 glibc-free 로 로드하는 것은 기각(무한표면).│
└────────────────────────────────────────────────────────────────────┘
```

**누적 심볼 델타 (linux canonical, 현재 floor 기준):**

| 스텝 | drop 심볼 | running floor 방향 |
|---|---|---|
| (현재 landed) | glob·globfree·fgets·rand·srand·mkstemp·mkdtemp·ns군 | 이미 반영 |
| A1 S1 | dlopen·dlsym·dlclose·dlerror·dladdr (−5) | 구조적 이탈 |
| B1 campaign | qsort·regcomp·regexec·regfree·strtod (−5) | |
| B2 FLIP-6 | __libc_calloc·__libc_free·__libc_realloc (−3) | |
| B3 FLIP-7 | atexit·environ (−2) | |
| **잔여** | **sanctioned-only WALL** (§3) | 종점 |

> 정직 주: 위 델타는 프롬프트 census 의 5-flip→15→7→3 투영과 정합(FLIP-6/7 후 3=dl*, S1 후 dl* 도 구조적 이탈). 절대 심볼 count 는 CI faithful-nobaseline(ARCHITECTURE #4338 = 60, 그 중 ~54 genuine libc)만 권위 — 여기 델타는 **class 단위 방향성**이지 CI-측정 절대치가 아님.

---

## 3. 정직한 ∅ 정의 — "진짜 floor→0" 이 실제 도달하는 바닥

**결론: `nm -u runtime.a`(unfiltered)는 ∅(빈 집합)에 도달하지 않는다.** 도달하는 정직한 종점은 **sanctioned-only floor** — advisory 필터가 걷어내던 클래스 중 알고리즘-포팅 가능한 것을 전부 native-emit 로 흡수한 뒤 **남는 영구 WALL**:

**영구 sanctioned WALL (알고리즘 없음 · kernel/loader/vendor ABI):**

1. **network / socket FFI** — `socket·bind·connect·accept·listen·recv/recvfrom/recvmsg·send/sendto/sendmsg·select·setsockopt·getsockopt·getaddrinfo·freeaddrinfo·gai_strerror`. `net.c` real socket syscall + DNS resolver = vendor-FFI 표면 등가. **포팅할 알고리즘 없음.** 최대 sanctioned 블록(~11-15 심볼).
2. **CRT bootstrap 잔여** — `_exit·__cxa_*·__errno_location·__stack_chk_*·__assert*·mallopt`. libc cold-start / compiler-runtime 계약 · `__libc_start_main` = irreducible seed([[project_hexa_m8_irreducible_floor]]). (atexit·environ·__libc_calloc·__libc_free 는 여기 아님 — FLIP-7 + campaign 으로 dissolve.)
3. **exec-family** — `execve·execvp`(+`posix_spawn`). kernel-ABI leaf. Route-C native-emit(#4263)이 default-OFF 로 존재 → *기술적으로는* flip-조건부 reducible 이나, flip 없으면 sanctioned. ns-syscall(mount/unshare/setns/setsid/getppid)은 이미 native(#4430)로 이탈.
4. **CUDA / vendor GPU** — `__cudaRegisterFatBinary·cuda*·fatbin*`. opt-in `HEXA_CUDA` 빌드에만 존재 · default runtime.a 엔 부재. sanctioned GPU-FFI.

**dl* 의 정직한 지위**: goal-terminal audit(woqhf1g3a/bcqqdsr8l)가 "dl* = genuine WALL" 주장을 **FALSE 로 판정**. dl* 는 single-runtime.a 전역 sanction 의 **구조적 아티팩트**이지 본질 WALL 이 아님 — S1 link-partition(A1)이 구조적으로 해소. **post-S1 dl* 는 canonical-floor 멤버가 아님.** 잔여 선택지 = S3 own-loader(hexa-산 .so 를 dl* 없이 로드)만, vendor glibc .so 를 glibc-free 로 로드하는 건 무한표면으로 기각.

**따라서 정직한 종점 표기 = "∅ 아님 · sanctioned-floor 도달"**:
```
unfiltered nm -u runtime.a  ─→  { network-FFI · CRT-startup · exec-family }  (+ CUDA는 opt-in축)
                                 = 영구 sanctioned WALL (kernel/loader/vendor ABI, portable-algorithm 없음)
```
그 밖의 census-60 전원 — dl*(S1), glob/fgets/regex/qsort/rand/strtod/mkstemp, WALL-2 calloc/free/realloc, atexit/environ, ns-syscall, sigset/flock — 은 **REDUCIBLE**(landed-ON 또는 flip 대기). darwin dl* 는 OS-mandated ABI(syscall 등가)로 ∅-축 밖 — Linux ELF canonical 만 판정축.

**과대주장 금지 라인**: "floor→0" 는 마케팅 표현 · 실제 도달 바닥은 **sanctioned-floor(network+CRT+exec)**, `∅` 는 CUDA/net/CRT/exec 를 sanctioned 로 명시 제외한 *reducible-floor* 축에서만 성립. 잔여 count 는 summer single-config 관측 · arm64/darwin nm 독립 미측정(goal-state 🟡) — 권위치는 github-hosted faithful-nobaseline CI.

---

## 4. 다음 3 액션 (#4481 착지 직후 즉시 우선순위)

> **⟳ 2026-07-04 reconcile (self-host workflow wcwe457nb · CI run 28678730603)**: **PHASE A 완전 종료** — S1 #4481 + PR-2 #4487 MERGED(아래 우선1 = done). qsort flip #4452 착지(default-ON). dl* 소멸 실측 확증(canonical runtime.a nm-UND 부재). **최신 floor = nm-UND 228 total · reducible residual 60**. ★**mini(git/gh only) 즉시-landing 가능 = 0** — 잔여 reducible 전부 (a) pool-gated(byteeq 3-target · seed regen · faithful) 또는 (b) PR-landing-blocked. mini-authorable **보조** 3종: ① #4409 rebase(CONFLICTING 해소=git-only · merge는 pool) ② resolver no-binary GRACEFUL 하드닝(`stage_resolve_runtime_a` · WALL-2 레인 unblock · flip은 pool) ③ 본 SSOT stale-line 정정(이 커밋). 아래 우선1(PR-2)은 done이라 실질 다음 = 우선2/3의 pool flip 라운드(aiden/summer seed regen).

| 우선 | 액션 | 게이트 | dep / 비고 |
|---|---|---|---|
| **1** | **PR-2 apply** — codegen `HEXA_FFI_DYN_TU` 신호 + 프로그램 조건부 링크(`codegen.hexa:1048/1236/1503-1507/2787` + `main.hexa:1580` probe, strict-fp 선례 1:1 복제) | **byteeq-neutral · ungated** (non-FFI 링크라인 불변 · vendor-FFI 프로그램만 smoke) | **A1(#4481) 착지 필수** — runtime_ffi_dyn.o 가 있어야 probe 가 물어감. 리스크 최저 → 먼저. |
| **2** | **reducible-CAMPAIGN flip (qsort·regex·strtod-tail)** — #4447/#4445/#4448 default-ON linux flip. 3개 묶어 한 flip 라운드 | **bit-changing · byteeq 3-target GREEN + faithful nm DROP 캡처** | S1 과 독립 병렬 가능 · pool-unblock(summer 포화/aiden dirty 해소) 필요 · regex/qsort ON = __libc_calloc/free caller 소멸 준비(B2 셋업) |
| **3** | **FLIP-6 (WALL-2 calloc/free/realloc default-ON)** — #4242/#4244 linux flip | **byteeq-neutral-태그 · but 실 flip = 3-target + faithful DROP + arm64/darwin fp-ABI 커버리지 해소** | 블로커 = `stage_resolve_runtime_a:1930/2084/2131` else-arm(non-x86_64-linux 무시)의 xmm fp-ABI 커버. B1 뒤(caller 소멸 후)면 DROP 캡처 청결. FLIP-7(#4409, CONFLICTING → rebase 선결)은 install-smoke 필요라 4순위로 미룸. |

**액션-후 게이트 순서 요약**: PR-2(무게이트) → campaign flip(byteeq 3-target) → FLIP-6(byteeq 3-target + arm64/darwin fp-ABI) → [FLIP-7 rebase→install-smoke] → [S2/S3 구조 후속]. bit-neutral 을 먼저 소진해 release-integrity 리스크를 격리.

---

## 관련 파일 (절대경로)
- `/Users/mini/dancinlab/hexa-lang/.github/workflows/nobaseline-gate.yml` (advisory 필터 L317-327 = ∅ 판정 하네스 · S1 게이트 대상 = dl* 그룹)
- `/Users/mini/dancinlab/hexa-lang/self/runtime_emit_full.hexa` (glob L13178 · regex `#ifndef` L51/L14016)
- `/Users/mini/dancinlab/hexa-lang/self/runtime_core_emit.hexa` (fgets L7655 · qsort L7262 · strtod-tail L2111)
- `/Users/mini/dancinlab/hexa-lang/self/runtime_core_hxlcl_shim_emit.hexa` (WALL-2 `#ifndef` L144+)
- `/Users/mini/dancinlab/hexa-lang/tool/stage_resolve_runtime_a` (WALL-2 driver L1901/L1930/L2055 · fp-ABI else-arm L2084/L2131)
- `/Users/mini/dancinlab/hexa-lang/self/codegen.hexa` (PR-2 편집 1048/1236/1503-1507/2787 + strict-fp 선례)
- `/Users/mini/dancinlab/hexa-lang/self/main.hexa` (PR-2 probe L1580 strict_fp_cflags twin)
- `/Users/mini/dancinlab/hexa-lang/compiler/link/hexa_ld.hexa` (S3 ELF reader 재사용 L167 read_elf_relocs · L168 got classifier · darwin 배제 L56-57)
- `/Users/mini/dancinlab/hexa-lang/docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (S3 dep L94 G7-B✅ · L96 G7-C)
- **선행 audit(대체 아닌 합성 소스)**: `state/zeroc-29-goal-terminal-verdict-2026-06-30.md` · `state/zeroc-29-terminal-front-reduction-2026-07-03.md` · `state/zeroc-29-dlopen-wall-breakthrough-2026-07-03.md` · `state/zeroc-29-s1-ffi-floor-partition-spec-2026-07-03.md`
- **memory SSOT**: `project_hexa_zeroc_floor_goal_state` · `project_hexa_functional_zeroc_libc_floor_census` · `project_hexa_m8_irreducible_floor`
