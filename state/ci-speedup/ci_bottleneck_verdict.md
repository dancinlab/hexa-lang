# CI 병목 속도개선 — 측정 verdict + 레버 사다리 (workflow wf_78fc7bdf-d03 · 2026-07-03)

측정 6에이전트(정찰 5축+합성) · 오류 0 · 428k tok. 모든 수치는 gh api 실런 데이터/ssh probe 캡처.

## ★ 헤드라인 — darwin 큐 문제 (exec도·클라우드도·컴파일도 아님)

- **PR 게이트 end-to-end 중앙값 60.6분** (최종 SHA 전 게이트 완료 기준 · n=7 · max 82.2) vs darwin 게이트 exec 합계 ~21.6분 → **~39분/PR = 순수 큐 대기**.
- queue:exec 최대 **40:1** (determinism 50m57s 대기 → 84s 실행 · miscompile 59m19s → 68s).
- 풀 활용률 **52%뿐** — 포화가 아니라 **burst fan-out + dispatch-시점 라벨 고정**이 원인: 컴파일러 PR 1건이 darwin 잡 ~9개를 동시 발사, pick-runner가 dispatch 시점에 ghost로 고정 후 재라우팅 없음 (스냅샷: 큐 129런 전부 ghost-핀 · mini는 online+idle).
- release darwin 레그: 2.7분 잡에 **중앙값 168.8분 큐** (14.1h에 릴리스 19회가 같은 ghost 슬롯 경쟁).
- 중복 재빌드는 실재(PR당 10잡이 release_build 실행 · 7잡이 byte-identical darwin ./hexa 재빌드)하나 비용은 컴파일이 아니라 **큐 슬롯 6개** (ccache 75–100% hot · warm build 0.5–1.6분).
- cloud/linux self-hosted = 병목 아님 (큐 0.0–0.1분 · aiden/summer 활용률 ~6%).
- 주의: gated create→merge 중앙값은 ~22분(17/30 PR이 admin-merge) — 게이트는 종종 **머지 후 60–82분에 완료**됨(green-확인 지연 = 60.6분 축).

## 레버 사다리 (무료만 · 게이트 불훼손)

| # | 신뢰 | 레버 | 절감 | 상태 |
|---|---|---|---|---|
| 1 | DERIVED | darwin 7중 동일빌드 fan-out → 1–2 큐슬롯 통합 (artifact-share 또는 umbrella 게이트잡) | 20–40분/PR | 다음 라운드 (canary PR로 verdict byte-diff 게이트) |
| 2 | MEASURED | dispatch-핀 해소: ghost+mini 공유 darwin 라벨(run-time 밸런싱) + mini gen3 슬롯 상시 프로비저닝 | ~10분/PR·burst 50분+ | **사용자 사인오프 필요** (mini=데일리 드라이버 · 'ghost 오프라인시만' 정책 완화) |
| 3 | MEASURED | nobaseline-gate PR path-filter (docs-PR가 darwin 풀 소각 차단) | docs-PR당 15.4 러너분(darwin 풀 6.5분) · ~100+ darwin풀분/일 | **본 PR** |
| 4 | DERIVED | advisory 스모크 3개 → 호스티드 러너 고정 (원설계 주석 복원) | ~6분/PR 셀프호스트 슬롯 + 큐엔트리 3개↓ | **본 PR** |
| 5 | DERIVED | autotag/release 큐-병합 (queued-미시작 릴리스만 최신 SHA로 coalesce) | 릴리스 green-지연 최대 ~166분 | 다음 라운드 (finalize 3/3 불가침 게이트) |
| 6 | DERIVED | push-이벤트 heavy 게이트 keep-latest 병합 (newest-always-completes) | push 파일업 제거 · byteeq-real 취소기아 무결성 홀 동시수리 | 일부 #4463 선착지 — 잔여 확인 후 라운드 |
| 7 | DERIVED | stage-3 precompile(~/.hexa-cache) OS×source-hash 캐시 (exact-key·no restore-keys) | ~4–5 exec분/PR | 다음 라운드 (stale-cache false-green 방지 키 설계 필수) |
| 8 | HYPOTHESIS | ghost 2번째 러너 슬롯 (burst 흡수) | 미계량 | 측정 라운드 선행 (contention: byteeq-real 13.4→29.5분 실측) |

## non-levers (기각 · 사유)

- Blacksmith/larger runner — 유료, #4015→#4016 revert 선례.
- ccache 추가 투자 — 이미 75–100% hit 실측(사실상 만점) · wall=transpile+link.
- heavy 게이트 약화/삭제 — 금지, required도 아니라 latency에 무효.
- heavy 게이트를 required로 승격(현상태) — 60.6분 큐를 머지에 수입 + 오프라인 러너 의존 금지 위반; 레버 1–2 착지 후 별도 무결성 결정.
- cloud/linux 레그 가속 — 측정상 비병목.
- arm64-linux self-hosted 추가 — 호스트 없음 + cloud 레그 큐 0.
- 휴면 워크플로 스텁 6개 삭제 — 0런/400런 윈도우, 위생일 뿐.
- faithful/게이트 잡의 cloud 스필오버 — gen3 슬롯 필요(SETUP ERROR 실측), 해법은 슬롯 프로비저닝(레버 2).

## 부수 적발 (게이트 무결성 · 속도 아님)

- **byteeq-real 취소-기아**: main-push 연속 7런(09:28–09:58Z)이 cancel-in-progress로 전부 취소 → 머지 burst 동안 main의 byteeq-real 검증 0회. (#4463가 일부 선착지 — 잔여 범위 레버 6 라운드에서 확인)
- **byteeq-real RED 2회 머지 통과** — heavy 게이트 비-required의 대가; 레버 1–2 후 required 승격 재론.

원자료: workflow wf_78fc7bdf-d03 저널(세션 transcript) · 합성 JSON은 이 문서로 갈음.
