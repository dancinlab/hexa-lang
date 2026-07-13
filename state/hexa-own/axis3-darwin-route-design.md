# axis-③ L2 rung-1 darwin native 라우팅 — Fable 설계 (2026-07-11·origin/main 199058dc)

정독 완료. origin/main(`199058dc`) 기준 설계를 드립니다. 핵심 선행 발견 두 가지: **(a)** compiler/main.hexa에 darwin ld64 clang-free 링크 레시피가 이미 존재하고 P1 코퍼스로 검증돼 있으며(`compiler/main.hexa:1213-1218`), **(b)** darwin용 Mach-O runtime.a는 install.sh의 stage_resolve_runtime_a가 이미 생성·설치합니다. 따라서 rung-1의 수정 표면은 **self/main.hexa 2곳(cmd_build·cmd_run_user_direct)뿐**이고 compiler/main.hexa는 무수정입니다.

---

# L2 axis-① rung-1 — darwin native build/run 라우팅 설계 (clang-0)

기준: `origin/main = 199058dc`. 라인 번호는 전부 이 커밋 기준.

## 0. 정독으로 확정한 사실 (설계 전제)

| 사실 | 근거 |
|---|---|
| darwin Mach-O .o emit은 **완성 경로** — `--target=arm64-apple-darwin --emit=obj`면 backend가 **자동으로 native** (`--backend=native` 명시 불필요) | `compiler/main.hexa:526-530`, emit 분기 `:1012-1030` |
| macho writer는 `__cstring`+PAGE21/PAGEOFF12·`__const` float pool·GOT_LOAD 분류까지 구현됨 — 헤더의 "out of scope" 주석(:54)은 **stale** (2026-05-26 시점 기록) | `compiler/emit/macho_arm64.hexa:1422-1583, 1791-1797` |
| darwin exec용 **시스템 ld64 레시피가 이미 in-tree**: `ld -o OUT OBJ -lSystem -syslibroot $(xcrun --show-sdk-path) -arch arm64 -e _main` — P1 LINKEXEC 코퍼스로 mini에서 검증된 전례 | `compiler/main.hexa:1213-1218` |
| darwin arm64 codegen(LIR)은 arm64-linux와 **동일 함수 공유**(`codegen_arm64_darwin`이 양쪽 담당) — proven된 arm64-linux leg-B와의 delta는 컨테이너(ELF vs Mach-O)+reloc 계층뿐 | `compiler/main.hexa:973-979` |
| darwin runtime.a는 install.sh가 **이미 staging** — darwin-arm64 브랜치가 Mach-O 시드(`_rt_*` underscore 심볼)로 조립, `$HX_BIN/build/runtime.a` 영속 + `HEXA_PREBUILT_RUNTIME` export | `tool/stage_resolve_runtime_a:258,281,343,385`, `install.sh:276-277,561-575` |
| darwin runtime.a에는 **own `_start` 없음** — `-DHEXA_ZEROC_OWN_START`가 Linux 게이트로 막혀 있고 주석이 명시적으로 "darwin runtime.a byte-change 방지" | `tool/stage_resolve_runtime_a:46` |
| 현 게이트: cmd_build leg-B는 Linux 3종만(`:3541`), cmd_run_user_direct도 Linux만(`:4546-4548`) — darwin은 무조건 hexat→.c→clang | `self/main.hexa:3541, 4546-4548` |
| ※ 요청문의 "cmd_run(:4548)"의 실체는 **`cmd_run_user_direct`**(`:4463`, 유저 `hexa run` 디스패치 `:575`/`:7258`). 별도의 `cmd_run`(`:4803`)은 native leg 없이 내부 `hexa build` subprocess로 위임하므로 **cmd_build 게이트가 자동 커버** | `self/main.hexa:4803+` grep |
| tool/hexa_ld.hexa(darwin own-link)는 scaffold 이상 — .a pull-all(`:479, 2566-2569`)·chained fixups·GOT_LOAD·LC_MAIN·ad-hoc codesign까지 구현. 단 fixture 스케일만 RUN-verified | `tool/hexa_ld.hexa:1-50, 2504-2569` |

## 1. darwin ld64 clang-free 링크 레시피

