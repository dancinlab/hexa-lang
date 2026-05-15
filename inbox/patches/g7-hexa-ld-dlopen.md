# incoming patch: g7-hexa-ld-dlopen — RFC 초안

> **id**: `g7-hexa-ld-dlopen` · **opened**: 2026-05-10 · **status**: `spec` (RFC 초안 — 미land)
> **trees**: `self/` + `compiler/` (`hexa_ld`, codegen, runtime loader)
> **source**: wilson plugin 아키텍처 (`~/core/wilson/docs/plugin-interfaces-comms-aot-brainstorm.md` Part C 개정판) — in-process plugin 을 재컴파일 없이 추가하려면 동적 링킹 필요. 현재 `hexa_ld v1.1` 은 static only (ELF64 + Mach-O static).
> **why this matters**: wilson 의 in-process plugin (provider / tool / hook / view) 은 핫패스라 IPC 부적합 → 정적 링크돼야 함. dlopen 없으면 plugin 켜고 끄기 = `wilson` 재컴파일 (codegen + full relink, 수십초~분). dlopen 있으면 plugin = `.so`/`.dylib` 런타임 로드 (재컴파일 0). **단 — 없어도 wilson 은 동작 가능** (모든 디폴트 번들 plugin 을 `wilson build` 로 흡수 + G8 incremental link 으로 재빌드 단축). 그래서 우선순위 ★ (있으면 좋음, blocking 아님).

---

## 1. 동기

hexa-lang 의 새 컴파일러(`compiler/`)는 `hexa_ld` 자체 링커로 ELF64 + Mach-O **static** 바이너리만 emit. wilson 처럼 "core + N plugin" 구조를 가지려면:
- (현재 강제) 모든 in-proc plugin 을 한 정적 바이너리(`wilson`)에 static link. plugin 추가/제거/업데이트 = `wilson build` (full codegen + relink). plugin 켜고 끄기가 잦으면 비용 큼.
- (G7 가 열어주는 것) plugin = 동적 라이브러리(`.so` ELF / `.dylib` Mach-O), `wilson` 이 런타임에 `dlopen` + `dlsym("<plugin_id>_dispatch")` → plugin 추가 = `.so` 하나 떨구기, 재컴파일 0. (= pi-mono 의 jiti-loaded ESM extension 의 컴파일-언어 등가물.)

이건 hexa-lang 전반에 유용 (anima/nexus 도 모듈을 동적 로드하고 싶을 수 있음) — wilson-only 아님.

## 2. 현 상태

- `compiler/link/hexa_ld.hexa` (+ `hexa_ld_test.hexa`) — static linker. ELF64 + Mach-O static. relocation 처리, 심볼 resolve (static).
- `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` — position-dependent code (static 바이너리니까 `-fPIC` 불필요).
- runtime (`self/runtime.c`) — `dlopen`/`dlsym` 래퍼 없음 (확인 필요 — `c_ffi.hexa` 로 libc `dlopen` 호출은 가능할 수도. 그렇다면 부분 우회.)
- → 동적 링킹 = (a) codegen 이 PIC 코드 emit (b) `hexa_ld` 가 dynamic ELF/Mach-O (PLT/GOT, 동적 심볼 테이블) emit (c) runtime 이 `dlopen`/`dlsym` 노출 — 셋 다 신규.

## 3. 디자인 옵션

| 옵션 | 설명 | 채택? |
|---|---|---|
| **(a) 풀 dynamic ELF/Mach-O + libc dlopen** | codegen `-fPIC`, `hexa_ld` 가 `.so`/`.dylib` (PLT/GOT/dynsym) emit, runtime 이 libc `dlopen`/`dlsym` 호출. 표준 방식. plugin 의 transitive dep 은 host 바이너리의 export 심볼에 resolve (host 가 동적 심볼 export) — 작은 `.so`. | 정석이지만 가장 큰 작업 (PLT/GOT/dynsym 전부) |
| **(b) "fat .so" + 단일 심볼 컨벤션** | plugin 의 transitive dep 을 `.so` 안에 전부 static link (fat). `.so` 는 단 하나의 심볼 `<plugin_id>_dispatch` 만 export. host 가 `dlopen` + `dlsym("<id>_dispatch")`. host↔plugin ABI surface = 함수 1개 (`(action: ptr-to-string, payload: ptr-to-hexaval) -> ptr-to-hexaval` — hexaval nanbox 표현 공유). 작은 ABI, dynsym 최소. | ✅ **권장 1차** — ABI 표면 최소, dynsym 단순 |
| **(c) 커스텀 relocatable blob + 자체 로더** | libc `dlopen` 안 쓰고 `hexa_ld` 가 relocatable blob emit, runtime 이 `mmap` + 자체 relocation 적용 + 알려진 entry offset 호출. libc 의존 회피 (hexa runtime 이 비교적 self-contained). | 중간 작업, 더 큰 통제 — (b) 가 막히면 |
| **(d) 안 함 — G8 (incremental link) + busybox-multi-call 로 우회** | 동적 링킹 0. plugin 추가 = `wilson build --with X` (incremental relink — G8 가 빠르게). out-of-proc plugin 은 별 정적 바이너리 (또는 멀티-콜 `wilson` 의 다른 모드). dlopen UX (`.so` 떨구기)는 포기. | wilson MVP 엔 충분 — G7 은 후순위 사치 |

**추천**: 1차 = **(b) fat .so + 단일 `<id>_dispatch` 심볼 컨벤션** (또는 (d) 로 아예 미루기). (a) 풀 dynamic 은 hexa-lang 이 다른 이유로 필요해질 때. (c) 는 libc-free 가 강제될 때.

## 4. (b) 안의 surface 스케치

