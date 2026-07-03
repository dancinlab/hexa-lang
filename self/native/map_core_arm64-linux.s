// map_core_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 MAP-CONSTRUCT-R1).
// GENERATED: tool/regen_map_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o map_core_arm64-linux.s stdlib/runtime/map_core.hexa.
//   Provides the map-core READ-half (rt_map_get_native / rt_map_fnv1a_native /
//   rt_map_strcmp0_native / rt_map_contains_native) PLUS the CONSTRUCT-half
//   in-place write (rt_map_set_inplace_native) as native raw-mem bodies
//   (__hx_ptr_load64/store64 over the HexaArr descriptor + __hx_make_val tag
//   re-stamp). These intrinsics are gen2-native-only (the hexat C-transpile
//   bootstrap cannot lower them), so the bodies enter the shipped runtime.a ONLY
//   via this seed — the rt_hi mechanism (resolve_native_rt_hi_seed / Z2a).
//   ABI: ELF aarch64, rt_map_*_native no underscore; external hexa_to_int. External: hexa_to_int (runtime.c).
//   Lets stage_resolve_runtime_a define HEXA_RT_ARRAY_NATIVE + ar this .o into
//   runtime.a so hexa_array_get/set delegate to the native bodies.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/map_core.hexa
.file 1 "stdlib/runtime/map_core.hexa"
.text
.globl rt_map_fnv1a_native
.hidden rt_map_fnv1a_native
    .p2align 2
