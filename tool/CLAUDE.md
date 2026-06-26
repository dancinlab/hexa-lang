# tool/ — 빌드·셀프호스트·린트·로드맵 도구 (sub-CLAUDE)

> hexa-lang **거버넌스 SSOT 는 repo-root `../CLAUDE.md`** (이 파일은 그 하위 폴더 안내일 뿐,
> 충돌 시 root 우선). 설계/모듈 SSOT 는 `../ARCHITECTURE.json`, 이력은 `../CHANGELOG.md` + git.

## 이 디렉터리는 무엇인가

`tool/` = 컴파일러 본체(`../compiler` · `../self`)와 stdlib 을 둘러싼 **운영 도구 모음** — 릴리스
빌드 스테이지, 셀프호스트(byteeq · zero-C) 게이트, Stage-0 린트, 로드맵 엔진, atlas 운영, GPU
프로브/벤치를 한 곳에 모은다. 대부분 `.hexa`(proof-carrying · `hexa run tool/<x>.hexa` 로 실행),
무거운 빌드 오케스트레이션은 `.sh`, 일회성 측정/덤프는 `.py`. 파일 수가 많아 아래는 **파일별이
아니라 family 별** 안내다 — 정확한 인벤토리는 `ls tool/`, 각 스크립트 상단 주석이 사용법 SSOT.

## 파일 family

### 빌드 · 릴리스 스테이지
- `stage_*` — release 파이프라인 단계 (`stage_prebuild_hexat` · `stage_regen_hexa_cc` ·
  `stage_build_hexa` · `stage_resolve_runtime_a` · `stage_precompile_package`). frozen seed +
  shallow-checkout 함정 주의 (`../CHANGELOG` history 참조).
- `build_*` — 타깃별 빌드 드라이버 (`build_hexa_cli*` · `build_native*` · `build_precompile.hexa`
  · `build_selfhost.sh` · `build_aprime.sh` · `build_hx*_linux.hexa` 가속 라이브러리). 무거운
  빌드는 pool(aiden/summer/ghost)에서만 — mini 금지.
- `cross_*` · `regen_*` — 크로스 타깃 emit + 런타임/codegen `.c`·`.o`·`.s` seed 재생성기.
  `regen_*` 는 emitter SSOT 에서 생성물(`runtime_core.c` 등 gitignored)을 다시 빚는다 — stale
  seed 충돌 시 여기서 재생성 (regen skip → alloc-seed multidef 사고 전례).
- `release_*` · `restore_frozen_seeds` · `promote_selfhost.sh` — 패키징 · frozen seed 복원 ·
  셀프호스트 default flip.

### 셀프호스트 게이트 (byteeq · zero-C)
- `selfhost_*` — `gen3≡gen4` byteeq · parity · shim-integrity · crossemit smoke · codegen guard
  게이트. `selfhost_gates_summary.sh` 가 묶음 요약, 3타깃 GREEN 이 stable 승격 전제.
- `zeroc_*` — zero-C drop/flip 측정 · ztrace 계측 (`zeroc_flip_measure.sh` ·
  `zeroc_drop_runtime_measure.sh` · `zeroc_exec_graduate.sh` 등). RFC061 사다리 측정 도구.
- `fixpoint_*` · `miscompile_zero_gate.sh` · `musl_ctor_abi_gate.sh` — fixpoint 비교/사전점검 +
  관련 무결성 게이트.

### Stage-0 린트 (`*_lint.hexa`)
`hexa run tool/<name>_lint.hexa` 로 도는 proof-carrying 텍스트 스캐너. 대부분 `.githooks/pre-commit`
에 배선 — 일부는 BLOCK(exit 1), 일부는 ADVISORY(warn-only). 새 린트 추가 시 폴리시(block vs warn)를
주석 상단에 명시할 것.
- 코드 규율: `bounded_loop_lint`(RFC-010 bounded-for/decreases-while) ·
  `blocking_timeout_lint`(blocking I/O 에 `timeout` 강제) · `no_hardcode_lint`(magic path/URL/host ·
  `.hardcode-baseline` grandfather) · `total_fn_lint` · `exec_eq_int_lint` ·
  `runaway_pattern_lint` · `resource_lint`.
- 코드젠/셀프호스트: `codegen_tau4_lint`(τ=4 emit-slot 불변량) · `module_loader_collision_lint` ·
  `private_fn_collision_lint` · `parser_format_stability_lint`.
- **`stdlib_guard_lint`** — Stage-0 ADVISORY(warn, 절대 block 안 함). 같은 함수 안에 empty/zero
  가드 없이 **새로** 추가된 `arr[0]` 첫-원소 read / `/ divisor` 나눗셈을 잡아낸다 — PR
  #3943..#3963 에서 고친 "malformed-input guard" 버그 클래스의 회귀 방지. 실행:
  `hexa run tool/stdlib_guard_lint.hexa --selftest | --mode=warn <files> | --changed`.
  `.githooks/pre-commit` 에 ADVISORY 로 배선(경고만, 커밋 차단 안 함). 일회성 전수 census 는
  `guard_class_census.py`(재실행 가능 · `state/` 는 gitignore 라 `tool/` 에 둠).
- 위생/기타: `backup_file_lint`(working-tree backup 파일 금지) · `ext_lint`/`doc_lint`/`poc_lint` ·
  `spawn_lint`/`precommit_spawn_lint`/`swarm_lint`/`telegram_lint`/`runaway_pattern` ·
  `lb_state_lint` · `roadmap_lint`/`roadmap_schema_lint`(+ `test_roadmap_lint`).

