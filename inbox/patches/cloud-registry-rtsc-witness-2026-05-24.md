---
slug: cloud-registry-rtsc-witness-2026-05-24
status: open
---

# `hexa cloud` pod registry 부재 — RTSC(demiurge) 2번째-도메인 witness

**Reporter**: claude (`dancinlab/demiurge` · RTSC 캠페인 reboot-재개 세션 · 2026-05-24)
**Severity**: high (anima 보고와 동일 — passive money loss + 결과 회수 불가)
**Primary**: [[hexa-cloud-pod-registry-tracking-2026-05-24]] — 본 건은 그 patch의 corroborating witness (별도 fix 제안 없음, severity 재확인용)
**Siblings**: [[hexa-cloud-idle-autokill-missing-2026-05-24]] · [[cloud-runpod-session-findings-anima-2026-05-23]]

## TL;DR

anima가 PURE Phase D에서 보고한 "pod registry 부재 → orphan burn + result LOST"가
**다른 도메인(RTSC)·다른 provider(vast)**에서 그대로 재현됐다. cross-domain 2번째 witness이므로
primary patch의 severity high를 재확인하고, fix(특히 Fix B `hexa cloud ls --reconcile`)의 시급성을 보강한다.

## 증거 — RTSC reboot-재개 실측 incident (2026-05-24)

reboot 후 새 세션 진입 시 두 건 동시 발생:

1. **result LOST (4번째 후보)** — BEE-NET fine-tune 결과 `finetune_real.json`
   (d7 wall 2nd-confirm 증거)가 `/tmp/betenet/results/finetuned/`에만 존재 → reboot로 소실.
   repo 어디에도 persist 안 됨. registry의 `result_path`가 있었으면 pull 대상이 명시돼 회수 가능했음.

2. **vast pod 검증 불가 (ORPHAN 검출 부재)** — SrAuH₃ vast pod 생존 여부 확인 시도:
   ```
   $ ls /tmp/betenet/vast.py        # ad-hoc 추적 스크립트 → /tmp와 함께 소실
   GONE (reboot wiped /tmp)
   $ hexa cloud --help              # run|nohup|poll|copy-to|copy-from 뿐
   → instance list / reconcile verb 없음
   ```
   살아있는 vast pod가 있는지조차 **clean 채널로 확인 불가**. `/tmp/betenet/vast.py`는
   g8(no raw vastai/REST)를 우회하던 ad-hoc 스크립트였고, 그것마저 휘발 → 정확히 primary patch가
   지적한 ORPHAN 검출 부재 + downstream ad-hoc 추적의 휴먼-에러.

## 본 건이 강화하는 지점

- primary의 Fix B `hexa cloud ls --reconcile`(ORPHAN/GHOST 검출)이 있었으면 #2가 구조적으로 방지됨.
- primary의 Fix A registry `result_path` 필드가 있었으면 #1(result LOST)이 방지됨.
- d8(Vast finding → inbox so hexa cloud absorbs upstream) 준수 — 캠페인 내부에서 raw vast 호출로
  paper-over하지 않고 upstream gap으로 기록.
- provider 커버리지: anima=runpod, demiurge=vast → registry는 provider-generic이어야 함을 재확인
  (primary Fix A의 `"provider": "runpod" | "vast"` 필드 타당).
