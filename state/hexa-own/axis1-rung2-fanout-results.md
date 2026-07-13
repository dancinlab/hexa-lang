# axis-① rung-2 + loose-end fan-out 결과 (/abg wf_0f1ce03f·2026-07-11)

## rung2-crosstarget

origin/main 정독 완료. 설계 판정을 정리한다.

---

## rung-2 cross-target native emit+link — 실현성 판정 + edit spec

### 1. 현행 코드 지형 (origin/main = `29f38d1ad`)

**cross-EMIT은 이미 clang-0 · host-독립이다.** `compiler/main.hexa:1080-1112`의 3-타깃 네이티브 obj writer(`pack_lir_x86_64`/`pack_lir_arm64_elf`/`pack_lir`+각 serialize)는 요청된 `--target` 문자열만 보고 ELF/Mach-O 바이트를 in-process로 직렬화한다. host 툴체인을 전혀 안 탄다. 즉 `aprime _drv.hexa --emit=obj --target=<t>`는 darwin host에서도 x86_64-linux .o를 뽑는다 — **cross-emit은 갭이 아니다.**

**cross-LINK이 유일한 벽이고, 타깃별로 실현성이 갈린다.** 링크 레시피 3종:
- `compiler/main.hexa:1210-1223` arm64-darwin: `ld -lSystem -syslibroot <SDK> -e _main` — macOS SDK(libSystem.tbd)+ld64 필요.
- `compiler/main.hexa:1224-1245` x86_64/arm64-linux: `ld <crt1.o> -lc -dynamic-linker <ld.so>` — 타깃 crt1.o+libc.so+타깃 인식 `ld` 필요.
- `compiler/main.hexa:1173-1230` **`--linker=hexa` own-start static ET_EXEC** (`link_elf_x86_64_ownstart_ar`) — **crt1.o/libc.so/dynamic-linker/system-ld 전부 ZERO. 유일 입력 = 타깃 arch runtime.a.** in-process ELF 바이트 방출이라 완전 host-독립.

**self/main.hexa 소비 드라이버 상태:**
- `cmd_build` leg-B 네이티브(`self/main.hexa:3541`) 게이트에 `len(target) == 0` — cross를 명시 배제. `--target=` 지정 시 `self/main.hexa:3844-3865`의 `zig cc -target <triple>` C-transpile로 라우팅(=clang-0 위반 소비처).
- `cmd_run`은 `--target`을 **아예 파싱 안 한다**(`self/main.hexa:7267-7305`). `_ntgt`(`:4659`)는 host uname에서 파생. cross-target `run`은 host에서 실행 불가한 바이너리를 낳으므로 의미 없음 → **rung-2의 정직한 범위는 `hexa build --target=` 하나**다.
- own-link 경로는 `cmd_run`이 `HEXA_LINK_HEXA=1`에서 이미 씀(`self/main.hexa:4603-4632`, `--backend=native --emit=exec --linker=hexa --target=x86_64-linux-gnu`) — 단 **host==Linux x86_64로 게이트**. emit은 host-독립인데 게이트만 host-고정이다. rung-2는 이 게이트를 host→target으로 옮기는 것.

### 2. cross-link clang-0 실현성 매트릭스

| target | native emit | clang-0 link | 판정 |
|---|---|---|---|
| **x86_64-linux-gnu** | ✅ aprime | ✅ `--linker=hexa` own-start static ET_EXEC (`link_elf_x86_64_ownstart_ar`) — sysroot 불필요, x86_64 runtime.a만 | **실현 가능** (host 무관) |
| arm64-linux-gnu | ✅ aprime | ❌ own aarch64 static ELF 링커 부재(`--linker=hexa`는 x86_64 ELF+arm64 Mach-O만; `compiler/main.hexa:1265` 폴백 경고). system `ld` cross는 cross-binutils+aarch64 sysroot 필요 | 벽 → zig cc |
| arm64-apple-darwin | ✅ aprime | ⚠️ own Mach-O 링커 존재(`--linker=hexa`, hexa_ld, `compiler/main.hexa:1247`)나 LC_LOAD_DYLIB libSystem 참조+ad-hoc codesign 필요. **darwin host=rung-1(OK)**, **비-darwin host→darwin=libSystem stub 없음+codesign darwin전용** | linux→darwin은 벽 → zig cc |

