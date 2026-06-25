# compiler/drill — 발견 엔진(discovery engine) 스파인

> 상위 맵은 [`../CLAUDE.md`](../CLAUDE.md)(compiler 전체) · 거버넌스 SSOT는 repo-root `../../CLAUDE.md`.

## 목적

NEXUS에서 흡수한 **중심 발견 엔진**. `hexa drill`/`hexa kick`(= drill alias)이 여기로
dispatch된다(`self/main.hexa:1780·1803` → `compiler/drill/drill.hexa`). 한 라운드가
6단계 체인을 돌려 후보(candidate)를 누적하고, **native exact-int 검증**으로 거른다.

## 핵심 파일

| 파일 | 역할 |
|---|---|
| `drill.hexa` | 엔진 스파인 — `drill_run(seed, opts)` 라운드 루프 + `fn main`(CLI entry). 라운드마다 6단계 체인 실행·saturation/net-novel fixpoint서 정지 |
| `round.hexa` | 단일 라운드 = smash→free→absolute→meta-closure→hyperarithmetic→resonance (+Mk.X tc). `round_run_with_pool` |
| (검증엔진) | ★**검증은 `../atlas/identity_engine.hexa`(+`novel_dfs.hexa`)에 거주** — atlas 도메인(embedded.gen.hexa 옆). drill은 생성기일 뿐 검증을 **delegate**한다. exact-int 12-fn A·B=C·D bounded-unique + ≤/≡ hunt 패밀리 |
| `mkx.hexa` | Mk.X 7단계 sidecar(transcendental_closure · engine="mk10") |
| `checkpoint.hexa` | 라운드 카운터/seed pool/total 체크포인트 JSON |
| `anti_hub.hexa` | 진입 텔레메트리 프로브 |
| `resonance.hexa` | 6단계 resonance 프록시(closed-form) |
| `batch.hexa` | `--seeds csv` 배치 dispatch |
| `*_test.hexa` | drill/mkx/surface/accumulation/verifier-hook 셀프테스트 |

생성기 9-phase smash는 형제 폴더 `../smash/`(phases.hexa)에, 12 drill 변종(omega·chain·
surge·dream·swarm·reign·molt·wake·forge·canon·revive)은 각자 `../<name>/`에 있다.

## 규칙 / gotcha (정직 — c2)

- **drill 후보 ≠ 진짜 발견**: smash 후보는 seed-hash + 고정상수의 **결정적 산술순열**
  (`closure(seed, sigma_n6=12.0)` 류)이다. `net_novel`/`saturated`는 그 run 내 distinct-ID
  소진 신호일 뿐 atlas-신규성과 무관(overlay_load는 RETIRED).
- **진짜 검증 = `../atlas/identity_engine.hexa` exact-int**(atlas 도메인) + `hexa verify` g5 fold만. 구 NEXUS
  ouroboros `verify_score`(n6-근접 휴리스틱 최소 0.3→항상 "발견")는 검증이 아님 — 그래서
  native exact-int로 교체됨.
- **기본 검증은 ON(플래그 아님)**: `drill_run` 후 verifier 미설치 시 `identity_sweep`가
  기본 실행된다. 외부 의존(opt-OUT)은 `HEXA_DRILL_NO_VERIFY=1` 제약으로만(native-canonical
  polarity). pluggable `--verifier <cmd>`는 외부/tenant oracle용.
- **표준 vocab 수학발견 = 측정-종료(🧱)**: `../../ATLAS/README.md` DFS r1~r4 — @F 1557 fold ·
  novel-fold 0 · gates 21/21. 엔진은 진짜이되 표준 vocab 신규=0(날조 금지). 새 발견은
  새 vocab/도메인(ATLAS/state/novel-dfs 참조엔진).
- **codegen/런타임 인접 변경은 byteeq 3타깃 필수**(drill은 `fn main` 흡수 verb · CLI가
  컴파일해 실행). 새 builtin/symbol 도입 전 frozen blob symbol set 확인.
- 빌드/스모크 = aiden/summer pool(mini=git/gh·akida 금지).