rt_map_fnv1a_native:
    .loc 1 38 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #192 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L16d1_rt_map_fnv1a_native_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #40389 // imm 0-15
    movk x1, #33052, lsl #16 // imm 16-31
    stp x0, x1, [sp, #16] // hv store L1
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
    b _L16d1_rt_map_fnv1a_native_bb1 // branch
_L16d1_rt_map_fnv1a_native_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_fnv1a_native_bb3 // br_cond: !truthy -> else
    b _L16d1_rt_map_fnv1a_native_bb2 // branch -> then
_L16d1_rt_map_fnv1a_native_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    eor x1, x1, x3 // __hx_payload_xor: x1 = a.pl eor b.pl
    movz x0, #0 // __hx_payload_xor: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #403 // imm 0-15
    movk x3, #256, lsl #16 // imm 16-31
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #16] // hv store L1
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
    b _L16d1_rt_map_fnv1a_native_bb1 // branch
_L16d1_rt_map_fnv1a_native_bb3:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #192 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_map_strcmp0_native
.hidden rt_map_strcmp0_native
    .p2align 2
rt_map_strcmp0_native:
    .loc 1 54 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #208 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L16d1_rt_map_strcmp0_native_bb0:
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
    b _L16d1_rt_map_strcmp0_native_bb1 // branch
_L16d1_rt_map_strcmp0_native_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #96] // hv load L6
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_strcmp0_native_bb3 // br_cond: !truthy -> else
    b _L16d1_rt_map_strcmp0_native_bb2 // branch -> then
_L16d1_rt_map_strcmp0_native_bb2:
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
    cbz x0, _L16d1_rt_map_strcmp0_native_bb5 // br_cond: !truthy -> else
    b _L16d1_rt_map_strcmp0_native_bb4 // branch -> then
_L16d1_rt_map_strcmp0_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_strcmp0_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_strcmp0_native_bb5:
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
    b _L16d1_rt_map_strcmp0_native_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #208 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_map_get_native
.hidden rt_map_get_native
    .p2align 2
rt_map_get_native:
    .loc 1 73 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #880 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L16d1_rt_map_get_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #16] // hv load L1
    bl rt_map_fnv1a_native // call rt_map_fnv1a_native
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #272] // hv load L17
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    b _L16d1_rt_map_get_native_bb1 // branch
_L16d1_rt_map_get_native_bb1:
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #208] // hv load L13
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_get_native_bb3 // br_cond: !truthy -> else
    b _L16d1_rt_map_get_native_bb2 // branch -> then
_L16d1_rt_map_get_native_bb2:
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #368] // hv load L23
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_get_native_bb5 // br_cond: !truthy -> else
    b _L16d1_rt_map_get_native_bb4 // branch -> then
_L16d1_rt_map_get_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add sp, sp, #880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_get_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    add sp, sp, #880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_get_native_bb5:
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    ldp x2, x3, [sp, #240] // hv load L15
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_get_native_bb7 // br_cond: !truthy -> else
    b _L16d1_rt_map_get_native_bb6 // branch -> then
_L16d1_rt_map_get_native_bb6:
    ldp x0, x1, [sp, #432] // hv load L27
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_strcmp0_native // call rt_map_strcmp0_native
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_get_native_bb9 // br_cond: !truthy -> else
    b _L16d1_rt_map_get_native_bb8 // branch -> then
_L16d1_rt_map_get_native_bb7:
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    ldp x2, x3, [sp, #272] // hv load L17
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    stp x0, x1, [sp, #320] // hv store L20
    b _L16d1_rt_map_get_native_bb1 // branch
_L16d1_rt_map_get_native_bb8:
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #144] // hv load L9
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    ldp x0, x1, [sp, #144] // hv load L9
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #768 // hv frame base
    ldp x2, x3, [x15] // hv load L48
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add sp, sp, #880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_get_native_bb9:
    b _L16d1_rt_map_get_native_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_map_contains_native
.hidden rt_map_contains_native
    .p2align 2
rt_map_contains_native:
    .loc 1 115 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #720 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L16d1_rt_map_contains_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #16] // hv load L1
    bl rt_map_fnv1a_native // call rt_map_fnv1a_native
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #208] // hv load L13
    ldp x2, x3, [sp, #240] // hv load L15
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #288] // hv store L18
    b _L16d1_rt_map_contains_native_bb1 // branch
_L16d1_rt_map_contains_native_bb1:
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #176] // hv load L11
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_contains_native_bb3 // br_cond: !truthy -> else
    b _L16d1_rt_map_contains_native_bb2 // branch -> then
_L16d1_rt_map_contains_native_bb2:
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #336] // hv load L21
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_contains_native_bb5 // br_cond: !truthy -> else
    b _L16d1_rt_map_contains_native_bb4 // branch -> then
_L16d1_rt_map_contains_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_contains_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_contains_native_bb5:
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    ldp x2, x3, [sp, #208] // hv load L13
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_contains_native_bb7 // br_cond: !truthy -> else
    b _L16d1_rt_map_contains_native_bb6 // branch -> then
_L16d1_rt_map_contains_native_bb6:
    ldp x0, x1, [sp, #400] // hv load L25
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_strcmp0_native // call rt_map_strcmp0_native
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_contains_native_bb9 // br_cond: !truthy -> else
    b _L16d1_rt_map_contains_native_bb8 // branch -> then
_L16d1_rt_map_contains_native_bb7:
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    ldp x2, x3, [sp, #240] // hv load L15
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    stp x0, x1, [sp, #288] // hv store L18
    b _L16d1_rt_map_contains_native_bb1 // branch
_L16d1_rt_map_contains_native_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_contains_native_bb9:
    b _L16d1_rt_map_contains_native_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_map_set_inplace_native
.hidden rt_map_set_inplace_native
    .p2align 2
rt_map_set_inplace_native:
    .loc 1 163 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1088 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_L16d1_rt_map_set_inplace_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #16] // hv load L1
    bl rt_map_fnv1a_native // call rt_map_fnv1a_native
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #320] // hv load L20
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #32] // hv load L2
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    b _L16d1_rt_map_set_inplace_native_bb1 // branch
_L16d1_rt_map_set_inplace_native_bb1:
    ldp x0, x1, [sp, #368] // hv load L23
    ldp x2, x3, [sp, #256] // hv load L16
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_set_inplace_native_bb3 // br_cond: !truthy -> else
    b _L16d1_rt_map_set_inplace_native_bb2 // branch -> then
_L16d1_rt_map_set_inplace_native_bb2:
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #480] // hv load L30
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_set_inplace_native_bb5 // br_cond: !truthy -> else
    b _L16d1_rt_map_set_inplace_native_bb4 // branch -> then
_L16d1_rt_map_set_inplace_native_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_set_inplace_native_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_set_inplace_native_bb5:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] // __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 // __hx_ptr_load64: TAG_INT
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    ldp x2, x3, [sp, #288] // hv load L18
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_set_inplace_native_bb7 // br_cond: !truthy -> else
    b _L16d1_rt_map_set_inplace_native_bb6 // branch -> then
_L16d1_rt_map_set_inplace_native_bb6:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    ldp x2, x3, [sp, #16] // hv load L1
    bl rt_map_strcmp0_native // call rt_map_strcmp0_native
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _L16d1_rt_map_set_inplace_native_bb9 // br_cond: !truthy -> else
    b _L16d1_rt_map_set_inplace_native_bb8 // branch -> then
_L16d1_rt_map_set_inplace_native_bb7:
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    ldp x2, x3, [sp, #320] // hv load L20
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    stp x0, x1, [sp, #368] // hv store L23
    b _L16d1_rt_map_set_inplace_native_bb1 // branch
_L16d1_rt_map_set_inplace_native_bb8:
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    ldp x0, x1, [sp, #160] // hv load L10
    add x15, sp, #784 // hv frame base
    ldp x2, x3, [x15] // hv load L49
    ldp x4, x5, [sp, #400] // hv load L25
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #160] // hv load L10
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #160] // hv load L10
    add x15, sp, #816 // hv frame base
    ldp x2, x3, [x15] // hv load L51
    ldp x4, x5, [sp, #432] // hv load L27
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #160] // hv load L10
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    add x1, x1, x3 // __hx_ptr_load32: addr = ptr + off
    ldr w1, [x1] // __hx_ptr_load32: w1 = *(i32*)addr
    movz x0, #0 // __hx_ptr_load32: TAG_INT
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    ldp x0, x1, [sp, #192] // hv load L12
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    ldp x4, x5, [sp, #400] // hv load L25
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #192] // hv load L12
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    ldp x0, x1, [sp, #192] // hv load L12
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    ldp x4, x5, [sp, #432] // hv load L27
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #192] // hv load L12
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L16d1_rt_map_set_inplace_native_bb9:
    b _L16d1_rt_map_set_inplace_native_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1088 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
