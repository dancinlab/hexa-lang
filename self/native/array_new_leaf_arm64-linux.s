// array_new_leaf_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ARR-NEW constructors).
// GENERATED: tool/regen_array_new_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o array_new_leaf_arm64-linux.s stdlib/runtime/array_new_leaf.hexa.
//   Provides the empty-array constructor native (hexa_array_new · calloc mint).
//   ABI: ELF aarch64, no underscore. External U-floor: calloc hexa_exit malloc write exit (calloc the only new floor entrant; pair-clean, no shim).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this
//   .o into runtime.a so hexa_array_new drops from the compiled runtime_core.c.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/array_new_leaf.hexa
.file 1 "stdlib/runtime/array_new_leaf.hexa"
.text
.globl hexa_array_new
.hidden hexa_array_new
    .p2align 2
hexa_array_new:
    .loc 1 26 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #48 // sp adj
_Le334_hexa_array_new_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl calloc // call calloc
    stp x0, x1, [sp, #0] // hv store L0
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #16] // hv store L1
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #5 // hv const_int val
    ldp x2, x3, [sp, #16] // hv load L1
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #48 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",%progbits
