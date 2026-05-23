# `grace-consent` workflow universally FAIL — `build/hexa_interp.linux` 부재

**Reporter**: anima (`dancinlab/anima` downstream consumer · cycle 11/FD 진단 · cycle 12 다중 carry 확인 · cycle 13/HA 본 patch 작성)
**Severity**: **high** — `.md`-only / `@grace`-free PR 포함 모든 PR universally FAIL,
trailer compliance 무관. 본 세션에만 4 PR carry: `#420` / `#438` / `#445` + 본 patch 도 self-affecting.
**Affected**: `.github/workflows/grace_consent.yml` lines 44–56 (`Locate hexa interpreter` step)

## §1 — TL;DR

`grace_consent.yml` workflow 가 `build/hexa_interp.linux` 우선 + PATH `hexa` fallback 으로
hexa interpreter 를 찾는데, origin/main 의 `build/` tree 에는 `hexa_interp.linux` 가 부재
(`hexa_linux` / `hexa_v2_linux` / `hx_linux` 만 존재) 하고 ubuntu-latest runner 의 PATH 에도
`hexa` 가 없다. 결과적으로 workflow 가 `Locate hexa interpreter` step 에서 `exit 1` 로 crash,
trailer scan step 에 도달조차 못 함. diff 에 `@grace(HX` 사이트가 **0** 인 `.md`-only PR 도
universally FAIL — trailer 자체 불필요한데 게이트 통과 못 함.

**Recommended fix** (g21 single primary): pre-flight step 추가, diff 에 `@grace(HX` 사이트가 0 이면
Locate + trailer-scan step 을 모두 skip. 비용 ≈ 0, semantic 정확, backward-compat 100%, 본 patch
PR 자체도 즉시 unblock.

## §2 — Reporter / Severity / Affected

- **Reporter**: anima cycle 11/FD evidence + cycle 12 다중 carry 확인 (cycle 12/GD 는 API rate
  limit 으로 실패 → cycle 13/HA 재시도)
- **Severity**: **high** (blocks **ALL** `.md`-only PRs from merging, trailer compliance 무관)
  - 본 세션 carry: `#420` (type_of inbox note, 7+ 번 carry), `#438` (proc_spawn_supervised
    FD-leak, cycle 10/EC), `#445` (websocat tool discovery, cycle 11/FC, +CONFLICTING)
  - 본 patch PR 자체도 self-affected — workflow 가 본 PR 에도 동일하게 fire
- **Affected file**: `.github/workflows/grace_consent.yml`
  - lines 44–56: `Locate hexa interpreter` step
  - lines 58–82 (대략): `Run consent checker (PR mode)` step (Locate 가 fail 하면 도달 못함)

## §3 — Symptom (verbatim)

GitHub Actions error log (모든 `.md`-only PR 동일):

```
##[error]no hexa interpreter found (expected build/hexa_interp.linux or PATH:hexa)
```

3 PRs 동일 failure 적용:

| PR    | scope                                       | cycle origin    | additional state |
|-------|---------------------------------------------|-----------------|------------------|
| #420  | type_of inbox note (4 scalars verbatim)     | 7+ 번 carry     | clean diff       |
| #438  | proc_spawn_supervised FD-leak inbox patch   | cycle 10/EC     | clean diff       |
| #445  | websocat tool discovery inbox patch         | cycle 11/FC     | +CONFLICTING (cycle 13/HC scope) |

본 patch 도 동일 failure 예상 — self-affecting workflow.

## §4 — Root cause

`.github/workflows/grace_consent.yml` lines 44–56 의 Locate step:

```yaml
- name: Locate hexa interpreter
  id: hexa
  shell: bash
  run: |
    set -euo pipefail
    if [ -x build/hexa_interp.linux ]; then
      echo "bin=build/hexa_interp.linux" >> "$GITHUB_OUTPUT"
    elif command -v hexa >/dev/null 2>&1; then
      echo "bin=hexa" >> "$GITHUB_OUTPUT"
    else
      echo "::error::no hexa interpreter found (expected build/hexa_interp.linux or PATH:hexa)"
      exit 1
    fi
```

| Probe                                  | origin/main 결과         | 비고 |
|----------------------------------------|--------------------------|------|
| `build/hexa_interp.linux` 존재         | **NO**                   | ships `hexa_linux` / `hexa_v2_linux` / `hx_linux` |
| ubuntu-latest PATH 의 `hexa`           | **NO**                   | workflow 가 install step 없음 |

