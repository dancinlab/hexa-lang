# RFC-045 — `qmirror` 흡수 (`stdlib/quantum/`)

- **상태**: **LANDED** (2026-05-16)
- **작성일**: 2026-05-16
- **선행**: 헌법 v2 (5 룰) + RFC 044 (qrng) + RFC 046 (sim-universe) absorption pattern
- **흡수 시리즈 #2/3 (마지막 land)**: RFC 044 (qrng ✅) → RFC 046 (sim-universe ✅) → **RFC 045 (qmirror)** — qmirror 최종 업그레이드 완료 후 재페치하여 진행
- **사용자 결정 (2026-05-16)**: nexus 식 archive 전환 + README 보존 + hexa CLI 통합
- **영향 영역**: `stdlib/quantum/` (신규) · `self/main.hexa` (qmirror dispatch + cmd_help) · `AGENTS.tape` (§0 qmirror_stack + l1 + @D ×2 + @F + @X)

---

## 1. 동기

`~/core/qmirror/` v2.6.0 — 62,402 LoC across 38 module directories — 는 dancinlab quantum-stack 흡수 시리즈의 마지막 후보. qmirror 최종 업그레이드 (clifford-data-regression · hardy-multipartite · mabk-ardehali · page-curve-scrambler · pseudo-telepathy-doily · qdrift-hamiltonian-sim · qfi-spin-motion · rpe-gate-calib · shallow-shadows · steering-gme-minimal · symmetry-adjusted-shadows · wigner-negativity-discrete · mirror-fidelity-bench 등 신규 알고리즘 모듈 추가) 완료 후 재페치하여 흡수.

qmirror = ≤30-qubit laptop-grade QPU-equivalent substrate. IBM Cloud / Braket QPU 렌탈의 drop-in 대체 (저잡음 ≤30-qubit 영역 한정 — Casio vs Rolex).

## 2. 헌법 v2 룰 매핑

| 룰 | 처리 |
|---|---|
| 1 (rodata 시드) | 비해당 (qmirror = 알고리즘 + 응용) |
| 2 (알고리즘 흡수) | 38 module dirs → `stdlib/quantum/`. engine_aer state-vector kernel + 27 @D-governed algorithms + chemistry_vqe |
| 3 (메타 frozen) | AGENTS.tape · README · CHANGELOG · CITATION · LICENSING · BENCH.tape · IDENTITY.tape · design docs · MODULE/ · cli/ · 38 module dirs → `~/core/archive_qmirror/` 묘비 |
| 4 (외부 자원 δ) | `qmirror/qrng/` = consumer-side HMAC-DRBG amplifier (ANU entropy). engine_aer = classical-simulator fallback when no QPU keys |
| 5 (overlap) | 비해당 |

## 3. 흡수 명세

### 3.1 디렉토리 보존 — flatten 안 함

qmirror 의 `chemistry_vqe` (29.6k LoC · 59 files) + `bench` 모듈은 상대경로 import 사용:
- `./xxx.hexa` (같은 디렉토리)
- `../../<feature>/module/xxx.hexa` (cross-module: engine_aer, chemistry_vqe lib)

따라서 RFC 046 의 flatten 방식 (`<feature>/module/<file>` → `<feature>/<file>`) 을 쓰면 상대경로가 깨진다. **본 RFC 는 `<feature>/module/` 구조를 그대로 보존**:

```
~/core/qmirror/<feature>/module/<file>.hexa
  → stdlib/quantum/<feature>/module/<file>.hexa
```

이렇게 하면 `../../<feature>/module/<file>` 상대경로가 `stdlib/quantum/` 하위에서 그대로 resolve — import rewrite 0.

### 3.2 File mapping

```
~/core/qmirror/                            → stdlib/quantum/
  <38 feature dirs>/module/*.hexa          → stdlib/quantum/<feature>/module/*.hexa
  cli/qmirror.hexa                         → (대체) stdlib/quantum/quantum.hexa CLI dispatcher

  (frozen archive → ~/core/archive_qmirror/)
  AGENTS.tape · AGENTS.md · CHANGELOG · README · CITATION · LICENSE ·
  LICENSING{.md,.tape} · BENCH{.tape,.log.tape} · IDENTITY.tape ·
  AER_HEXA_ABSORPTION_PLAN · CHEMISTRY_VQE_PYSCF_BACKEND_PLAN ·
  hexa.toml · install.hexa · docs/ · MODULE/ · cli/ · examples/
```

총 114 `.hexa` (60,423 LoC 측정 — worktree/build/state 제외), 38 module dirs.

### 3.3 모듈 그룹