**결론: rung-2에서 clang-0로 깨끗이 실현되는 cross-link은 `→ x86_64-linux-gnu` (own-start static) 단 하나.** 나머지 둘은 다음 rung(own aarch64 static writer / darwin SDK-less Mach-O)까지 zig cc 폴백 유지.

### 3. 진짜 DX 갭 = runtime.a arch 불일치

`resolve_prebuilt_runtime()`(`self/main.hexa:1673-1700`)은 **host-arch** runtime.a만 돌려준다(installer가 `<hxroot>/build/runtime.a` 1개 arch만 드롭). darwin-arm64 host에서 `→x86_64-linux` static link을 하려면 **x86_64-linux runtime.a**가 필요한데 부재 → own-start-ar 링크가 arch-mismatch로 실패(혹은 `compiler/main.hexa:1195`의 W1 fail-close `exit(3)` FATAL). 따라서 cross-native는 **타깃-arch runtime.a 리졸버**(`HEXA_PREBUILT_RUNTIME_<arch>` 또는 `build/runtime.<target>.a` 규약)가 선결. 없으면 반드시 zig cc로 폴백해야 함(release-safe).

부차 갭: **어휘 불일치.** 표면 `--target`은 zig-triple 별칭("linux-x86_64-glibc", "darwin-arm64" — `target_zig_triple` `self/main.hexa:2835`), aprime은 "x86_64-linux-gnu"/"arm64-linux-gnu"/"arm64-apple-darwin". cross-native leg에 표면→aprime 매핑 fn 필요.

### 4. self/main.hexa edit spec (default-OFF · 안전망 보존)

**삽입 위치**: leg-B 블록 종료(`self/main.hexa:3604`) 직후, Rider `resolve_or_bootstrap_hexat`(`:3608`) 직전. `__actual_src`(flatten 완료, `:3152/3184`)가 이 지점에서 사용 가능.

**신규 블록 (sibling, leg-B와 별개 — host==target이 아니라 host≠target·own-start-ar 레시피)**:

```
// axis-① rung-2: cross-target native leg (clang-0, own-start static ELF).
// 게이트: HEXA_BUILD_NATIVE_CROSS=1 (default-OFF·byte-neutral) + --target이
//   x86_64-linux로 매핑 + shared!=1 + c_only!=1 + len(__actual_src)>0.
// 실현 가능한 유일 clang-0 cross = →x86_64-linux own-start static.
// arm64-linux / darwin cross는 게이트 통과 안 함 → 기존 zig cc 폴백 유지.
if env_var("HEXA_BUILD_NATIVE_CROSS") == "1" && shared != "1" && c_only != "1"
   && len(__actual_src) > 0 && _cross_aprime_target(target) == "x86_64-linux-gnu" {
    let _xcc = resolve_native_cc()
    let _xrt = _resolve_target_runtime_a("x86_64-linux-gnu")   // 신규: arch-매치 runtime.a
    if len(_xcc) > 0 && len(_xrt) > 0 {
        let _xtmp = exec("printf '%s.xtmp.%s' '" + out + "' \"$$\"")
        // own emit+own ELF 링커 단일 호출 (system ld/as/clang ZERO):
        let _xr = exec("HEXA_PREBUILT_RUNTIME='" + _xrt + "' '" + _xcc
            + "' _drv.hexa --backend=native --emit=exec --linker=hexa"
            + " --target=x86_64-linux-gnu -o '" + _xtmp + "' '" + __actual_src + "' 2>&1")
        let _xok = exec("test -x '" + _xtmp + "' && printf yes || printf no")
        if _xok == "yes" {
            let _ = exec("mv -f '" + _xtmp + "' '" + out + "' 2>/dev/null")
            if env_var("HEXA_RUN_NATIVE_TRACE") == "1" { eprintln("[build-cross] clang-free own-link → " + out) }
            println("OK: built " + out + " (native cross-target x86_64-linux, own-start static — no clang, no zig)")
            return ""
        } else {
            let _ = exec("rm -f '" + _xtmp + "' 2>/dev/null")
            if env_var("HEXA_RUN_NATIVE_TRACE") == "1" { eprintln("[build-cross] own-link failed → zig cc fallback: " + _xr) }
        }
    }
    // runtime.a 부재 / cc 부재 / 링크 실패 → fall through = 기존 zig cc 경로
}
```