두 fallback 모두 실패 → `exit 1`. diff 에 `@grace(HX` 사이트 0 인 경우에도 Locate 가
crash 하므로 trailer scan step 시작 불가. workflow 가 universally FAIL.

## §5 — Suggested fix (single per g21)

### Pre-flight skip when 0 `@grace(HX` sites

`Checkout (full history)` step 직후, `Locate hexa interpreter` 앞에 추가:

```yaml
- name: Pre-flight @grace site count
  id: grace_count
  shell: bash
  run: |
    set -euo pipefail
    # @grace(HX 사이트가 0 이면 trailer 자체가 불필요 → skip
    n=$(git diff "origin/${{ github.base_ref }}...HEAD" -- '*.hexa' \
        | grep -cE '^\+.*@grace\(HX' || true)
    echo "n=$n" >> "$GITHUB_OUTPUT"
    echo "::notice::@grace(HX site count = $n"

- name: Locate hexa interpreter
  id: hexa
  if: steps.grace_count.outputs.n != '0'
  shell: bash
  run: |
    # … (기존 동작 보존)

- name: Run consent checker (PR mode)
  if: ${{ github.event.pull_request != null && steps.grace_count.outputs.n != '0' }}
  # … (기존 동작 보존)

- name: Trivially pass when no @grace sites
  if: steps.grace_count.outputs.n == '0'
  shell: bash
  run: |
    echo "::notice::grace-consent skipped (PR introduces no @grace(HX… sites)"
```

**Effect**:
- `.md`-only / `@grace`-free PR → 즉시 PASS (Locate 도 trailer scan 도 skip)
- `@grace` 포함 PR → 기존 동작 100% 보존 (Locate fail 하면 본 진단 그대로 — 별개 fix)
- backward-compat 100%
- 본 patch PR 자체도 `@grace` site 0 → 적용 후 본 PR 즉시 unblock 가능

### Alternative paths (열등, 본 §5 권고 우선)

- **Option 2 — `build/hexa_interp.linux` binary commit**: `build/hexa_linux` 또는 `hx_linux`
  를 `hexa_interp.linux` 로 rename / symlink commit. 즉효 + Locate step 변경 없음. 단점: build
  artifact 명명 정책 결정 필요 (`hexa_interp.linux` 정식 이름인가? `hx_linux` 가 정식인가?),
  binary 차이가 있다면 잘못된 선택 = silent regression risk.
- **Option 3 — ubuntu-latest runner 에 hexa install step**: `apt install` 또는 `make build`
  step 추가. 가장 안전하지만 install 시간 (~분 단위) + `make build` 의 toolchain 의존성 (gcc /
  clang version, native lib) workflow 표면 노출 → 유지비 증가.

**§5 권고 = Option 1 (pre-flight skip)** — 시간 0, semantic 정확 (trailer 가 필요한 경우에만
gate 발동), Option 2/3 은 cycle 후속.

## §6 — Acceptance test

workflow fixture PR 2개 (또는 단일 PR 의 두 분기):

| fixture | diff content                                 | 기대 결과                                  |
|---------|----------------------------------------------|--------------------------------------------|
| A       | `.hexa` 파일 1개 + `@grace(HX0001, ...)` 사이트 1, trailer `Acked-grace: HX0001 by <r>` 포함 | grace_count.n=1 → Locate + trailer scan 실행 → PASS |
| B       | `.md` 파일 1개 (`@grace` 사이트 0)            | grace_count.n=0 → Locate + scan skip → "Trivially pass" 출력 + workflow PASS |
| C (neg) | `.hexa` 파일 + `@grace(HX0002, ...)`, trailer 부재 | grace_count.n=1 → Locate + trailer scan 실행 → FAIL (exit 2) |

A/B 가 PASS, C 가 FAIL 이면 fix 정상 작동. fixture 자체는 별도 PR 권장 (본 patch 는 spec only).

## §7 — Cross-link

