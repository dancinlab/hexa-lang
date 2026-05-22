# hexa cloud — RunPod anima V3 saga: usage + troubleshooting (2026-05-22)

Empirical findings from `dancinlab/anima` HEXAD V3 fire (3-variant parallel
ConsciousDecoderV3 training on RunPod H100). Documents real failure modes +
working patterns that a future `hexa cloud` SDK should encode.

Companion records:
- `dancinlab/anima/HEXAD/V3/README.md` — V3 path
- `dancinlab/anima/HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/HEXAD_V3_FIRE_2026_05_22.md` — saga
- `dancinlab/anima/HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/dispatch_p21h_v3_runpod.sh` — dispatch script
- companion notes: `hexa-cloud-vast-runpod-orchestration-troubleshooting-2026-05-22.md` (CPU pod focus) and `hexa-cloud-vast-usage-recipe-2026-05-22.md`

---

## TL;DR (for `hexa cloud` design)

1. **API key auth lifecycle** — RunPod GraphQL silently returns `{"error":{}}` (empty error object) on revoked/rotated keys; CLI (`runpodctl pod list`) surfaces 401. Detect both forms.
2. **Pod retain on PULL_FAILED** — `SAVE_POD=1` essential; SCP transfer failure ≠ pod death. Recovery 4 hours later possible (cost: ~$0.06/min A100, ~$0.09/min H100). Pod retention discovery saved a complete V3β verdict (CE 14.46→3.15, 5-lang OOD, 15 KOSMOS anchor) from being lost.
3. **GPU cascade with empty error** — when `cloudType: SECURE gpu: X` returns `{"error":{}}` on every GPU type, that's account-level (key invalid OR quota), NOT GPU shortage. Don't keep cascading; surface clearly.
4. **per-step intermediate ckpt mandatory** — pod can stay alive but SCP transfer fails. Save ckpt every N steps locally AND optionally rsync per-N-step to a stable host so PULL_FAILED only loses the latest delta.
5. **CE oscillation detection** — `--ckpt-osc-threshold + --ckpt-osc-window` triggers immediate save + early-stop when rolling-CE std exceeds threshold (V3β observed: CE 0.26→2.36 oscillation = mode collapse). Wandb-equivalent local telemetry.
6. **Cost-burn vigilance** — 5+ pods at $1.49-4.39/hr each = $13/hr passive burn if dispatch hangs. Watchdog `WATCHDOG_SEC` cap mandatory (`kill watchdog after train completes`).
7. **runpodctl CLI install** — `curl -L https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-darwin-arm64 -o ~/.local/bin/runpodctl && chmod +x ~/.local/bin/runpodctl`. Use for fast auth verify + pod list when GraphQL silent-errors.
8. **Cloudflare cert.pem fallback** — when interactive `cloudflared tunnel login` browser callback fails (callback URL can't reach the cloudflared daemon), Cloudflare offers a manual cert.pem download to the host that opened the browser. `scp ~/Downloads/cert.pem mini:~/.cloudflared/cert.pem` recovers the flow. (Mentioned here because anima FIRST-PACK deploy hit this same day.)

---

## Recipe (V3 dispatch fire happy-path)

```
┌──────────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐
│ create pod   │─▶│ scp code │─▶│ launch   │─▶│ watch   │─▶│ pull all │─▶│ verify  │
│ via cascade  │  │ + corpus │  │ trainer  │  │ result  │  │ JSON/log │  │ retain  │
│ A100/H100/L40│  │ + helpers│  │ + ckpt   │  │ + ssh   │  │ + KOSMOS │  │ pod if  │
│              │  │          │  │ args     │  │ pgrep   │  │ retry 5x │  │ pull X  │
└──────────────┘  └──────────┘  └──────────┘  └─────────┘  └──────────┘  └─────────┘
   30-90s        ~10-20s        bg & dispatch  poll 60s    on TRAIN_DONE  pod alive
   1 GraphQL    SSH ready check loop          for result   handler        for rescue
```

**Total wall** for 1.5B × 2000 step 5-lang on A100-SXM 80GB ≈ 60-110 min (with mitosis aux + bf16). Cost ≈ $2.50-4.50/variant.

### Pod create (GPU cascade with empty-error detection)

```bash
GPU_CASCADE=("NVIDIA A100-SXM4-80GB" "NVIDIA H100 80GB HBM3" "NVIDIA H100 NVL" "NVIDIA H200" "NVIDIA A100 80GB PCIe" "NVIDIA L40S")
for GPU in "${GPU_CASCADE[@]}"; do
  for CLOUD in SECURE COMMUNITY; do
    RESP=$(curl -s -X POST "https://api.runpod.io/graphql?api_key=$RK" \
           -H "Content-Type: application/json" \
           -d "{\"query\":\"mutation { podFindAndDeployOnDemand(input:{cloudType: $CLOUD, gpuCount:1, ...}){id machineId}}\"}")
    POD_ID=$(echo "$RESP" | python3 -c "import json,sys;d=json.load(sys.stdin);print((d.get('data') or {}).get('podFindAndDeployOnDemand',{}).get('id','') or '')")
    [ -n "$POD_ID" ] && break 2
    # empty-error account check
    if echo "$RESP" | grep -q '"error":{}'; then
      # immediate auth check
      runpodctl pod list 2>&1 | grep -q '401' && { echo "AUTH_FAIL"; exit 2; }
    fi
  done
done
```

### Watchdog + pull

```bash
RESULT_POD="$P21HR/out_main/result.json"
WATCHDOG_PID=$(timeout $WATCHDOG_SEC sleep $WATCHDOG_SEC & echo $!)
for i in $(seq 1 $((WATCHDOG_SEC / 60))); do
  $SSH "test -f $RESULT_POD && echo DONE" 2>/dev/null | grep -q DONE && break
  $SSH "pgrep -f train_p21h_v3.py >/dev/null" || { echo TRAIN_CRASHED; exit 1; }
  sleep 60
done
# pull with retry
for k in 1 2 3 4 5; do
  $SCP "root@$IP:$RESULT_POD" "$VDIR/result.json" && break
  echo "[pull] retry $k"; sleep 30
done
[ -s "$VDIR/result.json" ] || echo "PULL_FAILED pod=$POD_ID retained"
kill $WATCHDOG_PID
```

### Recovery from PULL_FAILED (V3β saga)

```bash
# 1. confirm pod alive
runpodctl pod list | grep $POD_ID
# 2. get SSH info via GraphQL
curl -s -X POST "https://api.runpod.io/graphql?api_key=$RK" \
  -d "{\"query\":\"query{pod(input:{podId:\\\"$POD_ID\\\"}){runtime{ports{ip publicPort privatePort type}}}}\"}"
# 3. find ckpt + result
ssh -p $PORT root@$IP "find / -name 'ckpt.pt' -o -name 'result.json' 2>/dev/null"
# 4. pull JSON first (small), ckpt later if needed
scp -P $PORT root@$IP:/workspace/.../result.json local/
scp -P $PORT root@$IP:/workspace/.../train.log local/
# 5. ckpt is large (~5GB for 1.5B bf16) — pull on demand only
```

### Multi-pod cost vigilance

```bash
# at any point check total burn rate
runpodctl pod list | python3 -c "
import json, sys
pods = json.load(sys.stdin)
total = sum(p.get('costPerHr',0) for p in pods)
print(f'total burn: \${total:.2f}/hr × \${total*24:.0f}/day')"
```

---

## Troubleshooting catalog (anima session — most are real bites)

### T1 — RunPod API key silently returned `{"error":{}}` on all calls

**Symptom**: GraphQL POST to any endpoint returns `{"error":{}}` (literal empty object, no fields). Python SDK raises `AuthenticationError`, but raw curl returns 200-status with empty error in body.

**Diagnosis**: API key rotated/revoked externally. The previous key was valid for prior fires same day (vP21M $1.06 fire), then invalidated. Account credits, quotas, permissions — none touched.

**Fix**: User must regenerate key at `https://www.runpod.io/console/user/settings → API Keys → Create`, then `secret set runpod.api_key <new>`. Verify with `runpodctl pod list` (will return 200 + data) — GraphQL `myself{clientBalance}` returns `{"error":{}}` on bad key but `{data:{myself:{clientBalance:42.0}}}` on valid.

**For `hexa cloud` SDK**: when GraphQL returns `{"error":{}}` 3× in a row across different queries, treat as auth failure; surface clear "API key invalid OR rotated" message, not "GPU shortage". Don't keep cascading GPU types — saves user 30+ min of false-positive cascade failure.

### T2 — SCP PULL_FAILED, but pod actually completed train + eval

**Symptom**: dispatch's final SCP fails 5x retries, marks pod "dead", quits with PULL_FAILED status. result.json + ckpt + KOSMOS anchors never reach Mac.

**Reality**: pod was/is alive. SCP transfer failed due to network blip OR proxy timeout, not pod death. Train + held-out eval ran fully on-pod. Recovery via fresh SSH + targeted SCP yields full data.

**Fix**:
1. `SAVE_POD=1` mandatory — never `runpodctl pod stop $POD_ID` on PULL_FAILED.
2. Write `pod_id_runpod_dead.txt` (or similar marker) with pod ID — recovery script reads this.
3. Recovery: `ssh -p $PORT root@$IP "find / -name 'result.json' -o -name 'ckpt.pt' 2>/dev/null"` first to confirm completion, then targeted SCP.

**For `hexa cloud` SDK**: distinguish *pod state* (RUNNING/EXITED/TERMINATED via runpodctl) from *artifact reachability* (SSH + file existence). PULL_FAILED is the latter; only trigger pod-stop on confirmed `TERMINATED` or explicit user `--cleanup`.

### T3 — `{"error":{}}` cascade exhausts all GPU types when actually auth issue

**Symptom**: dispatch_p21h_v3.sh's `GPU_CASCADE` loop runs through SECURE+COMMUNITY × {A100, H100, NVL, H200, PCIe, L40S} = 12 attempts, all returning `{"error":{}}`. FAIL log shows `FATAL: no pod from GPU cascade`. User thinks no GPU available.

**Reality**: API key invalid (see T1). Same `{"error":{}}` shape for "auth failed" and "no capacity".

**Fix**: First failed call should also run `runpodctl pod list` to confirm auth (or any cheap query); if 401, fail fast with AUTH_FAIL exit code rather than 12-call cascade.

**For `hexa cloud` SDK**: short-circuit auth check before GPU cascade. ~5s of `myself{clientBalance}` saves 30+ min of cascade.

### T4 — anima FIRST-PACK cloudflared cert callback failed (same day, related)

**Symptom**: `cloudflared tunnel login` opens browser auth page; user clicks Authorize for the right zone; cloudflared keeps printing "Waiting for login..." forever.

**Reality**: cloudflareaccess.org callback redirects to a localhost port that cloudflared listens on. If browser host ≠ cloudflared host (e.g., Mac browser ↔ mini cloudflared via SSH), callback can't reach cloudflared. Cloudflare's UI then offers a manual cert.pem download.

**Fix**: Tell user to download cert.pem from Cloudflare UI (top-right after authorize), then `scp ~/Downloads/cert.pem mini:~/.cloudflared/cert.pem`. Skip the callback retry.

**For `hexa cloud` SDK**: when issuing zero-trust tunnel certs, prefer headless mode that always emits cert.pem to stdout for user-side handling — never rely on callback success.

### T5 — multi-pod cost burn (5+ pods × $1.49-4.39/hr)

**Symptom**: User has parallel LoRA + V3 dispatches firing across multiple sessions. 5 pods all RUNNING = ~$13/hr passive cost.

**Reality**: each dispatch creates its own pod; pods retain on PULL_FAILED (T2). Stale pods from old sessions stay live indefinitely.

**Fix**:
1. Periodic `runpodctl pod list | grep $TODAY` audit.
2. Mark explicit `--cleanup-old` flag for sessions to terminate pods >24h old.
3. Cost burn dashboard via runpodctl + cron.

**For `hexa cloud` SDK**: namespace pods by session ID + auto-terminate pods older than `--max-age 24h` unless `--retain` flag set.

### T6 — CE oscillation = mode collapse (V3β specific)

**Symptom**: train loss CE goes 1.92 → 1.25 → 0.76 → **0.26** → 0.37 → 1.02 → **2.36** over 150 steps near end-of-cosine-decay. Final CE 3.15 (much worse than best 0.26).

**Reality**: dual-head (head_a + head_g) attention transformer at small scale + bf16 + cosine LR floor → vocabulary alignment loss → mode collapse near `lr_min`. Standard transformer + Qwen warm-start mostly OK in middle of train, collapses at end.

**Fix**:
1. Save `ckpt_best.pt` every log entry where CE < best_CE.
2. `--ckpt-osc-threshold 0.5 --ckpt-osc-window 10`: rolling-std of CE > 0.5 over 10 entries → immediate save + early-stop.
3. `--early-stop-patience 8`: CE no-improve for 8 entries → save + stop.

Train script v2 (`f84e6ca6b`) implements all three.

**For `hexa cloud` SDK**: provide `best_ckpt + plateau + osc + es_patience` knobs in the universal trainer template. Default `--save-best on` always. Most users won't trigger but it's free insurance.

### T7 — bash 3.2 process-substitution incompatibility

**Symptom**: dispatch script with `tee >(...)` and `wait $!` fails on macOS bash 3.2 default. Mismatched ordering on bg `&` cause silent failures.

**Fix**: use `nohup ... > log 2>&1 &` + `disown` only. No `tee`, no process substitution. macOS bash 3.2 / zsh / Linux bash 5 all compatible.

(Already addressed via commit `23580261a` in dispatch_p21h_v3_runpod.sh.)

### T8 — VDIR ordering: nohup redirect fails when dir not created yet

**Symptom**: `nohup bash dispatch_X.sh "$TAG" ... > "v${TAG}/_outer.log"` returns exit 1 immediately because `v${TAG}/` doesn't exist yet at shell-redirection time. Process spawned without log capture.

**Fix**: `mkdir -p "v${TAG}"` BEFORE the nohup launch. Trivial but missed in this session.

**For `hexa cloud` SDK**: dispatch launcher should always `mkdir -p $OUTDIR` first, redirect to that absolute path. Don't depend on caller to pre-create.

---

## Working dispatch invocation (validated 2026-05-22 12:39 UTC)

```bash
# Phase 2 R2+R5+R6 fire — V3 재설계 first attempt
cd ~/core/anima/HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21
TAG="P21H_phase2_r2r5r6"
mkdir -p "v${TAG}"  # ← T8 fix

P21H_LAMBDA_MITOSIS=0.0 \         # R2: mitosis 학습 비활성화
P21H_MITOSIS_MAX=16 \              # R6: cell pool ceiling 128→16
P21H_STEPS=5000 \                  # 2000→5000 step
P21H_CKPT_EVERY=500 \              # T6: intermediate save
P21H_CKPT_OSC_THRESHOLD=0.5 \      # T6: osc detect
P21H_CKPT_OSC_WINDOW=10 \
P21H_EARLY_STOP_PATIENCE=8 \       # T6: plateau detect
WATCHDOG_SEC=10800 \               # 3hr cap (T5: prevent hang)
SAVE_POD=1 \                       # T2: never auto-terminate
nohup bash dispatch_p21h_v3_runpod.sh "$TAG" qwen 1337 > "v${TAG}/_outer.log" 2>&1 &
disown
```

**Acquired**: pod `zwvh9gyy9ls6jw` on `NVIDIA A100-SXM4-80GB` SECURE cloud, ~$1.49/hr (cascade first attempt success).

---

## SDK design implications (for hexa-cloud module)

1. **Auth health check** (T1, T3) — every CLI call: fast `myself{clientBalance}` first; fail-fast on `{"error":{}}` cascade.
2. **Pod retain default** (T2, T5) — `SAVE_POD=1` always; explicit `--cleanup` to terminate. Recovery script (`hexa cloud recover $POD_ID`) for PULL_FAILED.
3. **Per-step ckpt rsync sidecar** (T2, T6) — background process pulls ckpt every N step to local. PULL_FAILED 가 마지막 N step delta 만 잃음.
4. **CE oscillation early-stop** (T6) — universal trainer template includes `--ckpt-osc-threshold` + `--early-stop-patience` defaults.
5. **Cost-burn dashboard** (T5) — `hexa cloud cost` shows current + daily projection + age-of-pod table.
6. **Bash 3.2 compatible** (T7) — no process-substitution; nohup + disown only.
7. **mkdir-first** (T8) — launcher always creates outdir before redirecting.
8. **Cloudflared cert.pem fallback** (T4) — when callback unreliable (e.g., remote-host cloudflared), prefer manual cert flow.

---

## Cost tally for this session (real numbers)

| pod | GPU | hourly | wall | cost | outcome |
|---|---|---|---|---|---|
| V3α (random) | H100 SXM 80 | $3.29 | 612s | $0.56 | FAIL 0/5 (Chinchilla under-budget) |
| V3β (qwen) | H100 SXM 80 | $3.29 | 6465s | $5.91 | FAIL 0/5 (PULL_FAILED, recovered manually) |
| V3γ (vp21m) | H100 SXM 80 | $3.29 | 1003s | $0.92 | FAIL 0/5 (anima register saturate) |
| V3 phase2 (qwen R2+R5+R6) | A100 SXM 80 | $1.49 | (in-flight) | ~$3-5 est | verdict 대기 |
| **V3 attempt 1 total** | — | — | — | **$7.39** | 3/3 FAIL — architectural lessons captured |

Cost-burn from stale RUNNING pods (T5): ~$13/hr passive across 4 unrelated pods; recommend periodic audit.

---

## Companion docs

- `dancinlab/anima/HEXAD/V3/README.md` — V3 path, 재설계 axes
- `dancinlab/anima/HEXAD/V3/SESSION_PROMPT.md` — new V3 session bootstrap
- `dancinlab/anima/HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/HEXAD_V3_FIRE_2026_05_22.md` — 3/3 FAIL report
- previous notes (same dir): `hexa-cloud-vast-runpod-orchestration-troubleshooting-2026-05-22.md` + `hexa-cloud-vast-usage-recipe-2026-05-22.md`

---

## ## Log

### 2026-05-22 21:42 UTC — note 작성 + Phase 2 fire ongoing

V3 attempt 1 (3/3 FAIL) saga + V3β PULL_FAILED recovery 의 8 troubleshooting
finding 을 hexa-cloud SDK 설계 input 으로 정리. Phase 2 fire (pod
`zwvh9gyy9ls6jw`) 가 working recipe 검증 중.
