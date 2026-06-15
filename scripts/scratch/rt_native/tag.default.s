; hexa-lang emit pass — target=arm64-apple-darwin
; source: .claude/worktrees/agent-aa765db92c21fd1af/scripts/scratch/rt_native/tag_probe.hexa
.file 1 ".claude/worktrees/agent-aa765db92c21fd1af/scripts/scratch/rt_native/tag_probe.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _tag_dispatch
.private_extern _tag_dispatch
    .p2align 2
_tag_dispatch:
    .loc 1 14 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #144 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L537f_tag_dispatch_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_type_of ; call hexa_type_of
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE ; hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_tag_dispatch_bb2 ; br_cond: !truthy -> else
    b __L537f_tag_dispatch_bb1 ; branch -> then
__L537f_tag_dispatch_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_tag_dispatch_bb2:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_tag_dispatch_bb4 ; br_cond: !truthy -> else
    b __L537f_tag_dispatch_bb3 ; branch -> then
__L537f_tag_dispatch_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_tag_dispatch_bb4:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    mvn x1, x1 ; hv const_int: negate
    add sp, sp, #144 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _is_intval
.private_extern _is_intval
    .p2align 2
_is_intval:
    .loc 1 26 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #48 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L537f_is_intval_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_type_of ; call hexa_type_of
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE ; hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    add sp, sp, #48 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _classify
.private_extern _classify
    .p2align 2
_classify:
    .loc 1 33 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #176 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L537f_classify_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_type_of ; call hexa_type_of
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE ; hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_classify_bb2 ; br_cond: !truthy -> else
    b __L537f_classify_bb1 ; branch -> then
__L537f_classify_bb1:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_classify_bb2:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr2@PAGE ; hv str ptr page
    add x3, x3, .LCstr2@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_classify_bb4 ; br_cond: !truthy -> else
    b __L537f_classify_bb3 ; branch -> then
__L537f_classify_bb3:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_classify_bb4:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_classify_bb6 ; br_cond: !truthy -> else
    b __L537f_classify_bb5 ; branch -> then
__L537f_classify_bb5:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #2 ; hv const_int val
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_classify_bb6:
    ldp x0, x1, [sp, #32] ; hv load L2
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr3@PAGE ; hv str ptr page
    add x3, x3, .LCstr3@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_classify_bb8 ; br_cond: !truthy -> else
    b __L537f_classify_bb7 ; branch -> then
__L537f_classify_bb7:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #3 ; hv const_int val
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_classify_bb8:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #9 ; hv const_int val
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _maybe_double
.private_extern _maybe_double
    .p2align 2
_maybe_double:
    .loc 1 44 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #80 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L537f_maybe_double_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_type_of ; call hexa_type_of
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE ; hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF ; hv str ptr off
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_maybe_double_bb2 ; br_cond: !truthy -> else
    b __L537f_maybe_double_bb1 ; branch -> then
__L537f_maybe_double_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_maybe_double_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #80 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _main
    .p2align 2
_main:
    .loc 1 51 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    bl _hexa_set_args ; entry: wire argc/argv -> hexa_set_args
    sub sp, sp, #224 ; sp adj
__L537f_main_bb0:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #41 ; hv const_int val
    bl _tag_dispatch ; call tag_dispatch
    stp x0, x1, [sp, #0] ; hv store L0
    ldp x0, x1, [sp, #0] ; hv load L0
    stp x0, x1, [sp, #16] ; hv store L1
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr4@PAGE ; hv str ptr page
    add x1, x1, .LCstr4@PAGEOFF ; hv str ptr off
    bl _tag_dispatch ; call tag_dispatch
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    movz x0, #1 ; hv const_float: TAG_FLOAT
    adrp x14, .LCflt0@PAGE ; hv float pool page
    add x14, x14, .LCflt0@PAGEOFF ; hv float pool off
    ldr x1, [x14] ; hv load f64 bits .LCflt0
    bl _classify ; call classify
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #21 ; hv const_int val
    bl _maybe_double ; call maybe_double
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #7 ; hv const_int val
    bl _is_intval ; call is_intval
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L537f_main_bb2 ; br_cond: !truthy -> else
    b __L537f_main_bb1 ; branch -> then
__L537f_main_bb1:
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #112] ; hv load L7
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    add sp, sp, #224 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L537f_main_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    mvn x1, x1 ; hv const_int: negate
    add sp, sp, #224 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __TEXT,__const
.LCstr0:
    .byte 0x69, 0x6e, 0x74, 0x00
.section __TEXT,__const
.LCstr1:
    .byte 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67, 0x00
.section __TEXT,__const
.LCstr2:
    .byte 0x66, 0x6c, 0x6f, 0x61, 0x74, 0x00
.section __TEXT,__const
.LCstr3:
    .byte 0x62, 0x6f, 0x6f, 0x6c, 0x00
.section __TEXT,__const
.LCstr4:
    .byte 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x00
.section __TEXT,__const
    .p2align 3
.LCflt0:
    .double 3.14
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