**보조 신규 fn 2개** (`target_zig_triple` 인근 `self/main.hexa:2843` 뒤):
- `_cross_aprime_target(t)`: 표면 별칭 → aprime 타깃. rung-2에선 `"linux-x86_64-glibc"|"linux-x86_64-musl" → "x86_64-linux-gnu"`, 그 외 `""`(게이트 미통과). (musl은 own-start static이 사실상 musl-static과 동형이라 안전.)
- `_resolve_target_runtime_a(aprime_tgt)`: `HEXA_PREBUILT_RUNTIME_X86_64_LINUX` 우선 → `<hxroot>/build/runtime.x86_64-linux-gnu.a` → 없으면 `""`. (host==target일 때만 `resolve_prebuilt_runtime()` 재사용 가능하나 cross에선 arch 태그 필수.)

**중요**: 기존 leg-B 게이트(`:3541`)의 `len(target)==0`은 **건드리지 않음** — 네이티브-호스트 빌드는 char-identical 유지. 신규 블록은 `--target` 지정 + 신규 env opt-in에서만 발화하므로 default path byte-neutral. 실패 시 zig cc로 전락(delegate-fallback 온전).

### 5. 리스크

- **runtime.a arch 부재 (最)**: installer가 x86_64-linux runtime.a를 cross-host에 드롭 안 함 → `_resolve_target_runtime_a`가 `""` → 조용히 zig cc 폴백. 실제 clang-0 소비처 차단이 되려면 **installer/pool sync가 타깃별 runtime.a를 배포**해야 함(별도 packaging rung). 이게 안 되면 rung-2는 "코드는 있으나 대부분 폴백" 상태.
- **W1 fail-close 충돌**: arch-mismatch runtime.a를 잘못 넘기면 `compiler/main.hexa:1187-1197`이 `exit(3)` FATAL → 안전망 우회. 반드시 `_resolve_target_runtime_a`가 arch-검증(예: `file`/nm ELF-class 체크)한 것만 넘기고, 아니면 `""` 반환.
- **darwin/arm64-linux 오해**: 사용자가 `--target=darwin-arm64`(cross from linux) 기대 → 게이트 미통과로 조용히 zig cc. `HEXA_RUN_NATIVE_TRACE=1` 미설정 시 "왜 native가 아니지" 혼란. 도움말/trace 문서화 필요.
- **static-only 표면**: own-start는 static ET_EXEC만 — 동적 링크 소비자(`--shared` cross)는 여전히 배제(`self/main.hexa:3681` refuse 유지).

### 6. effort / risk

- **effort**: 낮음-중간. self/main.hexa 신규 블록 ~30줄 + 보조 fn 2개 ~15줄. compiler/main.hexa 무수정(own-start-ar 경로 이미 존재). 최대 부담은 **installer의 타깃별 runtime.a 배포**(별도 packaging 작업, self/main.hexa 밖).
- **risk**: 낮음(코드 자체). default-OFF + `--target` 게이트 + 전 실패경로 zig-cc 폴백 = release-integrity 불변. 진짜 리스크는 "실효성" — runtime.a 배포 없이는 소비처 차단이 명목상에 그침.
- **검증**: (a) darwin-arm64 host에서 x86_64-linux runtime.a를 `HEXA_PREBUILT_RUNTIME_X86_64_LINUX`로 명시 → `hexa build hello.hexa --target=linux-x86_64-glibc` → 산출 ELF를 x86_64-linux pod(summer/aiden)에서 rc-correct 실행 확인. (b) runtime.a 미설정 → zig cc 폴백 rc0 확인(회귀 없음). (c) `strace`/`ldd`로 static ET_EXEC + zero clang/zig/ld execve 확인. mini는 read-only이므로 실빌드는 pool.

**핵심 한 줄**: rung-2에서 clang-0 cross-link이 실제로 뚫리는 타깃은 `→x86_64-linux-gnu`(own-start static) 하나뿐이고, 코드 갭은 작으나(self/main.hexa ~45줄) 진짜 관문은 **타깃-arch runtime.a 배포**다. arm64-linux/darwin cross는 own aarch64 static writer / SDK-less Mach-O가 나오는 다음 rung까지 zig cc 폴백으로 남는다.

(측정 없음 — 위 실행시간/바이너리 판정은 origin/main 코드 정독 기반 추정.)

---

## rung2-shared

