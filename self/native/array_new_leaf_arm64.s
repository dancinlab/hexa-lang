// array_new_leaf_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ARR-NEW constructors).
// GENERATED: tool/regen_array_new_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o array_new_leaf_arm64.s stdlib/runtime/array_new_leaf.hexa.
//   Provides the empty-array constructor native (hexa_array_new · carrier mint + explicit zero).
//   ABI: Mach-O, _-prefixed. External U-floor: hexa_heap_zalloc hexa_exit hexa_bool — CARRIER-ONLY (HexaVal-ABI); a raw libc U here is a
//   pair-vs-C-ABI miscompile, not a sanctioned floor entrant (the #4930 break).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this
//   .o into runtime.a so hexa_array_new drops from the compiled runtime_core.c.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /home/aiden/hexa-lang/stdlib/runtime/array_new_leaf.hexa
.file 1 "stdlib/runtime/array_new_leaf.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _hexa_array_new
.private_extern _hexa_array_new
    .p2align 2
_hexa_array_new:
    .loc 1 56 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #96 ; sp adj
__L0635_hexa_array_new_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #32 ; hv const_int val
    bl _hexa_heap_zalloc ; call hexa_heap_zalloc
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    cbz x1, __L0635_hexa_array_new_bb2 ; br_cond: !payload -> else
    b __L0635_hexa_array_new_bb1 ; branch -> then
__L0635_hexa_array_new_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    bl _hexa_exit ; call hexa_exit
    stp x0, x1, [sp, #64] ; hv store L4
    b __L0635_hexa_array_new_bb2 ; branch
__L0635_hexa_array_new_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #5 ; hv const_int val
    ldp x2, x3, [sp, #16] ; hv load L1
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #96 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
