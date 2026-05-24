# GO — log

Append-only history sister of `GO.md` (TBD). Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T23:30:00Z — M5: hexa daemon RFC draft (design-only · code 0)

GO 도메인 M5 마일스톤 — fork-storm 의 *internal* axis 디자인 문서 신규.

외부 축 (pool-route 0.6.5+0.6.6+0.6.7) 은 이미 머지됨 — 동일 mac 호스트에서
다른 host 로 fork 를 옮기는 방식. 그러나 단일 세션의 반복 호출 (IDE/LSP
자동저장 · `hexa loop --dfs` 라운드 안의 N compile) 은 매번 fresh process →
parser/atlas TEXT-parse 재실행 → ~수십 ms 비용 누적. 본 RFC 가 그 internal
axis 의 첫 설계서.

| 산출물 | sha | scope |
|---|---|---|
| RFC 093 | (PR) | `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` (~370 lines · 11 절 · ASCII diagram 3 + 비교표 1 + falsifier 표 1 + phase 표 1) |
| GO.log.md | (PR) | 본 도메인 로그 신규 (sister `GO.md` 는 후속) |

### 핵심 결정

- **권장 = Option A (gradle-style stand-alone daemon)** — Option B (LSP 확장)
  는 CLI 의존성으로 부자연스럽고, Option C (.dylib) 는 fork-storm 자체를
  해결 못 함 (process-local, cross-call state 없음).
- Option A 의 단점 (새 verb · socket lifecycle) 은 검증된 패턴 (gradle, bazel
  10년+).
- `HEXA_DAEMON_AUTOSPAWN=1` opt-in · 미설치/crash 시 fork-mode 자동 fallback
  (graceful degrade · F-DAEMON-1, F-DAEMON-3).
- atlas SSOT 일관성은 60s mtime+hash re-stat → 변동 시 전체 flush (`@D
  atlas_fold` 우회 0건).
- 5 falsifier (fallback · speedup · crash · atlas consistency · privilege).
- 4-라운드 phase plan (R1 socket → R2 cache → R3 multi-session test →
  R4 prod ship).

### 본 RFC 가 *안* 푸는 것 (honest carve-out)

- 외부 host fan-out (pool-route 영역)
- 외부 LLM 호스팅 (`@D external_llm` 위배)
- atlas direct fold (`@D atlas_fold` 우회)
- Windows / 비-unix host (§8 Q3 별도 RFC)
- 본 RFC 머지 = 코드 변경 0건; R1–R4 후속 PR 에서 wiring

- [x] `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` 신규 (next RFC
      number — 092 까지 사용중이라 093 채택)
- [x] GO.log.md 신규 (도메인 sister log)
- [x] PR 생성 + 자동 squash merge (pr-cycle 훅)
- [ ] M6+ — daemon implementation R1–R4 (별도 RFC 머지 후 별도 PR 체인)