origin/main 정독 완료. rung-2 `--shared` clang-0 링크 설계를 아래에 낸다. (측정 미실행 항목은 "추정"으로 표기)

---

## 1. 현행 지형 (origin/main, `29f38d1ad`)

`self/main.hexa:cmd_build` 안에 `--shared`를 다루는 경로가 **두 개** 있고, 셋째(clang-0 leg-B)는 shared를 **거부**한다:

| 경로 | 위치 | shared 처리 | 링커 |
|---|---|---|---|
| C-transpile path | `self/main.hexa:3733-3842` | `_shared_cflags="-fPIC -shared "` (L3738-3739) → `compile` 라인(L3842) | **clang -shared** |
| native-backend (`HEXA_BACKEND=native`, K2) | `self/main.hexa:3320-3528` | `--nshared_flag=" --shared"` (asm emit L3335) + `__nshared_link="-fPIC -shared "` (L3350) → `__nlink`(L3503) | **`host_cc()`=clang -shared** (asm 어셈블+링크) |
| **clang-0 leg-B** (rung-1) | `self/main.hexa:3541-3604` | **`shared != "1"` 가드로 배제 (L3541)** | `ld`/`ld64` (순수) |

즉 native codegen(RFC070 G7-A)은 이미 `--shared`에서 GOT-load PIC 시퀀스를 emit하지만(K2 주석 D1 arm64 `8fdb29e2`·D2 x86_64 `b62809f8`), 실제 `-shared` **링크는 clang으로만** 떨어진다. rung-2 갭 = leg-B의 `ld -shared`/`ld64 -dylib` 경로 부재.

핵심 확인: `aprime_cc … --emit=obj --shared --target=<triple>`가 clang-0 PIC obj를 만든다는 것 —
- `compiler/main.hexa:481-485` `--shared` → `shared_flag=true`
- `compiler/main.hexa:962-965` `shared_flag` → `CodegenOptions{shared:1}` overlay → arm64+x86_64 emit-body GOT-load 분기 gate
- `compiler/main.hexa:525-544` `--target=<triple> --emit=obj` → `backend_kind="native"` (native ELF/Mach-O writer, `as`/clang fork 0)

→ **stage 1(PIC obj 생성)은 이미 준비됨.** rung-2는 stage 2(링크)만 추가.

---

## 2. 레시피 (clang-0 shared 링크)

### Stage 1 — PIC relocatable obj (양 OS 공통)
```
aprime_cc _drv.hexa --emit=obj --shared --target=<triple> -o <stem>.shobj.o <src>.hexa
```
`--shared`가 opts.shared=1 → GOT-load PIC emit. `--target`가 native writer 선택(no `as`).

### Stage 2a — Linux `.so` (`ld -shared`)
```
ld -shared -o <out> <shobj.o> <runtime.a> \
   --start-group -lc -lpthread -lm --end-group \
   -soname <basename(out)> \
   -L<crtdir> <crtdir>/crti.o <crtdir>/crtn.o
```
exec 경로 대비 **차이**: `crt1.o` **제거**(shared는 `_start` 불요), `--dynamic-linker` **제거**(exec 전용), `-soname` **추가**(DT_SONAME), `crti.o/crtn.o`는 runtime.a의 init-array/`.init` framing 안전용으로 유지 권장. own-start(`_bnzc`) 분기는 shared에 **무의미**(entry 없음) → 타지 않음.

### Stage 2b — Darwin `.dylib` (`ld64 -dylib`)
```
ld -dylib -o <out> <shobj.o> <runtime.a> -lSystem -syslibroot <SDK> -arch arm64 \
   -install_name @rpath/<basename(out)>
```
exec 경로 대비 **차이**: `-dylib`(MH_DYLIB), `-e _main` **제거**(entry 없음), `-install_name`(LC_ID_DYLIB) **추가**. 링크 후 `codesign_if_macos()`는 그대로(arm64 dylib도 ad-hoc 서명 필요).

**clang-0 불변식**: `ld`/`ld64`는 순수 링커, `xcrun --show-sdk-path`는 경로 probe(컴파일 아님), `codesign`은 sanctioned leaf → 불변식 보존.

---

## 3. self/main.hexa cmd_build shared 분기 edit spec

release-integrity: 전체 shared-native 경로를 **`HEXA_NATIVE_SHARED=1` opt-in·default-OFF**으로 gate(rung-1 `HEXA_NATIVE_DARWIN` 패턴 동형). 어떤 emit/link 실패든 기존 clang `-shared` C-path(L3733+)로 fall-through → shipping 무파손.

