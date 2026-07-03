// array_core_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 ARRAY-R4).
// GENERATED: tool/regen_array_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o array_core_arm64.s stdlib/runtime/array_core.hexa.
//   Provides the array-core READ-half (rt_array_get_native / rt_array_set_native /
//   rt_array_len_native / rt_array_pop_native) as native raw-mem bodies
//   (__hx_ptr_load64/store64 over the HexaArr descriptor + __hx_make_val tag
//   re-stamp), PLUS the alloc-bearing arena bridge rt_array_arena_alloc_items_native
//   (sh-array-write "alloc not a wall": n*16 bytes via the already-native
//   hexa_arena_alloc — self/rt/alloc.hexa). These intrinsics are gen2-native-only
//   (the hexat C-transpile bootstrap cannot lower them), so the bodies enter the
//   shipped runtime.a ONLY via this seed — the rt_hi mechanism (resolve_native_rt_hi_seed / Z2a).
//   ABI: Mach-O, _rt_array_*_native underscore-prefixed; external _hexa_to_int. External: hexa_to_int (runtime.c) + hexa_arena_alloc (alloc seed).
//   Lets stage_resolve_runtime_a define HEXA_RT_ARRAY_NATIVE (+ HEXA_RT_ARRAY_ARENA_NATIVE
//   when the alloc seed is native) + ar this .o into runtime.a so hexa_array_get/set
//   delegate to the native bodies + hexa_array_arena_alloc_items uses the native arena.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /home/aiden/wt-rfc061-strbuf-arena/stdlib/runtime/array_core.hexa
.file 1 "stdlib/runtime/array_core.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _rt_array_arena_alloc_items_native
.private_extern _rt_array_arena_alloc_items_native
    .p2align 2
_rt_array_arena_alloc_items_native:
    .loc 1 76 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__Ld116_rt_array_arena_alloc_items_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_arena_alloc ; call hexa_arena_alloc
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_arena_alloc_desc_native
.private_extern _rt_array_arena_alloc_desc_native
    .p2align 2
_rt_array_arena_alloc_desc_native:
    .loc 1 97 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #112 ; sp adj
__Ld116_rt_array_arena_alloc_desc_native_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #24 ; hv const_int val
    bl _hexa_arena_alloc ; call hexa_arena_alloc
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    cbz x1, __Ld116_rt_array_arena_alloc_desc_native_bb2 ; br_cond: !payload -> else
    b __Ld116_rt_array_arena_alloc_desc_native_bb1 ; branch -> then
__Ld116_rt_array_arena_alloc_desc_native_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__Ld116_rt_array_arena_alloc_desc_native_bb2:
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #112 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_len_native
.private_extern _rt_array_len_native
    .p2align 2
_rt_array_len_native:
    .loc 1 107 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #80 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__Ld116_rt_array_len_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_to_int ; call hexa_to_int
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_get_native
.private_extern _rt_array_get_native
    .p2align 2
_rt_array_get_native:
    .loc 1 116 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #224 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__Ld116_rt_array_get_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #112] ; hv load L7
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #160] ; hv load L10
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #144] ; hv load L9
    ldp x2, x3, [sp, #192] ; hv load L12
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    add sp, sp, #224 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_set_native
.private_extern _rt_array_set_native
    .p2align 2
_rt_array_set_native:
    .loc 1 130 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #256 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__Ld116_rt_array_set_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #32] ; hv load L2
    mov x1, x0 ; __hx_tag: payload = v.tag
    movz x0, #0 ; __hx_tag: TAG_INT
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #128] ; hv load L8
    ldp x4, x5, [sp, #160] ; hv load L10
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #224] ; hv load L14
    ldp x4, x5, [sp, #192] ; hv load L12
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #256 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_pop_native
.private_extern _rt_array_pop_native
    .p2align 2
_rt_array_pop_native:
    .loc 1 146 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #160 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__Ld116_rt_array_pop_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _rt_array_get_native ; call rt_array_get_native
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    ldp x4, x5, [sp, #96] ; hv load L6
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #160 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_shift_native
.private_extern _rt_array_shift_native
    .p2align 2
_rt_array_shift_native:
    .loc 1 163 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #496 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__Ld116_rt_array_shift_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #128] ; hv load L8
    bl _rt_array_get_native ; call rt_array_get_native
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #208] ; hv store L13
    b __Ld116_rt_array_shift_native_bb1 ; branch
__Ld116_rt_array_shift_native_bb1:
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #192] ; hv load L12
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    cbz x1, __Ld116_rt_array_shift_native_bb3 ; br_cond: !payload -> else
    b __Ld116_rt_array_shift_native_bb2 ; branch -> then
__Ld116_rt_array_shift_native_bb2:
    ldp x0, x1, [sp, #208] ; hv load L13
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #288] ; hv load L18
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #352] ; hv load L22
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #256] ; hv load L16
    ldp x4, x5, [sp, #320] ; hv load L20
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #256] ; hv load L16
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #432] ; hv load L27
    ldp x4, x5, [sp, #384] ; hv load L24
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #448] ; hv store L28
    ldp x0, x1, [sp, #208] ; hv load L13
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #464] ; hv load L29
    stp x0, x1, [sp, #208] ; hv store L13
    b __Ld116_rt_array_shift_native_bb1 ; branch
__Ld116_rt_array_shift_native_bb3:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    ldp x4, x5, [sp, #192] ; hv load L12
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #480] ; hv store L30
    ldp x0, x1, [sp, #160] ; hv load L10
    add sp, sp, #496 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_array_truncate_native
.private_extern _rt_array_truncate_native
    .p2align 2
_rt_array_truncate_native:
    .loc 1 194 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #256 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__Ld116_rt_array_truncate_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    ldp x2, x3, [sp, #112] ; hv load L7
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    cbz x1, __Ld116_rt_array_truncate_native_bb2 ; br_cond: !payload -> else
    b __Ld116_rt_array_truncate_native_bb1 ; branch -> then
__Ld116_rt_array_truncate_native_bb1:
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #144] ; hv store L9
    b __Ld116_rt_array_truncate_native_bb2 ; branch
__Ld116_rt_array_truncate_native_bb2:
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #144] ; hv load L9
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    cbz x1, __Ld116_rt_array_truncate_native_bb4 ; br_cond: !payload -> else
    b __Ld116_rt_array_truncate_native_bb3 ; branch -> then
__Ld116_rt_array_truncate_native_bb3:
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #144] ; hv store L9
    b __Ld116_rt_array_truncate_native_bb4 ; branch
__Ld116_rt_array_truncate_native_bb4:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    ldp x4, x5, [sp, #144] ; hv load L9
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #256 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
