# .clm 포맷 v0.2 — embed 테이블 + GN affine + conv bias 직렬화 (CORE-mounted descent unblock)

status: LANDED (hexa-lang PR #2540) · anima 동반 (CORE decode rewrite + spec v0.2)

## 문제 (named root cause)

추론-트랙 `.clm` (`stdlib/flame/clm_prod.hexa` PR4 serialization) 이 6 conv weight
블록만 직렬화하고 **학습된 embed 테이블 · GroupNorm affine(tgG/tgB/noG/noB) ·
conv bias 를 누락**. 트레이너는 이 파라미터를 전부 학습하지만 serialize 단계에서
conv weight 만 write → anima CORE-mounted decode(`generator.hexa::clm_decode_ce`)가
트레이너의 GPU-측 CE descent(d768 fire: epoch-1 4.88 → epoch-3 4.877)를 엔진을
통해 재구성 불가. (legacy d768 artifact = conv-only 3,651,389 B = 정확히 6-block
크기로 byte-검증; trained embed+GN 은 메모리에만 존재했고 직렬화 안 됨.)

## 수정 (a_completeness_over_cheap primary path)

### 1. 포맷 v0.2 — backward-compatible EXT trailer
```
v0.1: [MAGIC "CLM\x01"][nblocks u8][nblocks conv blocks]
v0.2: ... v0.1 ... [EXT_MAGIC "CLMX"=67,76,77,88][n_ext u8]
      per ext entry: [len u32-le][len × fp32-le]   # FULL fp32
```
- EXT 는 6 conv 블록 **뒤에 APPEND** → v0.1 리더는 nblocks 만 읽고 멈춤
  (backward-read 보존, byte-unaffected).
- embed/GN/bias 는 descent-critical + 소량이라 int4 양자화 없이 full fp32.
- 엔트리 순서: `0 embed[V·d] 1 ecB 2 tcB 3 e0B 4 e1B 5 rB 6 roB 7 tgG 8 tgB 9 noG 10 noB`

### 2. writer/reader
- `stdlib/flame/clm_ckpt.hexa`: `clm_ext_begin/save_entry/load_entry/present` pub
  fns + smoke gate `F-CLM-CKPT-EXT-ROUNDTRIP`(fp32 byte-eq) + `…-BACKWARD-READ`
  (v0.1 리더가 v0.2 파일의 6 블록 그대로 read). 둘 다 `hexa run` PASS.
- `stdlib/flame/clm_prod.hexa`: serialize 에 ext 11 엔트리 추가.

### 3. host 재export 드라이버 (clm_prod 가 forge_dispatch_adamw 로 mac 컴파일 불가)
- `stdlib/flame/clm_reexport.hexa` — host nn_conv1d_fwd/bwd + opt_adamw_step
  (forge dispatch 0, torch 0), byte-graph-faithful int4-QAT+STE. 실제 corpus 학습
  → epoch-1 CE 4.698 → epoch-12 CE 1.666 (`F-CLM-REEXPORT-DESCENT=1`) → v0.2 .clm.
- anima CORE 가 그 v0.2 .clm 로 측정: CE_realtext 2.078 < uniform 5.545 AND <
  shuffle 5.525 → CE-descent 🟢 GREEN CORE-mounted (toy d=8).

## anima 측 동반
- `CORE/generator.hexa::clm_decode_ce` = 트레이너 clm_prod_fwd 그래프 충실 미러
  + v0.2 ext 의 embed/GN/bias VERBATIM read (없으면 tied-readout stand-in
  fallback). d/E 를 block dims 에서 도출 = config-agnostic.
- `CLM/CLM_FORMAT_SPEC.md` §2.1 + §5 = v0.2 SSOT.

## 남은 production rung (cloud)
- `clm_prod.hexa` v0.2 serializer 의 **d=768 forge re-fire** — 로컬 mac 바이너리는
  `forge_dispatch_adamw` 부재로 BLOCKED → pod self-host build 에서 발사.
  → d=768 trained embed+GN 담긴 v0.2 .clm → CORE-mounted descent d=768 재측정
  → GREEN 시 anima ENGINE PUBLIC flip (a_toy_scale_recheck: toy→prod transfer 검증).
