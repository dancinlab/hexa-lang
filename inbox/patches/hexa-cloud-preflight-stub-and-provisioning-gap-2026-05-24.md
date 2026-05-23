# hexa cloud preflight stub + provisioning verb 부재 — RTSC BEE-NET fine-tune 발견

## TL;DR

`hexa cloud` 는 transport-only (run/nohup/poll/copy-to/copy-from) — GPU pod 를
띄우거나(provisioning) 워크로드 메모리를 사이징(preflight)하지 못해 실 워크로드가 막힘.

## gap 1: preflight 가 미수용 스텁

- 0.2.0 cycle C 빌드의 `hexa cloud preflight` 는 입력 파라미터를 무시하고
  항상 `model=1000M·2B / H100-80GB / PASS` 를 고정 출력함.
- 실 사이징 불가: BEE-NET fine-tune (2.46M params, <4GB) 처럼 24GB GPU 면
  충분한 워크로드에도 H100-80GB 를 추천 → 오사이징 = 비용 낭비.
- 수정: 실제 model param 수 / batch size / activation 을 입력받아
  GPU mem 을 closed-form 으로 추정 (LLM·pod spinup 없이 — 기존 d-spec 의도대로).
  최소 RAM 충족 GPU tier 를 추천하도록.

## gap 2: provisioning verb 부재

- 현재 verb: run / nohup / poll / copy-to / copy-from (전부 transport).
- 부재 verb: rent / create / up (pod 임대·기동) · destroy (pod 해제).
- 영향: GPU pod 를 띄우려면 raw `vastai` / `runpod` API curl 우회가 불가피 →
  g8 (no raw vastai/runpod CLI · structured argv only) 정신 위반.
- 수정: `hexa cloud rent <gpu> [--price-max <usd/h>] [--disk <GB>]` +
  `hexa cloud destroy <id>` verb 추가. Vast/RunPod API wrapper 로 구현하고
  cloud-guard hook 과 정합되게 (raw CLI 차단은 유지, 임대는 구조화 argv 경유).

## 영향 워크로드

- RTSC BEE-NET grid-extended fine-tune (d7 wall path B) — 24GB GPU 1대 필요한데
  `hexa cloud` 로는 pod 를 못 띄움.
- 이번 우회: Vast API curl 직접 호출 (현 상태에선 불가피).
  `hexa cloud` 가 provisioning 을 흡수하면 우회 불요.

## 우선순위

- provisioning verb (rent/destroy) = **높음** — GPU 워크로드가 빈번하고
  현재는 매번 raw API 우회를 강요당함 (g8 반복 위반).
- preflight 정확화 = **중간** — 오사이징은 비용 낭비지만 워크로드를 막지는 않음.