**엔트리 규약 (linux own-start와의 차이)**: darwin은 crt1.o가 애초에 없고 own `_start`도 안 씁니다. ld64가 `MH_EXECUTE`에 `LC_MAIN(entryoff→_main)`을 합성하고, `LC_LOAD_DYLINKER=/usr/lib/dyld`는 ld64가 자동 삽입 — dyld+libSystem이 프로세스 초기화(및 runtime.a 멤버의 initializer 실행)를 담당합니다. 즉 **linux의 crt-keep 레그와 구조적 동형**(glibc `_start`→main 역할을 dyld/libSystem이 대신)이고, **crt-drop/own-start nm-probe(`:3560`, `:4660`)는 darwin arm에서 통째로 skip**해야 합니다. aprime이 낸 .o는 clang byte-eq 검증을 통과한 물건이라 `_main` 및 `_rt_*`/`_hexa_*` 심볼이 전부 Mach-O underscore 규약 — clang이 컴파일한 runtime.a 멤버와 그대로 정합합니다.

레시피 (in-tree `:1218` 검증 전례 + runtime.a만 추가):

```sh
SDK=$(xcrun --show-sdk-path 2>/dev/null)
ld -o <out> <obj> <runtime.a> -lSystem -syslibroot "$SDK" -arch arm64 -e _main
```

- **`-lSystem` 하나로 끝** — darwin에서 libc/libm/libpthread는 전부 libSystem 우산 아래라 linux의 `--start-group -lc -lpthread -lm --end-group`에 대응하는 추가 플래그 불요.
- `--dynamic-linker` 대응물 불요(자동), crt1/crti/crtn 불요, `-platform_version` 생략 가능(.o가 LC_BUILD_VERSION 보유 → ld64가 추론; `:1218` 레시피가 이 형태로 검증됨. 신형 ld에서 경고가 나오면 `-platform_version macos 12.0 $(xcrun --show-sdk-version)` 추가는 무해한 옵션).
- `xcrun`은 clang이 아닌 SDK 경로 프로브이고 in-tree에서 이미 sanctioned("L1 keeper", `:1214`). CLT 미설치로 SDK가 비면 → 링크 실패 → C-fallback (안전망이 흡수).
- **codesign**: arm64 macOS는 서명 필수. 신형 ld64는 자동 ad-hoc 서명하지만(추정 — 버전 의존), 기존 헬퍼 `codesign_if_macos()`(`self/main.hexa:2436`)를 mv 전에 호출해 native-backend 경로(`:3517`)와 동형으로 확정 처리.
- clang-0 판정: 위 커맨드에 cc/clang 개입 0. `ld`(ld64)는 linux leg-B의 binutils `ld`와 동렬의 시스템 링커 — 사용자 명시대로 허용이며 no-LLVM 불변식(자기 파이프라인의 backend/IR)과 무관.

## 2+3. self/main.hexa edit spec (정확 좌표 + 스케치)

**플래그: `HEXA_NATIVE_DARWIN=1` (단일 opt-in, default-OFF)** — build/run 두 레그를 하나로 게이트. 미설정 시 두 게이트 모두 기존 조건과 완전 동일하게 평가(darwin arm이 dead) → 기본 경로 byte-중립. darwin은 릴리스 필수 타깃 + mini 본인 호스트이므로 검증 전 default-ON 금지(§4의 flip 조건 충족 후 linux r26 전례처럼 flip). `HEXA_RUN_CTRANSPILE=1`은 계속 상위 opt-out.

### (A) cmd_build leg-B — `self/main.hexa:3541-3577`

`:3541` 게이트에 OR-arm 1개 추가, 본문에 darwin 분기:

