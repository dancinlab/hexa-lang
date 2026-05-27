# TECS-L 축 E E3 — `hexa atlas register` install-dir 해저드 + patch-to-worktree 회복 (formal)

> SSOT 위치: `TECS-L/docs/e3-atlas-register-hazard-and-recovery.md`
> Anchors: 축 E E1 (PR #1070 · slug `tecs-l-axis-e-atlas` 그룹 TECS-L) · 축 E E2 (PR #1096 · slug `tecs-l-atlas-health`)
> 본 문서는 **신규 verify 0건**(M10/MR1 동일 패턴) — E1 hands-on + E2 audit 에서 입증된 두 해저드(쓰기/읽기) 와
> 그 회복 워크플로를 표준 문서로 정리한다. terminal-empirical synthesis.

---

## §1. 해저드 메커니즘 (write-side · install-dir leak)

### 1.1 정리
`hexa atlas register --from-verify <fn> <n> <v>` 는 **현재 cwd 무관**, 항상
설치 위치(`~/core/hexa-lang/compiler/atlas/embedded.gen.hexa`) 에 splice 한다.

```
$ pwd
/tmp/wt-tecs-l-E1                       # 격리 worktree 라고 가정

$ hexa atlas register --from-verify tau 496 10
# 실제 변경 파일 → /Users/ghost/core/hexa-lang/compiler/atlas/embedded.gen.hexa  (install-dir)
# /tmp/wt-tecs-l-E1/compiler/atlas/embedded.gen.hexa 는 건드리지 않음
```

이유: `embedded.gen.hexa` 는 SSOT 단일 파일이며 runtime `static_atlas` 가
TEXT-parse 로 직접 읽도록 설계됐다 (memory: `project_atlas_hxc_irreplaceable_ssot`).
register 는 `embed_fold_into` 로 그 단일 SSOT 에 직접 splice(no rebuild) 한다.
→ "현재 디렉터리" 가 무엇이든 fold 대상은 한 곳뿐.

### 1.2 공유 트리에서의 leak 위험
하지만 install-dir 의 git 트리(`~/core/hexa-lang`) 는 통상 **8세션 공유**
워킹트리이다 (memory: `feedback_hexa_lang_shared_worktree_branch_hazard`).
그 공유 트리에 다른 에이전트의 active 브랜치가 체크아웃돼 있으면:

```
~/core/hexa-lang  ← 공유 워킹트리, HEAD = antimatter-h1s2s-rydberg-verify
                    (다른 에이전트가 자기 PR 준비 중)

내 register 한 줄 → 공유 트리의 working tree 변경
                  → 다른 에이전트의 `git status` 에 보임
                  → 다른 에이전트가 자기 PR 에 휩쓸어 commit 가능
                  → 내 atlas fold 가 엉뚱한 PR 에 leak
```

이게 **"register install-dir leak"** 해저드다. 해저드 표면화 조건:
- 호스트 = install-dir 의 git 트리 == active 공유 트리
- `register --from-verify` 실행 (write-side surface)
- 동시에 다른 에이전트의 active 브랜치 HEAD

### 1.3 입증 사례 — E1 PR #1070 (2026-05-25T12:07:46Z 머지)
E1 에서 첫 6개 verified 발견을 atlas 로 fold 할 때 정확히 이 시나리오가 발생:
- 내 register 6 노드 → `embedded.gen.hexa` 16103→16109 라인
- 그러나 당시 `~/core/hexa-lang` 의 HEAD = **antimatter-h1s2s-rydberg-verify**
  (다른 에이전트의 active branch)
- → 내 register output 이 그 브랜치의 working tree 에 leak
- → 회수가 필요했고, 그 회수 절차가 §3 의 표준 워크플로의 원본

---

## §2. 해저드 메커니즘 (read-side · binary-builtin freeze · E2 발견 보강)

### 2.1 정리
`hexa atlas lookup` 은 install 된 hexa 바이너리에 **embedded at last build**
된 builtin 테이블을 읽는다. source SSOT(`embedded.gen.hexa`) 가 그 후 register
로 갱신되어도 lookup 에는 0 hit.

### 2.2 정량 (E2 PR #1096)
`.verdicts/tecs-l-atlas-health/binary_vs_source_divergence.txt` (2026-05-25):

```
binary-builtin (installed hexa atlas lookup):
  total nodes (audit) = 16101
  verified-* prefix hits = 74
  my E1 6 nodes findable = 0          ← !

source embedded.gen.hexa (origin/main):
  my E1 6 nodes present = 6           ← !
```

내부 audit 자체는 🟢 clean (binary 의 자체 정합성은 OK · drift=0),
**그러나 binary ≠ source** 는 out-of-band divergence.

### 2.3 두 해저드의 상보성
| 측면 | 해저드 | 표면 |
|---|---|---|
| **쓰기** (§1) | install-dir leak | register 가 cwd 무관 install-dir 의 source 갱신 → 공유 트리 leak |
| **읽기** (§2) | binary-builtin freeze | lookup 이 frozen binary 를 읽음 → source 갱신이 query 에 0 반영 |

E1 의 6 노드는 source 에 있지만 lookup 에 0 hit (E2 확인). E3 는 이 두 면을
한 장의 정리로 묶는다 — **write surface 와 read surface 가 분리된 design 의 양 측면이며,
하나만 보면 부분 진실이다.**

---

## §3. 회복 워크플로 — patch-to-worktree (E1 PR #1070 입증 패턴)

§1 의 leak 이 발생했을 때 회수하는 4단 표준 절차:

### Step 1 — register 직후 install-dir 트리에서 diff 추출
```bash
cd ~/core/hexa-lang
git diff compiler/atlas/embedded.gen.hexa > /tmp/atlas-fold.patch
```
- 변경된 단일 파일이 SSOT 이므로 diff 단일 파일 capture 로 충분.
- 노드 N 개를 register 했다면 N 개 노드 + 인접 라인의 컨텍스트.

### Step 2 — 공유 트리 즉시 회수 (타 에이전트 보호)
```bash
git -C ~/core/hexa-lang checkout -- compiler/atlas/embedded.gen.hexa
```
- 공유 트리의 working tree 변경 즉시 되돌림 → 다른 에이전트의 `git status` 정상화
- 이 시점에 patch 파일은 `/tmp/atlas-fold.patch` 에 살아있음.

### Step 3 — 격리 worktree 생성
```bash
git -C ~/core/hexa-lang worktree add -b atlas-fold-<topic>-2026-MM-DD \
  /tmp/wt-atlas-fold origin/main
cd /tmp/wt-atlas-fold
```
- `origin/main` 베이스 → 공유 트리의 ad-hoc 상태와 무관한 cleansl 한 워크트리.

### Step 4 — 격리 워크트리에서 패치 적용 → 검증 → PR
```bash
git apply /tmp/atlas-fold.patch
# (필요 시 stray 노드 strip / 오타 / 누락 commit 보강)
git add compiler/atlas/embedded.gen.hexa
git commit -m "feat(TECS-L): axis E … fold N verified discoveries"
git push -u origin atlas-fold-<topic>-2026-MM-DD
gh pr create --base main --title …
```

### 부가 — embedded.gen.hexa 는 codegen-급 직렬 권장
`compiler/atlas/embedded.gen.hexa` 는 16k+ 라인 생성파일이라 동시 PR 두 개가
같은 hunk 부근을 건드리면 거의 항상 conflict. (memory: `reference_codegen_change_verify_recipe`
의 "codegen PR mutually conflict = serial per round" 와 동형.)
- rebase 가 필요해지면 `git fetch origin main && git rebase origin/main` →
  hunk 충돌 시 양쪽 노드 모두 keep (둘 다 fold 의도된 발견이므로 union).

---

## §4. 권고 (forward · 시스템 차원)

### 4.1 atlas write = 1-writer 직렬화
- codegen-PR 패턴 차용 — 라운드당 atlas-register PR 한 개 (다 머지된 뒤 다음 시작).
- 이는 §3 의 4-step 회복을 거의 안 필요로 하게 만드는 가장 강한 예방.

### 4.2 query 가 source 를 우선 읽도록 명세 정리 (HEXA_ATLAS_EMBED overlay)
- 메모리(`project_atlas_hxc_irreplaceable_ssot`) 에는 `HEXA_ATLAS_EMBED` env 로
  runtime overlay 가 가능하다 명세돼 있으나, E2 실측은 lookup 이 여전히
  binary-builtin 단독/우선.
- → INBOX 업스트림(`INBOX.log.md` 2026-05-25T18:00Z) 에 두 옵션 등록 상태:
  - (i) `hexa atlas lookup` 이 `HEXA_ATLAS_EMBED` 또는 cwd
    `compiler/atlas/embedded.gen.hexa` 를 binary-builtin 보다 우선 읽도록 동작 명세
  - (ii) OR `hexa atlas register` 가 source fold 후 binary-builtin 상태에도
    in-memory 반영
- 이 hexa-lang 측 fix 가 들어오면 §2 의 read-side 해저드는 사라진다.

### 4.3 binary 재빌드 cadence
- register 누적 후 정기적 `hexa cc --regen` + install → source 와 binary 동기화.
- E2 의 source≠binary 갭은 register 후 hexa 바이너리 재빌드 전에는 영구.
- 현실적 cadence = N개 atlas-fold PR 머지 후 1회 일괄 재빌드.

### 4.4 register 직전 셀프-체크
정직한 운영 체크리스트 (한 줄):
```bash
git -C ~/core/hexa-lang status --short | grep -v '^??' \
  || echo "OK: 공유 트리 clean → register 안전"
git -C ~/core/hexa-lang branch --show-current   # 무엇 위에 leak 될지 알기
```
- 공유 트리가 깨끗하지 않거나, branch 가 `main` 이 아니면 → §3 회복 준비를
  먼저 하고 register.

---

## 부록 A — Anchors / 인용 표

| 항목 | 위치 | 비고 |
|---|---|---|
| 축 E E1 verdict batch | `.verdicts/atlas-divisor-sum-sigma/` 및 source `embedded.gen.hexa` 16103→16109 | PR #1070 머지 2026-05-25T12:07:46Z |
| 축 E E2 divergence verdict | `.verdicts/tecs-l-atlas-health/binary_vs_source_divergence.txt` | PR #1096 머지 2026-05-25T13:08:05Z |
| INBOX 업스트림 (hexa-lang 측) | `INBOX.log.md` 2026-05-25T18:00Z "atlas binary-builtin lookup vs source embedded.gen.hexa divergence" | 두 옵션(i)/(ii) 등록 |
| 공유 트리 위험 메모리 | `feedback_hexa_lang_shared_worktree_branch_hazard` · `feedback_subagent_worktree_leak_pattern` | 일반 worktree leak 와 동형 |
| codegen 직렬 권장 메모리 | `reference_codegen_change_verify_recipe` | 16k 라인 생성파일 동시 PR 충돌 동형 |

## 부록 B — 본 문서의 verify 디스시플린 지위
- **신규 verify 0건** — M10 uniqueness closed-form proof, MR1 Euclid-Euler 와 동일 패턴.
- 기존 두 verdict (`.verdicts/tecs-l-atlas-health/binary_vs_source_divergence.txt`
  와 E1 fold 의 source 변경 자체) 위에 reasoned synthesis 로 닫는다.
- CLAIMS.tape 의 본 문서 슬러그(`tecs-l-atlas-register-hazard`) 에는
  workflow synthesis verdict 1개 → `.verdicts/tecs-l-atlas-register-hazard/hazard_recovery_pattern.txt`.
- terminal-empirical: 회복 패턴이 E1 PR #1070 에서 이미 실집행 입증, divergence 가
  E2 PR #1096 에서 실측. 추가 verify 불요.
