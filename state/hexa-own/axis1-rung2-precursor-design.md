# axis-① rung-2 실효화 先決 설계 (/abg wf_0062ae70·2026-07-11)

★핵심: 3-target runtime.a는 CI가 매 릴리스 이미 빌드(stage_precompile_package)—크로스조립 불필요·arch-태그 asset 노출+install.sh opt-in pull+_resolve_target_runtime_a 헬퍼가 설계.

## rung2-crossarch-pkg

origin/main 정독 완료(코드 인용은 전부 origin/main `29f38d1ad` 계열 기준). rung-2 cross-target runtime.a **배포** 설계를 4-파트로 낸다. 측정 불가 항목은 "추정" 표기(mini=read-only, 실빌드는 pool).

---

# rung-2 cross-target runtime.a 배포 설계

## 0. 핵심 발견 — 타깃-arch runtime.a는 "빌드"가 아니라 "이미 존재하는 asset의 재배치" 문제다

정독 결과 **3-target arch-matched runtime.a는 이미 CI가 매 릴리스마다 만든다.** 새로 빌드할 게 없다.

- `tool/stage_precompile_package:44-72` — 각 릴리스 job이 `build/runtime.a`(그 job의 네이티브 arch)를 tarball의 `hexa-<target>/build/runtime.a`로 **이미 패키징**한다.
- `release.yml`의 3 job(`release-macos-arm64` :138 · `release-linux-x86_64` :305 · `release-linux-arm64` :373)은 각각 **네이티브 러너**(macos-latest / ubuntu-latest / ubuntu-24.04-arm)에서 `tool/release_build`(:8 Stage 0b `stage_resolve_runtime_a`→`build/runtime.a`)를 돌린다. 즉 x86_64-linux runtime.a는 x86_64-linux 러너가, arm64는 arm64 러너가 네이티브로 이미 뽑고 있다.

**결론: 크로스-호스트 "runtime.a 조립"(darwin에서 x86_64-linux용 C 크로스컴파일)은 하지 않는다.** 그건 크로스-clang+linux 헤더가 필요해 무겁고 불필요하다. 진짜 배포 설계 = **CI가 각 타깃에서 네이티브로 만든 runtime.a를 arch-태그된 asset으로 노출 → install.sh가 opt-in으로 pull → 소비처가 arch-검증 후 own-start-ar에 넘김.**

---

## (a) 타깃별 runtime.a 배포 방안

### A-1. release.yml — 경량 standalone asset 노출 (권장)

현재 각 job은 `files: hexa-<target>.tar.gz`만 업로드한다(`release.yml:300/368` 등). tarball 안 `build/runtime.a`는 접근하려면 수십MB tarball 전체를 받아야 함. runtime.a는 소형(추정 ~200KB–1MB: emitted-C ~5.5kLOC + `self/native/*.s` 시드)이므로 **전용 asset**이 대역폭·명료성 면에서 낫다.

각 릴리스 job의 Package 스텝 뒤에 arch-태그 복사 + 업로드 1줄 추가:

```yaml
# (각 job, release_package 뒤)
- name: Stage cross-consumable runtime.a asset
  run: cp build/runtime.a "runtime-${TARGET}.a"    # TARGET = darwin-arm64 | linux-x86_64 | linux-arm64
- name: Upload to GitHub Release
  with:
    files: |
      hexa-${TARGET}.tar.gz
      runtime-${TARGET}.a       # ← 신규 라인
```

`finalize` all-3-green 게이트(`release.yml:291-296`)를 그대로 상속하므로 **부분 릴리스(2/3)에서 cross runtime.a가 Latest로 새지 않음** — release-integrity 불변.

### A-2. install.sh — opt-in cross pull

`install_hexa`가 host tarball만 받는 현행(`install.sh:161-227`)에 **cross-target 루프**를 추가. default-OFF(env opt-in), 규약 = `<hxroot>/build/runtime.<aprime-triple>.a`.

```sh
# install_hexa 끝(build/ 복사 뒤, install.sh:283 근처) 신규 블록.
# opt-in: HEXA_CROSS_RUNTIME="linux-x86_64" (공백구분 다중 허용). 비지정=no-op.
for _xt in ${HEXA_CROSS_RUNTIME:-}; do
    [ "$_xt" = "$target" ] && continue           # host는 이미 있음
    _xtriple="$(_aprime_triple "$_xt")"          # linux-x86_64 → x86_64-linux-gnu
    [ -n "$_xtriple" ] || { dim "  ⚠ unknown cross target: $_xt"; continue; }
    _xurl="$(_asset_url "runtime-${_xt}")"
    if curl -fsSL "$_xurl" -o "$HX_BIN/build/runtime.${_xtriple}.a"; then
        # arch-검증(아래 (c)와 동일 magic 체크) — 실패 시 삭제
        if _verify_runtime_arch "$HX_BIN/build/runtime.${_xtriple}.a" "$_xtriple"; then
            green "  ✓ cross runtime.a → build/runtime.${_xtriple}.a"
        else
            red "  ⚠ runtime-${_xt}.a arch-mismatch → discarded"; rm -f "$HX_BIN/build/runtime.${_xtriple}.a"
        fi
    else
        dim "  ⚠ runtime-${_xt}.a not published (supplementary) → cross build will zig-cc fallback"
    fi
done
```

`_aprime_triple`(신규 install.sh 헬퍼): `linux-x86_64→x86_64-linux-gnu` · `linux-arm64→arm64-linux-gnu` · `darwin-arm64→arm64-apple-darwin`. rung-2에서 실효는 `x86_64-linux-gnu` 하나(나머지는 소비처 게이트 미통과, fanout doc §2).

**중요 — asset이 없어도 install은 성공**해야 함(supplementary 폴백 패턴, install.sh:197-204 musl/cuda와 동형). 없으면 소비처가 조용히 zig cc로 전락 → shipping 무파손.

### A-3. 무-release-변경 interim (선택)

release.yml 손 못 대는 상황이면: install.sh가 cross target의 **full tarball**(`hexa-<xt>.tar.gz`)을 받아 `tar -xzf … hexa-<xt>/build/runtime.a`만 추출→`build/runtime.<triple>.a`로 rename. 대역폭 낭비(수십MB)뿐 기능 동일. A-1이 landing되면 폐기.

---

## (b) stage_resolve_runtime_a 타깃arch 조립 확장 spec

`tool/stage_resolve_runtime_a`(3525줄)를 정독한 판정: **이 스크립트는 크로스-조립을 하지 않아야 한다.** 근거:

- 이 도구는 `CC`(=clang/gcc)로 `self/runtime.c`(+18 seed TU) + `self/native/{array,map}_core_*.s`를 **호스트 arch로** 컴파일/어셈블해 `build/runtime.a`를 만든다(헤더 주석 + release_build:8). darwin 호스트에서 x86_64-linux용을 뽑으려면 크로스-clang+glibc 헤더+x86_64 as가 필요 — install-time에 요구하는 건 packaging-defect 급 부담이고, `self/native/*.s`는 arch-고정 어셈블리라 크로스 어셈블도 별개 as 툴체인 필요.

