// map_query_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B — map-query DISPATCH).
// GENERATED: tool/regen_map_query_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o map_query_arm64-linux.s stdlib/runtime/map_query.hexa.
//   Provides the 8 map-query dispatcher natives (hexa_map_keys/values/entries/
//   map_values/filter_keys/count/any/all) as HX_MAP_TBL null-guard + delegate to
//   the already-hexa-source rt_map_* bodies. hexa_map_contains_key stays C
//   (mixed HexaVal/char*/int ABI — HEXA_RT_CORE_MAP_QUERY_CONTAINS_NATIVE sub-guard).
//   ABI: ELF aarch64, no underscore. External: delegates+ctors (all carrier-resolved in runtime.a, ZERO libc UND).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE + ar
//   this .o into runtime.a so the 8 dispatchers drop from the compiled runtime_core.c.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/map_query.hexa
.file 1 "stdlib/runtime/map_query.hexa"
.text
.globl hexa_map_keys
.hidden hexa_map_keys
    .p2align 2
hexa_map_keys:
    .loc 1 53 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L50a1_hexa_map_keys_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L50a1_hexa_map_keys_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_keys_bb1 // branch -> then
_L50a1_hexa_map_keys_bb1:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_keys_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L50a1_hexa_map_keys_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_keys_bb3 // branch -> then
_L50a1_hexa_map_keys_bb3:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_keys_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl rt_map_keys // call rt_map_keys
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_values
.hidden hexa_map_values
    .p2align 2
hexa_map_values:
    .loc 1 62 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L50a1_hexa_map_values_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L50a1_hexa_map_values_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_values_bb1 // branch -> then
_L50a1_hexa_map_values_bb1:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_values_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L50a1_hexa_map_values_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_values_bb3 // branch -> then
_L50a1_hexa_map_values_bb3:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_values_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl rt_map_values // call rt_map_values
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_entries
.hidden hexa_map_entries
    .p2align 2
hexa_map_entries:
    .loc 1 71 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L50a1_hexa_map_entries_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L50a1_hexa_map_entries_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_entries_bb1 // branch -> then
_L50a1_hexa_map_entries_bb1:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_entries_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L50a1_hexa_map_entries_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_entries_bb3 // branch -> then
_L50a1_hexa_map_entries_bb3:
    bl hexa_array_new // call hexa_array_new
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_entries_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl rt_map_entries // call rt_map_entries
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_map_values
.hidden hexa_map_map_values
    .p2align 2
hexa_map_map_values:
    .loc 1 82 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #240 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L50a1_hexa_map_map_values_bb0:
    bl hexa_map_new // call hexa_map_new
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _L50a1_hexa_map_map_values_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_map_values_bb1 // branch -> then
_L50a1_hexa_map_map_values_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_map_values_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L50a1_hexa_map_map_values_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_map_values_bb3 // branch -> then
_L50a1_hexa_map_map_values_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_map_values_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #48] // hv load L3
    bl rt_map_map_values // call rt_map_map_values
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_filter_keys
.hidden hexa_map_filter_keys
    .p2align 2
hexa_map_filter_keys:
    .loc 1 92 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #240 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L50a1_hexa_map_filter_keys_bb0:
    bl hexa_map_new // call hexa_map_new
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _L50a1_hexa_map_filter_keys_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_filter_keys_bb1 // branch -> then
_L50a1_hexa_map_filter_keys_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_filter_keys_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L50a1_hexa_map_filter_keys_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_filter_keys_bb3 // branch -> then
_L50a1_hexa_map_filter_keys_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_filter_keys_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #48] // hv load L3
    bl rt_map_filter_keys // call rt_map_filter_keys
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    add sp, sp, #240 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_count
.hidden hexa_map_count
    .p2align 2
hexa_map_count:
    .loc 1 104 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #384 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L50a1_hexa_map_count_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L50a1_hexa_map_count_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_count_bb1 // branch -> then
_L50a1_hexa_map_count_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_count_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _L50a1_hexa_map_count_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_count_bb3 // branch -> then
_L50a1_hexa_map_count_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_count_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _L50a1_hexa_map_count_bb6 // br_cond: !payload -> else
    b _L50a1_hexa_map_count_bb5 // branch -> then
_L50a1_hexa_map_count_bb5:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #336] // hv load L21
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_count_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_count_pred // call rt_map_count_pred
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_any
.hidden hexa_map_any
    .p2align 2
hexa_map_any:
    .loc 1 121 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L50a1_hexa_map_any_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L50a1_hexa_map_any_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_any_bb1 // branch -> then
_L50a1_hexa_map_any_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_any_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _L50a1_hexa_map_any_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_any_bb3 // branch -> then
_L50a1_hexa_map_any_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_any_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _L50a1_hexa_map_any_bb6 // br_cond: !payload -> else
    b _L50a1_hexa_map_any_bb5 // branch -> then
_L50a1_hexa_map_any_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_any_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_any_pred_b // call rt_map_any_pred_b
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_map_all
.hidden hexa_map_all
    .p2align 2
hexa_map_all:
    .loc 1 133 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L50a1_hexa_map_all_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L50a1_hexa_map_all_bb2 // br_cond: !payload -> else
    b _L50a1_hexa_map_all_bb1 // branch -> then
_L50a1_hexa_map_all_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_all_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _L50a1_hexa_map_all_bb4 // br_cond: !payload -> else
    b _L50a1_hexa_map_all_bb3 // branch -> then
_L50a1_hexa_map_all_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_all_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _L50a1_hexa_map_all_bb6 // br_cond: !payload -> else
    b _L50a1_hexa_map_all_bb5 // branch -> then
_L50a1_hexa_map_all_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L50a1_hexa_map_all_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_all_pred_b // call rt_map_all_pred_b
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",%progbits
