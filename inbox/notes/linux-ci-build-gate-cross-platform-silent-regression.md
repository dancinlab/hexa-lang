# Linux CI 빌드 게이트 + forge/farr32 codegen smoke — cross-platform 사일런트 회귀 방지

- **kind**: notes
- **filed**: 2026-05-26
- **relates**: #1187 (farr32 codegen), #1194 (hxlcl_nanosleep), #1198 (linux #elif parity), #1172 (spawn.h)

## 사건 — 5-fire 캐스케이드

anima forge d768 GPU fire(`tool/dispatch_runpod_agtape_d768.sh`)를 V=151643(real Qwen BPE)로
A100 에 발사하니, Linux x86_64 빌드가 **계층별로** 깨졌고 fire 마다 다음 층이 드러났다:

| fire | 블로커 | 위치 | fix |
|---|---|---|---|
| 1-3 | `farr32_*` 가 bare 방출(undeclared) + 프로토타입 없음 | codegen.hexa / runtime.h | #1187 |
| 4 | `HXLCL_SYS_SELECT` Apple-arm64 전용 | runtime.c `hxlcl_nanosleep` | #1194 |
| 5 | `hxlcl_mkdir/longjmp/backtrace/getuid` Apple-only | runtime.c raw-trap 블록 | #1198 (별도) |

5번째에 build LINK 클린 → V=151643 모델이 A100 에 로드/실행(`model size 151071744 doubles`).

## 근본 원인 — "Mac 에서 초록불" 사일런트 킬러

세 가지가 겹쳐 **머지 전까지 전혀 안 보였다**:

```
 ① 개발·CI 가 전부 Mac(Apple-arm64)
    → runtime.c 의 #if (__arm64__||__aarch64__) && __APPLE__ 분기만 컴파일
    → Linux #else/#elif 갭은 영영 안 빌드됨 (Apple-only 드리프트 무한 누적)

 ② `hexa check` = parse/lint 만 (codegen→clang 안 함)
    → transpiler 가 farr32_* 를 bare 로 방출해도 check 는 초록불
    → 에러는 codegenned C 를 clang 할 때만 나옴 = 실제 빌드에서만

 ③ farr32(FP32 forge) 경로는 희귀 — 일반 hexa 코드는 farr_*(FP64)/무-farr
    → 일상 빌드·테스트가 farr32 emit 을 절대 안 건드림
```

**LSP 는 못 잡는다**: LSP 는 `.hexa` *소스* 진단. 이 버그는 ①transpiler 출력(codegen) ②C 런타임
포팅 — 둘 다 소스 아래 층이라 LSP 사정권 밖.

## 제안 (레버리지 순)

### 🥇 1. Linux CI 빌드 게이트
PR 마다 x86_64 Linux(GitHub Actions `ubuntu-latest` 또는 pool `ubu-1/ubu-2`)에서
`runtime.c` + 대표 forge 프로그램을 **실제 clang 컴파일**(`-DHEXA_CUDA` 없이도 hxlcl_*/포팅 갭은
잡힘). Apple-only 회귀를 머지 전 차단. #1198 제목("unblocks all linux hexa builds")이 곧
*이 게이트가 없었다*는 증거. **침묵의 근본원인을 끊는 단일 최고 수단.**

### 🥈 2. forge/farr32 codegen → clang smoke
`farr32_*` 를 쓰는 최소 `.hexa` 1개를 `hexa build --c-only` 로 codegen + 그 C 를 clang `-fsyntax-only`.
방출 갭(bare `farr32_zeros` 등)을 잡음. 1번 게이트의 forge-특화 보강.

### 🥉 3. (선택) `hexa check --compile`
lint 너머 codegen+컴파일 패스. 무겁지만 ①②를 로컬에서도 재현.

## 효과
1번만 있어도 이번 캐스케이드(farr32 + hxlcl_* + HXLCL_SYS_SELECT)가 **각자의 PR 에서 즉시
red** 였을 것 — 5 fire(~$2.5) 대신 0 fire. cross-platform CI matrix 가 표준 처방.