따라서 확장은 **"조립"이 아니라 "arch-태깅 + 방출"** 최소 변경:

**Edit B-1 — 빌드 완료 후 arch-태그 사본 방출** (스크립트 말미, `build/runtime.a` 확정 직후):
```sh
# cross-consumable: TARGET(release.yml env) 지정 시 arch-triple 이름 사본을 남긴다.
# release_package/upload는 이 이름을 standalone asset(runtime-<TARGET>.a)으로 집어간다.
if [ -n "${TARGET:-}" ]; then
    case "$TARGET" in
      linux-x86_64) _tri=x86_64-linux-gnu ;;
      linux-arm64)  _tri=arm64-linux-gnu ;;
      darwin-arm64) _tri=arm64-apple-darwin ;;
      *) _tri="" ;;
    esac
    [ -n "$_tri" ] && cp -f build/runtime.a "build/runtime.${_tri}.a"
fi
```

**Edit B-2 — self-verification anti-vacuous 가드** (방출 직후, silent wrong-arch 방지):
```sh
# 방출한 runtime.a가 실제로 TARGET arch의 오브젝트를 담는지 magic 검증(빈/오염 archive 조기 FATAL).
if [ -n "${_tri:-}" ]; then
    _mem="$(ar t build/runtime.a 2>/dev/null | head -1)"
    _sig="$(ar p build/runtime.a "$_mem" 2>/dev/null | od -An -tx1 -N20)"
    # ELF64 x86_64: 7f 45 4c 46 02 … e_machine=3e 00 (bytes 18-19)
    # Mach-O arm64: cf fa ed fe (MH_MAGIC_64 LE) + cputype 0100000c
    case "$_tri" in
      x86_64-linux-gnu) echo "$_sig" | grep -q '7f 45 4c 46 02' && echo "$_sig" | grep -q ' 3e 00' || { echo "[stage_resolve] FATAL: build/runtime.a not ELF64-x86_64"; exit 2; } ;;
      arm64-linux-gnu)  echo "$_sig" | grep -q '7f 45 4c 46 02' && echo "$_sig" | grep -q ' b7 00' || { echo "[stage_resolve] FATAL"; exit 2; } ;;
      arm64-apple-darwin) echo "$_sig" | grep -q 'cf fa ed fe' || { echo "[stage_resolve] FATAL"; exit 2; } ;;
    esac
fi
```

이 검증은 **네이티브 러너에서만** 돌므로 항상 arch-match(sanity check 성격). 진짜 cross-arch 검증은 소비 측 (c)에서 한다.

규모: ~25줄. `HEXA_RT_MULTIOBJ`(release_build:57 include-drop 스플릿) 경로와 무충돌(사본 뜨기만 함).

---

## (c) self/main.hexa `_resolve_target_runtime_a(aprime_tgt)` edit spec

**신규 fn** — `resolve_prebuilt_runtime()`(`self/main.hexa:1673`) 바로 뒤 삽입. `resolve_hxroot()`(`:1630`) 재사용.

```
// axis-① rung-2: cross-target용 arch-매치 runtime.a 리졸버.
// resolve_prebuilt_runtime()은 host-arch 1개만 돌려주므로(shim이
// HEXA_PREBUILT_RUNTIME을 host runtime.a로 강제, install.sh:276) cross에는
// 못 씀 — 오히려 그 env가 wrong-arch trap이다. 여기서 arch-태그 archive를
// 명시 리졸브하고 ELF-class magic으로 검증한 것만 돌려준다. 실패=""(호출처는
// zig cc 폴백 → release-safe).
fn _resolve_target_runtime_a(aprime_tgt) {
    // 1) 명시 env override (arch별)
    let mut _p = ""
    if aprime_tgt == "x86_64-linux-gnu" { _p = env("HEXA_PREBUILT_RUNTIME_X86_64_LINUX") }
    // (arm64-linux/darwin cross는 rung-2 게이트 미통과 — 확장 여지만 남김)
    if len(_p) > 0 && file_exists(_p) {
        if _runtime_a_arch_ok(_p, aprime_tgt) { return _p }
        return ""
    }
    // 2) <hxroot>/build/runtime.<triple>.a 규약
    let __root = resolve_hxroot()
    if len(__root) > 0 {
        let __ra = __root + "/build/runtime." + aprime_tgt + ".a"
        if file_exists(__ra) && _runtime_a_arch_ok(__ra, aprime_tgt) { return __ra }
    }
    return ""
}

// archive 첫 멤버 오브젝트의 magic으로 arch 검증. darwin host에는 ELF nm이
// 없을 수 있으므로 od(1) magic-byte 검사만 사용(툴체인-무관).
fn _runtime_a_arch_ok(ra, aprime_tgt) {
    let _mem = exec("ar t '" + ra + "' 2>/dev/null | head -1 | tr -d '\\n'")
    if len(_mem) == 0 { return false }
    let _sig = exec("ar p '" + ra + "' '" + _mem + "' 2>/dev/null | od -An -tx1 -N20 | tr -s ' '")
    if aprime_tgt == "x86_64-linux-gnu" {
        // ELF64(7f454c46 02) + e_machine=0x3e(LE bytes 18-19 = "3e 00")
        let _elf = exec("printf '%s' \"" + _sig + "\" | grep -c '7f 45 4c 46 02'")
        let _m   = exec("printf '%s' \"" + _sig + "\" | grep -c ' 3e 00'")
        if _elf == "1" && _m == "1" { return true }
    }
    return false
}
```

그리고 fanout §4의 cross 블록(`self/main.hexa:3604` leg-B 뒤)에서 `_resolve_target_runtime_a("x86_64-linux-gnu")`를 호출해 얻은 `_xrt`를 **`HEXA_PREBUILT_RUNTIME='" + _xrt + "'`로 aprime에 넘긴다** — 이게 결정적으로 중요하다:

> **shim trap**: `install.sh:276-277`의 `$HX_BIN/hexa` shim은 `HEXA_PREBUILT_RUNTIME`을 **host-arch** `build/runtime.a`로 무조건 export한다. cross 빌드에서 aprime의 own-start-ar 경로(`compiler/main.hexa:1266-1278`)는 `HEXA_PREBUILT_RUNTIME`을 **1순위**로 읽으므로, override 안 하면 darwin-arm64 Mach-O archive를 x86_64 ELF 링커에 먹여 `link_elf_x86_64_ownstart_ar`가 Mach-O 멤버를 ELF로 파싱→링크 실패(rc→`compiler/main.hexa:1294 exit(2)`). 따라서 cross leg은 반드시 env를 target archive로 **덮어써서** 자식 aprime에 넘겨야 한다. fanout §4 블록이 이미 그렇게 함(line 60) — 이 spec은 그 값의 출처를 arch-검증된 `_resolve_target_runtime_a`로 못박는 것.

