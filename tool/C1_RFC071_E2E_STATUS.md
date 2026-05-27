# C1 milestone — RFC 071 P1-P4 source-to-silicon e2e 상태

## 현재 상태 (P0 landed, P1-P4 deferred)

RFC 071 P0: `cmd_build` 가 `nvptx64-nvidia-cuda-sm{80,90,120}` target string 인식 → informative deferred exit + RFC pointer. CPU codegen path 무영향 (F-RFC071-CPU-CODEGEN-UNTOUCHED).

P1-P4 = 실제 dispatch + emit-driver + module_loader bridge + silicon fire 통합.

## P1-P4 작업 분할

| Phase | 작업 | 추정 PR |
|---|---|---|
| P1 | `cmd_build --target=nvptx64-*` 가 실제 `compiler/codegen/nvptx_target.hexa::codegen_emit_ptx_sm80` 호출 | 2-3 PR (in-hexa compiler self-host expose) |
| P2 | Emit-driver module — `tool/build_nvptx.hexa` (이미 존재) 와 `cmd_build` 통합 | 1 PR |
| P3 | `module_loader` bridge — `@gpu_kernel fn`s 만 flatten 후 emit | 1-2 PR |
| P4 | silicon fire — `hexa build kernel.hexa --target=nvptx64-sm_80` → `.ptx` artifact → ubu-2 driver-JIT | 1 fire PR |

## 현재 대안 (out-of-band pattern)

`/tmp/nvptx_emit_<session>` binary로 8 silicon fires 모두 성공 (#1278, #1323, #1336, #1337, #1346, #1411, etc). **`hexa build` 통합 없이도 silicon validation 가능** — P1-P4 는 ergonomics, 필수 인프라 아님.

## g0 권고

Occam's razor — 현재 out-of-band 패턴이 충분하면 P1-P4 deferred 유지. self-host 통합은 strategic multi-cycle 작업으로 별도 큐.

## 다음 cycle 시작 시그널

production용 kernel 코드 (stdlib/flame, stdlib/forge) 가 일상적으로 `hexa build` 호출하면서 GPU target을 요청할 때. 현재는 모두 nvptx_emit 직접 호출이라 압박 없음.
