// float_parse_exact_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-exact).
// GENERATED: tool/regen_float_parse_exact_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o float_parse_exact_arm64-linux.s stdlib/runtime/float_parse_exact.hexa.
//   Provides the EXACT correctly-rounded decimal->f64 tail
//   (rt_str_parse_float_exact) as a native big-integer (David Gay / glibc
//   strtod __mpn front + integer round-half-even) body that replaces the
//   strtod TAIL the Clinger fast path declines. Bit-exact to strtod over the
//   full finite-decimal domain; returns a TAG_VOID sentinel for
//   hex/inf/nan/malformed so the C wrapper still falls back to strtod.
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF aarch64, rt_str_parse_float_exact no underscore. External: hexa array runtime (resolved within runtime.a).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_EXACT (opt-IN)
//   + ar this .o into runtime.a so __hexa_num_parse_float composes
//   fast(Clinger) -> exact(this) -> C strtod.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/float_parse_exact.hexa
.file 1 "stdlib/runtime/float_parse_exact.hexa"
.text
.globl fpe_norm
.hidden fpe_norm
    .p2align 2
fpe_norm:
    .loc 1 59 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #272 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_norm_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_norm_bb1 // branch
_L7b0c_fpe_norm_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _L7b0c_fpe_norm_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_norm_bb2 // branch -> then
_L7b0c_fpe_norm_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _L7b0c_fpe_norm_bb5 // br_cond: !payload -> else
    b _L7b0c_fpe_norm_bb4 // branch -> then
_L7b0c_fpe_norm_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_norm_bb6 // branch
_L7b0c_fpe_norm_bb4:
    b _L7b0c_fpe_norm_bb3 // branch
_L7b0c_fpe_norm_bb5:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_norm_bb1 // branch
_L7b0c_fpe_norm_bb6:
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _L7b0c_fpe_norm_bb8 // br_cond: !payload -> else
    b _L7b0c_fpe_norm_bb7 // branch -> then
_L7b0c_fpe_norm_bb7:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_norm_bb6 // branch
_L7b0c_fpe_norm_bb8:
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #272 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_is_zero
.hidden fpe_is_zero
    .p2align 2
fpe_is_zero:
    .loc 1 75 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #64 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_is_zero_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _L7b0c_fpe_is_zero_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_is_zero_bb1 // branch -> then
_L7b0c_fpe_is_zero_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #64 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_is_zero_bb2:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #64 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_from
.hidden fpe_from
    .p2align 2
fpe_from:
    .loc 1 80 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #128 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_from_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_fpe_from_bb1 // branch
_L7b0c_fpe_from_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L7b0c_fpe_from_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_from_bb2 // branch -> then
_L7b0c_fpe_from_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_fpe_from_bb1 // branch
_L7b0c_fpe_from_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #128 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_cmp
.hidden fpe_cmp
    .p2align 2
fpe_cmp:
    .loc 1 90 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #384 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_cmp_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _L7b0c_fpe_cmp_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_cmp_bb1 // branch -> then
_L7b0c_fpe_cmp_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_cmp_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    cbz x1, _L7b0c_fpe_cmp_bb4 // br_cond: !payload -> else
    b _L7b0c_fpe_cmp_bb3 // branch -> then
_L7b0c_fpe_cmp_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_cmp_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_cmp_bb5 // branch
_L7b0c_fpe_cmp_bb5:
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _L7b0c_fpe_cmp_bb7 // br_cond: !payload -> else
    b _L7b0c_fpe_cmp_bb6 // branch -> then
_L7b0c_fpe_cmp_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #240] // hv load L15
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _L7b0c_fpe_cmp_bb9 // br_cond: !payload -> else
    b _L7b0c_fpe_cmp_bb8 // branch -> then
_L7b0c_fpe_cmp_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_cmp_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_cmp_bb9:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #320] // hv load L20
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    cbz x1, _L7b0c_fpe_cmp_bb11 // br_cond: !payload -> else
    b _L7b0c_fpe_cmp_bb10 // branch -> then
_L7b0c_fpe_cmp_bb10:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_cmp_bb11:
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_cmp_bb5 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #384 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_add
.hidden fpe_add
    .p2align 2
fpe_add:
    .loc 1 104 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #528 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_add_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _L7b0c_fpe_add_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_add_bb1 // branch -> then
_L7b0c_fpe_add_bb1:
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    b _L7b0c_fpe_add_bb2 // branch
_L7b0c_fpe_add_bb2:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #176] // hv store L11
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_add_bb3 // branch
_L7b0c_fpe_add_bb3:
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _L7b0c_fpe_add_bb5 // br_cond: !payload -> else
    b _L7b0c_fpe_add_bb4 // branch -> then
_L7b0c_fpe_add_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _L7b0c_fpe_add_bb7 // br_cond: !payload -> else
    b _L7b0c_fpe_add_bb6 // branch -> then
_L7b0c_fpe_add_bb5:
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _L7b0c_fpe_add_bb11 // br_cond: !payload -> else
    b _L7b0c_fpe_add_bb10 // branch -> then
_L7b0c_fpe_add_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _L7b0c_fpe_add_bb7 // branch
_L7b0c_fpe_add_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _L7b0c_fpe_add_bb9 // br_cond: !payload -> else
    b _L7b0c_fpe_add_bb8 // branch -> then
_L7b0c_fpe_add_bb8:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #288] // hv store L18
    b _L7b0c_fpe_add_bb9 // branch
_L7b0c_fpe_add_bb9:
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #400] // hv load L25
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_fpe_add_bb3 // branch
_L7b0c_fpe_add_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #496] // hv store L31
    b _L7b0c_fpe_add_bb11 // branch