주의: `compiler/main.hexa:1280-1289`의 **W1 fail-close `exit(3)`**는 "UND 있는데 runtime.a 없음"에서만 발화 — arch-mismatch 자체는 검출 안 함(그건 link 실패 rc→exit(2)). 그래서 arch 검증을 **소비 진입 전** self/main.hexa `_runtime_a_arch_ok`에서 하는 게 필수. 검증 실패 시 `""` 반환→cross 게이트 미통과→zig cc 폴백(release-safe).

---

## (d) release-integrity 리스크 · effort

### 리스크

| # | 리스크 | 심각도 | 완화 |
|---|---|---|---|
| R1 | cross runtime.a 부재 시 "코드는 있으나 대부분 폴백" (명목상 clang-0, 실제 zig cc) | 中(실효성) | A-1 asset landing이 실효 게이트. 없으면 zig cc 폴백=회귀 0이지만 clang-0 소비처 차단은 명목뿐 |
| R2 | shim `HEXA_PREBUILT_RUNTIME` host-arch trap이 cross에 새면 wrong-arch 링크 | 高→해소 | (c) env override + `_runtime_a_arch_ok` magic 검증 2중 방어. 검증 실패=""→폴백 |
| R3 | wrong-arch archive가 W1 fail-close 우회해 exit(2) FATAL로 안전망 붕괴 | 中→해소 | 소비 진입 전 arch 검증→"" 반환으로 게이트 미통과. FATAL 도달 불가 |
| R4 | `finalize` 2/3에서 cross asset이 Latest로 샘 | 低 | all-3-green 게이트(release.yml:291) 상속 — prerelease로만 업로드, finalize가 3/3에서만 승격 |
| R5 | musl 소비자와 규약 충돌 | 低 | own-start static은 musl-static과 동형(fanout §4). `x86_64-linux-gnu` 단일 규약으로 흡수 |
| R6 | ING #82類 cuda runtime.a clobber | 低 | cross asset은 별도 파일명(`runtime.<triple>.a`)이라 host `build/runtime.a`(cuda 포함)와 경로 분리 — clobber 불가 |

**release-integrity 총평: 불변.** 전 경로 opt-in(`HEXA_CROSS_RUNTIME` install-time · `HEXA_BUILD_NATIVE_CROSS` build-time, fanout §4) default-OFF, 실패 시 zig cc 폴백, host build/byteeq/shipping 무영향. rung-1(`HEXA_NATIVE_DARWIN`) 안전망 패턴 동형.

### effort

- release.yml: 3 job × (cp 1줄 + upload 1줄) = 소. **낮음.**
- stage_resolve_runtime_a: arch-태그 방출 + self-verify ~25줄. **낮음.**
- install.sh: `_aprime_triple` + `_verify_runtime_arch` + cross-pull 루프 ~30줄. **낮음-중간.**
- self/main.hexa: `_resolve_target_runtime_a` + `_runtime_a_arch_ok` ~35줄(+ fanout §4 cross 블록 ~30줄이 이 두 fn 소비). **낮음-중간.**
- compiler/main.hexa: **무수정**(own-start-ar 경로 이미 존재).

### 검증(pool — mini read-only)
1. release.yml 변경 후 태그 → `runtime-linux-x86_64.a` asset 존재 + `od` magic=ELF64-x86_64 확인.
2. darwin-arm64 호스트: `HEXA_CROSS_RUNTIME=linux-x86_64` 재설치 → `~/.hx/bin/build/runtime.x86_64-linux-gnu.a` 드롭 + `_runtime_a_arch_ok` 통과 확인.
3. `HEXA_BUILD_NATIVE_CROSS=1 hexa build hello.hexa --target=linux-x86_64-glibc` → 산출물을 summer/aiden(x86_64-linux)서 rc-correct 실행 + `strace`로 clang/zig/ld execve 0(clang-0) 확인.
4. runtime.a 미배포/wrong-arch 주입 → 조용히 zig cc 폴백 rc0(회귀 0) 확인.

---

## 요약 한 줄

3-target arch-matched runtime.a는 **CI가 이미 tarball `build/runtime.a`로 생산** 중이므로(release.yml 3 native job → stage_precompile_package:44-72) 배포 설계 = **standalone asset 노출(release.yml +2줄/job) → install.sh opt-in pull(`build/runtime.<triple>.a` 규약) → self/main.hexa `_resolve_target_runtime_a`가 od-magic으로 arch-검증 후 `HEXA_PREBUILT_RUNTIME` override로 aprime own-start-ar에 주입**. 크로스-조립은 하지 않는다(불필요·클래정1 부담). 유일 高리스크(shim host-arch env trap, install.sh:276)는 env override + magic 검증 2중 방어로 해소. 전 경로 default-OFF + zig cc 폴백 → release-integrity 불변. effort 전반 낮음, 실효 게이트=release.yml asset landing.

관련 파일(절대경로): `/Users/mini/dancinlab/hexa-lang/.github/workflows/release.yml`(3 job upload :300/:368) · `/Users/mini/dancinlab/hexa-lang/tool/stage_precompile_package`(:44-72 tarball runtime.a) · `/Users/mini/dancinlab/hexa-lang/tool/stage_resolve_runtime_a`(host-arch 빌드) · `/Users/mini/dancinlab/hexa-lang/install.sh`(:161 install_hexa·:276 shim env trap·:561 stage_resolve 호출) · `/Users/mini/dancinlab/hexa-lang/self/main.hexa`(:1630 resolve_hxroot·:1673 resolve_prebuilt_runtime — 신규 fn 삽입점) · `/Users/mini/dancinlab/hexa-lang/compiler/main.hexa`(:1266 own-start-ar env 1순위·:1280 W1 fail-close exit(3)) · `/Users/mini/dancinlab/hexa-lang/state/hexa-own/axis1-rung2-fanout-results.md`(§2 실현성 매트릭스·§4 cross leg 블록).

(측정 없음 — runtime.a 크기·실행시간·arch-mismatch 실패모드는 origin/main 코드 정독 기반 추정.)

---

## rung2-shared-pic

조사 완료. origin/main(`607f19460`) 정독 기반으로 rung-2 `--shared` PIC runtime.a 설계를 낸다. (측정 미실행 항목은 "추정" 명시)

---

## 0. 핵심 정정 — "PIC runtime.a 재빌드 = clang-0 위반"은 오류

이전 fanout 스펙(state/hexa-own/axis1-rung2-fanout-results.md §4)이 "clang `-fPIC`로 runtime.a 재빌드는 clang-0 위반이라 불가"라 적었는데, **틀렸다.** 근거:

- 현행 runtime.a는 **이미 clang으로 빌드된다** — `tool/stage_resolve_runtime_a:3282`(Case-A) / `:3194·3199·3212`(Case-B)가 `$CC $CFLAGS -c self/runtime.c` (CC=clang/gcc)로 컴파일 후 `ar rcs`(`:3283·3254`). CLAUDE.md가 명시한 대로 이 ~5.5k-LOC emitted-C substrate는 **"reducible RUNTIME-PORT target"**(bootstrap frozen-dough)이지 clang-0 라인이 아니다.
- clang-0 불변식은 **app compile+link 드라이버 경로**(aprime `--emit=obj` → `ld`)를 지배한다. runtime.a는 `ld`가 소비하는 **prebuilt 아카이브 asset**(stdlib `.a`와 동급). exec 경로가 이미 clang-빌드 non-PIC runtime.a를 `ld`로 링크하는 것과 정확히 동형.
- 따라서 기존 clang 컴파일에 `-fPIC` 한 플래그를 더해 `runtime.pic.a`를 만드는 것은 **새 clang 의존을 app 경로에 넣는 게 아니다.** app 경로는 여전히 `aprime → ld -shared`로 clang 포크 0. clang-0 보존.

(진짜 fully-native PIC runtime = `tool/emit_runtime_obj.hexa`를 `--shared`로 확장해 aprime own-emit하는 것 — 단 현재 그 도구는 `_hexa_exit`/`_hexa_set_args` **2심볼만** 방출(`tool/emit_runtime_obj.hexa:7-14`), 5.5k-LOC 전체는 native-emit 불가 → 별개 far-future rung. 근시일 PIC runtime.a의 정답은 clang `-fPIC` 재빌드다.)

---

## 1. 현행 지형 (origin/main)

**Stage-1 (user obj PIC) — 이미 완성.** `compiler/codegen/x86_64_linux.hexa:36-72` 블록주석이 설계를 박제: call-site → `R_X86_64_PLT32`(cycle 30), extern/global 주소 → `R_X86_64_GOTPCREL`(shared mode, `:3026-3029` `mov scratch,[rip+g<id>@GOTPCREL]`), **default(non-shared) → `R_X86_64_64` 절대 reloc → `ld.so`가 REFUSE**(`:48-52`). arm64는 `8fdb29e2`가 adrp+GOT emit. 즉 `aprime --emit=obj --shared`는 PIC-clean obj를 낸다.

**Linux `.so`의 유일 벽 = non-PIC runtime.a.** `tool/stage_resolve_runtime_a:37` `CFLAGS="${CFLAGS_COMMON:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}"` — `-fPIC` 없음. `self/main.hexa:1380` `os_clang_cflags()`에도 없음. → x86_64 runtime.o의 `.text`가 `R_X86_64_32/32S` 절대 reloc을 실어 `ld -shared`가 `recompile with -fPIC`로 거부(추정, 미측정이나 x86_64 SysV code-model상 확정적). arm64-linux는 코드가 본질적 PC-rel(adrp/add)이라 통과 가능성 높음(추정). darwin arm64는 전 코드 PIC-default → runtime.a가 이미 position-independent.

---

## 2. (a) PIC runtime.a 빌드 방안

**권고 = 별도 변종 `build/runtime.pic.a` (default runtime.a는 byte-identical 유지).** `runtime.cuda.a`(`:3263·3291`) 선례와 동형 네이밍. default를 PIC로 뒤집으면 exec-path 전 바이트가 바뀌어 byteeq 레인이 churn → 금지.

**edit spec (tool/stage_resolve_runtime_a · `build_runtime_a_from_source`, `:1190~3311`)**:

1. 상단(`:37` CFLAGS 인근)에 토글:
   ```
   _pic_cflag=""; _ra_pic=""
   [ "${HEXA_RT_PIC:-0}" = "1" ] && { _pic_cflag="-fPIC"; _ra_pic="$ROOT/build/runtime.pic.a"; }
   ```
2. C-TU 컴파일 4곳에 `$_pic_cflag` 삽입 — Case-B `:3194`(runtime.o)·`:3199`(runtime_core.o)·`:3212`(hxlcl_shim.o), Case-A `:3282`(runtime.o). (예: `$CC $CFLAGS $_pic_cflag -D_FORTIFY_SOURCE=0 … -c self/runtime.c -o build/runtime_pic.o`)
3. `HEXA_RT_PIC=1`일 때 **추가 `ar`**로 `$_ra_pic` 방출 — Case-A `:3283` / Case-B `:3254` 직후에 PIC .o들을 `ar rcs "$_ra_pic" …`. (기존 `ar rcs "$RA"` 라인은 그대로 두어 non-PIC runtime.a byte-neutral 보존.)

효과 규모: ~15-25줄. 대안 = 독립 `tool/build_runtime_pic_a`(같은 컴파일 재현) — stage 스크립트 오염 최소화 원하면 이쪽.

**⚠️ 미해결 리스크(측정 필요) = native-seed .o.** runtime.a는 C-TU 외에 `self/native/*.s`에서 어셈블된 frozen 네이티브 seed(`str_core_native.o`·`num_float_core_native.o`·`float_parse_*` 등, `:566·639·694·749`)을 `ar`한다. 이 .s들은 **손으로 쓴 어셈블리**라 `-fPIC`가 무의미(clang은 순수 .s에 무시). 이들이 절대 reloc을 실으면 `-fPIC`로 C-TU를 고쳐도 `ld -shared`가 여전히 거부. → x86_64 seed .s의 PIC-safety가 **최상위 GO/NO-GO 측정항목**. NO-GO면 (i) shared 링크에서 native-seed 배제(느린 C-fallback rt_str 경로) 또는 (ii) seed .s를 RIP-rel로 재작성(별도 rung).

---

## 3. (b) aprime --emit=obj PIC 산출 + ld 링크 레시피

**Stage 1 — PIC relocatable obj (host-target, `--target` 미지정):**
```
aprime _drv.hexa --emit=obj --shared -o <stem>.shobj.o <src>.hexa
```
`--shared` → `compiler/main.hexa:485` `shared_flag=true` → `:963` `CodegenOptions{shared:1}` overlay → GOTPCREL/adrp-GOT emit gate. (cross `--shared --target`는 `self/main.hexa:~3681` `error: --shared is not yet supported with --target`로 아직 refuse → 근시일 shared는 **host-target 전용**.)

**Stage 2a — Linux `.so` (`ld -shared`):**
```
ld -shared -o <out> <shobj.o> <runtime.pic.a> \
   --start-group -lc -lpthread -lm --end-group \
   -soname <basename(out)> -L<crtdir> <crtdir>/crti.o <crtdir>/crtn.o
```
exec 경로 대비 차이: `crt1.o` **제거**(shared는 `_start` 불요), `--dynamic-linker` **제거**, own-start(`_bnzc`) 분기 **미적용**(entry 없음), `-soname` **추가**(DT_SONAME). crti.o/crtn.o는 runtime의 `.init_array`/`.init` framing 안전용 유지 권장(LOW).

