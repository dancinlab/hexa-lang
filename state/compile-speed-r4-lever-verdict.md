# 컴파일속도 R4 — post-bsearch 차기레버 verdict (예측·미측정)

워크플로 `compile-speed-r4-lever-enumeration` (wf_bee72c07-15f · 8 agent · 36 레버 · build-free
소스 white-box). **전부 PREDICTION** — 이 라운드 빌드 0회(summer가 R3 byteeq CI 중·mini=git/gh).
유일 측정 datum = PRE-bsearch 프로파일(state/real-ci-build-hotspot-verdict.md · summer · 99,741 샘플).

## 예측된 새 #1 병목 (post-bsearch)

bsearch가 `__blk_*` 블록walk(PRE 79.4% self)를 소멸시킨 뒤 Stage-1 #1 = **emit spine 근접 동률**:
- `hexa_val_heapify` RESIDUAL self 9.89% (~15s/154s) — bsearch는 자식(__blk_*)만 깎음, dispatch+envelope 머신 잔존
- `hexa_add_slow` per-AST-node C-text 문자열 concat self 8.95% (~14s) — `runtime_core_emit.hexa:8262-8264` (hexa_to_string→hexa_str_concat)
- 합 ~63% post-bsearch Stage-1.
- heapify-residual 내 지배적 reducible 하위비용 = per-element envelope reject(:5269)의 ~210M frozen-seed `hexa_arena_env_lo/hi` 호출. 실제 deep-copy는 이미 ~0 (walk_found=0).

## 생존 레버 (adversarial verify 후 · algorithmic-byteeq-safe만)

| rank | 레버 | subsystem | 예측이득 | 확신 | byteeq |
|------|------|-----------|----------|------|--------|
| 1 | arena envelope를 C-static 캐시 + heapify-root당 sync-once → ~210M frozen-seed env 호출 제거 | heapify-residual (:5267-5270 + :1770-1781 + :1803-1817) | ~2-3s of ~15s heapify-self (~5-7% Stage-1) | MED | 조건부: heapify가 transitive arena_alloc 안 함을 감사해야(아니면 lazy-cache가 미동기 신규블록 문자열 오거부→strdup 누락→byte 발산→substrate floor) |
| 2 | array/map 원소 재귀 call-site에 scalar+out-of-arena 문자열 fast-path 인라인 | heapify-residual | ~0.5-1s (dispatch elim) · small NOT 10-25% | HIGH | safe (faithful-subset predicate) |
| 3 | emit를 단일 growable byte/string buffer로 → per-AST hexa_str_concat churn 제거 | codegen (hexa_add_slow) | ~14s hexa_add_slow self의 높은 천장·high-variance | MED | main.c byte-for-byte 재현 필수 |
| 4 | seed-converge 내 4 독립 SSOT 모듈 transpile 병렬화(12 유휴코어·현재 단일스레드) | seed-converge | ~1.5-2x of 76s · 빌드레벨(Stage-1 밖) | HIGH | byteeq-무관(독립빌드 병렬·출력불변) |
| 5 | pre-converged 커밋 시드 → HEXA_SEED_CONVERGE i=0 break(regen 2회+cc 2회 제거) | seed-converge | cold-path만 ~76s+2 cc 제거·warm은 이미 no-op | MED | safe |

기각: arena envelope-drop=byteeq-safe지만 PERF-NEGATIVE(114M 전부 bsearch 강제 > 2-call early-out) ·
head-lock=tiny(~9M만) · codegen ROI-23 해시=측정상 0.20% self floor 미만 0%mover · hexa_ld linker
레버=O(R*D)→O(R) byteeq-safe지만 측정 282s 빌드경로 밖(darwin byteeq link만) · intern <0.24% negligible.

## 두 substrate floor (낙관 금지)
(a) arena→heap 실제 deep-copy는 self-emit서 이미 ~0 (walk_found=0) — 복사작업 잔존 없음, dispatch+frozen-seed env-call 오버헤드만.
(b) frozen native seed(__blk_*/env accessor·immutable .s) 수정불가 → ~210M env-call은 C-side 캐싱으로만 reducible(lazy-sync 발산 hazard, heapify-never-arena_allocs 감사에 gated).

## FALSIFY 계획 (호스트 free 후 · aiden/summer byteeq CI 후 · 1-SSH · 격리 /tmp)
1. 현 main(bsearch ON) 재빌드, state/real-ci-build-hotspot-verdict.md 레시피(TARGET=linux-x86_64 CC=gcc HEXA_SEED_CONVERGE=1 ... bash tool/release_build), /usr/bin/time -v whole-wall + per-stage 타임스탬프(Stage-1 ~46s 기대 if 3.36x held).
2. perf record -g on 라이브 Stage-1 hexa_v2 PID(-- sleep 25); perf report --no-children(self)+--children. FALSIFY TARGET: __blk_* 79%→<5% self, 새 top self = heapify(~9.89%)+hexa_add_slow(~8.95%). parse/typecheck/flatten(미프로파일 44s flatten·module_loader) OR gcc-compile stage가 지배하면 heapify-residual #1 예측 FALSIFIED.
3. perf annotate + counted build로 ~210M env_lo/hi + walk_found~0 확인. env-call이 지배 아니면 rank-1 전제 falsified→rank-2/3.
4. rank-1 프로토타입 behind HEXA_RT_HEAPIFY_ENV_CACHE(default-OFF): byte-diff main.c+runtime_core.c flag ON vs OFF(d1e385bc 213k-probe법), 3타깃 byteeq + walk_found=0 invariant + arena-read-only 감사(grep hexa_strbuf_dup_n/TAG_VALSTRUCT/closure 재귀 any arena_alloc). Stage-1 wall ON vs OFF taskset-pinned MEDIAN(1-shot 아님). 이득<노이즈→closed-neg 정직보고.

## 추천 진입 순서 (정직)
- **가장 안전+명확한 win = rank-4 seed-converge 병렬화**(byteeq-무관·HIGH·~1.5-2x of 76s) — Stage-1 밖이지만 whole-build ~30-40s. 빌드 orchestration(tool/stage_build_hexa)만 변경.
- **가장 큰 Stage-1 잠재 = rank-1 env-cache** — 단 byteeq audit(heapify-never-arena_allocs) 선행 필수. 감사 통과 시만.
- 둘 다 호스트 free + 실측 falsify(예측 검증) 후 착수. 미검증 impl 금지.