_L7b0c_fpe_add_bb11:
    ldp x0, x1, [sp, #160] // hv load L10
    bl fpe_norm // call fpe_norm
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_sub
.hidden fpe_sub
    .p2align 2
fpe_sub:
    .loc 1 127 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #416 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_sub_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_sub_bb1 // branch
_L7b0c_fpe_sub_bb1:
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L7b0c_fpe_sub_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_sub_bb2 // branch -> then
_L7b0c_fpe_sub_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _L7b0c_fpe_sub_bb5 // br_cond: !payload -> else
    b _L7b0c_fpe_sub_bb4 // branch -> then
_L7b0c_fpe_sub_bb3:
    ldp x0, x1, [sp, #112] // hv load L7
    bl fpe_norm // call fpe_norm
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_sub_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #208] // hv store L13
    b _L7b0c_fpe_sub_bb5 // branch
_L7b0c_fpe_sub_bb5:
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_sub // binop -
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_sub // binop -
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _L7b0c_fpe_sub_bb7 // br_cond: !payload -> else
    b _L7b0c_fpe_sub_bb6 // branch -> then
_L7b0c_fpe_sub_bb6:
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #304] // hv store L19
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    b _L7b0c_fpe_sub_bb8 // branch
_L7b0c_fpe_sub_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    b _L7b0c_fpe_sub_bb8 // branch
_L7b0c_fpe_sub_bb8:
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_sub_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_mul_small
.hidden fpe_mul_small
    .p2align 2
fpe_mul_small:
    .loc 1 150 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #400 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_mul_small_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _L7b0c_fpe_mul_small_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_small_bb1 // branch -> then
_L7b0c_fpe_mul_small_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_mul_small_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _L7b0c_fpe_mul_small_bb3 // branch
_L7b0c_fpe_mul_small_bb3:
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _L7b0c_fpe_mul_small_bb5 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_small_bb4 // branch -> then
_L7b0c_fpe_mul_small_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #160] // hv load L10
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_mul // binop *
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #160] // hv store L10
    b _L7b0c_fpe_mul_small_bb3 // branch
_L7b0c_fpe_mul_small_bb5:
    b _L7b0c_fpe_mul_small_bb6 // branch
_L7b0c_fpe_mul_small_bb6:
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _L7b0c_fpe_mul_small_bb8 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_small_bb7 // branch -> then
_L7b0c_fpe_mul_small_bb7:
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_mul_small_bb6 // branch
_L7b0c_fpe_mul_small_bb8:
    ldp x0, x1, [sp, #128] // hv load L8
    bl fpe_norm // call fpe_norm
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_mul
.hidden fpe_mul
    .p2align 2
fpe_mul:
    .loc 1 169 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #784 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_mul_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl fpe_is_zero // call fpe_is_zero
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L7b0c_fpe_mul_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb1 // branch -> then
_L7b0c_fpe_mul_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_mul_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl fpe_is_zero // call fpe_is_zero
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _L7b0c_fpe_mul_bb4 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb3 // branch -> then
_L7b0c_fpe_mul_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_mul_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #256] // hv store L16
    b _L7b0c_fpe_mul_bb5 // branch
_L7b0c_fpe_mul_bb5:
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _L7b0c_fpe_mul_bb7 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb6 // branch -> then
_L7b0c_fpe_mul_bb6:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #256] // hv store L16
    b _L7b0c_fpe_mul_bb5 // branch
_L7b0c_fpe_mul_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #336] // hv store L21
    b _L7b0c_fpe_mul_bb8 // branch
_L7b0c_fpe_mul_bb8:
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _L7b0c_fpe_mul_bb10 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb9 // branch -> then
_L7b0c_fpe_mul_bb9:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #368] // hv store L23
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #384] // hv store L24
    b _L7b0c_fpe_mul_bb11 // branch
_L7b0c_fpe_mul_bb10:
    ldp x0, x1, [sp, #240] // hv load L15
    bl fpe_norm // call fpe_norm
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_mul_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    cbz x1, _L7b0c_fpe_mul_bb13 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb12 // branch -> then
_L7b0c_fpe_mul_bb12:
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #432] // hv load L27
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #464] // hv load L29
    ldp x2, x3, [sp, #480] // hv load L30
    bl hexa_mul // binop *
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #448] // hv load L28
    ldp x2, x3, [sp, #496] // hv load L31
    bl hexa_add_slow // binop +
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    ldp x2, x3, [sp, #368] // hv load L23
    bl hexa_add_slow // binop +
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #432] // hv load L27
    add x15, sp, #560 // hv frame base
    ldp x4, x5, [x15] // hv load L35
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #240] // hv store L15
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    stp x0, x1, [sp, #384] // hv store L24
    b _L7b0c_fpe_mul_bb11 // branch
_L7b0c_fpe_mul_bb13:
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_add_slow // binop +
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _L7b0c_fpe_mul_bb14 // branch
_L7b0c_fpe_mul_bb14:
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _L7b0c_fpe_mul_bb16 // br_cond: !payload -> else
    b _L7b0c_fpe_mul_bb15 // branch -> then
_L7b0c_fpe_mul_bb15:
    ldp x0, x1, [sp, #240] // hv load L15
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    ldp x2, x3, [sp, #368] // hv load L23
    bl hexa_add_slow // binop +
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #240] // hv load L15
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    add x15, sp, #704 // hv frame base
    ldp x4, x5, [x15] // hv load L44
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #240] // hv store L15
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #368] // hv store L23
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _L7b0c_fpe_mul_bb14 // branch
_L7b0c_fpe_mul_bb16:
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    stp x0, x1, [sp, #336] // hv store L21
    b _L7b0c_fpe_mul_bb8 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_pow2
.hidden fpe_pow2
    .p2align 2
fpe_pow2:
    .loc 1 204 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_pow2_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_pow2_bb1 // branch
_L7b0c_fpe_pow2_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _L7b0c_fpe_pow2_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_pow2_bb2 // branch -> then
_L7b0c_fpe_pow2_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8192 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_pow2_bb1 // branch
_L7b0c_fpe_pow2_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_pow2_bb4 // branch
_L7b0c_fpe_pow2_bb4:
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L7b0c_fpe_pow2_bb6 // br_cond: !payload -> else
    b _L7b0c_fpe_pow2_bb5 // branch -> then
_L7b0c_fpe_pow2_bb5:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_pow2_bb4 // branch
_L7b0c_fpe_pow2_bb6:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #128] // hv load L8
    bl fpe_mul_small // call fpe_mul_small
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_pow10
.hidden fpe_pow10
    .p2align 2
fpe_pow10:
    .loc 1 223 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_pow10_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_pow10_bb1 // branch
_L7b0c_fpe_pow10_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _L7b0c_fpe_pow10_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_pow10_bb2 // branch -> then
_L7b0c_fpe_pow10_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_pow10_bb1 // branch
_L7b0c_fpe_pow10_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_pow10_bb4 // branch
_L7b0c_fpe_pow10_bb4:
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L7b0c_fpe_pow10_bb6 // br_cond: !payload -> else
    b _L7b0c_fpe_pow10_bb5 // branch -> then
_L7b0c_fpe_pow10_bb5:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #144] // hv store L9
    b _L7b0c_fpe_pow10_bb4 // branch
_L7b0c_fpe_pow10_bb6:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #128] // hv load L8
    bl fpe_mul_small // call fpe_mul_small
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_shl
.hidden fpe_shl
    .p2align 2
fpe_shl:
    .loc 1 242 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_shl_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _L7b0c_fpe_shl_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_shl_bb1 // branch -> then
_L7b0c_fpe_shl_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_shl_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl fpe_is_zero // call fpe_is_zero
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _L7b0c_fpe_shl_bb4 // br_cond: !payload -> else
    b _L7b0c_fpe_shl_bb3 // branch -> then
_L7b0c_fpe_shl_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_shl_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    bl fpe_pow2 // call fpe_pow2
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L7
    bl fpe_mul // call fpe_mul
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_ilog2
.hidden fpe_ilog2
    .p2align 2
fpe_ilog2:
    .loc 1 248 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #96 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_ilog2_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #32] // hv store L2
    b _L7b0c_fpe_ilog2_bb1 // branch
_L7b0c_fpe_ilog2_bb1:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L7b0c_fpe_ilog2_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_ilog2_bb2 // branch -> then
_L7b0c_fpe_ilog2_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #16] // hv store L1
    b _L7b0c_fpe_ilog2_bb1 // branch
_L7b0c_fpe_ilog2_bb3:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #96 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_bitlen
.hidden fpe_bitlen
    .p2align 2
fpe_bitlen:
    .loc 1 259 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_bitlen_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl fpe_is_zero // call fpe_is_zero
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _L7b0c_fpe_bitlen_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_bitlen_bb1 // branch -> then
_L7b0c_fpe_bitlen_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_bitlen_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1805 // imm 0-15
    movk x3, #2, lsl #16 // imm 16-31
    bl hexa_mul // binop *
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #128] // hv load L8
    bl fpe_ilog2 // call fpe_ilog2
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_divmod
.hidden fpe_divmod
    .p2align 2
fpe_divmod:
    .loc 1 268 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1088 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L7b0c_fpe_divmod_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl fpe_is_zero // call fpe_is_zero
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L7b0c_fpe_divmod_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb1 // branch -> then
_L7b0c_fpe_divmod_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #128] // hv store L8
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_divmod_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl fpe_cmp // call fpe_cmp
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L7b0c_fpe_divmod_bb4 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb3 // branch -> then
_L7b0c_fpe_divmod_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #240] // hv load L15
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_fpe_divmod_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    b _L7b0c_fpe_divmod_bb5 // branch
_L7b0c_fpe_divmod_bb5:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _L7b0c_fpe_divmod_bb7 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb6 // branch -> then
_L7b0c_fpe_divmod_bb6:
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #416] // hv load L26
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    bl fpe_from // call fpe_from
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #480] // hv load L30
    bl fpe_add // call fpe_add
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    stp x0, x1, [sp, #384] // hv store L24
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9999 // hv const_int val
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _L7b0c_fpe_divmod_bb8 // branch
_L7b0c_fpe_divmod_bb7:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    b _L7b0c_fpe_divmod_bb16 // branch
_L7b0c_fpe_divmod_bb8:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    bl hexa_cmp_le // binop <=
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _L7b0c_fpe_divmod_bb10 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb9 // branch -> then
_L7b0c_fpe_divmod_bb9:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    bl hexa_add_slow // binop +
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    ldp x0, x1, [sp, #16] // hv load L1
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    ldp x2, x3, [sp, #384] // hv load L24
    bl fpe_cmp // call fpe_cmp
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _L7b0c_fpe_divmod_bb12 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb11 // branch -> then
_L7b0c_fpe_divmod_bb10:
    ldp x0, x1, [sp, #352] // hv load L22
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _L7b0c_fpe_divmod_bb15 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb14 // branch -> then
_L7b0c_fpe_divmod_bb11:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L7b0c_fpe_divmod_bb13 // branch
_L7b0c_fpe_divmod_bb12:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    b _L7b0c_fpe_divmod_bb13 // branch
_L7b0c_fpe_divmod_bb13:
    b _L7b0c_fpe_divmod_bb8 // branch
_L7b0c_fpe_divmod_bb14:
    ldp x0, x1, [sp, #16] // hv load L1
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    ldp x0, x1, [sp, #384] // hv load L24
    add x15, sp, #800 // hv frame base
    ldp x2, x3, [x15] // hv load L50
    bl fpe_sub // call fpe_sub
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    stp x0, x1, [sp, #384] // hv store L24
    b _L7b0c_fpe_divmod_bb15 // branch
_L7b0c_fpe_divmod_bb15:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    stp x0, x1, [sp, #416] // hv store L26
    b _L7b0c_fpe_divmod_bb5 // branch
_L7b0c_fpe_divmod_bb16:
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _L7b0c_fpe_divmod_bb18 // br_cond: !payload -> else
    b _L7b0c_fpe_divmod_bb17 // branch -> then
_L7b0c_fpe_divmod_bb17:
    ldp x0, x1, [sp, #352] // hv load L22
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    b _L7b0c_fpe_divmod_bb16 // branch
_L7b0c_fpe_divmod_bb18:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    bl fpe_norm // call fpe_norm
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1024 // hv frame base
    ldp x2, x3, [x15] // hv load L64
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    ldp x0, x1, [sp, #384] // hv load L24
    bl fpe_norm // call fpe_norm
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1056 // hv frame base
    ldp x2, x3, [x15] // hv load L66
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_to_i64
.hidden fpe_to_i64
    .p2align 2
fpe_to_i64:
    .loc 1 320 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_fpe_to_i64_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_to_i64_bb1 // branch
_L7b0c_fpe_to_i64_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _L7b0c_fpe_to_i64_bb3 // br_cond: !payload -> else
    b _L7b0c_fpe_to_i64_bb2 // branch -> then
_L7b0c_fpe_to_i64_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10000 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #64] // hv store L4
    b _L7b0c_fpe_to_i64_bb1 // branch
_L7b0c_fpe_to_i64_bb3:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl fpe_assemble
.hidden fpe_assemble
    .p2align 2
fpe_assemble:
    .loc 1 332 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #192 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L7b0c_fpe_assemble_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_mul // binop *
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _L7b0c_fpe_assemble_bb2 // br_cond: !payload -> else
    b _L7b0c_fpe_assemble_bb1 // branch -> then
_L7b0c_fpe_assemble_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    movk x3, #65535, lsl #32 // imm 32-47
    movk x3, #32767, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #80] // hv store L5
    b _L7b0c_fpe_assemble_bb2 // branch
_L7b0c_fpe_assemble_bb2:
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_bits_to_float // call hexa_bits_to_float
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #192 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_parse_float_exact
.hidden rt_str_parse_float_exact
    .p2align 2
rt_str_parse_float_exact:
    .loc 1 342 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #3696 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L7b0c_rt_str_parse_float_exact_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb1 // branch
_L7b0c_rt_str_parse_float_exact_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb3 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb2 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb5 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb4 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb17 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb16 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb4:
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    b _L7b0c_rt_str_parse_float_exact_bb6 // branch
_L7b0c_rt_str_parse_float_exact_bb5:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #128] // hv store L8
    b _L7b0c_rt_str_parse_float_exact_bb6 // branch
_L7b0c_rt_str_parse_float_exact_bb6:
    ldp x0, x1, [sp, #128] // hv load L8
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb8 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb7 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb7:
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #160] // hv store L10
    b _L7b0c_rt_str_parse_float_exact_bb9 // branch
_L7b0c_rt_str_parse_float_exact_bb8:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #160] // hv store L10
    b _L7b0c_rt_str_parse_float_exact_bb9 // branch
_L7b0c_rt_str_parse_float_exact_bb9:
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb11 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb10 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_rt_str_parse_float_exact_bb12 // branch
_L7b0c_rt_str_parse_float_exact_bb11:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _L7b0c_rt_str_parse_float_exact_bb12 // branch
_L7b0c_rt_str_parse_float_exact_bb12:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb14 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb13 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb13:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb15 // branch
_L7b0c_rt_str_parse_float_exact_bb14:
    b _L7b0c_rt_str_parse_float_exact_bb3 // branch
_L7b0c_rt_str_parse_float_exact_bb15:
    b _L7b0c_rt_str_parse_float_exact_bb1 // branch
_L7b0c_rt_str_parse_float_exact_bb16:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb19 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb18 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb17:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #464] // hv store L29
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #480] // hv store L30
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #496] // hv store L31
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L7b0c_rt_str_parse_float_exact_bb23 // branch
_L7b0c_rt_str_parse_float_exact_bb18:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb22 // branch
_L7b0c_rt_str_parse_float_exact_bb19:
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb21 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb20 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb20:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb21 // branch
_L7b0c_rt_str_parse_float_exact_bb21:
    b _L7b0c_rt_str_parse_float_exact_bb22 // branch
_L7b0c_rt_str_parse_float_exact_bb22:
    b _L7b0c_rt_str_parse_float_exact_bb17 // branch
_L7b0c_rt_str_parse_float_exact_bb23:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb27 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb26 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb24:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb30 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb29 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb25:
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb44 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb43 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb26:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _L7b0c_rt_str_parse_float_exact_bb28 // branch
_L7b0c_rt_str_parse_float_exact_bb27:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _L7b0c_rt_str_parse_float_exact_bb28 // branch
_L7b0c_rt_str_parse_float_exact_bb28:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb25 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb24 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb29:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _L7b0c_rt_str_parse_float_exact_bb31 // branch
_L7b0c_rt_str_parse_float_exact_bb30:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _L7b0c_rt_str_parse_float_exact_bb31 // branch
_L7b0c_rt_str_parse_float_exact_bb31:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb33 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb32 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb32:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    bl fpe_from // call fpe_from
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    bl fpe_add // call fpe_add
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb35 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb34 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb33:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb37 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb36 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb34:
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    stp x0, x1, [sp, #464] // hv store L29
    b _L7b0c_rt_str_parse_float_exact_bb35 // branch
_L7b0c_rt_str_parse_float_exact_bb35:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb42 // branch
_L7b0c_rt_str_parse_float_exact_bb36:
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb39 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb38 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb37:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L7b0c_rt_str_parse_float_exact_bb41 // branch
_L7b0c_rt_str_parse_float_exact_bb38:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L7b0c_rt_str_parse_float_exact_bb40 // branch
_L7b0c_rt_str_parse_float_exact_bb39:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb40 // branch
_L7b0c_rt_str_parse_float_exact_bb40:
    b _L7b0c_rt_str_parse_float_exact_bb41 // branch
_L7b0c_rt_str_parse_float_exact_bb41:
    b _L7b0c_rt_str_parse_float_exact_bb42 // branch
_L7b0c_rt_str_parse_float_exact_bb42:
    b _L7b0c_rt_str_parse_float_exact_bb23 // branch
_L7b0c_rt_str_parse_float_exact_bb43:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb44:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb46 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb45 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb45:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #101 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb48 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb47 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb46:
    b _L7b0c_rt_str_parse_float_exact_bb72 // branch
_L7b0c_rt_str_parse_float_exact_bb47:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    b _L7b0c_rt_str_parse_float_exact_bb49 // branch
_L7b0c_rt_str_parse_float_exact_bb48:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #69 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    b _L7b0c_rt_str_parse_float_exact_bb49 // branch
_L7b0c_rt_str_parse_float_exact_bb49:
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb51 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb50 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb50:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb53 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb52 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb51:
    b _L7b0c_rt_str_parse_float_exact_bb46 // branch
_L7b0c_rt_str_parse_float_exact_bb52:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb55 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb54 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb53:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    b _L7b0c_rt_str_parse_float_exact_bb59 // branch
_L7b0c_rt_str_parse_float_exact_bb54:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb58 // branch
_L7b0c_rt_str_parse_float_exact_bb55:
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb57 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb56 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb56:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb57 // branch
_L7b0c_rt_str_parse_float_exact_bb57:
    b _L7b0c_rt_str_parse_float_exact_bb58 // branch
_L7b0c_rt_str_parse_float_exact_bb58:
    b _L7b0c_rt_str_parse_float_exact_bb53 // branch
_L7b0c_rt_str_parse_float_exact_bb59:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb61 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb60 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb60:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb63 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb62 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb61:
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L95
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb71 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb70 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb62:
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _L7b0c_rt_str_parse_float_exact_bb64 // branch
_L7b0c_rt_str_parse_float_exact_bb63:
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _L7b0c_rt_str_parse_float_exact_bb64 // branch
_L7b0c_rt_str_parse_float_exact_bb64:
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb66 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb65 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb65:
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    bl hexa_add_slow // binop +
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #34464 // imm 0-15
    movk x3, #1, lsl #16 // imm 16-31
    bl hexa_cmp_gt // binop >
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb68 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb67 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb66:
    b _L7b0c_rt_str_parse_float_exact_bb61 // branch
_L7b0c_rt_str_parse_float_exact_bb67:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #34464 // imm 0-15
    movk x1, #1, lsl #16 // imm 16-31
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    b _L7b0c_rt_str_parse_float_exact_bb68 // branch
_L7b0c_rt_str_parse_float_exact_bb68:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb69 // branch
_L7b0c_rt_str_parse_float_exact_bb69:
    b _L7b0c_rt_str_parse_float_exact_bb59 // branch
_L7b0c_rt_str_parse_float_exact_bb70:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    add x15, sp, #1552 // hv frame base
    ldp x0, x1, [x15] // hv load L97
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb71:
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1280 // hv frame base
    ldp x2, x3, [x15] // hv load L80
    bl hexa_mul // binop *
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    ldp x0, x1, [sp, #464] // hv load L29
    add x15, sp, #1568 // hv frame base
    ldp x2, x3, [x15] // hv load L98
    bl hexa_add_slow // binop +
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    stp x0, x1, [sp, #464] // hv store L29
    b _L7b0c_rt_str_parse_float_exact_bb51 // branch
_L7b0c_rt_str_parse_float_exact_bb72:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb74 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb73 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb73:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1616 // hv frame base
    stp x0, x1, [x15] // hv store L101
    add x15, sp, #1616 // hv frame base
    ldp x0, x1, [x15] // hv load L101
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv load L103
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb76 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb75 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb74:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1792 // hv frame base
    ldp x0, x1, [x15] // hv load L112
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb88 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb87 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb75:
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv load L103
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    b _L7b0c_rt_str_parse_float_exact_bb77 // branch
_L7b0c_rt_str_parse_float_exact_bb76:
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    b _L7b0c_rt_str_parse_float_exact_bb77 // branch
_L7b0c_rt_str_parse_float_exact_bb77:
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb79 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb78 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb78:
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    b _L7b0c_rt_str_parse_float_exact_bb80 // branch
_L7b0c_rt_str_parse_float_exact_bb79:
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    add x15, sp, #1712 // hv frame base
    ldp x0, x1, [x15] // hv load L107
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    b _L7b0c_rt_str_parse_float_exact_bb80 // branch
_L7b0c_rt_str_parse_float_exact_bb80:
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb82 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb81 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb81:
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    b _L7b0c_rt_str_parse_float_exact_bb83 // branch
_L7b0c_rt_str_parse_float_exact_bb82:
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1744 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1744 // hv frame base
    ldp x0, x1, [x15] // hv load L109
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    b _L7b0c_rt_str_parse_float_exact_bb83 // branch
_L7b0c_rt_str_parse_float_exact_bb83:
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L108
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb85 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb84 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb84:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1776 // hv frame base
    stp x0, x1, [x15] // hv store L111
    add x15, sp, #1776 // hv frame base
    ldp x0, x1, [x15] // hv load L111
    stp x0, x1, [sp, #48] // hv store L3
    b _L7b0c_rt_str_parse_float_exact_bb86 // branch
_L7b0c_rt_str_parse_float_exact_bb85:
    b _L7b0c_rt_str_parse_float_exact_bb74 // branch
_L7b0c_rt_str_parse_float_exact_bb86:
    b _L7b0c_rt_str_parse_float_exact_bb72 // branch
_L7b0c_rt_str_parse_float_exact_bb87:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb88:
    ldp x0, x1, [sp, #448] // hv load L28
    bl fpe_is_zero // call fpe_is_zero
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb90 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb89 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb89:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L118
    add x15, sp, #1888 // hv frame base
    ldp x0, x1, [x15] // hv load L118
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb90:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1904 // hv frame base
    stp x0, x1, [x15] // hv store L119
    add x15, sp, #1904 // hv frame base
    ldp x0, x1, [x15] // hv load L119
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb92 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb91 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb91:
    ldp x0, x1, [sp, #464] // hv load L29
    bl fpe_pow10 // call fpe_pow10
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    ldp x0, x1, [sp, #448] // hv load L28
    add x15, sp, #2000 // hv frame base
    ldp x2, x3, [x15] // hv load L125
    bl fpe_mul // call fpe_mul
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    bl fpe_from // call fpe_from
    add x15, sp, #2032 // hv frame base
    stp x0, x1, [x15] // hv store L127
    add x15, sp, #2032 // hv frame base
    ldp x0, x1, [x15] // hv load L127
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    b _L7b0c_rt_str_parse_float_exact_bb93 // branch
_L7b0c_rt_str_parse_float_exact_bb92:
    ldp x0, x1, [sp, #448] // hv load L28
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #464] // hv load L29
    bl hexa_sub // binop -
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    add x15, sp, #2048 // hv frame base
    ldp x0, x1, [x15] // hv load L128
    bl fpe_pow10 // call fpe_pow10
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    add x15, sp, #2064 // hv frame base
    ldp x0, x1, [x15] // hv load L129
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    b _L7b0c_rt_str_parse_float_exact_bb93 // branch
_L7b0c_rt_str_parse_float_exact_bb93:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    bl fpe_bitlen // call fpe_bitlen
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    bl fpe_bitlen // call fpe_bitlen
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L132
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    add x15, sp, #2112 // hv frame base
    ldp x2, x3, [x15] // hv load L132
    bl hexa_sub // binop -
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv load L133
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #53 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb95 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb94 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb94:
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #52 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    add x15, sp, #2208 // hv frame base
    ldp x2, x3, [x15] // hv load L138
    bl fpe_shl // call fpe_shl
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv load L139
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    add x15, sp, #2208 // hv frame base
    ldp x2, x3, [x15] // hv load L138
    bl hexa_add_slow // binop +
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L140
    add x15, sp, #2240 // hv frame base
    ldp x0, x1, [x15] // hv load L140
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    b _L7b0c_rt_str_parse_float_exact_bb98 // branch
_L7b0c_rt_str_parse_float_exact_bb95:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #52 // hv const_int val
    add x15, sp, #2144 // hv frame base
    ldp x2, x3, [x15] // hv load L134
    bl hexa_sub // binop -
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv load L141
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    add x15, sp, #2272 // hv frame base
    ldp x0, x1, [x15] // hv load L142
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #2288 // hv frame base
    stp x0, x1, [x15] // hv store L143
    add x15, sp, #2288 // hv frame base
    ldp x0, x1, [x15] // hv load L143
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb97 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb96 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb96:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    b _L7b0c_rt_str_parse_float_exact_bb97 // branch
_L7b0c_rt_str_parse_float_exact_bb97:
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #2272 // hv frame base
    ldp x2, x3, [x15] // hv load L142
    bl fpe_shl // call fpe_shl
    add x15, sp, #2320 // hv frame base
    stp x0, x1, [x15] // hv store L145
    add x15, sp, #2320 // hv frame base
    ldp x0, x1, [x15] // hv load L145
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    add x15, sp, #2272 // hv frame base
    ldp x2, x3, [x15] // hv load L142
    bl hexa_sub // binop -
    add x15, sp, #2336 // hv frame base
    stp x0, x1, [x15] // hv store L146
    add x15, sp, #2336 // hv frame base
    ldp x0, x1, [x15] // hv load L146
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    b _L7b0c_rt_str_parse_float_exact_bb98 // branch
_L7b0c_rt_str_parse_float_exact_bb98:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #52 // hv const_int val
    bl fpe_pow2 // call fpe_pow2
    add x15, sp, #2352 // hv frame base
    stp x0, x1, [x15] // hv store L147
    add x15, sp, #2352 // hv frame base
    ldp x0, x1, [x15] // hv load L147
    add x15, sp, #2368 // hv frame base
    stp x0, x1, [x15] // hv store L148
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #53 // hv const_int val
    bl fpe_pow2 // call fpe_pow2
    add x15, sp, #2384 // hv frame base
    stp x0, x1, [x15] // hv store L149
    add x15, sp, #2384 // hv frame base
    ldp x0, x1, [x15] // hv load L149
    add x15, sp, #2400 // hv frame base
    stp x0, x1, [x15] // hv store L150
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2416 // hv frame base
    stp x0, x1, [x15] // hv store L151
    b _L7b0c_rt_str_parse_float_exact_bb99 // branch
_L7b0c_rt_str_parse_float_exact_bb99:
    add x15, sp, #2416 // hv frame base
    ldp x0, x1, [x15] // hv load L151
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2432 // hv frame base
    stp x0, x1, [x15] // hv store L152
    add x15, sp, #2432 // hv frame base
    ldp x0, x1, [x15] // hv load L152
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb101 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb100 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb100:
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    add x15, sp, #2368 // hv frame base
    ldp x2, x3, [x15] // hv load L148
    bl fpe_mul // call fpe_mul
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L153
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    add x15, sp, #2464 // hv frame base
    stp x0, x1, [x15] // hv store L154
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    add x15, sp, #2400 // hv frame base
    ldp x2, x3, [x15] // hv load L150
    bl fpe_mul // call fpe_mul
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L155
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv load L155
    add x15, sp, #2496 // hv frame base
    stp x0, x1, [x15] // hv store L156
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #2496 // hv frame base
    ldp x2, x3, [x15] // hv load L156
    bl fpe_cmp // call fpe_cmp
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L157
    add x15, sp, #2512 // hv frame base
    ldp x0, x1, [x15] // hv load L157
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L158
    add x15, sp, #2528 // hv frame base
    ldp x0, x1, [x15] // hv load L158
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb103 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb102 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb101:
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1075 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2672 // hv frame base
    stp x0, x1, [x15] // hv store L167
    add x15, sp, #2672 // hv frame base
    ldp x0, x1, [x15] // hv load L167
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2704 // hv frame base
    stp x0, x1, [x15] // hv store L169
    add x15, sp, #2704 // hv frame base
    ldp x0, x1, [x15] // hv load L169
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb109 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb108 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb102:
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #2560 // hv frame base
    stp x0, x1, [x15] // hv store L160
    add x15, sp, #2560 // hv frame base
    ldp x0, x1, [x15] // hv load L160
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2576 // hv frame base
    stp x0, x1, [x15] // hv store L161
    add x15, sp, #2576 // hv frame base
    ldp x0, x1, [x15] // hv load L161
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    b _L7b0c_rt_str_parse_float_exact_bb107 // branch
_L7b0c_rt_str_parse_float_exact_bb103:
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #2464 // hv frame base
    ldp x2, x3, [x15] // hv load L154
    bl fpe_cmp // call fpe_cmp
    add x15, sp, #2592 // hv frame base
    stp x0, x1, [x15] // hv store L162
    add x15, sp, #2592 // hv frame base
    ldp x0, x1, [x15] // hv load L162
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #2608 // hv frame base
    stp x0, x1, [x15] // hv store L163
    add x15, sp, #2608 // hv frame base
    ldp x0, x1, [x15] // hv load L163
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb105 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb104 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb104:
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #2640 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L165
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2656 // hv frame base
    stp x0, x1, [x15] // hv store L166
    add x15, sp, #2656 // hv frame base
    ldp x0, x1, [x15] // hv load L166
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    b _L7b0c_rt_str_parse_float_exact_bb106 // branch
_L7b0c_rt_str_parse_float_exact_bb105:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2416 // hv frame base
    stp x0, x1, [x15] // hv store L151
    b _L7b0c_rt_str_parse_float_exact_bb106 // branch
_L7b0c_rt_str_parse_float_exact_bb106:
    b _L7b0c_rt_str_parse_float_exact_bb107 // branch
_L7b0c_rt_str_parse_float_exact_bb107:
    b _L7b0c_rt_str_parse_float_exact_bb99 // branch
_L7b0c_rt_str_parse_float_exact_bb108:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L171
    add x15, sp, #2736 // hv frame base
    ldp x0, x1, [x15] // hv load L171
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb109:
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2752 // hv frame base
    stp x0, x1, [x15] // hv store L172
    add x15, sp, #2752 // hv frame base
    ldp x0, x1, [x15] // hv load L172
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb111 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb110 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb110:
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #1952 // hv frame base
    ldp x2, x3, [x15] // hv load L122
    bl fpe_divmod // call fpe_divmod
    add x15, sp, #2784 // hv frame base
    stp x0, x1, [x15] // hv store L174
    add x15, sp, #2784 // hv frame base
    ldp x0, x1, [x15] // hv load L174
    add x15, sp, #2800 // hv frame base
    stp x0, x1, [x15] // hv store L175
    add x15, sp, #2800 // hv frame base
    ldp x0, x1, [x15] // hv load L175
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2816 // hv frame base
    stp x0, x1, [x15] // hv store L176
    add x15, sp, #2816 // hv frame base
    ldp x0, x1, [x15] // hv load L176
    bl fpe_to_i64 // call fpe_to_i64
    add x15, sp, #2832 // hv frame base
    stp x0, x1, [x15] // hv store L177
    add x15, sp, #2832 // hv frame base
    ldp x0, x1, [x15] // hv load L177
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L178
    add x15, sp, #2800 // hv frame base
    ldp x0, x1, [x15] // hv load L175
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2864 // hv frame base
    stp x0, x1, [x15] // hv store L179
    add x15, sp, #2864 // hv frame base
    ldp x0, x1, [x15] // hv load L179
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #2880 // hv frame base
    stp x0, x1, [x15] // hv store L180
    add x15, sp, #2880 // hv frame base
    ldp x0, x1, [x15] // hv load L180
    add x15, sp, #1952 // hv frame base
    ldp x2, x3, [x15] // hv load L122
    bl fpe_cmp // call fpe_cmp
    add x15, sp, #2896 // hv frame base
    stp x0, x1, [x15] // hv store L181
    add x15, sp, #2896 // hv frame base
    ldp x0, x1, [x15] // hv load L181
    add x15, sp, #2912 // hv frame base
    stp x0, x1, [x15] // hv store L182
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2928 // hv frame base
    stp x0, x1, [x15] // hv store L183
    add x15, sp, #2912 // hv frame base
    ldp x0, x1, [x15] // hv load L182
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #2944 // hv frame base
    stp x0, x1, [x15] // hv store L184
    add x15, sp, #2944 // hv frame base
    ldp x0, x1, [x15] // hv load L184
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb113 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb112 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb111:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2688 // hv frame base
    ldp x2, x3, [x15] // hv load L168
    bl hexa_sub // binop -
    add x15, sp, #3232 // hv frame base
    stp x0, x1, [x15] // hv store L202
    add x15, sp, #3232 // hv frame base
    ldp x0, x1, [x15] // hv load L202
    add x15, sp, #3248 // hv frame base
    stp x0, x1, [x15] // hv store L203
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    add x15, sp, #3248 // hv frame base
    ldp x2, x3, [x15] // hv load L203
    bl fpe_shl // call fpe_shl
    add x15, sp, #3264 // hv frame base
    stp x0, x1, [x15] // hv store L204
    add x15, sp, #3264 // hv frame base
    ldp x0, x1, [x15] // hv load L204
    add x15, sp, #3280 // hv frame base
    stp x0, x1, [x15] // hv store L205
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #3280 // hv frame base
    ldp x2, x3, [x15] // hv load L205
    bl fpe_divmod // call fpe_divmod
    add x15, sp, #3296 // hv frame base
    stp x0, x1, [x15] // hv store L206
    add x15, sp, #3296 // hv frame base
    ldp x0, x1, [x15] // hv load L206
    add x15, sp, #3312 // hv frame base
    stp x0, x1, [x15] // hv store L207
    add x15, sp, #3312 // hv frame base
    ldp x0, x1, [x15] // hv load L207
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3328 // hv frame base
    stp x0, x1, [x15] // hv store L208
    add x15, sp, #3328 // hv frame base
    ldp x0, x1, [x15] // hv load L208
    bl fpe_to_i64 // call fpe_to_i64
    add x15, sp, #3344 // hv frame base
    stp x0, x1, [x15] // hv store L209
    add x15, sp, #3344 // hv frame base
    ldp x0, x1, [x15] // hv load L209
    add x15, sp, #3360 // hv frame base
    stp x0, x1, [x15] // hv store L210
    add x15, sp, #3312 // hv frame base
    ldp x0, x1, [x15] // hv load L207
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3376 // hv frame base
    stp x0, x1, [x15] // hv store L211
    add x15, sp, #3376 // hv frame base
    ldp x0, x1, [x15] // hv load L211
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl fpe_mul_small // call fpe_mul_small
    add x15, sp, #3392 // hv frame base
    stp x0, x1, [x15] // hv store L212
    add x15, sp, #3392 // hv frame base
    ldp x0, x1, [x15] // hv load L212
    add x15, sp, #3280 // hv frame base
    ldp x2, x3, [x15] // hv load L205
    bl fpe_cmp // call fpe_cmp
    add x15, sp, #3408 // hv frame base
    stp x0, x1, [x15] // hv store L213
    add x15, sp, #3408 // hv frame base
    ldp x0, x1, [x15] // hv load L213
    add x15, sp, #3424 // hv frame base
    stp x0, x1, [x15] // hv store L214
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #3440 // hv frame base
    stp x0, x1, [x15] // hv store L215
    add x15, sp, #3424 // hv frame base
    ldp x0, x1, [x15] // hv load L214
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #3456 // hv frame base
    stp x0, x1, [x15] // hv store L216
    add x15, sp, #3456 // hv frame base
    ldp x0, x1, [x15] // hv load L216
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb126 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb125 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb112:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2928 // hv frame base
    stp x0, x1, [x15] // hv store L183
    b _L7b0c_rt_str_parse_float_exact_bb118 // branch
_L7b0c_rt_str_parse_float_exact_bb113:
    add x15, sp, #2912 // hv frame base
    ldp x0, x1, [x15] // hv load L182
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2976 // hv frame base
    stp x0, x1, [x15] // hv store L186
    add x15, sp, #2976 // hv frame base
    ldp x0, x1, [x15] // hv load L186
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb115 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb114 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb114:
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L178
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #3008 // hv frame base
    stp x0, x1, [x15] // hv store L188
    add x15, sp, #3008 // hv frame base
    ldp x0, x1, [x15] // hv load L188
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    add x15, sp, #3024 // hv frame base
    ldp x0, x1, [x15] // hv load L189
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb117 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb116 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb115:
    b _L7b0c_rt_str_parse_float_exact_bb118 // branch
_L7b0c_rt_str_parse_float_exact_bb116:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2928 // hv frame base
    stp x0, x1, [x15] // hv store L183
    b _L7b0c_rt_str_parse_float_exact_bb117 // branch
_L7b0c_rt_str_parse_float_exact_bb117:
    b _L7b0c_rt_str_parse_float_exact_bb115 // branch
_L7b0c_rt_str_parse_float_exact_bb118:
    add x15, sp, #2928 // hv frame base
    ldp x0, x1, [x15] // hv load L183
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3056 // hv frame base
    stp x0, x1, [x15] // hv store L191
    add x15, sp, #3056 // hv frame base
    ldp x0, x1, [x15] // hv load L191
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb120 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb119 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb119:
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L178
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3088 // hv frame base
    stp x0, x1, [x15] // hv store L193
    add x15, sp, #3088 // hv frame base
    ldp x0, x1, [x15] // hv load L193
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L178
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L178
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #32, lsl #48 // imm 48-63
    bl hexa_eq // binop ==
    add x15, sp, #3104 // hv frame base
    stp x0, x1, [x15] // hv store L194
    add x15, sp, #3104 // hv frame base
    ldp x0, x1, [x15] // hv load L194
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb122 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb121 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb120:
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3152 // hv frame base
    stp x0, x1, [x15] // hv store L197
    add x15, sp, #3152 // hv frame base
    ldp x0, x1, [x15] // hv load L197
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb124 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb123 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb121:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    movk x1, #16, lsl #48 // imm 48-63
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L178
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3136 // hv frame base
    stp x0, x1, [x15] // hv store L196
    add x15, sp, #3136 // hv frame base
    ldp x0, x1, [x15] // hv load L196
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    b _L7b0c_rt_str_parse_float_exact_bb122 // branch
_L7b0c_rt_str_parse_float_exact_bb122:
    b _L7b0c_rt_str_parse_float_exact_bb120 // branch
_L7b0c_rt_str_parse_float_exact_bb123:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #3184 // hv frame base
    stp x0, x1, [x15] // hv store L199
    add x15, sp, #3184 // hv frame base
    ldp x0, x1, [x15] // hv load L199
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb124:
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L178
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #3200 // hv frame base
    stp x0, x1, [x15] // hv store L200
    ldp x0, x1, [sp, #256] // hv load L16
    add x15, sp, #2688 // hv frame base
    ldp x2, x3, [x15] // hv load L168
    add x15, sp, #3200 // hv frame base
    ldp x4, x5, [x15] // hv load L200
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #3216 // hv frame base
    stp x0, x1, [x15] // hv store L201
    add x15, sp, #3216 // hv frame base
    ldp x0, x1, [x15] // hv load L201
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb125:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #3440 // hv frame base
    stp x0, x1, [x15] // hv store L215
    b _L7b0c_rt_str_parse_float_exact_bb131 // branch
_L7b0c_rt_str_parse_float_exact_bb126:
    add x15, sp, #3424 // hv frame base
    ldp x0, x1, [x15] // hv load L214
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3488 // hv frame base
    stp x0, x1, [x15] // hv store L218
    add x15, sp, #3488 // hv frame base
    ldp x0, x1, [x15] // hv load L218
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb128 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb127 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb127:
    add x15, sp, #3360 // hv frame base
    ldp x0, x1, [x15] // hv load L210
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #3520 // hv frame base
    stp x0, x1, [x15] // hv store L220
    add x15, sp, #3520 // hv frame base
    ldp x0, x1, [x15] // hv load L220
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3536 // hv frame base
    stp x0, x1, [x15] // hv store L221
    add x15, sp, #3536 // hv frame base
    ldp x0, x1, [x15] // hv load L221
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb130 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb129 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb128:
    b _L7b0c_rt_str_parse_float_exact_bb131 // branch
_L7b0c_rt_str_parse_float_exact_bb129:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #3440 // hv frame base
    stp x0, x1, [x15] // hv store L215
    b _L7b0c_rt_str_parse_float_exact_bb130 // branch
_L7b0c_rt_str_parse_float_exact_bb130:
    b _L7b0c_rt_str_parse_float_exact_bb128 // branch
_L7b0c_rt_str_parse_float_exact_bb131:
    add x15, sp, #3440 // hv frame base
    ldp x0, x1, [x15] // hv load L215
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3568 // hv frame base
    stp x0, x1, [x15] // hv store L223
    add x15, sp, #3568 // hv frame base
    ldp x0, x1, [x15] // hv load L223
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb133 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb132 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb132:
    add x15, sp, #3360 // hv frame base
    ldp x0, x1, [x15] // hv load L210
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3600 // hv frame base
    stp x0, x1, [x15] // hv store L225
    add x15, sp, #3600 // hv frame base
    ldp x0, x1, [x15] // hv load L225
    add x15, sp, #3360 // hv frame base
    stp x0, x1, [x15] // hv store L210
    b _L7b0c_rt_str_parse_float_exact_bb133 // branch
_L7b0c_rt_str_parse_float_exact_bb133:
    add x15, sp, #3360 // hv frame base
    ldp x0, x1, [x15] // hv load L210
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3616 // hv frame base
    stp x0, x1, [x15] // hv store L226
    add x15, sp, #3616 // hv frame base
    ldp x0, x1, [x15] // hv load L226
    cbz x1, _L7b0c_rt_str_parse_float_exact_bb135 // br_cond: !payload -> else
    b _L7b0c_rt_str_parse_float_exact_bb134 // branch -> then
_L7b0c_rt_str_parse_float_exact_bb134:
    add x15, sp, #3360 // hv frame base
    ldp x0, x1, [x15] // hv load L210
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #3648 // hv frame base
    stp x0, x1, [x15] // hv store L228
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x15, sp, #3648 // hv frame base
    ldp x4, x5, [x15] // hv load L228
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #3664 // hv frame base
    stp x0, x1, [x15] // hv store L229
    add x15, sp, #3664 // hv frame base
    ldp x0, x1, [x15] // hv load L229
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L7b0c_rt_str_parse_float_exact_bb135:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x15, sp, #3360 // hv frame base
    ldp x4, x5, [x15] // hv load L210
    bl fpe_assemble // call fpe_assemble
    add x15, sp, #3680 // hv frame base
    stp x0, x1, [x15] // hv store L230
    add x15, sp, #3680 // hv frame base
    ldp x0, x1, [x15] // hv load L230
    add sp, sp, #3696 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