**Stage 2b — Darwin `.dylib` (`ld -dylib`):**
```
ld -dylib -o <out> <shobj.o> <runtime.a> -lSystem -syslibroot <SDK> \
   -arch arm64 -install_name @rpath/<basename(out)>
```
exec(`self/main.hexa:3567`) 대비: `-dylib`(MH_DYLIB), `-e _main` **제거**, `-install_name`(LC_ID_DYLIB) **추가**. **darwin은 `runtime.pic.a` 불요** — 기존 runtime.a가 PIC-default. 링크 후 `codesign_if_macos()` 유지(arm64 dylib ad-hoc 서명 필수).

clang-0 불변식: `ld`/`ld64`=순수 링커, `xcrun --show-sdk-path`=경로 probe, `codesign`=sanctioned leaf → 보존.

---

## 4. (c) self/main.hexa cmd_build shared 분기 edit spec

release-integrity: 전 경로 **`HEXA_NATIVE_SHARED=1` opt-in·default-OFF**(rung-1 `HEXA_NATIVE_DARWIN` 동형). 어떤 emit/link 실패든 fall-through → 기존 C `-fPIC -shared` 경로(`:3738 _shared_cflags` → `:3842` clang link)가 온전한 안전망(shipping 무파손·byteeq 무영향).

**Edit A — leg-B 가드 (`self/main.hexa:3541`)**: `&& shared != "1"` →
```
&& (shared != "1" || env_var("HEXA_NATIVE_SHARED") == "1")
```
(나머지 조건 `c_only != "1" && len(target) == 0`은 **유지** — shared는 host-target 전용.)

**Edit B — aprime emit (`:3555` `_bne = exec("…--emit=obj --target=…")`)**: `--shared` 조건부 삽입
```
let mut _bnsh = ""
if shared == "1" { _bnsh = " --shared" }
// … "--emit=obj" + _bnsh + " --target=" + _bntgt + …
```

**Edit C — darwin 링크 (`_bn_dar` 분기, `:3567` `_bnlnk`)**: shared 분기
```
if shared == "1" {
  _bnlnk = "'"+_bnld+"' -dylib -o '"+_bntmp+"' '"+_bnobj+"' '"+_bnrt+"' -lSystem"+_bnsdkarg+" -arch arm64 -install_name '@rpath/"+basename(out)+"' 2>&1"
} else { /* 기존 -e _main */ }
```
성공체크(`:3568` `test -x`) → shared는 `test -e`(dylib 0644). `_bnrt = resolve_prebuilt_runtime()`(`:3550`) 그대로(darwin PIC-default).

**Edit D — linux 링크 (`else` 분기, `:3589` `_bnlnk`)**: PIC runtime 리졸버 + shared 서브분기. crt1/dynamic-linker/own-start 불요 → `if len(_bncrt)>0 && len(_bndl)>0`(`:3581`) 앞에 shared 서브분기를 두거나 가드를 `shared=="1" || (…)`로 완화:
```
let _bnrt_pic = _resolve_pic_runtime()          // 신규
if shared == "1" && len(_bnrt_pic) > 0 {
  _bnlnk = "'"+_bnld+"' -shared -o '"+_bntmp+"' '"+_bnobj+"' '"+_bnrt_pic+"' --start-group -lc -lpthread -lm --end-group -soname '"+basename(out)+"' -L'"+_bncrt+"' 2>&1"
  // test -e 로 성공체크
} else if shared != "1" { /* 기존 exec 링크 */ }
```
`runtime.pic.a` 부재 시 `_bnrt_pic==""` → 조용히 C `-fPIC -shared` 경로로 fall-through(release-safe).

**신규 fn `_resolve_pic_runtime()`** (`resolve_prebuilt_runtime` 인근 `:1698` 뒤):
```
HEXA_PREBUILT_RUNTIME_PIC 우선 → <hxroot>/build/runtime.pic.a → ""
// darwin이면 resolve_prebuilt_runtime() 재사용 가능(PIC-default)
```

규모: Edits A-D + 리졸버 = ~25-30줄. CHANGELOG.jsonl 동반 필요.

---

## 5. (d) PIC 오버헤드 · 리스크 · effort

**오버헤드(추정, 미측정)**:
- x86_64 `-fPIC`: GOT/PLT 간접 + 레지스터 예약 압박. 일반 코드 ~1-3%, 그러나 runtime.a는 대부분 syscall/alloc/glue라 compute 부담 작음 → 사실상 ~0-1% (추정).
- arm64-linux: 코드가 이미 PC-rel → ~0.
- darwin arm64: PIC-default → 0.

**리스크**:
| 항목 | 등급 | 근거 |
|---|---|---|
| **native-seed .s PIC-safety (x86_64)** | **HIGH·미측정** | frozen 어셈블리라 `-fPIC` 무효. 절대 reloc이면 `ld -shared` 여전히 거부. **GO/NO-GO 게이트.** |
| **packaging (installer runtime.pic.a 배포)** | HIGH | resolver가 `""` 반환 → 명목상만 clang-0, 실제 대부분 C-fallback. cross-target rung과 동일한 진짜 관문. |
| Linux runtime.o C-TU reloc | MED→해소(추정) | `-fPIC` C 재컴파일로 `.text` 절대 reloc 소거 |
| libc PLT (`-lc`) | LOW-MED·미측정 | user obj call=PLT32(`x86_64_linux.hexa:46`) → `.so` 안전 |
| byteeq churn | LOW(회피) | 별도 `runtime.pic.a` 변종·default runtime.a byte-identical |
| clang-0 | 없음 | §0 정정 — asset 빌드, app 경로 aprime→ld 유지 |
| darwin `.dylib` | LOW | runtime.a PIC-default·Edit C만 |

**effort**:
- tool/stage_resolve_runtime_a: ~15-25줄 (또는 독립 `tool/build_runtime_pic_a`).
- self/main.hexa: ~25-30줄 (Edits A-D + resolver).
- installer/pool packaging: **별도 rung**(runtime.pic.a 드롭) — 실효성의 진짜 관문.
- **darwin `.dylib`: LOW effort·LOW-MED risk → 먼저 착지 권장**(runtime.pic.a 벽 없음).
- **Linux `.so`: MED effort·MED-HIGH risk** — native-seed .s reloc 실측이 GO/NO-GO.

**검증(mini=read-only → pool)**: (1) x86_64 pod에서 `HEXA_RT_PIC=1 tool/stage_resolve_runtime_a` → `runtime.pic.a` 생성, `ld -shared user.shobj.o runtime.pic.a …` reloc smoke(★native-seed relocs GO/NO-GO). (2) darwin-arm64 host에서 `HEXA_NATIVE_SHARED=1 hexa build lib.hexa --shared -o lib.dylib` → `otool -l`로 MH_DYLIB+LC_ID_DYLIB+codesign 확인·`dlopen` load smoke. (3) 전 실패경로에서 C `-fPIC -shared` fallback rc0(회귀 0). (4) `strace`/execve 로그로 clang/as/zig 포크 0 확인.

