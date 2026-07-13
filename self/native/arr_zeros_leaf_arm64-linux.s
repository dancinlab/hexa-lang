// arr_zeros_leaf_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ZEROS-LEAF constructors).
// GENERATED: tool/regen_arr_zeros_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o arr_zeros_leaf_arm64-linux.s stdlib/runtime/arr_zeros_leaf.hexa.
//   Provides the 2 boxed-zeros constructor natives (hexa_arr_zeros_leaf{,_int}).
//   ABI: ELF aarch64, no underscore. External U-floor: hexa_ptr_alloc hexa_exit — CARRIER-ONLY (HexaVal-ABI); a raw libc U here is a
//   pair-vs-C-ABI miscompile, not a sanctioned floor entrant.
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this
//   .o into runtime.a so the 2 zeros constructors drop from the compiled runtime_core.c.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/arr_zeros_leaf.hexa
.file 1 "stdlib/runtime/arr_zeros_leaf.hexa"
.text
.globl hexa_arr_zeros_leaf
.hidden hexa_arr_zeros_leaf
    .p2align 2
hexa_arr_zeros_leaf:
    .loc 1 51 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #672 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L8cdb_hexa_arr_zeros_leaf_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #32 // hv const_int val
    bl hexa_ptr_alloc // call hexa_ptr_alloc
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_bb2 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_bb1 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    bl hexa_exit // call hexa_exit
    stp x0, x1, [sp, #80] // hv store L5
    b _L8cdb_hexa_arr_zeros_leaf_bb2 // branch
_L8cdb_hexa_arr_zeros_leaf_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #24 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #5 // hv const_int val
    ldp x2, x3, [sp, #32] // hv load L2
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_bb4 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_bb3 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _L8cdb_hexa_arr_zeros_leaf_bb5 // branch
_L8cdb_hexa_arr_zeros_leaf_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    fmov d0, x1 // __hx_payload_f2i: d0 = v.f bits
    fcvtzs x1, d0 // __hx_payload_f2i: x1 = (i64)trunc(v.f)
    movz x0, #0 // __hx_payload_f2i: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #224] // hv store L14
    b _L8cdb_hexa_arr_zeros_leaf_bb5 // branch
_L8cdb_hexa_arr_zeros_leaf_bb5:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_bb7 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_bb6 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_bb6:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_ptr_alloc // call hexa_ptr_alloc
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
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_bb9 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_bb8 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_bb7:
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #672 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L8cdb_hexa_arr_zeros_leaf_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    bl hexa_exit // call hexa_exit
    stp x0, x1, [sp, #432] // hv store L27
    b _L8cdb_hexa_arr_zeros_leaf_bb9 // branch
_L8cdb_hexa_arr_zeros_leaf_bb9:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    b _L8cdb_hexa_arr_zeros_leaf_bb10 // branch
_L8cdb_hexa_arr_zeros_leaf_bb10:
    ldp x0, x1, [sp, #496] // hv load L31
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_bb12 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_bb11 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #448] // hv load L28
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #384] // hv load L24
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    ldp x0, x1, [sp, #384] // hv load L24
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #384] // hv load L24
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    stp x0, x1, [sp, #496] // hv store L31
    b _L8cdb_hexa_arr_zeros_leaf_bb10 // branch
_L8cdb_hexa_arr_zeros_leaf_bb12:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #384] // hv load L24
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    ldp x4, x5, [sp, #224] // hv load L14
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    ldp x4, x5, [sp, #224] // hv load L14
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L8cdb_hexa_arr_zeros_leaf_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #672 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hexa_arr_zeros_leaf_int
.hidden hexa_arr_zeros_leaf_int
    .p2align 2
hexa_arr_zeros_leaf_int:
    .loc 1 94 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #672 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L8cdb_hexa_arr_zeros_leaf_int_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #32 // hv const_int val
    bl hexa_ptr_alloc // call hexa_ptr_alloc
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_int_bb2 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_int_bb1 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_int_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    bl hexa_exit // call hexa_exit
    stp x0, x1, [sp, #80] // hv store L5
    b _L8cdb_hexa_arr_zeros_leaf_int_bb2 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #24 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #5 // hv const_int val
    ldp x2, x3, [sp, #32] // hv load L2
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_int_bb4 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_int_bb3 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_int_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _L8cdb_hexa_arr_zeros_leaf_int_bb5 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    fmov d0, x1 // __hx_payload_f2i: d0 = v.f bits
    fcvtzs x1, d0 // __hx_payload_f2i: x1 = (i64)trunc(v.f)
    movz x0, #0 // __hx_payload_f2i: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #224] // hv store L14
    b _L8cdb_hexa_arr_zeros_leaf_int_bb5 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb5:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_int_bb7 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_int_bb6 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_int_bb6:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_ptr_alloc // call hexa_ptr_alloc
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
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_int_bb9 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_int_bb8 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_int_bb7:
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #672 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L8cdb_hexa_arr_zeros_leaf_int_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    bl hexa_exit // call hexa_exit
    stp x0, x1, [sp, #432] // hv store L27
    b _L8cdb_hexa_arr_zeros_leaf_int_bb9 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb9:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    b _L8cdb_hexa_arr_zeros_leaf_int_bb10 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb10:
    ldp x0, x1, [sp, #496] // hv load L31
    cbz x1, _L8cdb_hexa_arr_zeros_leaf_int_bb12 // br_cond: !payload -> else
    b _L8cdb_hexa_arr_zeros_leaf_int_bb11 // branch -> then
_L8cdb_hexa_arr_zeros_leaf_int_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #448] // hv load L28
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #384] // hv load L24
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    ldp x0, x1, [sp, #384] // hv load L24
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #384] // hv load L24
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    stp x0, x1, [sp, #496] // hv store L31
    b _L8cdb_hexa_arr_zeros_leaf_int_bb10 // branch
_L8cdb_hexa_arr_zeros_leaf_int_bb12:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #384] // hv load L24
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    ldp x4, x5, [sp, #224] // hv load L14
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    ldp x4, x5, [sp, #224] // hv load L14
    add x1, x1, x3 // __hx_ptr_store64: addr = ptr + off
    str x5, [x1] // __hx_ptr_store64: *(addr) = val
    movz x0, #0 // __hx_ptr_store64: TAG_INT (ret ptr)
    ldp x0, x1, [sp, #32] // hv load L2
    movz x0, #0 // __hx_ptr_store64: TAG_INT
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L8cdb_hexa_arr_zeros_leaf_int_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #672 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",%progbits