```hexa
    // (:3541 게이트 — 기존 3-arm 뒤에 darwin opt-in arm 추가)
    if env_var("HEXA_BUILD_NATIVE") != "0" && ( ...기존 Linux 3종... ||
        (exec("uname -sm 2>/dev/null | tr -d ' \\n\\t'") == "Darwinarm64" && env_var("HEXA_NATIVE_DARWIN") == "1")
       ) && shared != "1" && c_only != "1" && len(target) == 0 && len(__actual_src) > 0 {
        let _bn_dar = exec("uname -sm 2>/dev/null | tr -d ' \\n\\t'") == "Darwinarm64"
        let _bn_arm = !_bn_dar && exec("uname -sm 2>/dev/null | tr -d ' \\n\\t'") != "Linuxx86_64"   // :3542 수정
        let mut _bntgt = if _bn_arm { "arm64-linux-gnu" } else { "x86_64-linux-gnu" }               // :3543
        if _bn_dar { _bntgt = "arm64-apple-darwin" }
        // _bncc/_bnrt/_bnld 해석(:3544-3546)은 무수정 — darwin에서도 command -v ld = /usr/bin/ld(ld64),
        // resolve_prebuilt_runtime()은 install.sh가 심은 Mach-O runtime.a를 그대로 돌려준다.
        ...
        // emit(:3550)은 무수정 — --target=arm64-apple-darwin이면 backend native가 default(:526-530).
        if _bnobj_ok == "yes" {
            if _bn_dar {
                // darwin 분기: crt/dl probe(:3553-3554)·own-start nm probe(:3560-3561) 전부 skip.
                let _bnsdk = exec("xcrun --show-sdk-path 2>/dev/null | tr -d '\\n'")
                let _bntmp = exec("printf '%s.bntmp.%s' '" + out + "' \"$$\"")
                let mut _bnsdkarg = ""
                if len(_bnsdk) > 0 { _bnsdkarg = " -syslibroot '" + _bnsdk + "'" }
                let _bnlnk = "'" + _bnld + "' -o '" + _bntmp + "' '" + _bnobj + "' '" + _bnrt + "' -lSystem" + _bnsdkarg + " -arch arm64 -e _main 2>&1"
                let _bnlr = exec(_bnlnk)
                let _bnbin_ok = exec("test -x '" + _bntmp + "' && printf yes || printf no")
                if _bnbin_ok == "yes" {
                    codesign_if_macos(_bntmp)                                    // :2436 헬퍼, :3517과 동형
                    let _ = exec("mv -f '" + _bntmp + "' '" + out + "' 2>/dev/null")
                    let _ = exec("rm -f '" + _bnobj + "' 2>/dev/null")
                    println("OK: built " + out + " (native backend, leg-B darwin — no hexat, no clang)")
                    return ""
                } else if env_var("HEXA_RUN_NATIVE_TRACE") == "1" { eprintln("[build-native] ld64 link failed → C fallback: " + _bnlr) }
            } else {
                ...기존 :3553-3573 linux 블록 문자 그대로...
            }
        }
        ...:3574-3576 trace/rm 무수정...
    }
```

핵심 불변: **모든 실패 경로(emit 실패·SDK 부재·ld64 실패·codesign 경고)는 기존 fallthrough 구조를 그대로 타고 `:3582` hexat→C-transpile로 내려감** — return은 `test -x` 성공시에만.

### (B) cmd_run_user_direct leg-B — `self/main.hexa:4546-4675`

- `:4547-4548` 호스트 게이트:
  ```hexa
  let _run_native_dar = _run_native_host == "Darwin arm64" && env_var("HEXA_NATIVE_DARWIN") == "1"
  let _run_native_on = (_run_native_host == "Linux x86_64" || _run_native_arm || _run_native_dar) && env("HEXA_RUN_CTRANSPILE") != "1"
  ```
- `:4569` `HEXA_LINK_HEXA` own-link 블록: **무수정** (`Linux x86_64` 조건이 이미 darwin 배제 — own-link darwin은 별도 rung).
- `:4630` 타깃 선택: `_ntgt`에 darwin arm 추가 (`if _run_native_dar { "arm64-apple-darwin" }`).
- `:4645` 이후 링크 스테이지: `if _run_native_dar { ld64 분기 } else { 기존 :4648-4670 crt-probe 블록 무수정 }` — ld64 분기는 (A)와 동일 커맨드(`_nobj`+`_nrt`→`_nbin`), 성공 시 `codesign_if_macos(_nbin)` 후 `:4667` 동형의 `mv -f`로 tmpbin 슬롯에 atomic-rename, 실패 시 trace 후 기존 clang `hexa build` 루프(`:4676`)로 fallthrough.
- flatten 로직(`:4618-4628`)·cleanup(`:4673`)은 아치 무관이라 무수정.
- `cmd_run`(`:4803`)은 내부 `hexa build` 위임이므로 (A)가 커버 — 별도 edit 불요.

**옵션 하드닝(권장)**: darwin arm에서 runtime.a Mach-O 지문 probe — `nm '<rt>' | grep -qE ' T _rt_' && printf yes || printf no` (Mach-O는 underscore, ELF 아카이브가 잘못 잡히면 no → leg skip). linux own-start probe(`:3560`)와 같은 관용구라 스타일 정합. 없어도 ld64 실패→fallback으로 안전하지만, 확정 실패 링크의 낭비를 줄임. (기존 `exec()` 내 `grep -q… && printf` 패턴은 pipefail 셸이 아니라 SIGPIPE-141 반전 이슈 없음 — 기존 2사이트와 동일.)

