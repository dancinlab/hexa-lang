# stdlib — 폴더 가이드 (sub-CLAUDE)

> hexa-lang **거버넌스 SSOT 는 repo-root `../CLAUDE.md`** (이 파일은 그 하위 디렉터리 안내일
> 뿐, 충돌 시 root 우선). 설계 SSOT 는 `../ARCHITECTURE.json` (Component map · Data flow).
> 이력은 git + `../CHANGELOG.md`. 이 파일은 지도일 뿐 — 버전/날짜 누적 금지.

## 이 디렉터리는 무엇인가

`stdlib/` = `.hexa` 표준 라이브러리. ~2270 `.hexa` 파일로, 성격이 다른 **두 반구**가 한
디렉터리에 산다 — ⓐ 범용 spine(core·collections·io·json·net·http·time·path·crypto·…)와
ⓑ 거대한 **과학-수치 반구**(qforge·bio·flame·quantum·chem·signal·matter·physics·kernels·…).
범용 spine 은 컴파일러/툴체인이 쓰는 일반 자료구조·I/O·파싱 유틸이고, 과학 반구는
도메인 시뮬·수치 커널·ML 학습/추론 스택으로 대부분 `hexa <verb>`(예 `hexa qforge`) 런타임
디스패치나 도메인 라이브러리로 소비된다.

## 주요 서브트리 맵

### 범용 spine (core / 일반)
```
core/          — 기반 타입·산술: string · bytes · math · parse · special · option/result · trait fixtures
collections.hexa · hashset.hexa · record.hexa · smart_ptr.hexa — 일반 자료구조
io.hexa · log.hexa · path.hexa · portable_fs.hexa · proc.hexa · sys.hexa — I/O·프로세스·FS
json* · yaml.hexa · csv·parse.hexa · semver.hexa · argparse.hexa · regex/ — 파싱·직렬화
net/ · http*.hexa · http_sse.hexa · websocket.hexa · channel.hexa · future.hexa · cancel.hexa — 네트워크·동시성
crypto/ (101) · hash/ · cert/ · qrng/ · cloak/ · keychain.hexa — 암호·해시·자격증명
codec/ · regex/ · tokenize/ · time/ · stats/ · linalg/ · matrix/ · tensor/ — 인코딩·수치 유틸
c_ffi.hexa · python_ffi.hexa · dynlink_caps.hexa · wasm/ · posix/ · hal/ (139) — FFI·플랫폼·HW abstraction
hx/ · build/ · cloud/ (84) · ddp/ · registry_autodiscover.hexa — 패키지/빌드/클러스터 글루
```

### 과학-수치 반구 (numeric / ML)
```
qforge/ (365)  — 최대 과학 서브트리: SCF·DFPT·el-ph·MAE·smearing 등 first-principles 물리 (QE reference-match · `hexa qforge` CLI)
bio/ (247)     — 생명: PK/PD · protein-fold · gene-edit · rna-therapy · organoid · xeno
flame/ (140)   — ML 학습 스택 (decoder·trainer·flame_math) — 일부 byteeq-relevant (아래 참조)
quantum/ (116) · qubit/ — 양자 회로·상태 시뮬
chem/ (48)     — MD(langevin·verlet) · kinetics(TST·Arrhenius) · FEP/MBAR · SMILES
signal/ (25)   — DSP: FFT · 필터(biquad) · mel filterbank · autocorrelation (native libm trig)
math/          — ode · special(elliptic) · lattice(A₂…Λ₂₄ Gram) · numtheory · rng · quadrature
kernels/ (54)  — 저수준 수치/신경 커널 (lif_kernel 등) · mc_integrate/ · optim/
physics/ · matter/ (42) · material/ · sim_universe/ (77) · space/ · nuclear/ — 물리·재료·우주
nn.hexa · autograd.hexa · optim.hexa · safetensors.hexa — ML 코어 프리미티브
```

### 도메인 클러스터 (응용 과학·엔지니어링)
```
재료/소자: crystal · graphene · perovskite · spintronic · photonic · memristor · neuromorphic · chip · metamaterial · aerogel
에너지/화학: fusion · energy · co2-capture · green-nh3 · electrocat · photoredox · mlff · mol*.hexa
회로/HW: vhdl · yosys · firmware · rtsc · booksim · component · memristor · srr · sscb
시스템/툴: demi · deck · dojo · loop · lsp · scope · policy · research · discovery · easy · bot · cockpit · cluster
```
(전체 모듈 트리·dataflow 는 `../ARCHITECTURE.json` — 여기 중복 금지. 위는 기여자 진입용 지도.)

## byteeq-neutrality 컨벤션 (IMPORTANT gotcha)

stdlib 모듈은 **self-host 컴파일러 클로저(`self/`)가 import 하지 않으면 "byteeq-neutral"** 이다.
byteeq-neutral 모듈 편집은 `gen3≡gen4` 바이트-동일 self-host fixpoint 를 **바꿀 수 없으므로**,
3타깃 byteeq 게이트 없이 **직접 고치고 PR CI 로 검증**한다 (과학 stdlib 대부분이 여기 해당 —
런타임 디스패치 `hexa qforge`/`hexa deck` 등으로만 소비됨).