### 로드맵 엔진 (`roadmap_*`)
DAG 기반 작업 로드맵 파서·스케줄러·관찰성 모듈군 (`roadmap_engine` · `roadmap_kahn` ·
`roadmap_critical_path` · `roadmap_dispatch` · `roadmap_status_flip` · `roadmap_to_changelog` 등).
`roadmap_cli.hexa` 가 진입점.

### atlas 운영 (`atlas_*`)
사람층(`../ATLAS/`) ↔ 기계층(`../compiler/atlas/embedded.gen.hexa`) 운영 —
`atlas_cli` · `atlas_verify` · `atlas_embed_gen` · `atlas_bulk_absorb` · `atlas_split_by_kind`.
verdict atom fold 는 항상 `hexa verify` g5 PASS 경로로만.

### CLI · 진단 · 검증
- `hx.hexa`/`hx_*` — `hx` 패키지매니저 보조 (drift/coverage/stage-health 스캐너).
- `verify_*` · `cross_prover.hexa` · `dod_gate.hexa` · `doctor.hexa` · `hexa_diag.hexa` —
  검증 인증서 · DoD 게이트 · 진단.
- `hexa_ld.hexa` · `hexa_link.hexa` · `hexa_repl.hexa` · `hexa_init.hexa` · `compile.hexa` —
  링커 · REPL · 프로젝트 init 등 CLI 보조 표면.

### GPU · 벤치 · 프로브 (대부분 일회성 측정)
- `probe_*_f64.hexa` · `*_probe.hexa` — 커널 정밀도/오라클 프로브 (libm trig · gemm · rope ·
  softmax …). reference-match 측정용.
- `gpu_*` · `cuda_*` · `*_driver.cu` · `dispatch_*` · `fusion_*` · `decode_*` · `wgmma/` ·
  `hexa-fusion/` — GPU 마이크로벤치 · cuBLAS 대조 · fused 커널 · 원격 dispatch 스크립트.
- **`build_cuda_runtime`** — `cuda_available 0→1` CUDA 런타임 빌드 + `cuda_gemm_verify` verdict.
  `CUDA_HOME=/usr/local/cuda-X.Y SM=120 bash tool/build_cuda_runtime` (sm_120 = RTX 50계열 ·
  nvcc ≥12.8 필요). ⚠️ **알려진 결함 (summer nvcc 12.9, 2026-06-26)**: 추출한 RT-NATIVE
  cores($CORES: `rt_hi_native.o`·`alloc_syscall_native.o` …)를 `runtime_cuda_host.o`와 **명시 .o로
  강제링크** → `rt_str_*`·`hexa_arena_*` 19× `multiple definition` collect2 fail(DONE_RC=1).
  출하 runtime.a는 archive lazy 해소로 무충돌이나 explicit-.o-link는 둘 다 force-pull. 매크로
  (`HEXA_HAS_HEXA_RT_STDLIB`/`HEXA_RT_ALLOC_NATIVE`) 추가·archive화 모두 무효(frozen runtime.c의
  게이팅 ↔ seed 심볼셋 불일치가 근본). **root fix(TODO)** = 게이팅을 seed 제공 심볼셋과 정렬.
  **검증-only 우회**(출하 금지·no-escape-hatch): verify 하니스는 `-Wl,--allow-multiple-definition`
  로 재링크 가능(중복=byte-identical runtime 본문). 헤더 주석 + convergence
  `CUDA-BUILD-CORES-EXPLICIT-LINK-MULTIDEF` 가 SSOT. 2026-06-26 summer 실측(이 우회로): cuda=1 ·
  d2048 451 GFLOP/s · `farr_packed_gemv_offset [V=151643×64]` GPU out_id=2(illegal-D2H 회피) ·
  max|GPU−ref|=3.3e-16 → anima PR #2631 디코더 expert gemv 검증.
- `unshadow_*_bench.hexa` · `bench_*` · `train_floor_bench.hexa` — codegen/런타임 perf 벤치.

### 서브폴더
`bin/`(빌드 진입) · `wrappers/`(CLI 래퍼) · `hooks/` · `config/` · `docs/`(stdlib 모듈 레퍼런스
`.md`) · `bench/` · `jit/` · `pkg/` · `test/` · `clm/` · `training/` · `phi_extractor/` ·
`*_selftest_fixtures/` · `transient_py/`(폐기 예정 일회성 py) · `r9_walls`/`r14_walls`/`r15_walls`
(측정 wall 아티팩트).

## 작업 규칙 (root 거버넌스 + 폴더 보강)

- **빌드/regen/byteeq 는 pool(aiden·summer·ghost)에서만.** mini = git/gh/read only (heavy build
  crash). akida 빌드 farm 금지.
- **린트 추가/수정 시 폴리시 명시** — BLOCK 인지 ADVISORY(warn-only)인지 스크립트 상단 주석에
  적고, `.githooks/pre-commit` 배선을 같은 변경에서 갱신. ADVISORY 린트는 절대 커밋을 막지 않는다
  (`stdlib_guard_lint` 가 기준 예시).
- **regen 생성물은 SSOT 아님** — `regen_*` 출력(`runtime_core.c`·`*.o`·`*.s`)은 emitter 에서
  재생성되는 gitignored 산출물. 직접 손대지 말고 emitter + regen 스크립트로 빚는다.
- **codegen/runtime/stage 변경은 byteeq-safe 확인 후 머지** — 3타깃 GREEN + 출하 smoke (root
  [릴리스 무결성] 가드레일). docs-only 도구 변경은 게이트 무관.
- 상세 history 는 `../CHANGELOG.md` + git (이 파일은 update-in-place CURRENT-STATE).
