# FLAME-PERF — append-only step log

## 2026-06-01 — 도메인 생성 (개선아이디어 백로그 시드)

hexa-native CLMConvMoE QAT 트레이너 완성 직후(4 op + fwd/bwd GRAD-EXACT + CE/AdamW
descent + int4 QAT + 임의 L·E 일반화 + large 44.68M 실동작, PR #2288–#2307) 도출된
성능·자원·속도·패러다임 개선 여지를 도메인으로 박제. 모든 작업이 host farr(CPU) 경로라
forge GPU device-routing 미연결이 최대 wall-time 병목 — 이 도메인의 1순위 lever.

시드 milestone 12개 (4축): 성능·속도 5 · 자원 4 · 패러다임 3. 각 아이디어는 측정 가능한
falsifier(roofline % · wall Δ · 메모리 Δ · GRAD-EXACT/byte-eq 유지)로 닫는다. 측정 잣대는
GPU-ROOFLINE 도메인과 공유. 날조 0 · a_scale_honest_scope 준수.