**Edit A — 가드 (`self/main.hexa:3541`)**: `&& shared != "1"` →
```
&& (shared != "1" || env_var("HEXA_NATIVE_SHARED") == "1")
```

**Edit B — aprime emit (`:3555`)**: `--shared` 조건부 삽입
```
let mut _bnsh = ""
if shared == "1" { _bnsh = " --shared" }
let _bne = exec("'" + _bncc + "' _drv.hexa --emit=obj" + _bnsh + " --target=" + _bntgt + " -o '" + _bnobj + "' '" + __actual_src + "' 2>&1")
```

**Edit C — darwin 링크 (`:3567`)**: `_bnlnk`를 shared 분기
```
let _bnbase = exec("basename '" + out + "' | tr -d '\\n'")   // soname/install_name용
let _bnlnk = if shared == "1" {
  "'" + _bnld + "' -dylib -o '" + _bntmp + "' '" + _bnobj + "' '" + _bnrt + "' -lSystem" + _bnsdkarg + " -arch arm64 -install_name '@rpath/" + _bnbase + "' 2>&1"
} else {
  "'" + _bnld + "' -o '" + _bntmp + "' '" + _bnobj + "' '" + _bnrt + "' -lSystem" + _bnsdkarg + " -arch arm64 -e _main 2>&1"
}
```
그리고 성공 체크(`:3569`) `test -x` → shared일 때 `test -e`(dylib 0644). `codesign_if_macos`·`mv`·성공 println은 shared 문구만 분기.

**Edit D — linux 링크 (`:3578-3599`)**: shared는 crt1/dynamic-linker 불요 → `if len(_bncrt)>0 && len(_bndl)>0` **probe 앞에** shared 서브분기를 두거나(권장), 가드를 `shared=="1" || (len(_bncrt)>0 && len(_bndl)>0)`로 완화. shared 링크:
```
let _bnbase = exec("basename '" + out + "' | tr -d '\\n'")
let _bnlnk_so = "'" + _bnld + "' -shared -o '" + _bntmp + "' '" + _bnobj + "' '" + _bnrt + "' --start-group -lc -lpthread -lm --end-group -soname '" + _bnbase + "' -L'" + _bncrt + "' 2>&1"
```
성공 체크(`:3591`) `test -x` → shared는 `test -e`.

edit 규모: 약 25-30줄(주로 조건부 분기). CHANGELOG.jsonl 동반 필요.

---

## 4. PIC / GOT / PLT 리스크 (측정 없으면 추정)

| 항목 | 판정 | 근거 |
|---|---|---|
| **user obj PIC** | **해소됨 (LOW)** | `--shared`가 GOT-load emit gate — K2에서 arm64/x86_64 이미 구현·clang-path에서 검증(`8fdb29e2`/`b62809f8`) |
| **runtime.a PIC (Linux) — 최대 벽** | **x86_64 실패 추정 / arm64 성공 가능** | `resolve_prebuilt_runtime()`의 runtime.a는 **static-exec용**. `os_clang_cflags()`(L1380)에 `-fPIC` 없음 → non-PIC이면 `ld -shared`가 `R_X86_64_32/32S … recompile with -fPIC`로 **거부** (추정). arm64는 codegen이 본질적으로 adrp/GOT-relative라 abs32 reloc 적어 통과 가능성 높음(추정, 미측정) |
| **runtime.a PIC (Darwin)** | **성공 추정 (LOW-MED)** | arm64 macOS는 전 코드 PIC-default → runtime.a가 이미 position-independent → `-dylib` 링크 통과 추정 |
| **PLT (libc extern)** | **MED·미측정** | runtime.a는 .so 내부로 static pull-in(hexa_* PLT 불요). libc는 `-lc`로 PLT/GOT 경유 — aprime가 extern call을 PLT32/GOTPCREL로 마킹하면 OK, 직접 PC-rel이면 `-shared`가 거부 가능 |
| **-soname / -install_name** | LOW | 재배포 로더 요구 필드, 문법 단순 |
| **crti/crtn (init framing)** | LOW-MED | runtime.a에 constructor/init-array 있으면 `.so`도 필요 — crti.o/crtn.o 포함 권장(ld가 DT_INIT_ARRAY 합성) |