## 4. 검증 게이트 + flip 조건

darwin arm64 실측 호스트 = **ghost(darwin-arm64)** 우선, mini는 git/gh(표준 롤 유지 — 단 darwin 로컬 byteeq 전례상 mini 스모크 관찰은 가능).

1. **G1 기능 (flag ON)**: ghost에서 `HEXA_NATIVE_DARWIN=1 HEXA_RUN_NATIVE_TRACE=1`로 leg-B 12-construct 코퍼스 + r9-r25에서 쓴 361-corpus audit 재사용 — `hexa build`/`run` rc0 + stdout parity(vs flag-OFF C경로) + native-serve율([build-native]/[run-native] 로그 카운트) 캡처. 서명 검증 `codesign -v` rc0 포함.
2. **G2 byte-중립 (flag unset)**: byteeq-real gen3≡gen4 (darwin local + PR CI 3-target byteeq GREEN). default 경로 산출물 char-identical이 주장이므로 이 게이트가 본체.
3. **G3 shipping**: install.sh consumer smoke darwin — flag OFF에서 파손 0(기존 경로 무변), flag ON 재실행에서 native-serve 또는 안전 fallback 확인.
4. **flip(default-ON) 조건**: G1 코퍼스 parity 100%(native-serve 실패분은 전부 loud-fallback으로 C경로 rc0) + G2/G3 GREEN + mini dogfood 기간 무회귀 → linux r26 flip 전례처럼 opt-in을 opt-out(`HEXA_RUN_CTRANSPILE`/`HEXA_BUILD_NATIVE=0`)으로 승격. **"only darwin green" 단독 승격 금지** — 3-target byteeq GREEN 동반 필수.

## 5. 리스크 / 난이도

- **ld64 사용 정당성**: 정당. tool/hexa_ld.hexa는 scaffold보다 진척(아카이브 pull-all·chained fixups·LC_MAIN·codesign 구현)이지만 RUN-verified가 fixture 스케일뿐이고, pull-all 아카이브 의미론은 runtime.a 전체(수십 멤버)에서 dup-symbol/미지원 reloc 리스크가 미측정 — ld64의 selective member loading과 다름. **rung-1 = 시스템 ld64, own-link darwin(`--linker=hexa`, `compiler/main.hexa:1302-1316` 경유) = 별도 후속 rung**. ld64는 clang/cc 드라이버가 아니며 linux leg-B의 binutils ld와 거버넌스상 동형 — clang-0·no-LLVM 위반 없음.
- **emit 실패율 (최대 미지수)**: Mach-O writer의 byte-eq 코퍼스는 소형({trivial,fib,while,if}+P1)이지만, LIR-codegen이 proven arm64-linux와 공용이므로 미커버 표면은 Mach-O reloc/섹션 직렬화 계층으로 국한 — **추정** 중간 리스크. 실패 모드는 전부 loud-fallback(C경로) 커버라 사용자 파손 0. 실패율은 G1 코퍼스 audit에서 실측이 결론.
- **런타임 초기화**: darwin은 dyld가 runtime.a 멤버 initializer를 실행 — clang 링크 경로와 동일 아카이브·동일 메커니즘이라 동등 **추정**, G1 스모크가 확정.
- **24min doomed-emit 재발(#4483) 없음**: darwin arm은 host-native 타깃 emit(cross 아님)이고 opt-in — 기존 게이트 주석(`:4538-4545`)의 회귀 조건 자체가 성립 안 함.
- **runtime.a 부재/arch 불일치**: `resolve_prebuilt_runtime()==""`이면 leg no-op, 불일치면 link-fail→fallback(+옵션 nm 지문 가드). dev checkout에서 `build/runtime.a` 없으면 조용히 C경로 — trace 메시지로 관찰 가능.
- **난이도**: 소 — 수정 2블록(self/main.hexa), 신규 코드 ~40줄, 컴파일러/링커/러ntime 신규 구현 0. 리스크의 무게는 코드가 아니라 검증(G1 코퍼스 실측)에 있음.

**요약**: 부품(emit·ld64 레시피·runtime.a·codesign)은 전부 origin/main에 이미 존재하고, rung-1은 self/main.hexa의 두 게이트에 `HEXA_NATIVE_DARWIN=1` opt-in darwin arm을 잇는 배선 작업입니다. 안전망(전 실패→C-fallback)이 기존 구조 그대로 보존되므로 release-integrity 측면의 신규 노출은 flag-ON 사용자에 한정됩니다.