- **Core**: engine_aer (2.2k LoC Aer-compat state-vector kernel + QASM3) · circuit · sampler · stabilizer · entropy · qrng · selftest · chsh · iit_mip · phi · tomography · process_tomography · cscs
- **Algorithms (27, @D-governed)**: rqaoa · ctx · dynghz · vqd · stab-ext · overlap-vqe · sre · lg · pseudo-tel · rpe · sym-shadow · hardy · page-curve · qdrift · cdr · wigner · qfi · shallow · gme-steer · mabk · mirror-bench (+ standalone dirs)
- **Applications**: chemistry_vqe (29.6k LoC · 59 files · per-molecule CMT hamiltonians) · bench · surface_code_d3

## 4. CLI 통합 (별도 `tool/hexa_qmirror/` 폐기)

원본 `~/core/qmirror/cli/qmirror.hexa` (~870 LoC subprocess + sentinel). 본 RFC 는 hexa main CLI 통합:

- `stdlib/quantum/quantum.hexa` — dispatcher (status/selftest/chsh/iit/qrng + 27 algorithm subcmds + --help + --version). 모듈을 subprocess (`hexa run stdlib/quantum/<feature>/module/<file>.hexa`) 로 호출.
- `self/main.hexa` + `else if sub == "qmirror"` 분기
- cmd_help "STDLIB CLI" 섹션 + qmirror 27 subcommand 노출

호출 패턴:
```sh
hexa qmirror                              # status (default)
hexa qmirror chsh                         # CHSH Bell test
hexa qmirror iit                          # IIT 4.0 phi-star
hexa qmirror rqaoa | ctx | dynghz | vqd | ... | mirror-bench
hexa qmirror --help / --version
```

## 5. 거버넌스 변경 (AGENTS.tape)

- `@L l1` +`stdlib/quantum/` 행
- §0 `@N qmirror_stack` — core / algorithms / applications / cli / structure_note / envelope / qrng_boundary / archive / governance / DOI / RFC
- `@D g_qmirror_envelope` — ≤30-qubit 저잡음 envelope 한정 (Casio-vs-Rolex)
- `@D g_qmirror_consumer_qrng` — qmirror.qrng = consumer-side amplifier; stdlib/qrng/ = provider
- `@F f_qmirror_real_qpu_claim` — real-QPU overreach 금지
- `@X x_archive_qmirror` — 묘비 pointer + Zenodo DOI 10.5281/zenodo.20102964

## 6. 호환성

- 원본 `dancinlab/qmirror` GitHub repo → private (사용자 액션)
- provider/consumer 경계: `stdlib/quantum/qrng/` (consumer amplifier) vs `stdlib/qrng/` (RFC 044 provider) — 동일 이름 다른 경로, zero overlap
- chemistry_vqe + bench 상대경로 import — `<feature>/module/` 구조 보존으로 무변경 resolve

## 7. Falsifier (인수 조건)

1. **F-RFC045-PARSE**: 114 `.hexa` 모두 `hexa parse` PASS (114/114).
2. **F-RFC045-DISPATCH**: `hexa parse self/main.hexa` 0. `else if sub == "qmirror"` 분기 + cmd_help STDLIB CLI qmirror 섹션 존재.
3. **F-RFC045-CLI**: `hexa run stdlib/quantum/quantum.hexa --help` 가 27 algorithm subcommand 표 출력. `... status` 가 module inventory 출력.
4. **F-RFC045-RELIMPORT**: chemistry_vqe + bench 의 `../../<feature>/module/` 상대경로가 `stdlib/quantum/` 하위에서 resolve (구조 보존 확인) — bench/module/*.hexa parse PASS 가 증거.
5. **F-RFC045-TAPE**: AGENTS.tape grep — `@N qmirror_stack`, `@D g_qmirror_envelope`, `@D g_qmirror_consumer_qrng`, `@F f_qmirror_real_qpu_claim`, `@X x_archive_qmirror`, `@L l1 stdlib/quantum/` 모두 존재.
6. **F-RFC045-ARCHIVE**: `~/core/archive_qmirror/AGENTS.tape` byte-identical to `~/core/qmirror/AGENTS.tape`. `ABSORBED.md` 존재. `chmod -R a-w` 적용.

## 8. 후속

dancinlab quantum-stack 흡수 시리즈 **COMPLETE**:
- RFC 044 (qrng) ✅ LANDED 2026-05-16
- RFC 045 (qmirror) ✅ LANDED 2026-05-16 (본 RFC)
- RFC 046 (sim-universe) ✅ LANDED 2026-05-16

총 흡수: ~96k LoC (qrng 4.4k + sim-universe 30k + qmirror 62k) + 3 묘비 archive.

---

**Co-author**: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