| 링크                                                                                    | 관계 |
|-----------------------------------------------------------------------------------------|------|
| `dancinlab/hexa-lang` #420                                                              | 본 workflow self-fail 의 7+ 번 carry victim (type_of-array note) |
| `dancinlab/hexa-lang` #438                                                              | victim (proc_spawn_supervised FD-leak) |
| `dancinlab/hexa-lang` #445                                                              | victim (websocat tool discovery, +CONFLICTING from cycle 13/HC scope) |
| `dancinlab/hexa-lang` `inbox/patches/proc-spawn-supervised-daemon-silent-exit.md`       | 시블링 patch (silent-exit, 본 patch 와 별개 root cause) |
| `dancinlab/hexa-lang` `inbox/patches/websocat-tool-discovery-homebrew-prefix-2026-05-23.md` | 시블링 patch (websocat discovery, 본 patch 와 별개 root cause) |
| `dancinlab/anima` `feedback_anima_main_protection_toggle.md`                            | hexa-lang protection toggle carry pattern (next-cycle retry) |
| `dancinlab/hexa-lang` SPEC.yaml `opt_out.ai_native_warn_policy.user_consent_mechanism` | trailer spec 정의 (`Acked-grace: HXxxxx by <reviewer>`) |

## §8 — honest C3

- (a) **Self-referential** — 본 patch 의 PR 도 동일 workflow 거쳐야 land. `.md`-only diff 이므로
  현재 workflow 에서도 universally FAIL 예상 (g30 force 금지). PR 은 BLOCKED 로 carry,
  hexa-lang 측이 (i) fix 직접 적용 후 land OR (ii) 본 patch 를 force-merge OR (iii) Option 2
  bootstrap binary commit 으로 unblock 후 land 의 3 path 중 하나 선택 필요. anima 측 carry
  pattern (next cycle retry) 으로 처리.
- (b) **`git diff | grep '@grace(HX'` 정확도** — `+` prefix 매치를 위해 `^\+` anchor 추가했지만,
  patch hunk header (`@@` 라인), context line 의 `@grace` 멘션, 또는 `-` 라인 (제거) 의
  potential edge case 가능. 정확한 site count 는 `tool/check_grace_consent.hexa` 가 알려주지만
  그건 hexa interpreter 필요 → 닭 / 달걀. pre-flight 의 false-positive (n>0 인데 실제 site 없음)
  는 기존 동작 (Locate fail) 으로 복귀, false-negative (n=0 인데 실제 site 있음) 는 trailer
  scan skip 으로 잘못 PASS — `^\+.*@grace\(HX` anchored regex 가 false-negative 막는 첫 보호선.
  의심 시 Option 3 (interpreter 항상 install) 이 더 엄밀.
- (c) **Option 2 (binary commit) / Option 3 (runner install) 미선** — Option 2 는 `build/`
  artifact 명명 ownership 필요 (어느 binary 가 정식 `hexa_interp.linux` 인가?), Option 3 은
  workflow install 시간 + toolchain 표면 노출. Option 1 이 즉효 + 최소 변경.
- (d) **Skip semantics 적정성** — `@grace` site 0 PR 에서 trailer scan 안 함이 정의상 옳음.
  SPEC.yaml `user_consent_mechanism` 은 "site introduces / modifies a `@grace(HXxxxx, ...)`"
  조건부, site 0 이면 trailer 의무 없음. workflow 가 site 0 PR 도 강제로 gate 발동 시킨 것은
  버그 (over-gating). 본 fix 는 over-gating 제거.
- (e) **Concurrent PR 의 race** — base 이동 (main 에 다른 PR merge) 시 base..HEAD diff 가
  달라질 수 있음. `origin/${{ github.base_ref }}...HEAD` 의 `...` (three-dot) 는 merge-base
  기준이므로 PR 의 own changes 만 capture (false-positive 회피). OK.
- (f) **Workflow self-bootstrap** — 본 fix 가 적용된 commit 이 main 에 들어가야 후속 PR 이
  unblock 됨. 즉 본 patch 가 정착하기 전까지 4 PR carry 는 지속. hexa-lang 측이 본 patch 또는
  Option 2 bootstrap binary 를 admin force-merge 로 첫 lift 필요. anima 측 directive 외 영역.
- (g) **Trailer regex 의 sub-edge** — `Acked-grace: HXxxxx by <reviewer>` 는 PR body OR commit
  message scan. driver `tool/check_grace_consent.hexa` 가 책임. 본 patch 는 driver 변경 아님,
  workflow gate 만 조정 — driver 의 정확도 변동 0.
- (h) **`build/` rebuild 비용 미고려** — make 또는 explicit build step 으로 `hexa_interp.linux`
  생성하면 binary 크기 + commit churn + .gitattributes lfs 결정 필요. Option 1 은 이 모든 비용
  회피.

---

**End of patch** — 본 spec 만 land, 0 actual workflow file 변경 (g21 single primary + g30
protection 변경 금지 준수). hexa-lang 측에서 §5 reviewable.
