// array_typed_leaf_f64_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array typed-leaf i64 DISPATCH).
// GENERATED: tool/regen_array_typed_leaf_f64_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o array_typed_leaf_f64_arm64.s stdlib/runtime/array_typed_leaf_f64.hexa.
//   Provides the 4 packed-i64 array dispatcher natives (hexa_arr_f64_new/push/len/box).
//   ABI: Mach-O, _-prefixed. External U-floor: malloc realloc write hexa_exit hexa_throw (libc-bearing: realloc grow dissolves the
//   array_core.hexa:25 wall via extern realloc CALL; the C body carries the same undefs).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE + ar this
//   .o into runtime.a so the 4 i64 dispatchers drop from the compiled runtime_core.c.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /tmp/f64regen/stdlib/runtime/array_typed_leaf_f64.hexa
.file 1 "stdlib/runtime/array_typed_leaf_f64.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _hexa_arr_f64_new
.private_extern _hexa_arr_f64_new
    .p2align 2
_hexa_arr_f64_new:
    .loc 1 38 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #224 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L1161_hexa_arr_f64_new_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    cbz x1, __L1161_hexa_arr_f64_new_bb2 ; br_cond: !payload -> else
    b __L1161_hexa_arr_f64_new_bb1 ; branch -> then
__L1161_hexa_arr_f64_new_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    stp x0, x1, [sp, #16] ; hv store L1
    b __L1161_hexa_arr_f64_new_bb2 ; branch
__L1161_hexa_arr_f64_new_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #16 ; hv const_int val
    bl _malloc ; call malloc
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _malloc ; call malloc
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    ldp x4, x5, [sp, #144] ; hv load L9
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_store32: addr = ptr + off
    str w5, [x1] ; __hx_ptr_store32: *(addr) = (i32)val
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x0, #0 ; __hx_ptr_store32: TAG_INT
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #12 ; hv const_int val
    ldp x4, x5, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_store32: addr = ptr + off
    str w5, [x1] ; __hx_ptr_store32: *(addr) = (i32)val
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x0, #0 ; __hx_ptr_store32: TAG_INT
    stp x0, x1, [sp, #192] ; hv store L12
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #5 ; hv const_int val
    ldp x2, x3, [sp, #80] ; hv load L5
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    add sp, sp, #224 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arr_f64_push_bits
.private_extern _hexa_arr_f64_push_bits
    .p2align 2
_hexa_arr_f64_push_bits:
    .loc 1 53 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #544 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L1161_hexa_arr_f64_push_bits_bb0:
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
    add x1, x1, x3 ; __hx_ptr_load32: addr = ptr + off
    ldr w1, [x1] ; __hx_ptr_load32: w1 = *(i32*)addr
    movz x0, #0 ; __hx_ptr_load32: TAG_INT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #12 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load32: addr = ptr + off
    ldr w1, [x1] ; __hx_ptr_load32: w1 = *(i32*)addr
    movz x0, #0 ; __hx_ptr_load32: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #112] ; hv load L7
    cmp x1, x3 ; __hx_payload_ge: cmp payloads
    cset x0, ge ; __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl _hexa_bool ; __hx_payload_ge: box bool
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    cbz x1, __L1161_hexa_arr_f64_push_bits_bb2 ; br_cond: !payload -> else
    b __L1161_hexa_arr_f64_push_bits_bb1 ; branch -> then
__L1161_hexa_arr_f64_push_bits_bb1:
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #2 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #176] ; hv load L11
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #240] ; hv load L15
    bl _realloc ; call realloc
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    cbz x1, __L1161_hexa_arr_f64_push_bits_bb4 ; br_cond: !payload -> else
    b __L1161_hexa_arr_f64_push_bits_bb3 ; branch -> then
__L1161_hexa_arr_f64_push_bits_bb2:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #448] ; hv store L28
    ldp x0, x1, [sp, #448] ; hv load L28
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #432] ; hv load L27
    ldp x2, x3, [sp, #464] ; hv load L29
    ldp x4, x5, [sp, #16] ; hv load L1
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #432] ; hv load L27
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #480] ; hv store L30
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #496] ; hv store L31
    ldp x0, x1, [sp, #496] ; hv load L31
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    ldp x4, x5, [x15] ; hv load L32
    add x1, x1, x3 ; __hx_ptr_store32: addr = ptr + off
    str w5, [x1] ; __hx_ptr_store32: *(addr) = (i32)val
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x0, #0 ; __hx_ptr_store32: TAG_INT
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #544 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L1161_hexa_arr_f64_push_bits_bb3:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr0@PAGE ; hv str ptr page
    add x1, x1, .LCstr0@PAGEOFF ; hv str ptr off
    movz x0, #0 ; __hx_str_ptr: TAG_INT
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    stp x0, x1, [sp, #336] ; hv store L21
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    ldp x2, x3, [sp, #336] ; hv load L21
    movz x4, #0 ; hv const_int: TAG_INT
    movz x5, #20 ; hv const_int val
    bl _write ; call write
    stp x0, x1, [sp, #352] ; hv store L22
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    bl _hexa_exit ; call hexa_exit
    stp x0, x1, [sp, #368] ; hv store L23
    b __L1161_hexa_arr_f64_push_bits_bb4 ; branch
__L1161_hexa_arr_f64_push_bits_bb4:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    ldp x4, x5, [sp, #272] ; hv load L17
    add x1, x1, x3 ; __hx_ptr_store64: addr = ptr + off
    str x5, [x1] ; __hx_ptr_store64: *(addr) = val
    movz x0, #0 ; __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x0, #0 ; __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #12 ; hv const_int val
    ldp x4, x5, [sp, #176] ; hv load L11
    add x1, x1, x3 ; __hx_ptr_store32: addr = ptr + off
    str w5, [x1] ; __hx_ptr_store32: *(addr) = (i32)val
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x0, #0 ; __hx_ptr_store32: TAG_INT
    stp x0, x1, [sp, #400] ; hv store L25
    b __L1161_hexa_arr_f64_push_bits_bb2 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #544 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arr_f64_len
.private_extern _hexa_arr_f64_len
    .p2align 2
_hexa_arr_f64_len:
    .loc 1 79 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #64 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L1161_hexa_arr_f64_len_bb0:
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
    add x1, x1, x3 ; __hx_ptr_load32: addr = ptr + off
    ldr w1, [x1] ; __hx_ptr_load32: w1 = *(i32*)addr
    movz x0, #0 ; __hx_ptr_load32: TAG_INT
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #64 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _hexa_arr_f64_box
.private_extern _hexa_arr_f64_box
    .p2align 2
_hexa_arr_f64_box:
    .loc 1 86 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #304 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L1161_hexa_arr_f64_box_bb0:
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
    add x1, x1, x3 ; __hx_ptr_load32: addr = ptr + off
    ldr w1, [x1] ; __hx_ptr_load32: w1 = *(i32*)addr
    movz x0, #0 ; __hx_ptr_load32: TAG_INT
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    cbz x1, __L1161_hexa_arr_f64_box_bb2 ; br_cond: !payload -> else
    b __L1161_hexa_arr_f64_box_bb1 ; branch -> then
__L1161_hexa_arr_f64_box_bb1:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr1@PAGE ; hv str ptr page
    add x1, x1, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_throw ; call hexa_throw
    stp x0, x1, [sp, #128] ; hv store L8
    b __L1161_hexa_arr_f64_box_bb2 ; branch
__L1161_hexa_arr_f64_box_bb2:
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #80] ; hv load L5
    cmp x1, x3 ; __hx_payload_ge: cmp payloads
    cset x0, ge ; __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl _hexa_bool ; __hx_payload_ge: box bool
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    cbz x1, __L1161_hexa_arr_f64_box_bb4 ; br_cond: !payload -> else
    b __L1161_hexa_arr_f64_box_bb3 ; branch -> then
__L1161_hexa_arr_f64_box_bb3:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr1@PAGE ; hv str ptr page
    add x1, x1, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_throw ; call hexa_throw
    stp x0, x1, [sp, #176] ; hv store L11
    b __L1161_hexa_arr_f64_box_bb4 ; branch
__L1161_hexa_arr_f64_box_bb4:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #8 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #240] ; hv load L15
    add x1, x1, x3 ; __hx_ptr_load64: addr = ptr + off
    ldr x1, [x1] ; __hx_ptr_load64: x1 = *(addr)
    movz x0, #0 ; __hx_ptr_load64: TAG_INT
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    movz x0, #1 ; __hx_bits_f64: TAG_FLOAT
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    add sp, sp, #304 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __TEXT,__const
.LCstr0:
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x61, 0x72, 0x72, 0x5f, 0x66, 0x36, 0x34, 0x5f, 0x70
    .byte 0x75, 0x73, 0x68, 0x0a, 0x00
.section __TEXT,__const
.LCstr1:
    .byte 0x69, 0x6e, 0x64, 0x65, 0x78, 0x20, 0x6f, 0x75, 0x74, 0x20, 0x6f, 0x66, 0x20, 0x62, 0x6f, 0x75
    .byte 0x6e, 0x64, 0x73, 0x00
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
