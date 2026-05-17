# stdlib/ — 사용자용 라이브러리

사용자가 `import "../stdlib/xxx.hexa"` (파일형) 또는
`import "../stdlib/xxx/mod.hexa"` (디렉토리형) 으로 쓰는 고수준 모듈.

`self/lib/` 와 구분:
- **stdlib/** = 사용자 import (public API)
- **self/lib/** = 컴파일러 내부 유틸 (fraction, simd, sieve, tensor_ops 등)

병합 금지 — 역할 다름.

---

## 파일형 모듈 (`import "stdlib/xxx.hexa"`)

| 파일 | 역할 |
|---|---|
| collections.hexa | 컬렉션 (List, Set, Map 확장) |
| math.hexa | 수학 함수 (정수 산술 surface) |
| nn.hexa | 신경망 |
| optim.hexa | 옵티마이저 |
| autograd.hexa | 자동미분 |
| string.hexa | 문자열 유틸 |
| consciousness.hexa | anima 의식 모듈 |
| json.hexa · yaml.hexa · parse.hexa | 직렬화 / 파싱 |
| http.hexa · http2.hexa · websocket.hexa | 네트워크 프로토콜 |
| safetensors.hexa | 텐서 직렬화 |

## 디렉토리형 패키지 (`import "stdlib/xxx/mod.hexa"`)

| 패키지 | 역할 |
|---|---|
| tensor/ | 텐서 primitive (shape · ops · dispatch · ffi) |
| linalg/ · matrix/ | 선형대수 |
| math/ | 수학 (eigen · float · rng) |
| net/ | HTTP client/server · socket |
| optim/ | 옵티마이저 |
| mc_integrate/ · qrng/ · sim_universe/ · xeno/ | 과학 런타임 |
| regex/ · tokenize/ · hash/ · cert/ · test/ | 유틸 |

---

## science stack — hexa-matter / hexa-bio 종속 흡수

`hexa-matter` · `hexa-bio` 두 프로젝트가 의존하는 Python 과학 라이브러리를
hexa-native 로 흡수하는 패키지군. 2-stage 이관:

- **Stage 1** (현 구현 이관) — 두 프로젝트의 `_python_bridge` /
  `_absorption_bridge` 어댑터를 아래 패키지 API 로 재타깃.
- **Stage 2** (종속 라이브러리 hexa-native 포팅) — 흡수 대상 Python
  라이브러리 자체를 hexa-native 커널로 재구현 (no python/c shell-out,
  `.roadmap.stdlib` RC1).

| hexa stdlib | 흡수 Python | 쓰는 프로젝트 | 상태 |
|---|---|---|---|
| `nd` | numpy | bio | 기존 `tensor/` + `linalg/` + `matrix/` 묶음 — numpy surface |
| `grad` | torch · transformers | bio | 기존 `autograd.hexa` + `nn.hexa` + `optim/` — torch surface |
| `net` | requests · feedparser · bs4 · huggingface_hub | matter | 기존 `net/` 확장 |
| `atoms` | ase | matter | **SCAFFOLD** (`atoms/mod.hexa`) |
| `crystal` | pymatgen · mp_api | matter | **SCAFFOLD** (`crystal/mod.hexa`) |
| `mol` | rdkit | matter · bio | **SCAFFOLD** (`mol/mod.hexa`) |
| `mlff` | chgnet · mace · m3gnet/matgl · alignn · schnetpack | matter | **SCAFFOLD** (`mlff/mod.hexa`) |
| `quantum` | qiskit · qiskit_nature · qiskit_algorithms · qiskit_aer · pyscf | bio | **SCAFFOLD** (`quantum/mod.hexa`) |

`nd` · `grad` · `net` 은 기존 stdlib 자산을 science-stack surface 로
재명명/묶음 — 신규 디렉토리 불필요. `atoms` · `crystal` · `mol` ·
`mlff` · `quantum` 5개는 신규 scaffold (각 `mod.hexa` 에 흡수 대상 ·
Stage 1/2 계획 · planned public API 명시).

honesty: MP / NNP / qiskit 출력은 전부 **PREDICTION** (DFT 또는 NNP
또는 시뮬레이션) — 측정값 아님. 각 패키지 `mod.hexa` 헤더에 명시.

`numa` (scipy) 는 두 프로젝트에서 직접 import 0 — pyscf/numpy 내부
간접 의존이라 Stage 2 에서 `quantum`/`nd` 포팅 시 필요분만 흡수.

전수조사 SSOT: `hexa-matter` · `hexa-bio` 의 모든 `.py` import 추출 결과
(2026-05-18) 에 근거.