**다음 라운드 이름**: `rung-2b-x86 = native-seed .s PIC-hardening` (x86_64 `ld -shared` reloc 실측이 게이트) · `rung-2c-pkg = installer runtime.pic.a 배포`.

---

관련 파일(절대경로):
- `/Users/mini/dancinlab/hexa-lang/tool/stage_resolve_runtime_a` — CFLAGS `:37`·Case-B 컴파일 `:3194·3199·3212`·Case-B ar `:3254`·Case-A `:3282-3283`·CUDA 변종 선례 `:3263·3291`
- `/Users/mini/dancinlab/hexa-lang/self/main.hexa` — leg-B 가드 `:3541`·emit `:3555`·darwin 링크 `:3567`·linux 링크 `:3589`·shared+target refuse `:~3681`·C `-fPIC -shared` 안전망 `:3738·3842`·`resolve_prebuilt_runtime` `:1673`·`os_clang_cflags` `:1380`
- `/Users/mini/dancinlab/hexa-lang/compiler/codegen/x86_64_linux.hexa` — PIC 설계 박제 `:36-72`·GOTPCREL emit `:3026-3029`
- `/Users/mini/dancinlab/hexa-lang/compiler/main.hexa` — `--shared` flag `:485`·CodegenOptions overlay `:963`
- `/Users/mini/dancinlab/hexa-lang/tool/emit_runtime_obj.hexa` — fully-native PIC runtime의 far-future 씨앗(현 2심볼)

(측정 없음 — 실행시간/reloc 판정은 origin/main 코드 정독 기반 추정. native-seed .s PIC-safety가 유일한 확정 미지수.)

---

## g1-ghost-harness

origin/main 정독 완료(`607f19460`). ghost(darwin-arm64)용 자기완결 native-serve 검증 하니스 설계를 낸다. 측정 미실행 항목은 "추정"으로 표기.

---

## 0. 코드 지형 확정 (origin/main = `607f19460`)

**leg-B darwin native path는 두 진입점 · 모두 opt-in `HEXA_NATIVE_DARWIN=1`:**

- **build leg-B** `self/main.hexa:3541` 게이트 = `HEXA_BUILD_NATIVE!=0 && (Linux… || (Darwinarm64 && HEXA_NATIVE_DARWIN==1)) && shared!="1" && c_only!="1" && len(target)==0 && len(__actual_src)>0`. darwin 분기(`:3559-3577`): `aprime_cc --emit=obj --target=arm64-apple-darwin` → **`ld -lSystem -syslibroot <SDK> -arch arm64 -e _main`**(ld64, crt/own-start 없음 — dyld+libSystem init) → `codesign_if_macos`(`:2436`, ad-hoc `--sign -`) → `mv`.
- **run leg-B** `self/main.hexa:4576` `_run_native_dar = "Darwin arm64" && HEXA_NATIVE_DARWIN==1`, `:4586` `_run_native_on = (…|_run_native_dar) && HEXA_RUN_CTRANSPILE!=1`. darwin 링크(`:4671-4685`): 동일 ld64 레시피 + codesign + cache-slot rename.

**성공/폴백 trace 문자열(전부 `eprintln`=stderr, `HEXA_RUN_NATIVE_TRACE=1`일 때만):**
- build 성공 `self/main.hexa:3574` `"[build-native] clang-free: aprime --emit=obj + ld64 → "`
- build 폴백 `:3577` `"[build-native] ld64 link failed → C fallback: "` · `:3601` `"[build-native] native-emit failed → C fallback: "`
- run 성공 `self/main.hexa:4682` `"[run-native] clang-free: aprime --emit=obj + ld64 → "`
- run 폴백 `:4684` `"[run-native] ld64 link failed → clang fallback: "` · `:4728` `"[run-native] native-emit failed → clang fallback: "`

**리졸버 계약(하니스가 만족시켜야 할 seam):**
- `resolve_native_cc()` `self/main.hexa:2645` → `$HEXA_APRIME_CC` → `<install>/build/aprime_cc` → `./build/aprime_cc` → `$HEXA_LANG/build/aprime_cc`.
- `resolve_prebuilt_runtime()` `self/main.hexa:1673` → `$HEXA_PREBUILT_RUNTIME` → `<hxroot>/build/runtime.a`. **darwin에선 arm64 Mach-O runtime.a 필수**(own-start 불요 — ld64가 LC_MAIN 합성).
- `_bnld/_nld = command -v ld` — darwin ld64 사용. `xcrun --show-sdk-path`로 SDK probe(컴파일 아님=clang-0 보존).

**빌드 레시피:** `aprime_cc` = `tool/build_aprime.sh -o build/aprime_cc`(5-stage: flatten→hexat→post→**clang -arch arm64**→smoke exit42). runtime.a = `tool/stage_resolve_runtime_a`(CC로 self/runtime.c 컴파일 후 `build/runtime.a`). **주의: 이 둘의 clang 사용은 bootstrap seed 빌드로 clang-0 불변식과 무관**(불변식은 `hexa build/run`의 emit+link **serve** path 한정 — 거기서 clang/cc 드라이버 0, 순수 ld64/codesign만).

**기존 darwin CI:** `.github/workflows/selfhost-native-build-gate.yml`이 ghost(darwin-arm64) 라우팅 패턴의 정본 — `pick-runner kind:darwin` + `RUNNER_PROBE_TOKEN`으로 ghost online 시 self-hosted, else macos-15 폴백. 단 이 게이트는 **gen3/hexa_ld/rt.o SLOT 경로**(`tool/selfhost_native_build_gate`)로 leg-B(`HEXA_NATIVE_DARWIN` aprime_cc+ld64)와 **다른 메커니즘**이다. 재사용할 것은 그 **corpus 내용**(`tool/selfhost_native_build_gate` 7-construct: arith/string/loop/userfn/cond/array/var)이지 SLOT 배관이 아니다.

**"12-construct/361-corpus"는 추적 단일파일 아님** — `self/main.hexa:4560-4562` 주석의 leg-B 캠페인 증명 corpus를 지칭. 하니스에선 (a) 7-construct 게이트 corpus를 12로 확장, (b) 361-corpus audit = 트리 내 기존 .hexa(stdlib selftest + `tool/*.hexa` + examples)를 OFF/ON 양경로 컴파일→stdout diff의 broad silent-differ audit으로 재현한다.

---

## 1. 하니스 파일 · 위치

`tool/ghost_darwin_native_serve_gate` (extension-less — 프로젝트 sidecar hook이 `.sh` Write/Edit 차단, `selfhost_native_build_gate` 선례). ghost에서 `bash tool/ghost_darwin_native_serve_gate` 단독 실행. mini=git/gh(read-only)이므로 실측은 ghost에서만.

---

## 2. 스크립트 스케치

