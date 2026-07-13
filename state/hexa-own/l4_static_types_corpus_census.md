# L4 static-types corpus census — HEXA_STATIC_TYPES=1 default-ON 플립까지 남은 거리

출처: CI run 29257995039 (`.github/workflows/static-types-corpus.yml` · advisory)
게이트는 `continue-on-error: true` 라 PR 을 막지 않지만, DIRTY 면 의도적으로 exit 1 해서 빨갛게 보인다.

## 총계 (실측)

| 항목 | 값 |
|---|---|
| 검사 파일 | 3332 |
| dirty 파일 | 82 |
| HX3011/HX3016/HX3017/HX3024 emission | 147 |

→ **플립 조건 = 147 → 0**. 이게 L4 static-typing 레인의 유일한 측정 가능한 DONE 게이트다.

## 디렉토리 분포
```
  15 self/tui
  12 self/ml
  10 stdlib/qforge
   7 stdlib/rtsc
   6 self/attrs
   4 stdlib/test
   4 self/lsp
   3 stdlib/demi
   2 stdlib/deck
   2 stdlib/alloc
   2 self/tools
   2 self/test
   1 stdlib/wasm
   1 stdlib/verify
   1 stdlib/sim_universe
   1 stdlib/loop
   1 stdlib/kernels
   1 stdlib/easy
   1 stdlib/dojo
   1 stdlib/core
   1 stdlib/cockpit
   1 stdlib/aws
   1 self/stdlib
   1 self/serve
   1 compiler/intrinsics
```

## dirty 파일 전수 (82 · emission 내림차순)
```
stdlib/qforge/scratch_bank_store_selftest.hexa: 8
stdlib/qforge/scratch_bank_store.hexa: 7
stdlib/alloc/path.hexa: 7
stdlib/qforge/scratch_bank_selftest.hexa: 6
stdlib/qforge/checkpoint_selftest.hexa: 6
stdlib/qforge/scratch_bank.hexa: 5
stdlib/qforge/checkpoint_integration_selftest.hexa: 5
compiler/intrinsics/intrinsics.hexa: 5
stdlib/qforge/scf.hexa: 4
stdlib/qforge/scf_selftest.hexa: 4
stdlib/qforge/checkpoint.hexa: 4
stdlib/verify/blue_max_audit.hexa: 3
stdlib/rtsc/verify/empirical_specific_heat_arxiv.hexa: 2
stdlib/rtsc/verify/empirical_mcmillan_arxiv.hexa: 2
stdlib/rtsc/verify/empirical_hc2_high_field_arxiv.hexa: 2
stdlib/rtsc/verify/empirical_csh_arxiv.hexa: 2
stdlib/rtsc/verify/empirical_bcs_cooper_arxiv.hexa: 2
stdlib/rtsc/verify/empirical_abrikosov_sans_arxiv.hexa: 2
stdlib/kernels/logic_synth/passes.hexa: 2
stdlib/demi/dispatch.hexa: 2
stdlib/demi/demi_cli.hexa: 2
stdlib/demi/cellrun.hexa: 2
stdlib/cockpit/cellrun.hexa: 2
stdlib/alloc/argparse.hexa: 2
self/ml/profiler.hexa: 2
stdlib/wasm/wasm_export.hexa: 1
stdlib/test/test_record.hexa: 1
stdlib/test/test_jsonl_pool.hexa: 1
stdlib/test/test_io.hexa: 1
stdlib/test/test_channel.hexa: 1
stdlib/sim_universe/anu_stream/client_example.hexa: 1
stdlib/rtsc/origins/sc-dse/main.hexa: 1
stdlib/qforge/qforge_telemetry_selftest.hexa: 1
stdlib/loop/state.hexa: 1
stdlib/easy/cli.hexa: 1
stdlib/dojo/cli.hexa: 1
stdlib/deck/emit_run.hexa: 1
stdlib/deck/cli.hexa: 1
stdlib/core/trait_hash_fixture.hexa: 1
stdlib/aws/sigv4.hexa: 1
self/tui/wire/lsp_widget_host.hexa: 1
self/tui/wire/editor_bridge.hexa: 1
self/tui/wire.hexa: 1
self/tui/widget/text.hexa: 1
self/tui/widget/table.hexa: 1
self/tui/widget/progress.hexa: 1
self/tui/widget/modal.hexa: 1
self/tui/widget/list.hexa: 1
self/tui/widget/input.hexa: 1
self/tui/widget/indent.hexa: 1
self/tui/widget/diff.hexa: 1
self/tui/widget/box.hexa: 1
self/tui/render.hexa: 1
self/tui/input.hexa: 1
self/tui/app.hexa: 1
self/tools/safetensors_to_hexaw.hexa: 1
self/tools/lora_to_hexaw.hexa: 1
self/test/test_module_gate.hexa: 1
self/test/test_attr_mandatory.hexa: 1
self/stdlib/law_io.hexa: 1
self/serve/serve_alm.hexa: 1
self/ml/zeta_bench.hexa: 1
self/ml/visualize.hexa: 1
self/ml/train_logger.hexa: 1
self/ml/tokenizer_trainer.hexa: 1
self/ml/roadmap_tracker.hexa: 1
self/ml/monitor.hexa: 1
self/ml/lora_serve.hexa: 1
self/ml/hexaw.hexa: 1
self/ml/gpu_train.hexa: 1
self/ml/cuda_rtc.hexa: 1
self/ml/cuda_kernels.hexa: 1
self/lsp/test/test_import_surface.hexa: 1
self/lsp/server.hexa: 1
self/lsp/import_diagnostics.hexa: 1
self/lsp/handlers.hexa: 1
self/attrs/publish.hexa: 1
self/attrs/domain.hexa: 1
self/attrs/_publish_registry.hexa: 1
self/attrs/_domain/scaffold.hexa: 1
self/attrs/_domain/registry.hexa: 1
self/attrs/_domain/mk_bump.hexa: 1
```

## 판정 규율 (워크플로 스크립트 §F0 r9b 인용)

- true positive → 코퍼스 코드를 평범한 PR 로 고친다
- false positive → **flip-blocking checker rung** (체커 자체가 틀린 것)

즉 147 건은 먼저 TP/FP 분류가 선결이다. 82 파일 중 self/tui(15) + self/ml(12) + stdlib/qforge(10) = 37 파일(45%)이 3개 디렉토리에 몰려 있어, 패밀리 단위 처리가 가능하다.

## ⚠️ 계측 함정 (내가 실제로 빠진 것)

잡 이름 문자열이 `HX3011/HX3016/HX3017/HX3024/HX3025/HX3053/HX3054` 를 포함해서, 로그 전 줄에 접두로 붙는다.
`grep -oE "HX30[0-9]{2}" run.log | sort | uniq -c` 를 그대로 돌리면 **703 건**이 나오는데 전부 잡-이름 허수다.
반드시 `cut -f3-` 로 잡 이름/스텝/타임스탬프를 벗긴 뒤 세라.
