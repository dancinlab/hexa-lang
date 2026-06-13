# patch: pod self-teardown must use RunPod GraphQL podTerminate, not `runpodctl pod`

## symptom (observed 2026-06-13, anima 7B fire)
A pod-side self-teardown watcher detected DONE + HF-verified and tried to self-terminate, but the call FAILED:

```
[watcher] DONE + HF-verified -> self-terminating
Error: unknown command "pod" for "runpodctl"
```

The `runpodctl` version on the pod image has NO `pod` subcommand. The teardown silently failed, so the pod idle-ran ~17h burning ~$2.59/hr (~$44 wasted) until a manual check caught it.

## fix
Self-teardown should call the RunPod GraphQL API directly (version-independent), not `runpodctl pod terminate`:

```bash
curl -s -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
  -X POST https://api.runpod.io/graphql \
  -d "{\"query\":\"mutation{podTerminate(input:{podId:\\\"$POD_ID\\\"})}\"}"
```

(verified working — terminated anima pod uq71dp0ob6fd9r this way.)

## belt-and-suspenders
- self-teardown should `echo` the terminate command's exit status + response to its log and, on non-zero/parse-failure, retry once + emit a LOUD marker so a watcher/poller notices the pod is DONE-but-alive.
- a host-side poller should flag any pod whose GPU util==0 AND no train proc for >N min as "DONE-but-burning" → manual/auto teardown.