확인:
```sh
grep -rl "<module-path>" self/ | grep -vE 'test_|_test'   # empty = neutral
```
⚠️ bare grep 은 **주석·CLI 디스패치 문자열에서 false-positive** 가 난다 — 예컨대 `self/main.hexa`
는 `"stdlib/qforge/qforge_cli.hexa"` 를 런타임 verb 디스패치 경로로 **문자열로** 들고 있을 뿐
컴파일 클로저에 끌어들이지 않는다(여전히 neutral). 애매하면 실제 `import …`/`from …` 구문인지
hit 라인을 눈으로 확인할 것.

self/ 가 **진짜로 import** 하는 모듈은 **byteeq-RELEVANT** — 변경은 3타깃(x86_64-linux ·
arm64-linux · darwin-arm64) byteeq 게이트가 필요하다. 알려진 예:
- `nn.hexa` ← `self/env.hexa`
- `autograd.hexa` ← `self/token.hexa` (외 codegen·parser·attrs 경로)
- `path.hexa` · `self/stdlib/*` (array·map·random·tensor_ops) 도 클로저 내부
relevant 모듈은 mini 에서 머지하지 말고 pool(aiden·summer·ghost) byteeq 실측 후 머지한다.

## malformed-input guard 컨벤션

stdlib 함수는 malformed/degenerate 입력을 **가드**해야 한다 — Inf/NaN/OOB 를 토해내는 대신
문서화된 sentinel(`[]` · `0.0` · `-1.0` 등)을 반환한다.
- `arr[0]`/`arr[i]` 읽기는 `len(arr)==0`(또는 인덱스 범위) 체크로 가드.
- `/ divisor`(파라미터·길이·질량·sample_rate·temperature 등)는 `divisor<=0` 체크로 가드.

이 클래스는 대형 QA 캠페인의 주제였다(`../CHANGELOG.md` #3943..#3969 — ~69 byteeq-neutral 수정).
한 번의 census(`tool/guard_class_census.py` · 재실행 가능)가 **~2576 후보 사이트/658 파일** 을
측정 → 클래스가 stdlib 전반이라 수동 라운드론 고갈 불가 → **회귀 게이트로 전환**했다:
- `tool/stdlib_guard_lint.hexa` — `.githooks/pre-commit` 에 **advisory(warn-only · non-blocking)**
  로 와이어. 새로 추가된 unguarded 사이트(G1 unguarded-index · G2 unguarded-divide)를 flag.
  휴리스틱이라 hard-fail 아닌 warn. (`--selftest`/`--mode=warn`/`--changed`)
- `tool/guard_class_census.py` — 1회 전수 감사(one-shot)용.

## native-canonical 컨벤션

- math/signal 은 **native libm trig**(`cos`/`sin`/`tan`/…)를 쓴다 — 손짜기 Taylor series 금지
  (codegen-fragile). 일반 polarity 는 root `../CLAUDE.md` [native-canonical-default] 와 lockstep.
- 수치 커널은 **reference-match** 로 정답을 검증한다 — QE(qforge el-ph) · scipy/numpy(special·
  lattice·stats) · LAPACK(linalg). parity 는 출발점이지 종착점이 아니다.
- 테스트는 모듈 옆에 `*_test.hexa` / `*_selftest.hexa` 로 둔다(예 `core/string.hexa` ↔
  `core/cmp_total_order_test.hexa` · `math/ode.hexa` ↔ `math/ode_test.hexa`). 일부 모듈은
  자정답을 inline 한 self-contained 테스트라 출하 데이터 drift 를 못 잡을 수 있다(예 과거
  `lattice_test` 가 inline Gram 으로 통과해 `gram_K12` 데이터 오류를 가렸음 — 출하 경로와 대조).

## gotcha

- **거대 stdlib · per-module ownership** — 2270 파일이라 단일 소유자가 없다. 한 모듈을 고칠 때
  옆 `*_test.hexa`/`*_selftest.hexa` 와 reference 정답을 같이 확인한다.
- **공식 보유 함수는 atlas 인용 필수** — formula-bearing 함수는 `@cite(L[id])` · 활성 `@verify` ·
  `@grace` 중 하나가 없으면 빌드가 binary emit 을 거부한다(S8 citation 게이트 · fatal `HX8004`).
- **편집 전 byteeq 분류** — 손대기 전에 위 grep 으로 neutral/relevant 를 가른다. neutral 이면
  mini 에서 직접 고쳐 PR CI; relevant 면 pool byteeq 3타깃 GREEN 후에만 머지.
- **빌드/byteeq/측정은 pool**(aiden·summer·ghost) — `mini` 는 git/gh/read·write 전용
  (heavy build·akida 금지).
- **`.ai.md` 사이드카** — 일부 모듈 옆 `*.ai.md`(io·yaml·semver·channel·cancel·c_ffi 등)는 그
  모듈의 AI 보조 노트다(소스 SSOT 아님 · root CLAUDE.md 우선).