```bash
#!/usr/bin/env bash
# tool/ghost_darwin_native_serve_gate — darwin-arm64 leg-B native-serve 검증
# (flip 전제). aprime_cc --emit=obj + ld64 -lSystem 경로(HEXA_NATIVE_DARWIN=1)의
#   (b) rc0  (c) native-serve율  (d) stdout parity  (e) codesign -v  를 측정.
# EXIT 0=flip-GREEN 후보 / 1=RED(parity 깨짐·silent-fallback·rc≠0) / 2=NEUTRAL(infra).
set -u
[ "$(uname -sm)" = "Darwin arm64" ] || { echo "NEUTRAL: not darwin-arm64"; exit 2; }

# ── (a) main clone + cc_native build ──────────────────────────────────
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
git clone --depth 1 https://github.com/dancinlab/hexa-lang "$WORK/repo" || exit 2
cd "$WORK/repo"
REV="$(git rev-parse HEAD)"; echo "== rev $REV =="
bash tool/build_aprime.sh -o build/aprime_cc || { echo "NEUTRAL: aprime_cc build fail"; exit 2; }
# runtime.a (darwin arm64 Mach-O). stage_resolve_runtime_a 레시피 재사용.
CC=clang CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE" \
  bash tool/stage_resolve_runtime_a || { echo "NEUTRAL: runtime.a fail"; exit 2; }
# resolver seam 충족: aprime_cc + runtime.a 를 명시 export
export HEXA_APRIME_CC="$PWD/build/aprime_cc"
export HEXA_PREBUILT_RUNTIME="$PWD/build/runtime.a"
HEXA="$PWD/hexa"   # 또는 promote 된 ~/.hx/bin/hexa (launcher)
command -v "$HEXA" >/dev/null || HEXA="$HOME/.hx/bin/hexa"
# runtime.a arch sanity (Mach-O arm64 아니면 링크 FATAL → NEUTRAL)
file "$HEXA_PREBUILT_RUNTIME" | grep -qi 'ar archive' || { echo "NEUTRAL: bad runtime.a"; exit 2; }

# ── 12-construct corpus (7 = selfhost_native_build_gate + 5 확장) ──────
names=(arith string loop userfn cond array var match struct enum nestcall recur)
srcs=(
 'fn main(){ let a=30; let b=12; print(to_string(a+b)); exit(0) }'
 'fn main(){ print("he"+"llo"); exit(0) }'
 'fn main(){ let mut s=0; let mut i=1; while i<=5 { s=s+i; i=i+1 }; print(to_string(s)); exit(0) }'
 'fn add(a:Int,b:Int)->Int{ return a+b } fn main(){ print(to_string(add(40,2))); exit(0) }'
 'fn main(){ let x=7; if x>5 { print("big") } else { print("small") }; exit(0) }'
 'fn main(){ let a=[10,20,30]; print(to_string(a[0]+a[2])); exit(0) }'
 'fn main(){ var x=41; x=x+1; print(to_string(x-1)); exit(0) }'
 # + match / struct / enum / nested-call / recursion (leg-B 캠페인 축)
 ...
)
exps=(42 hello 15 42 big 40 41 ...)

# ── (b)+(c)+(d)+(e) 코어 루프 ─────────────────────────────────────────
built_served=0; built_fb=0; run_served=0; run_fb=0
fail=0; parity_fail=0; sign_fail=0; N=${#names[@]}
for i in $(seq 0 $((N-1))); do
  n="${names[$i]}"; printf '%s\n' "${srcs[$i]}" > "$WORK/$n.hexa"; exp="${exps[$i]}"

  # (d-baseline) flag-OFF = C-transpile(clang) 경로 — HEXA_NATIVE_DARWIN 미설정
  env -u HEXA_NATIVE_DARWIN "$HEXA" build "$WORK/$n.hexa" -o "$WORK/$n.off" >/dev/null 2>&1
  off_out="$("$WORK/$n.off" 2>&1)"; off_rc=$?

  # (b)+(c) flag-ON = native ld64 경로, trace 캡처(stderr)
  HEXA_NATIVE_DARWIN=1 HEXA_RUN_NATIVE_TRACE=1 \
    "$HEXA" build "$WORK/$n.hexa" -o "$WORK/$n.on" 2>"$WORK/$n.btrace"
  on_out="$("$WORK/$n.on" 2>&1)"; on_rc=$?

  # (c) native-serve 판정: 성공 trace vs loud-fallback trace
  if grep -q '\[build-native\] clang-free: aprime --emit=obj + ld64' "$WORK/$n.btrace"; then
    built_served=$((built_served+1)); served=1
  elif grep -qE '\[build-native\] (ld64 link failed|native-emit failed) → C fallback' "$WORK/$n.btrace"; then
    built_fb=$((built_fb+1)); served=0    # LOUD fallback = 허용
  else
    served=0; echo "RED $n: SILENT fallback (no trace line)"; fail=$((fail+1))  # ← flip 차단
  fi

  # (b) rc0 정답
  [ "$on_rc" = 0 ] && [ "$on_out" = "$exp" ] || { echo "RED $n: on rc=$on_rc out=[$on_out] exp=[$exp]"; fail=$((fail+1)); }

  # (d) parity: OFF(C) vs ON(native) 동일 stdout+rc
  [ "$off_out" = "$on_out" ] && [ "$off_rc" = "$on_rc" ] || { echo "RED $n: PARITY off=[$off_out/$off_rc] on=[$on_out/$on_rc]"; parity_fail=$((parity_fail+1)); }

  # (e) codesign -v — native-served 산출물만
  if [ "$served" = 1 ]; then
    codesign -v "$WORK/$n.on" 2>/dev/null || { echo "RED $n: codesign -v fail"; sign_fail=$((sign_fail+1)); }
  fi

  # run-leg 동일 검증 (hexa run 경로)
  HEXA_NATIVE_DARWIN=1 HEXA_RUN_NATIVE_TRACE=1 "$HEXA" run "$WORK/$n.hexa" >"$WORK/$n.rout" 2>"$WORK/$n.rtrace"; r_rc=$?
  if grep -q '\[run-native\] clang-free: aprime --emit=obj + ld64' "$WORK/$n.rtrace"; then run_served=$((run_served+1));
  elif grep -qE '\[run-native\] (ld64 link failed|native-emit failed) → clang fallback' "$WORK/$n.rtrace"; then run_fb=$((run_fb+1));
  else echo "RED $n: run SILENT fallback"; fail=$((fail+1)); fi
  [ "$r_rc" = 0 ] || { echo "RED $n: run rc=$r_rc"; fail=$((fail+1)); }
done

# ── 361-corpus broad silent-differ audit (트리 기존 .hexa 재사용) ──────
# stdlib selftest + tool/*.hexa + examples 를 OFF vs ON 컴파일→stdout diff.
# (build-only 도 가능한 프로그램은 rc/aborts만 비교; main 없는 lib는 skip.)
audit_total=0; audit_differ=0
for f in $(git ls-files 'stdlib/**/*_selftest*.hexa' 'tool/*.hexa' 2>/dev/null); do
  grep -q 'fn main' "$f" || continue
  audit_total=$((audit_total+1))
  env -u HEXA_NATIVE_DARWIN "$HEXA" build "$f" -o "$WORK/a.off" 2>/dev/null && ao="$("$WORK/a.off" 2>&1)"; arc_o=$?
  HEXA_NATIVE_DARWIN=1 "$HEXA" build "$f" -o "$WORK/a.on" 2>/dev/null && an="$("$WORK/a.on" 2>&1)"; arc_n=$?
  [ "$ao" = "$an" ] && [ "$arc_o" = "$arc_n" ] || { audit_differ=$((audit_differ+1)); echo "DIFFER $f"; }
done

# ── 판정 ──────────────────────────────────────────────────────────────
echo "== corpus N=$N build-served=$built_served/$((built_served+built_fb)) run-served=$run_served =="
echo "== fail=$fail parity_fail=$parity_fail sign_fail=$sign_fail audit=$audit_total differ=$audit_differ =="
[ $fail = 0 ] && [ $parity_fail = 0 ] && [ $sign_fail = 0 ] && [ $audit_differ = 0 ] || exit 1
exit 0
```

