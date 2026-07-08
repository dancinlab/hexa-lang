// intern_core_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 INTERN-R1).
// GENERATED: tool/regen_intern_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o intern_core_arm64-linux.s stdlib/runtime/intern_core.hexa.
//   Provides the intern-core READ-half (rt_intern_find_native /
//   rt_intern_strcmp0_native) as native raw-mem bodies — the open-addressing
//   find probe over HexaInternTable char** buckets + uint32_t* hashes
//   (__hx_ptr_load64/load8 + __hx_payload_* + __hx_make_val). These intrinsics
//   are gen2-native-only (the hexat C-transpile bootstrap cannot lower them),
//   so the bodies enter the shipped runtime.a ONLY via this seed.
//   ABI: ELF aarch64, rt_intern_*_native no underscore. External: none (rt_intern_strcmp0_native is local).
//   Lets stage_resolve_runtime_a define HEXA_RT_INTERN_NATIVE + ar this .o into
//   runtime.a so hexa_intern delegates its find half to the native body.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/intern_core.hexa
.file 1 "stdlib/runtime/intern_core.hexa"
.text
.globl rt_intern_strcmp0_native
.hidden rt_intern_strcmp0_native
    .p2align 2
rt_intern_strcmp0_native:
    .loc 1 48 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #208 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Le37b_rt_intern_strcmp0_native_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    b _Le37b_rt_intern_strcmp0_native_bb1 // branch
_Le37b_rt_intern_strcmp0_native_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #96] // hv load L6
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_strcmp0_native_bb3 // br_cond: !truthy -> else
    b _Le37b_rt_intern_strcmp0_native_bb2 // branch -> then
_Le37b_rt_intern_strcmp0_native_bb2:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_strcmp0_native_bb5 // br_cond: !truthy -> else
    b _Le37b_rt_intern_strcmp0_native_bb4 // branch -> then
_Le37b_rt_intern_strcmp0_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Le37b_rt_intern_strcmp0_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Le37b_rt_intern_strcmp0_native_bb5:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #32] // hv load L2
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #32] // hv load L2
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #96] // hv store L6
    b _Le37b_rt_intern_strcmp0_native_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_intern_find_native
.hidden rt_intern_find_native
    .p2align 2
rt_intern_find_native:
    .loc 1 72 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #768 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
    stp x6, x7, [sp, #48] // ingress param 3
    ldp x9, x10, [x29, #16] // ingress stack param 4
    stp x9, x10, [sp, #64] // store stack param 4
_Le37b_rt_intern_find_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #224] // hv load L14
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #272] // hv store L17
    b _Le37b_rt_intern_find_native_bb1 // branch
_Le37b_rt_intern_find_native_bb1:
    ldp x0, x1, [sp, #272] // hv load L17
    ldp x2, x3, [sp, #160] // hv load L10
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_find_native_bb3 // br_cond: !truthy -> else
    b _Le37b_rt_intern_find_native_bb2 // branch -> then
_Le37b_rt_intern_find_native_bb2:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #320] // hv load L20
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_find_native_bb5 // br_cond: !truthy -> else
    b _Le37b_rt_intern_find_native_bb4 // branch -> then
_Le37b_rt_intern_find_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Le37b_rt_intern_find_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Le37b_rt_intern_find_native_bb5:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #464] // hv load L29
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    ldp x2, x3, [sp, #192] // hv load L12
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_find_native_bb7 // br_cond: !truthy -> else
    b _Le37b_rt_intern_find_native_bb6 // branch -> then
_Le37b_rt_intern_find_native_bb6:
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #64] // hv load L4
    bl rt_intern_strcmp0_native // call rt_intern_strcmp0_native
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Le37b_rt_intern_find_native_bb9 // br_cond: !truthy -> else
    b _Le37b_rt_intern_find_native_bb8 // branch -> then
_Le37b_rt_intern_find_native_bb7:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    ldp x2, x3, [sp, #224] // hv load L14
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #272] // hv store L17
    b _Le37b_rt_intern_find_native_bb1 // branch
_Le37b_rt_intern_find_native_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #384] // hv load L24
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Le37b_rt_intern_find_native_bb9:
    b _Le37b_rt_intern_find_native_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",%progbits
