# HEXA-C-ZERO — log

Append-only history sister of `HEXA-C-ZERO.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-30 — C1 warm-seed CI (git-rm CLOSED · warm-CI DEFERRED, honest)

verdicts: `.verdicts/hexa-c-zero/C1-GROUND-TRUTH.txt` · `.verdicts/hexa-c-zero/C1-WARM-SEED-CI.txt`

C1 = 두 반쪽. (A) `hexa_cc_seed.c` git rm + (B) warm-seed CI 복귀. (A) 닫힘, (B) upstream RED 으로 deferred — fake green 금지(g5/g63).

- [x] (A) **git-rm 반쪽 = CLOSED** — fresh /tmp clone of origin/main(HEAD 5561241c8) 실측: `git cat-file -e HEAD:self/native/hexa_cc_seed.c` = fatal(ABSENT) · `git cat-file -e HEAD:self/native/hexa_cc.c` = fatal(gitignored build artifact) · `git ls-files self/native/*.c` = `native_gate.c` (비-트랜스파일러; m7-probe 는 C2). **커밋된 트랜스파일러 .c = 0**. (GROUND-TRUTH verdict verbatim.)
- [ ] (B) **warm-CI 반쪽 = DEFERRED (upstream 2중 RED · NOT fake green)** — warm-install path(`hx install`/edge-download → `hexa cc --regen` → build → smoke)가 `ubuntu-latest`(x86_64)에서 green 불가: ① `edge` release 가 `hexa-linux-arm64.tar.gz` 만 보유, `hexa-linux-x86_64.tar.gz` 부재(release.yml x86_64 job long-red — 마지막 5런 failure/cancelled, handoff 726b8b67) → x86_64 runner 에 받을 바이너리 없음 ; ② 바이너리가 있어도 `hexa cc --regen` 이 clean main 에서 self-host 깨짐(merged `hexa_cc.c.new` undeclared symbols, clean install.sh 실패 — handoff 16afa5bb/e311289a). 둘 다 UPSTREAM(release-pipeline + cc --regen), C1 scope 내 수정 불가. (WARM-SEED-CI verdict 에 `gh release view edge`·`gh run list release.yml`·handoff verbatim.)
- [x] `bootstrap.yml` = **DISABLED stub 유지** + WARM-CI BLOCKER + RE-ENABLE PATH 코멘트를 정확한 2중-RED 로 구체화(no push/PR trigger = workflow_dispatch-only no-op → 빨간 런이 auto-merge 게이트를 통과할 일 없음).
- [x] `codegen-bootstrap-sync.yml` = RETIRED no-op 유지(전제 hexa_cc.c 제거로 구조적 무효, 무변경).
- [x] docs 재조정 — `HEXA-C-ZERO.md` C1 = `[ ]`(git-rm 닫힘·warm-CI deferred 명기) · honest note 갱신 · `HEXA-CC-ZERO.md` P6 = **SUPERSEDED**(seed-refresh 경로 사용자 제거 결정으로 retired).
- ⚠ **C1 미flip(honest)**: git-rm 목표("커밋 .c = 0")는 달성이나 milestone 텍스트가 "warm-seed 복귀"를 포함하고 그 복귀(warm-CI green)는 upstream-blocked → C1 체크박스는 보류. 두 upstream RED 해소 시 warm-CI green 으로 flip.