---

## 3. 각 축 정확 기준 (요청 (a)-(f) 매핑)

- **(a) clone+build**: `git clone --depth 1` origin/main → `tool/build_aprime.sh`(aprime_cc) + `tool/stage_resolve_runtime_a`(darwin arm64 Mach-O runtime.a). 둘 다 실패=NEUTRAL(2)(infra, RED 아님). rev 기록 필수.
- **(b) rc0**: 12-construct 각각 `HEXA_NATIVE_DARWIN=1`로 build+run, `on_rc==0 && on_out==exp`. 실패=RED.
- **(c) native-serve율**: `[build-native]/[run-native] clang-free … ld64` 성공 trace = served. 나머지는 **반드시 loud-fallback trace**(`… → C/clang fallback`)여야 하며, **trace가 아예 없으면=SILENT fallback=RED**(flip 차단 — "조용히 clang으로 샜다"가 최악). served율 리포트하되 flip 기준은 "실패분=전부 loud-fallback + 그래도 rc0-정답".
- **(d) stdout parity**: flag-OFF baseline = `env -u HEXA_NATIVE_DARWIN`(C-transpile clang 경로, `self/main.hexa:3541` 게이트 미통과 → 하단 C-path). ON=native. `off_out==on_out && off_rc==on_rc`. run-leg OFF는 `HEXA_RUN_CTRANSPILE=1`로 강제 C. 불일치=RED. **byte-eq determinism 정신과 동형** — 산출물 동일이 flip 대전제.
- **(e) codesign -v**: native-served 산출물만 `codesign -v` rc0(ad-hoc 서명 무결). `codesign_if_macos`(`self/main.hexa:2436`)가 `--sign -` 하므로 서명 자체는 되어야 정상; `-v` 실패=RED.
- **(f) flip 판정기준(default-ON `self/main.hexa:3541`/`4576` 게이트에서 `&& HEXA_NATIVE_DARWIN=="1"` 제거)**:
  1. **parity 100%** (corpus + 361-audit differ=0),
  2. **native-serve 실패분=전부 loud-fallback**(silent=0)이고 그 폴백도 rc0-정답,
  3. **byteeq 3-target GREEN 동반** — mini에서 `gh`로 PR 열어 `selfhost-byteeq-gate.yml`+`selfhost-native-build-gate.yml`(darwin ghost)+linux x86_64/arm64 3-target GREEN 확인. **only-darwin-green 금지**(CLAUDE.md release-integrity: "never promote on only x86 green"의 대칭 — darwin만 GREEN으로 flip 불가),
  4. install.sh consumer smoke GREEN(canonical install path에서 `cuda_available`류 회귀 없음).

---

## 4. 함정 / 리스크

- **trace=stderr**: 성공 trace도 `eprintln`(stderr). 반드시 `2>trace` 캡처, `2>&1` 혼선 금지(프로그램 stdout과 섞이면 parity 오판).
- **build 게이트 `len(target)==0`** (`self/main.hexa:3541`): corpus build에 `--target` 절대 전달 금지(전달 시 leg-B 미발화 → 항상 C-path → served=0 오측).
- **runtime.a arch mismatch**: darwin에 x86_64 runtime.a가 잘못 오면 ld64 링크 실패→loud fallback으로 떨어져 served=0. `file`로 Mach-O arm64 사전검증, 아니면 NEUTRAL.
- **launcher vs raw hexa**: `resolve_native_cc/resolve_prebuilt_runtime`이 `install_dir_from_argv0()` 기반이라, ghost에서 promote된 `~/.hx/bin/hexa`를 쓰면 그 install 트리의 aprime_cc/runtime.a를 볼 수 있음. `HEXA_APRIME_CC`/`HEXA_PREBUILT_RUNTIME` **명시 export로 seam 고정**(clone 트리 것을 강제) — 안 하면 stale ~/.hx 산출물로 false 측정(MEMORY: stale-pool-hexat 함정).
- **361-audit 범위**: `fn main` 없는 lib .hexa는 skip(build-only는 rc만). stdlib selftest가 GPU/CUDA 의존이면 darwin에서 skip 처리 필요(false differ 방지).
- **SILENT-fallback 미검출 위험**: trace 문자열이 코드 변경으로 바뀌면 grep 미스→served 0으로 보이나 실은 정상. flip 게이트를 grep 문자열에 결속하므로, `self/main.hexa`의 6개 trace 리터럴(§0)과 **문자열 동기 유지**가 하니스 유지보수 포인트.

---

## 5. effort / 측정 위치

- **effort**: 낮음-중간. 신규 파일 1개(~150줄), 기존 `tool/selfhost_native_build_gate` corpus 로직 + `pick-runner`(darwin ghost 라우팅, `.github/workflows/selfhost-native-build-gate.yml` 정본) 재사용. CI 결선은 별도 rung(신규 `.github/workflows/darwin-native-serve-gate.yml` — dispatch→ghost→`bash tool/ghost_darwin_native_serve_gate`, exit2=neutral remap, sister-gate와 동형).
- **측정**: ghost(darwin arm64 selfhost)에서만. mini는 clone/gh/read-only. 실빌드·실행 전부 ghost.
- **관련 절대경로**: `self/main.hexa`(leg-B build `:3541-3604`·run `:4575-4730`·codesign `:2436`·resolver `:1673`/`:2645`), `tool/selfhost_native_build_gate`(corpus 정본), `tool/build_aprime.sh`, `tool/stage_resolve_runtime_a`, `.github/workflows/selfhost-native-build-gate.yml`(ghost 라우팅 정본), 설계 SSOT `state/hexa-own/axis1-rung2-fanout-results.md`(rung-2 인접 맥락).

(측정 없음 — 위 rc/serve율/parity 판정은 origin/main 코드 정독 기반 설계이며 ghost 실행으로 확정 필요.)

---

