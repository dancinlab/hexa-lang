# RFC — runpod GraphQL builtin / cloud verb hexa-fn 표면 (PURE dispatcher 8 TODO unblock)

> **Status:** RESOLVED (2026-05-25) — 7/8 dispatcher needs were ALREADY
> covered by `stdlib/cloud/{runpod,cloud}.hexa` (landed via #86 GraphQL
> provider + #88 CLI-first/API-fallback). The §3 self-finding was correct:
> no new GraphQL builtin needed. The one genuine surface gap (§4-4 `save_pod`
> conditional teardown) is now closed by **`runpod_terminate_unless(api_key,
> pod_id, skip)`** in `stdlib/cloud/runpod.hexa` (compiled smoke PASS,
> RUNPODCTL_DISABLE path, no live API). The four acceptance items (§8) are
> documented in `stdlib/cloud/README.md` → "Wiring a downstream dispatcher".
> Note: canonical module keyword is `use`, NOT `import` (§4-1 reworded).
> Dispatcher → stdlib mapping:
>
> | dispatcher stub (anima)      | call                                        |
> |------------------------------|---------------------------------------------|
> | `pod_create`                 | `runpod_create_cascade`                     |
> | `pod_ssh_wait`               | `runpod_wait_ssh`                           |
> | `pod_terminate(_, save_pod)` | `runpod_terminate_unless(api_key, id, skip)`|
> | `corpus_build_*`             | `cloud_run`                                 |
> | `train_launch`               | `cloud_nohup`                               |
> | `result_pull`                | `cloud_copy_from`                           |
> | api_key sourcing             | `exec("secret get runpod.api_key").trim()`  |
> | sha256 ckpt verify           | caller-side (anima `sha256_verify` already) |
>
> anima may now do the stub→real rewiring (§4-4 note: ~30 min, separate PR).
>
> **From:** anima (downstream consumer)
> **Slug rule:** @D a_runpod_inbox — slug 에 `runpod` 명시

## § 1. background

anima HEXAD/PURE Track 1 closure 작업이 hexa dispatcher 포팅 단계에서 stub-only 상태로 막혀 있다. PR #295 (MERGED 2026-05-23) 가 `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` (225 LoC) 를 land 했으나 8 fn 이 `TODO[runpod|corpus|train|pull]` print-only — 실제 GPU dispatch 는 여전히 `dispatch_p21h_v3_runpod.sh` (304 LoC bash) 에 의존. anima project-tape 가 `.py`/`.sh` 신규 author 차단 (`@D hexa_only_authoring`) 이므로 본 RFC 가 land 되어야 dispatcher 가 true `.hexa` SSOT 가 된다.

## § 2. source-PR — 8 stub fn 표

anima PR #295 (MERGED) 의 stub fn 와 각 TODO marker, 해결에 필요한 hexa-lang 측 surface:

| anima fn (dispatch_p21h_v3.hexa) | TODO marker | 필요 surface |
|----------------------------------|-------------|--------------|
| `pod_create(init_variant, gpu_cascade)` | `TODO[runpod]` | `runpod_create_cascade` (이미 stdlib 존재) |
| `pod_ssh_wait(pod_id, max_tries)` | `TODO[runpod]` | `runpod_wait_ssh` (이미 stdlib 존재) |
| `pod_terminate(pod_id, save_pod)` | `TODO[runpod]` | `runpod_terminate` + `save_pod` 게이팅 (callsite) |
| `corpus_build_anima(ip, port, p21hr)` | `TODO[corpus]` | `cloud_run` (이미 stdlib 존재) |
| `corpus_build_multilingual_wiki(...)` | `TODO[corpus]` | `cloud_run` (동일) |
| `train_launch(ip, port, p21hr, env, init_variant, seed)` | `TODO[train]` | `cloud_nohup` (이미 stdlib 존재) |
| `result_pull(ip, port, p21hr, vdir)` | `TODO[pull]` | `cloud_copy_from` (이미 stdlib 존재) |
| (orchestration in `main`) | `TODO[*]` 표시 | 위 6 fn 의 wiring + `secret get runpod.api_key` 호출 |

## § 3. 발견 — 대부분 이미 stdlib 에 LANDED

`stdlib/cloud/{runpod,cloud}.hexa` 조사 결과 표면이 사실상 갖춰져 있음:

- `runpod_create(api_key, gpu_type, image, pubkey, name) -> RunPodPod`
- `runpod_create_cascade(api_key, gpu_types: [str], image, pubkey, name) -> RunPodPod`
- `runpod_wait_ssh(api_key, pod_id, max_tries, sleep_each_sec) -> RunPodSshPort`
- `runpod_terminate(api_key, pod_id) -> int`
- `runpod_list_pods() -> RunPodList`
- `cloud_run(host, argv) -> CloudResult`
- `cloud_nohup(host, argv, logfile) -> CloudResult`
- `cloud_poll(host, pid) -> int`
- `cloud_copy_to(host, local_path, remote_path) -> CloudResult`
- `cloud_copy_from(host, remote_path, local_path) -> CloudResult`

→ **anima 쪽 결론**: 신규 builtin 발명 불필요. 본 RFC 의 핵심 ask 는 “신규 fn” 가 아니라 “downstream 사용 패턴 공식화 + 미세 gap 메움”.

## § 4. ask — 4 항목

1. **공식 import path 문서화** — `import "<HEXA>/stdlib/cloud/runpod.hexa"` / `import "<HEXA>/stdlib/cloud/cloud.hexa"` (또는 짧은 별칭) 의 canonical 사용 예 를 `stdlib/cloud/README.md` 에 게재. anima 가 dispatcher 에서 즉시 import 가능해야 함.
2. **`secret get runpod.api_key` 정합** — 두 가지 옵션 중 선택을 명문화:
   - (a) caller 가 `exec("secret get runpod.api_key")` 로 읽어 `api_key` 인자 전달 (현 stdlib 시그니처)
   - (b) `runpod_create_from_secret(...)` 헬퍼 추가 — secret 키 명 (`runpod.api_key`) 을 SSOT 화
3. **`sha256_verify` 체인 통합 가이드** — PR #295 의 `sha256_verify(path, expected) -> dict` 가 anima 측에 LANDED. ckpt 무결성 검증을 dispatcher orchestration 흐름에 끼우는 패턴 (전: train_launch 직전, 후: result_pull 직후) 의 권장 위치 를 design 노트로.
4. **`save_pod` 분기 게이팅** — `runpod_terminate` 는 unconditional. anima 의 `pod_terminate(pod_id, save_pod)` 는 `save_pod="yes"` 시 skip 필요. stdlib 에 add 할지 (e.g. `runpod_terminate_unless(api_key, pod_id, skip: bool)`) vs callsite 분기 유지 할지 결정.

## § 5. secret 통합

현재 stdlib `runpod_*` 는 `api_key: str` 인자 first-class. anima 측 wiring 안:

```hexa
let api_key = exec_capture(["secret", "get", "runpod.api_key"])
let pod = runpod_create_cascade(api_key, ["H100 NVL", "H100 PCIe"], image, pubkey, "p21h-alpha-1337")
```

→ § 4-2 의 (a) 라면 위 패턴이 SSOT. (b) 라면 `runpod_create_from_secret(...)` 한 줄. anima 는 어느 쪽이든 수용 — 단, sidecar `commons.tape` g8 (canonical runpod dispatch) 와 분기되지 않도록 hexa-lang 측 단일 결정 권장.

## § 6. honest C3 (≥ 3)

1. **single-provider lock-in** — `runpod_*` 는 runpod 전용. vast.ai (`stdlib/cloud/vast.hexa` 존재) 와 multi-cloud 추상화 통합 vs provider-specific 분리 trade-off 는 본 RFC 범위 밖.
2. **GraphQL schema drift 위험** — runpod GraphQL response 가 변하면 stdlib 내부 파서 (`_runpod_create_api`, `_runpod_get_ssh_port_api`) 가 silent-fail 할 수 있음. stdlib 측 version pin + smoke contract 필요. anima 는 본 RFC 로 그 책임을 hexa-lang 에 위임.
3. **SSH key 관리** (pubkey upload, `known_hosts`, host-key TOFU) 는 stdlib 시그니처 (`pubkey: str` 인자) 가 caller 책임으로 둠. anima 는 `~/.ssh/id_ed25519.pub` 를 read 해서 넘기는 패턴 채용 예정 — stdlib 측 헬퍼 추가는 본 RFC 범위 밖.
4. **stub→real 전환 wall 시간** — anima 측 8 fn rewiring 자체는 1 cycle 이내 (~30 min) 예상; 본 RFC land 후 그 cycle 을 별도 PR 로 진행.

## § 7. alternatives

- **(a) shell exec 우회** — anima 측 8 stub 을 `exec(["runpodctl", ...])` / `exec(["ssh", ...])` 로 직접 채움. **REJECTED** — commons g11 (no gap workaround) + `@D a_runpod_inbox` (upstream inbox 우선).
- **(b) hexa-cloud CLI 외부 호출** — `exec(["hexa", "cloud", "run", host, cmd])` 처럼 subcommand 외부 호출. 작동은 하나 hexa-native fn import 보다 두꺼움 (process spawn × 8). 임시 fallback 으로만 수용.
- **(c) stdlib fn 직접 import** — § 3 발견대로 표면이 이미 존재. 본 RFC 의 § 4 4 항만 처리되면 즉시 채택 가능. **RECOMMENDED**.

## § 8. acceptance

`stdlib/cloud/README.md` 가 다음 4 절을 포함:
1. import path 공식 예 (anima dispatcher 직접 인용 가능)
2. `secret get runpod.api_key` 정합 패턴 (a/b 중 택일 명시)
3. sha256_verify 통합 권장 위치 design 노트
4. `save_pod` 게이팅 결정 (stdlib 추가 vs callsite)

land 후 anima 가 별도 PR 로 dispatcher 8 stub → real wiring 진행.

## § 9. related

- anima PR #295 (MERGED) — `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` v0 skeleton
- hexa-lang `stdlib/cloud/{runpod,cloud,vast}.hexa` — 이미 LANDED 표면
- hexa-lang inbox: `hexa-cloud-subcommand.md` (CLI 통합, MERGED) · `cloud-runpod-session-findings-anima-2026-05-23.md` · `stdlib-ssh-client.md`
- sidecar `commons.tape` g8 — canonical `hexa cloud` 정합 reference
- anima `@D a_runpod_inbox` — 본 RFC 의 라우팅 directive
