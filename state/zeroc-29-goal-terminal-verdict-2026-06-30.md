# zero-c #29 /goal TERMINAL readiness verdict (2026-06-30)

4개 감사 레인(A 바닥센서스 · B 감축-재사냥 · C flip byteeq-안전 · D flip 실행준비)을 종합한 종결 판정.

---

## 1. /goal TERMINAL 판정 — **부분 도달 · "reducible=0" 프레이밍은 FALSE**

### 결론: 종결(floor = pure WALL)은 **5개 flip 이후에도 깨끗하게 도달하지 않는다.** 캠페인 SSOT의 "15 U = WALL-only, reducible=0" 주장은 **내부 모순이며 자체 반증**된다.

**핵심 화해 (레인 A ↔ 레인 B):**

- 레인 A는 캠페인 SSOT(`#4427` · `ARCHITECTURE.json:386` · `state/zeroc-flip-measure-2026-07-03.txt`)가 주장하는 "ON-floor 15 U = WALL-only, 감축잔여 0"이 **같은 날 자체 재평가(`state/zeroc-wall-reassess-2026-07-03.md`, flip-measure보다 7분 앞선 5-agent 워크플로)에 의해 반증**됨을 확인했다. 프롬프트가 말하는 "5개 reducible flip"(glob·fgets·qsort·regex·strtod)은 **15개 floor에서 제거된 게 아니라 여전히 그 안에 들어 있다.** 즉 "15 = flip 후 잔여"가 아니라 "**15 = 그 flip들이 아직 default-ON으로 랜딩되지 않은 상태의 floor**"다. → "reducible=0 after the 5"는 15가 무엇인지를 오기술한 lazy ceiling.

- 레인 B는 6개 카테고리(STRING/IO/MATH/SYSCALL/ALLOC/FMT)를 적대적으로 재사냥했고 **새 pure-algorithm reducible을 0건 발견** → "reducible surface EXHAUSTED"는 생존. **레인 B가 새 감축대상을 찾지 못했으므로 종결주장이 조기(premature)라는 반전은 없다.** 두 레인은 다른 것을 측정한다: A는 *현 15개 floor의 내부 분류*가 틀렸다(WALL 4개뿐)고, B는 *15개 밖에 숨은 감축가능*은 없다고 말한다. 두 결과는 정합적이다.

### 정직한 종결 상태 — 15 U의 참 분류