**Linux .so의 진짜 게이팅 = non-PIC runtime.a.** clang-0 유지하며 PIC runtime.a를 얻으려면 (a) runtime을 aprime로 emit하거나 (b) PIC 빌드된 runtime.a asset 배포 — 별도 follow-rung. (clang `-fPIC`로 runtime.a 재빌드는 clang-0 위반이라 이 레인에선 불가.)

---

## 5. effort / risk 판정 + 권고

- **Darwin `.dylib`: LOW effort · LOW-MED risk.** Edit C만으로 기존 ld64 exec 분기 미러(`-e _main`→`-install_name`, `-dylib`, `test -e`). PIC-default 호스트라 runtime.a 벽 없음. **먼저 착지 권장.**
- **Linux `.so`: MED effort · MED-HIGH risk.** Edit D 자체는 소규모지만 non-PIC runtime.a reloc 벽에 막힐 확률 높음(x86_64). 권고 순서: (1) 경로를 `HEXA_NATIVE_SHARED=1` default-OFF로 착지, (2) 풀 호스트에서 `ld -shared` reloc smoke 실측(x86_64/arm64 각각), (3) x86_64 실패 시 PIC runtime.a follow-rung 분리.
- **release-integrity**: 전 경로 opt-in + 실패 시 clang C-path fall-through → shipping·byteeq 무영향. rung-1과 동형이라 회귀 위험 최소.

**다음 라운드 이름**: `rung-2b = PIC runtime.a (Linux .so 벽 해소)` — x86_64 `ld -shared` reloc 실측이 GO/NO-GO 게이트.

관련 파일: `/Users/mini/dancinlab/hexa-lang/self/main.hexa` (cmd_build L3014-3604·leg-B 가드 L3541·darwin 링크 L3567·linux 링크 L3589), `/Users/mini/dancinlab/hexa-lang/compiler/main.hexa` (`--shared` L481·CodegenOptions overlay L962·target native-writer L525-544·native ld self-link L1230-1340).

---

## changelog-prep

