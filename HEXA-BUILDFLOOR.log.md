# HEXA-BUILDFLOOR — log

Append-only history sister of `HEXA-BUILDFLOOR.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-31 — M1 🟠 PARTIAL: 3-fix origin/main 검증, 빌드/스모크 honest-STOP

- [x] 핵심 발견: 밀스톤이 가리키는 `build_hexa_cloud.sh` 는 트리에 없음. 레시피는 이미
  `tool/build_hexa_cloud.hexa` 로 hexa-native 포팅되어 origin/main 에 머지됨 (PR #2102 포팅 + #2112 --install).
  그 빌더가 3 fix 를 이미 포함.
- [x] gate (a) PASS: `git show origin/main:tool/build_hexa_cloud.hexa` → Python → `od -c` 바이트검증.
  L193 `build/hexa_v2` · L202 `build/self/runtime.c` · L206 `-I build/self`(inc_gen); 죽은 `self/native/hexat` 코드에 없음(주석만).
  (raw grep 은 dedup 커널이 L206 28회 복제 → 우회; Read 가 가짜 FIX4 줄 주입 → od -c 적발·기각.)
- [ ] gate (b/c) BLOCKED honest-STOP: build/hexa_v2 transpiler + fallback + 부트스트랩 소스 부재
  (transpiler not found EXIT=1) + 이번 세션 `! sidecar sign local` 미서명 heavy-invocation 게이트 → 빌드 차단(@L4 genuine wall).
- [x] SAFETY: ~/.hx/bin/hexa.real md5 PRE==POST 7493583e 무손상 · 설치 안 함.
- [x] 초기 폐기 draft 의 hallucinated md5(8f86e95b) 기각, 실측 7493583e 로 정정. 모든 수치 파일영속화→재측정.
- verdict: `.verdicts/buildfloor-m1/F-BUILDFLOOR-M1.txt` · evidence: `.verdicts/buildfloor-m1/_evidence/`
- 다음 단계: `! sidecar sign local` → build/hexa_v2 부트스트랩 → `HEXA_LANG=$PWD NO_SMOKE=1 hexa run tool/build_hexa_cloud.hexa`.