| 클래스 | 심볼 | 판정 |
|---|---|---|
| **permanent-WALL (FFI)** | `dlopen` `dlsym` `dlerror` | 비가역 — 벤더-FFI 디스패치(`runtime.c:3058-3227`), cuBLAS가 탑승. native-canonical-default가 sanction. |
| **permanent-WALL (musl match)** | `atexit` | 의도적 route-to-libc(`runtime.c:2524`, #4275) · 3 caller 전부 env-gated OFF. |
| **conditional (own-start 결합)** | `environ` | 런타임이 이미 글로벌 소유(ctor 101, ungated ship). 잔여 UND = CRT `envp` 핸드오프 → `HEXA_ZEROC_OWN_START`(default-OFF, `${…:-0}` 모든 stage) flip시에만 절단. |
| **conditional (WALL-2)** | `__libc_calloc` `__libc_free` | transitive-only · arena-calloc/free 포트(별도 blocked front)에서만 용해. glob/qsort/regex flip과 무관. |
| **reducible-but-unflipped** | `strtod` `qsort` `fgets` `glob` `globfree` `regcomp` `regexec` `regfree` | 8개 — 재평가가 명시적으로 WALL이 아닌 REDUCIBLE로 falsify. |

**참 terminal permanent-WALL = 4 names (dlopen/dlsym/dlerror + atexit)**, 15가 아님. 나머지: environ+__libc_calloc/__libc_free = 별도 캠페인 조건부 3개, 8개 = 감축가능하나 아직 default-ON flip 안 됨.

### 레인 B가 본 진짜 ABI/kernel WALL (15-U와 별개 축, setjmp 등)
`setjmp`/`longjmp`(예외-언와인드 ABI) · `dlopen`/`dlsym`/`dlerror` · `pthread_*` · `sigaction`(SA_RESTORER) · `va_list`/`va_start`/`va_arg`. 전부 ABI/kernel/loader 프리미티브 = glob/qsort/regex 같은 이식가능 알고리즘 아님. **새 감축 후보 없음 → 'dry' 확정.**

**⚠️ 종결 판정 요약: 5개 flip을 전부 랜딩하면 functional floor는 15→7 (permanent 4 + conditional 3)로 줄지만, `pure WALL만 남는 종결`은 도달하지 않는다.** environ은 own-start flip(별개 default-OFF 스캐폴드)을, __libc_calloc/free는 WALL-2 arena 포트(별개 blocked)를 각각 요구하므로 5개 flip만으로 종결 불가. **5개 flip = "reducible floor를 permanent+conditional로 축소"이지 "종결"이 아니다.**

---

## 2. flip byteeq-safety 요약 (레인 C)

| flip | byteeq 클래스 | 컴파일러 바이트 변경? | 유저-런타임 바이트 변경? | MUST-PASS 게이트 | unsound 주장? |
|---|---|---|---|---|---|
| **qsort #4452** | **bit-changing (RECONVERGE)** | No (sort가 main.hexa emit closure 밖) | **Yes** — int/str/mixed `.sort()` tie-order | byteeq 3-target + ship smoke | ⚠️ 인라인 주석 "byteeq-safe" **overclaim** (nit) |
| **regex PR-A #4458** | **byteeq-NEUTRAL (OFF opt-IN)** | No (`check/bind`를 아무도 import 안 함 · dead module) | No (dead `#ifdef` + resolver early-return) | PR-A 자체는 게이트-경량; ON-flip은 3-target+faithful+corpus | 없음 — 양 claim 검증 TRUE |
| **strtod tail ON** | **bit-changing (RECONVERGE)** | No | **Yes** — hex/inf/nan/nan-payload 파싱 | 3-target byteeq + glibc+Apple 이중 tail-corpus oracle | 없음 — sentinel-decline로 junk는 libc 유지, surface 좁음 |

**게이트로서 어떤 flip도 설계대로 gated인 한 shipping user-path를 깨지 않는다.**

### qsort 주석 unsoundness (레인 C가 flag한 유일 nit)
`runtime_core_emit.hexa:7266` 주석 "the byteeq-risk inverts to byteeq-safe"는 **오도**. stable merge-sort는 *forward-determinism*만 byteeq-safe(run-to-run 재현)이지 *qsort 이전 baseline과는 다르다* — 중복키/혼합타입 배열에서 tie-order가 직전 릴리스와 FLIP. qsort의 임의 tie-order를 캡처한 golden/fixture는 전부 뒤집힌다. 이건 정당한 RECONVERGE이며 3-target 게이트는 **선택이 아니라 필수**. 주석은 리뷰어를 drop-in으로 오인시킬 수 있으니 머지 오너에게 명시할 것.

---

## 3. remaining-flip 실행 계획 (레인 D · CI 클리어 후 하나씩)

### 실행 순서 요약
1. **qsort #4452** — 3/3 GREEN에서 **머지만** (독립 · seed regen 無 · resolver edit 無).
2. **strtod flip** — regex와 독립이나 **pool-seed-gated**: 먼저 seed regen → 커밋 → line-707 변경 → strtod 게이트.
3. **regex 체인 (엄격 의존):** PR-A #4458 머지 FIRST → THEN regex PR-B(line-761 변경). PR-B는 편집할 라인이 main에 아직 없으므로 PR-A 전엔 존재 불가.

의존: `#4452`(독립) · `strtod`(독립·pool-seed-gated) · `PR-A #4458 → regex PR-B`(하드 체인).

---

### STEP 1 — qsort #4452 (merge-only)
브랜치 `selfhost/flip-qsort-on` · 이미 CI에서 default-ON. 단일 load-bearing 변경 = `self/runtime_core_emit.hexa:~7235`:
```
- "#ifdef HEXA_RT_ARRAY_SORT_NATIVE\n"
+ "#if !defined(HEXA_RT_ARRAY_SORT_NATIVE_OFF)   /* zeroc #29 FLIP: stable native merge-sort default-ON; env escape -DHEXA_RT_ARRAY_SORT_NATIVE_OFF; drops qsort */\n"
```
resolver flip 없음. **액션 = 3/3 GREEN에서 머지.** env escape = `-DHEXA_RT_ARRAY_SORT_NATIVE_OFF`.

게이트 체크리스트:
- [ ] byteeq 3-target (x86_64 + arm64-linux + darwin-arm64) GREEN
- [ ] shipping smoke GREEN
- [ ] "only x86 green" 승격 금지

---

### STEP 2 — strtod tail default-ON (pool-seed-gated)
resolver: `resolve_native_float_parse_hexinfnan_seed()`, `tool/stage_resolve_runtime_a:707`.

**PREREQUISITE — seed `.s`가 워킹트리에 없음** (`self/native/float_parse_hexinfnan_*.s` = ABSENT). flip 전 pool에서 regen 필수:
```
tool/regen_float_parse_hexinfnan_native_s.sh all      # build/aprime_cc 필요 · aiden/summer에서 · mini 금지
```
SSOT = `stdlib/runtime/float_parse_hexinfnan.hexa` → 3-arch seed emit. regen seed는 flip PR에 커밋. seed 없는 타깃에선 `.globl` SAFETY 게이트로 C strtod tail fallback(NO-OP).

resolver 1-line 변경 (line **707**):
```sh
# before
    [ "${HEXA_RT_STRTOD_TAIL_NATIVE:-0}" = "1" ] || return 0        # opt-IN only (default-OFF)
# after
    [ "${HEXA_RT_STRTOD_TAIL_NATIVE:-x}" = "0" ] && return 0        # opt-OUT auto-activate (env=0 forces C strtod tail)
```
companion wiring guard `line 1285`은 변경 불필요(resolver가 var export + `.o` 존재시 자동 링크).

게이트 체크리스트:
- [ ] pool-regen seed 3개 커밋 (각 `.globl rt_str_parse_float_hexinfnan` ≥1 SAFETY)
- [ ] byteeq 3-target GREEN (gen3≡gen4, tail seed default-linked)
- [ ] hex/inf/nan corpus vs **이중 libc oracle** (glibc AND Apple) — `0x1.8p3` · `inf`/`infinity` · `nan`/`nan(payload)` · malformed junk(TAG_VOID sentinel → C hxlcl_atof #else governs)
- [ ] install.sh consumer smoke GREEN

---

### STEP 3 — regex 체인 (PR-A #4458 머지 → PR-B flip)

**3a. PR-A #4458 (`selfhost/regex-rt-wiring`) 머지 대기.** resolver `resolve_native_regex_rt_seed()` + 3 seed(`self/native/regex_rt_{arm64,arm64-linux,x86_64}.s`) + regen script + `-DHEXA_REGEX_NATIVE=1` 배선 도입 — 전부 default-OFF byteeq-neutral. main에 아직 없음.

**3b. regex PR-B (PR-A 머지 후 라인번호 기준).** `tool/stage_resolve_runtime_a` line **761**:
```sh
# before
    [ "${HEXA_REGEX_NATIVE:-0}" = "1" ] || return 0                 # opt-IN only (default-OFF)
# after
    [ "${HEXA_REGEX_NATIVE:-x}" = "0" ] && return 0                 # opt-OUT auto-activate (env=0 forces C libc regex)
```
그 외 무변경: wiring guard `line 1359` + `.globl`-count SAFETY 게이트(6/6 `rt_regex_*`)가 부분/부재 seed시 C libc regex fallback → unknown-target self-safe.

게이트 체크리스트 (bit-CHANGING · 3-target 필수):
- [ ] byteeq 3-target GREEN (gen3≡gen4 reconverge, seed default-linked)
- [ ] faithful/nobaseline-gate: `regcomp`/`regexec`/`regfree` DROP 캡처 (libc regex family가 floor에서 사라짐)
- [ ] install.sh consumer smoke GREEN
- [ ] regex-vs-host-libc corpus (glibc + Apple): `(?i)` · `\d` · backreference · `{n,m}` · findall · split · replace
- [ ] "only x86 green" 승격 금지

---

### STEP 4 — 종결 재검증 (5 flip 랜딩 후)
- [ ] `nm -u build/runtime.a` 재측정 (advisory dump `nobaseline-gate.yml:305-330`) — floor가 15→7로 축소 확인
- [ ] 잔여 7 = {dlopen, dlsym, dlerror, atexit} (permanent) + {environ, __libc_calloc, __libc_free} (conditional) 인지 확인
- [ ] **⚠️ 종결(pure-WALL-only)은 여기서 도달 안 함** — environ은 own-start flip, calloc/free는 WALL-2 arena 포트를 추가로 요구. /goal "terminal reached"로 마킹하지 말 것.

---

## 4. open risks / gaps (감사 레인이 flag한 불확실/미검/누락)

1. **🔴 종결 프레이밍 자체가 FALSE (레인 A).** 캠페인 SSOT의 "15=WALL-only, reducible=0"은 자체 same-day 재평가로 반증. /goal을 "terminal reachable after 5 flips"로 종료하면 잘못. 참: 5 flip = floor 15→7 축소, 종결 아님.

2. **🟡 glob/globfree 폴라리티 불일치 (레인 A · UNCERTAIN).** frozen seed `self/runtime.c:11635-11644`(Jun 30)는 여전히 libc glob 호출하나, live emitter `runtime_emit_full.hexa:13176-13238`(Jul 3)은 이미 native getdents64 body emit. 게이트 `#if defined(__linux__) && (defined(HEXA_RT_GLOB_NATIVE) || !defined(HEXA_RT_GLOB_NATIVE_OFF))` — `!defined(..._OFF)` arm이 **linux에서 native를 default-ON**으로 만들어 인라인 주석 "default-OFF byte-neutral" 및 15-U에 glob이 나타나는 것과 모순. **직접 nm 재측정 필요** — 측정 floor가 이 arm이 engage 안 된 빌드에서 나왔거나, 게이트 폴라리티가 latent byte-changing default.

3. **🟡 15-count = single-host single-config (레인 A).** summer clang-18 · linux-x86_64 한 빌드에서만. CI advisory dump는 필터가 WALL set을 pre-exclude하므로 "15"를 독립 확인 못 함. darwin(libSystem)/arm64 leg의 이 floor는 미측정. census 메모리 자체가 "authoritative nm-UND = CI-harness-bound" + "4개 ad-hoc build path가 재현 실패"를 flag. **"15"는 CI oracle이 아니라 summer 한 빌드에 의존.**

4. **🟢 syscall = mislabel-correction (레인 A · benign).** floor에서 정당하게 제거됐으나 감축이 아니라 오분류-교정 — libc `syscall()`이 아니라 hexa 자체 `__asm__("syscall")`/`svc 0`. flip-measure의 "syscall dropped" 라인이 명령어-니모닉과 libc-dep을 혼동.

5. **🟡 qsort 주석 overclaim (레인 C · nit, unsound 아님).** `runtime_core_emit.hexa:7266` "byteeq-safe"는 forward-det만 해당, baseline-equal 아님. RECONVERGE로 표기하고 3-target 게이트 필수임을 머지 오너에 명시.

6. **🟡 strtod tail의 진짜 적대 리스크 = hex-float round-half-even + nan(payload) (레인 C).** native 구현이 주어진 libc와 1-ULP/1-bit 발산할 가장 그럴듯한 두 지점. corpus oracle이 올바른 게이트 — flip은 그 corpus가 3-target 각 native libc에서 byte-equal로 **증명될 때만** 안전(가정 아님).

7. **🟢 __libc_calloc/free는 5-flip 범위 밖 (레인 A).** transitive-only, WALL-2 arena-calloc/free 포트(별도 blocked front) 필요. 5 flip 캠페인이 이걸 건드린다는 인상은 오류.

8. **🟢 environ own-start 스캐폴드 default-OFF 확인 (레인 A).** `${HEXA_ZEROC_OWN_START:-0}` 모든 stage script. ship path가 절대 set 안 함 → environ은 CRT-bootstrap dep 유지. 별도 own-start flip 캠페인 필요.

---

## 최종 한 줄
**5개 flip(qsort·regex·strtod·glob·fgets)을 안전하게 랜딩하면 zero-c #29 functional floor는 15→7로 줄고, 그 중 4개(dlopen/dlsym/dlerror/atexit)만 permanent-WALL이다. 그러나 "floor = pure WALL만" 종결은 environ(own-start flip)과 __libc_calloc/free(WALL-2 arena)라는 별개 blocked front 2개 때문에 5-flip만으로 도달하지 않는다. 캠페인 SSOT의 "15 = WALL-only, reducible=0"은 정직하지 않은 ceiling이며 자체 재평가가 8/15를 reducible로 반증했다. /goal을 "terminal reached"로 종료하지 말 것 — "floor 15→7 축소, permanent-WALL 4 확정, 종결은 own-start + WALL-2 게이트"로 표기하라.**