**codegen**: `-fPIC` 등가 (position-independent) — `hexa cc --shared <plugin>.hexa -o <plugin>.so`. 모든 dep static link into `.so`. export = `<plugin_id>_dispatch` 만 (다른 심볼은 hidden/local).
**hexa_ld**: `--shared` 모드 — ELF: `ET_DYN`, `.dynsym`/`.dynstr` 에 export 심볼 1개, `.hash`/`.gnu.hash`, `DT_SONAME`. Mach-O: `MH_DYLIB`, export trie 에 심볼 1개. PLT/GOT 는 fat 라 (dep 가 안에 있어서) 최소 — 사실상 외부 참조 0 이면 PLT 불필요, GOT 도 자기 데이터만.
**runtime** (`self/runtime.c` 또는 `self/rt/`): `hexa_dlopen(path) -> handle` (libc `dlopen(path, RTLD_NOW|RTLD_LOCAL)`), `hexa_dlsym(handle, name) -> fn_ptr` (`dlsym`), `hexa_dlclose(handle)`. + hexaval ABI: plugin 의 `<id>_dispatch` 는 `HexaVal (*)(HexaVal action, HexaVal payload)` 시그니처 — nanbox 표현이 host 와 동일해야 (같은 runtime ABI 빌드).
**hexa surface** (stdlib 또는 self):
```hexa
// stdlib/dynlink.hexa (신규) — 동적 모듈 로드 (host 측)
pub fn dynlink_open(so_path: string) -> int          // handle id (0 = fail)
pub fn dynlink_call(handle: int, action: string, payload: any) -> any   // <id>_dispatch 호출
pub fn dynlink_close(handle: int) -> void
pub fn dynlink_last_error() -> string
```
wilson `core/loader.hexa` 가 plugin 의 `link: "dynamic"` 보면 `hexa cc --shared` 로 빌드 (or 미리 빌드된 `.so` fetch) → `dynlink_open` → `wilson_plugin_call` 이 `dynlink_call` 로 라우팅. (link: "static" 이면 static-link 흡수, "subprocess" 면 IPC.)

## 5. capability 문제 (동적 plugin)

static-link plugin 의 capability 는 컴파일타임에 바이너리에 고정 (codegen 이 `@capabilities` 합집합 검증). **동적 로드 plugin 은 그게 안 됨** — `.so` 가 무슨 capability 를 쓰는지 정적 보장 불가. 대응:
- (1) `.so` 헤더에 capability 매니페스트 임베드 (`hexa cc --shared` 가 `@plugin(capabilities=...)` 를 `.so` 의 별 섹션에 기록), host 가 `dlopen` 전 읽어 게이트.
- (2) 동적 plugin 은 sandbox 프로세스에서만 (= 사실상 subprocess 모델로 강등 — in-proc dynamic 의 의미가 약해짐).
- (3) trusted 동적 plugin 만 (디폴트 번들 + 서명된 것), untrusted 는 subprocess.
→ 권장: (1) `.so` 섹션에 capability 매니페스트 + host 게이트, untrusted 는 (3).

## 6. 단계 로드맵

| Phase | 산출물 | 전제 |
|---|---|---|
| G7-A | codegen `--shared` (PIC, export = `<id>_dispatch` 만) | codegen 변경 |
| G7-B | `hexa_ld --shared` (ET_DYN/MH_DYLIB, dynsym 1심볼) | A + linker 변경 |
| G7-C | runtime `hexa_dlopen/dlsym/dlclose` + `stdlib/dynlink.hexa` | B + runtime |
| G7-D | `.so` 에 capability 매니페스트 섹션 + host 게이트 | C |
| G7-E | wilson `core/loader.hexa` 가 `link:"dynamic"` plugin 지원 (wilson 쪽) | C/D |
| G7-F | Mach-O 패리티 (위 전부 Mach-O `.dylib` 도) | A-D |

## 7. 미해결

1. **libc `dlopen` 의존** — hexa runtime 이 얼마나 libc-free 인지? `dlopen`/`dlsym` 은 libc (`libdl`). 이미 `c_ffi.hexa` 로 libc 호출하면 OK; "no libc" 가 mandate 면 (c) 커스텀 로더.
2. **nanbox ABI 안정성** — host 와 `.so` 가 같은 hexa runtime 버전으로 빌드돼야 hexaval 표현 일치. 버전 mismatch → crash. `.so` 헤더에 runtime ABI 버전 기록 + host 가 체크.
3. **(d) 로 충분한가** — wilson 의 plugin 켜고 끄기가 정말 잦은가? 디폴트 번들이 안정적이면 `wilson build --with X` (G8 incremental, 수초) 로도 OK — 그럼 G7 불필요. wilson 운영 데이터 보고 결정.
4. **`hexa_ld` 가 dynamic ELF 를 emit 한 적 없음** — PLT/GOT/dynsym/relocation type (R_X86_64_GLOB_DAT, R_X86_64_JUMP_SLOT 등) 전부 신규. 작업량 큼 — (b) fat 라도 dynsym/hash 섹션은 필요.

## 8. 한 줄

`hexa_ld` 가 static only → wilson in-proc plugin = 재컴파일 흡수 강제. G7 = `hexa cc --shared` (PIC, export = `<id>_dispatch` 1심볼 fat `.so`) + `hexa_ld --shared` (ET_DYN/MH_DYLIB) + runtime `hexa_dlopen/dlsym` + `.so` 헤더 capability 매니페스트. 권장 (b) fat .so + 단일 심볼 컨벤션. **단 — (d) "안 하고 G8 incremental link 으로 우회" 도 valid** — wilson MVP 엔 충분, G7 은 plugin 켜고 끄기가 잦다고 측정되면.