RECONCILE: 태스크의 전제(#4847/#4849/#4851/#4857 누락, CHANGELOG가 07-09서 정지)는 stale였다. origin/main은 shallow(4-commit)이고 CHANGELOG.jsonl은 이미 07-11 엔트리를 담고 있음 — argv 배선(#4847류)=entry4 `fix(codegen/x86_64): axis-3 main-entry hexa_set_args(argc,argv) wiring`, comment fix(#4849류)=entry2 `docs(self/main): fix stale HEXA_BUILD_NATIVE comment`, own-link(#4851류)=entry5 `fix(axis3): own-link fail-close … argv map` 로 이미 로깅됨. reachable 머지커밋 4개(#4856·#4858·#4857·#4853) 중 #4856(entry0)·#4853(entry1)도 이미 존재.

실제 누락 = **#4857·#4858 두 건뿐**. #4858(darwin run)은 진행중이 아니라 **MERGED**(501d49ff2, 07-11 21:28)이므로 포함함.

INSERT 위치: newest-first 정렬상 top의 #4856(21:38)과 2번째 #4853(20:45) **사이**에, 아래 순서(#4858 먼저 → #4857)로 prepend/삽입.

```
{"ts": "2026-07-11", "title": "feat(self/main): axis-① rung-1b — darwin arm64 native `hexa run` (clang-0·default-OFF)", "body": "rung-1a(cmd_build)와 동형으로 cmd_run_user_direct에 darwin arm64 native run leg 추가 — HEXA_NATIVE_DARWIN=1(default-OFF·byte-neutral)일 때 --target=arm64-apple-darwin --emit=obj→ld64(-lSystem -syslibroot·crt/own-start skip·codesign·cache-slot atomic-rename)로 라우팅하고 전 실패경로는 기존 clang `hexa build` fallback 보존. HEXA_LINK_HEXA own-link 블록은 무수정(Linux x86_64 배제·arm64 own-link=별도 rung)·이로써 rung-1(build+run) 완성. #4858."}
{"ts": "2026-07-11", "title": "feat(self/main): axis-① rung-1a — darwin arm64 native `hexa build` leg (clang-0·default-OFF)", "body": "axis-③ end-to-end(ARC_E2E=PASS_BYTEID) 종결 후 최대 C-fallback 소비처인 darwin build를 native 경로로 라우팅하는 첫 rung — self/main.hexa cmd_build leg-B 게이트에 opt-in HEXA_NATIVE_DARWIN=1(default-OFF·byte-neutral) 분기 추가로 darwin arm64면 --emit=obj→ld64(-lSystem -syslibroot·crt/own-start skip·codesign, clang/cc 개입 0)를 쓰고 실패 시 기존 hexat→.c→clang fallthrough 보존. flip 게이트=ghost darwin-arm64 corpus rc0+byteeq 3-target+install.sh smoke. #4857."}
```

둘 다 `json.loads` 검증 통과. title=커밋 subject 그대로, ts=머지날짜 2026-07-11, body=한국어 핵심 요약(default-OFF·byte-neutral 안전망·clang-0 불변식 반영). 파일 경로: `CHANGELOG.jsonl`(repo root, origin/main SSOT).

---

## exempt-prune

프룬 대상 식별 완료. 시뮬레이션까지 검증했다.

---

## 판정 요약

`tool/symcensus_exempt.txt`(220줄, 주석 제외 실엔트리 **198**개) 중 **138개가 STALE** — 이미 `_builtin_runtime_sym`에 실매핑되어 exempt 불필요. **60개는 genuine**으로 유지. 프룬해도 lint는 GREEN(residual=∅) 유지, STALE advisory만 0으로 청소됨.

근거: origin/main 4-surface를 뽑아 `symcensus_lint.sh`(fakeroot)로 직접 재현.
- 매핑소스: `compiler/codegen/arm64_darwin.hexa:1812` `_builtin_runtime_sym` (mapped=318)
- C-ABI: `compiler/codegen/x86_64_linux.hexa:2258` `_is_cabi` (cabi=81)
- 게이트: `compiler/check/bind.hexa:1354` `_bind_builtin_names` + `compiler/check/types.hexa:4370` `_is_builtin_method` (gate_union: bindgate=393, whitelist=93)
- lint의 STALE advisory 로직: `tool/symcensus_lint.sh:97-121` (이미 exit0 advisory로 138 검출)

## STALE 분류 (전부 단일 카테고리)

138개 **전부** `_builtin_runtime_sym`(arm64)에 `name == "X"`로 실매핑 확인. cabi-only=0, 게이트-이탈(dead weight)=0, special-op정규식매치=0 — 즉 정확히 "part-2가 매핑 착지했으나 exempt 라인을 안 지운" 케이스만 남음. #4839/#4842 array60+non-array137 드레인 + argv#4847의 후폭풍 그대로.

**프룬 대상 138 (symcensus_exempt.txt에서 삭제):**
```
aes256_ctr_xor argv array_alloc array_count array_drop array_fill array_index_of
array_max array_min array_product array_reverse array_take bytes_to_f32_le
bytes_to_f64_le chacha20_poly1305_decrypt chacha20_poly1305_encrypt chacha20_xor
clock cstring delete_file deref ed25519_keypair ed25519_sign ed25519_verify
exec_argv exec_capture exec_pipe_open f32_to_bytes_le f64_to_bytes_le fma
from_cstring gelu hadamard ham_free http_get input is_error isfinite isinf isnan
json_decode json_encode json_parse json_stringify layer_norm libsodium_available
map_contains_key matmul matvec mod mount namespace_clone_const net_accept net_close
net_connect net_listen net_read net_read_bytes net_read_n net_recv_fd net_select
net_send_fd net_set_nonblock net_set_timeout net_write net_write_bytes now_monotonic_s
one_hot phi_mi_pair phi_spatial pivot_root poly1305_onetimeauth proc_fork
proc_reap_zombies proc_setsid proc_wait proc_wait_flag_const ptr_addr ptr_alloc
ptr_free ptr_null ptr_offset pty_forkexec pty_get_winsize pty_open pty_set_winsize
read_bytes_at read_file_bytes read_lines read_stdin real_args regex_findall
regex_match regex_match_full regex_replace regex_search regex_split rms_norm rope_pair
script_path setenv setns sha256_bytes sha512 silu sleep_ms sleep_ns sleep_s softmax
str_trim_end str_trim_start struct_free struct_pack struct_unpack swiglu_vec
tensor_add tensor_dot tensor_mul_scalar tensor_ones tensor_slice tensor_zeros
term_winsize_cols term_winsize_rows term_write_str time_ms tty_isatty tty_ttyname
u_floor umount unshare utc_compact_now utc_iso_format utc_iso_parse write_bytes_append
write_bytes_append_v write_bytes_v x25519_keypair x25519_scalarmult
```
(샘플 실매핑 검증: `argv→hexa_args` arm64_darwin.hexa:1823, `matmul→hexa_matmul` :2241, `net_connect` :2172, `json_encode` :2204, `x25519_scalarmult` :2235)

## 유지할 genuine exempt (60개 — 아직 미매핑, residual 방어 계속 필요)

코드젠 어디에도 `name==`매핑/인라인이 없음(hexa_str_concat·hexa_str_parse_int·ptr_from_int만 다른 문맥 1회 등장하나 `_builtin_runtime_sym` 키 아님). 성격별:
- **CUDA-gated (3):** `gpu_matmul` `gpu_matmul_NT_a` `gpu_matmul_NT_b`
- **native-thread/atomic aliased (14):** `atomic_cell_{new,load,store,add,sub,cas}`(6) `thread_spawn` `thread_join` `thread_channel_{new,send,recv,close}` (원문 header의 "native-thread aliased" 분류)
- **terminal/pty interp-syscall leaves (21):** `term_*`(17: fd_{close,poll,read,write}, getppid, install_sigint, install_sigwinch, isatty_stdin, isatty_stdout, poll_stdin, pty_reap, pty_spawn_sh, raw_enter, raw_restore, read_byte, sigint_pending, sigwinch_pending) + `pty_tcgetattr` `pty_tcsetattr` `read_line` `exec_stream_kill`
- **fs/time/misc — identity-OK 또는 다음 드레인 라운드 need-map 후보 (22):** `copy_file` `remove_file` `rename_file` `file_modtime` `file_size_native` `clock_ms` `nanos` `now_ms` `now_unix_ms` `time_now` `getenv` `getpid` `crc32` `hash_string` `is_digit` `panic` `assert` `arange` `ham_pack` `f32_bits` `f32_from_bits` `ptr_from_int`

주의: 이 60 중 fs/time/misc 그룹 상당수는 "영구 exempt"가 아니라 **아직 드레인 안 된 need-map**일 가능성이 높다(getpid는 CLAUDE.md상 raw-svc 라우팅, getenv/fs계열은 hexa_* 정의 존재 가능성) — 다음 census 라운드 매핑 후보다. 진짜 영구 exempt는 CUDA-gated(3)+native-thread(14)+term interp(21) 성격군.

## selfhost_gates_summary required check 승격 가부

**승격 가능 — 권장.** 근거:
1. **소스-only, 빌드/runtime.a 불요** → cloud checkout에서 즉시 실행(`symcensus_lint.sh:29` 주석 명시). github-hosted 러너에 이상적, 오프라인 self-hosted 러너 의존 없음(`selfhost-gates-summary`가 오프라인 러너에 의존 금지 규칙 충족).
2. **현재 GREEN(residual=∅)** — "measured green 후에만 승격" 규칙 충족. 프룬 시뮬레이션 후에도 GREEN 유지 확인.
3. **anti-vacuous 가드 내장** — 각 추출 <10개면 FATAL exit2(`symcensus_lint.sh`의 degenerate 체크)로 awk-drift로 인한 silent-green 방지.

승격 전 선결/주의:
- **먼저 138 프룬 커밋**(advisory 노이즈 제거 → 게이트가 residual만 판정하게). 프룬은 exempt에서 covered 엔트리 삭제라 residual 불변(검증 완료).
- **False-RED 리스크 1건:** body-end를 column-0 `}`로 잡는 awk 휴리스틱(`symcensus_lint.sh:60-72`)은 .hexa 포매팅 리팩터에 취약 → 무관 PR을 exit2로 막을 수 있음. required 승격 시 이 파서 취약성이 유일한 fragility. 완화책은 이미 있는 degenerate-guard지만, 승격과 함께 STALE advisory를 hard-fail로 올릴지는 별도 결정(현재 exit0 유지가 안전 — 매핑 착지 PR이 exempt 청소를 깜빡해도 RED 안 됨).

파일: `/Users/mini/dancinlab/hexa-lang/tool/symcensus_exempt.txt` (프룬 대상), `/Users/mini/dancinlab/hexa-lang/tool/symcensus_lint.sh` (게이트).

---

