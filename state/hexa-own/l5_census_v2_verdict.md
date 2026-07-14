# L5 census-v2 판정 — borrowck 레인의 신규 검출력 = 0 (측정)

계측기를 고친 뒤(#4941 `HEXA_BORROWCK_CENSUS_ALL`) 실코퍼스를 처음으로 **22/22 코드 전부** 관측했다.
결과는 "숨은 백로그" 가설을 반증한다.

## 계측기 근인 (수리 전)

`compiler/lower/hir_to_mir.hexa:1137` (코드줄 · 주석 아님):

```
fn _bck_diag_push(d: Diagnostic) {
    if _bck_warn_default {                     // B3 flip 이후 DEFAULT-ON
        if !_bck_warn_allowed(d.code) { return }   // ← 여기서 20개를 계산한 뒤 폐기
```

`_bck_warn_allowlist = ["HX3014", "HX3055"]` (`:567`). `_bck_diag_push` 호출 사이트는 **정확히 22개**.
즉 shipping band 하에서 돌린 모든 이전 L5 census 는 **"체커"가 아니라 "필터"를 측정**했다.

## 판별력 실증 (교훈: 알려진 파손에서 RED 가 떠야 한다)

rustc 교과서 borrow 오류 4종(E0502 · E0499 · E0503 · E0384) fixture 를 실제 빌드된 `./hexa` 로 두 band 컴파일:

| band | 결과 |
|---|---|
| 현행 census (`HEXA_BORROWCK_CENSUS=1`) | 발화 **0** = **BLIND (거짓 초록)** |
| census-v2 (`HEXA_BORROWCK_CENSUS_ALL=1`) | **RED: HX3021 · HX3028 · HX3027 · HX3045 전부 발화** |

⇒ 현행 계측기가 알려진 파손에서 초록을 낸다는 것을 실증했고, v2 는 같은 입력에서 RED 를 낸다.

## 실측 (summer · corpus = aprime_cc self-compile 클로저 + self/main.hexa · band 당 wall 86s)

| 코드 | 발화 |
|---|---|
| HX3055 | 1 (`compiler/emit/elf_arm64.hexa:2149`) — 기존 allowlist, 이미 보이던 것 |
| **HX3045** | **3** (`self/main.hexa:2570 exe` · `:4025 _cc_label` · `:4602 _sfx`) |
| 나머지 **19개** (HX3014·3019·3021·3023·3027·3028·3029·3031·3032·3034·3035·3036·3037·3038·3039·3040·3041·3042·3049·3052) | **0** |

⇒ 어둠 속 20개 코드의 실코퍼스 발화 총합 = **3건, 전부 HX3045**.

## ★ 판정 — 신규 검출력 = 0

그 HX3045 3건은 **전부 true positive 이지만, 전부 이미 잡히고 있는 줄이다.**

| 코드 | 제목 | stage | 상태 |
|---|---|---|---|
| HX3045 | cannot assign **twice to** immutable variable | S3 (borrowck · opt-in) | 3 site |
| **HX2006** | cannot assign to immutable binding | S2 | **always-on · 같은 3 site** |

같은 결함 클래스, 같은 줄, 그리고 HX2006 은 이미 기본 경로에서 켜져 있다. catalog 자신의 원칙
("one mistake = one diagnostic")에 비추면 HX3045 를 allowlist 에 올리는 것은 **중복 보고**다.

> **그러므로 borrowck 레인을 전부 켜도 shipping 코퍼스에 대한 신규 검출력은 0 이다.**

## 무엇이 벽인가 — 엔진이 아니라 연료

엔진은 진짜다(fixture 가 증명). 코퍼스가 연료를 안 준다:

- `&` / `&mut` / `@own` 채택 = **0줄** → loan/move 레인 19개가 **진짜로 0 발화**
- 힙이 회수를 안 한다(free = NO-OP) → 잡을 UAF 자체가 없다

⇒ **다음 rung 은 "체커 코드를 더 켜는 것" 이 아니다.** 그건 이미 측정으로 0 이 나왔다.
   진짜 축은 **코퍼스가 소유권 주석을 채택하게 만드는 것**(마이그레이션 캠페인)이고,
   그건 체커 rung 이 아니라 별개의 대형 축이다. 이 구분을 흐리면 filler round 가 된다.

## 부수 실측 (별건 프론티어로 분리)

코퍼스 컴파일은 emit 단계에서 **SIGILL(rc=132)** 로 죽어 `.o` 가 안 나온다. 단:

- borrowck 전부 OFF 대조군도 **동일하게** SIGILL → 선재 결함, borrowck 무관 (대조군으로 격리)
- `CG_PROFILE` 로 `lower_hir` 이 3330ms 완주 → mir_opt → codegen **뒤에** 죽는 것을 확인
- `_lr_diag` 드레인은 `lower_hir` 직후 → **census 는 완전히 배출된 뒤** 크래시 → 위 수치는 유효

별건: `self/main.hexa --emit=obj` emit-stage crash.

## 하니스가 스스로 잡은 거짓 초록 (교훈 박제)

1차 실행에서 `release_build` 가 rc=1 로 죽었는데(pool 함정 — 프로필이 export 한
`HEXA_PREBUILT_RUNTIME=~/.hx/bin/build/runtime.a` 가 CUDA 심볼 링크벽), 레포에 체크인된 3.4KB **래퍼
스크립트** `./hexa` 가 `-x` 라서 게이트를 통과했고 모든 band 가 조용히 0 을 냈다.
→ 게이트를 **"ELF magic + rc==0"** 으로 조이고 `HEXA_PREBUILT_RUNTIME` 을 unset 한 뒤 재실행했다.
   (`-x` 존재검사 = proxy 게이트. 실행가능 ≠ 우리가 빌드한 바이너리.)
