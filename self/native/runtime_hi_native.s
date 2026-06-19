// runtime_hi_native.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B Z2a).
// GENERATED: tool/regen_runtime_hi_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o runtime_hi_native.s runtime_hi_lib.hexa (lib-only head of self/runtime_hi.hexa).
//   Provides rt_str_* (zero C): split/lines/pad_left/pad_right/repeat/center +
//   to_upper/to_lower/trim/trim_start/trim_end +
//   starts_with_b/ends_with_b/contains_b + from_int (15 fns). ABI: Mach-O, _rt_str_* underscore + .private_extern.
//   Lets this target avoid #include "runtime_hi_gen.c" (leg B ls-reduction).
.file 1 "self/runtime_hi.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _rt_str_split
.private_extern _rt_str_split
    .p2align 2
_rt_str_split:
    .loc 1 22 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #416 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L62a9_rt_str_split_bb0:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_split_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_split_bb1 ; branch -> then
__L62a9_rt_str_split_bb1:
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #416 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_split_bb2:
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #160] ; hv store L10
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_split_bb3 ; branch
__L62a9_rt_str_split_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #144] ; hv load L9
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #208] ; hv load L13
    bl _hexa_cmp_le ; binop <=
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_split_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_split_bb4 ; branch -> then
__L62a9_rt_str_split_bb4:
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #144] ; hv load L9
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #176] ; hv load L11
    ldp x4, x5, [sp, #240] ; hv load L15
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_split_bb7 ; br_cond: !truthy -> else
    b __L62a9_rt_str_split_bb6 ; branch -> then
__L62a9_rt_str_split_bb5:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #160] ; hv load L10
    ldp x4, x5, [sp, #368] ; hv load L23
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #384] ; hv load L24
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #48] ; hv load L3
    add sp, sp, #416 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_split_bb6:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #160] ; hv load L10
    ldp x4, x5, [sp, #176] ; hv load L11
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #304] ; hv load L19
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #144] ; hv load L9
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_split_bb8 ; branch
__L62a9_rt_str_split_bb7:
    ldp x0, x1, [sp, #176] ; hv load L11
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_split_bb8 ; branch
__L62a9_rt_str_split_bb8:
    b __L62a9_rt_str_split_bb3 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #416 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_lines
.private_extern _rt_str_lines
    .p2align 2
_rt_str_lines:
    .loc 1 45 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #32 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_lines_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE ; hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF ; hv str ptr off
    bl _rt_str_split ; call rt_str_split
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    add sp, sp, #32 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_pad_left
.private_extern _rt_str_pad_left
    .p2align 2
_rt_str_pad_left:
    .loc 1 52 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #432 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L62a9_rt_str_pad_left_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_left_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_left_bb1 ; branch -> then
__L62a9_rt_str_pad_left_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_pad_left_bb2:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_left_bb4 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_left_bb3 ; branch -> then
__L62a9_rt_str_pad_left_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_pad_left_bb4:
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #64] ; hv load L4
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    ldp x2, x3, [sp, #192] ; hv load L12
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_left_bb6 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_left_bb5 ; branch -> then
__L62a9_rt_str_pad_left_bb5:
    ldp x0, x1, [sp, #224] ; hv load L14
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    stp x0, x1, [sp, #224] ; hv store L14
    b __L62a9_rt_str_pad_left_bb6 ; branch
__L62a9_rt_str_pad_left_bb6:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    stp x0, x1, [sp, #320] ; hv store L20
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #336] ; hv store L21
    b __L62a9_rt_str_pad_left_bb7 ; branch
__L62a9_rt_str_pad_left_bb7:
    ldp x0, x1, [sp, #336] ; hv load L21
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_left_bb9 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_left_bb8 ; branch -> then
__L62a9_rt_str_pad_left_bb8:
    ldp x0, x1, [sp, #320] ; hv load L20
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #336] ; hv load L21
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #384] ; hv load L24
    stp x0, x1, [sp, #336] ; hv store L21
    b __L62a9_rt_str_pad_left_bb7 ; branch
__L62a9_rt_str_pad_left_bb9:
    ldp x0, x1, [sp, #320] ; hv load L20
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_pad_right
.private_extern _rt_str_pad_right
    .p2align 2
_rt_str_pad_right:
    .loc 1 70 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #432 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L62a9_rt_str_pad_right_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_right_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_right_bb1 ; branch -> then
__L62a9_rt_str_pad_right_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_pad_right_bb2:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_right_bb4 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_right_bb3 ; branch -> then
__L62a9_rt_str_pad_right_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_pad_right_bb4:
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #64] ; hv load L4
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    ldp x2, x3, [sp, #192] ; hv load L12
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_right_bb6 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_right_bb5 ; branch -> then
__L62a9_rt_str_pad_right_bb5:
    ldp x0, x1, [sp, #224] ; hv load L14
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    stp x0, x1, [sp, #224] ; hv store L14
    b __L62a9_rt_str_pad_right_bb6 ; branch
__L62a9_rt_str_pad_right_bb6:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #336] ; hv store L21
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #352] ; hv store L22
    b __L62a9_rt_str_pad_right_bb7 ; branch
__L62a9_rt_str_pad_right_bb7:
    ldp x0, x1, [sp, #352] ; hv load L22
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_pad_right_bb9 ; br_cond: !truthy -> else
    b __L62a9_rt_str_pad_right_bb8 ; branch -> then
__L62a9_rt_str_pad_right_bb8:
    ldp x0, x1, [sp, #320] ; hv load L20
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #352] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #400] ; hv load L25
    stp x0, x1, [sp, #352] ; hv store L22
    b __L62a9_rt_str_pad_right_bb7 ; branch
__L62a9_rt_str_pad_right_bb9:
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    add sp, sp, #432 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_repeat
.private_extern _rt_str_repeat
    .p2align 2
_rt_str_repeat:
    .loc 1 89 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #176 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L62a9_rt_str_repeat_bb0:
    ldp x0, x1, [sp, #16] ; hv load L1
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_le ; binop <=
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_repeat_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_repeat_bb1 ; branch -> then
__L62a9_rt_str_repeat_bb1:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr1@PAGE ; hv str ptr page
    add x1, x1, .LCstr1@PAGEOFF ; hv str ptr off
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_repeat_bb2:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_repeat_bb3 ; branch
__L62a9_rt_str_repeat_bb3:
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_repeat_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_repeat_bb4 ; branch -> then
__L62a9_rt_str_repeat_bb4:
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_repeat_bb3 ; branch
__L62a9_rt_str_repeat_bb5:
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    add sp, sp, #176 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_center
.private_extern _rt_str_center
    .p2align 2
_rt_str_center:
    .loc 1 101 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #656 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
    stp x4, x5, [sp, #32] ; ingress param 2
__L62a9_rt_str_center_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L3
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #32] ; hv load L2
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #64] ; hv load L4
    ldp x2, x3, [sp, #16] ; hv load L1
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb1 ; branch -> then
__L62a9_rt_str_center_bb1:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #656 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_center_bb2:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb4 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb3 ; branch -> then
__L62a9_rt_str_center_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    add sp, sp, #656 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_center_bb4:
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #64] ; hv load L4
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #2 ; hv const_int val
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #192] ; hv load L12
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #224] ; hv load L14
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb6 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb5 ; branch -> then
__L62a9_rt_str_center_bb5:
    ldp x0, x1, [sp, #288] ; hv load L18
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #288] ; hv store L18
    b __L62a9_rt_str_center_bb6 ; branch
__L62a9_rt_str_center_bb6:
    ldp x0, x1, [sp, #256] ; hv load L16
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #384] ; hv load L24
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_mul ; binop *
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #400] ; hv load L25
    ldp x2, x3, [sp, #256] ; hv load L16
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb7 ; branch -> then
__L62a9_rt_str_center_bb7:
    ldp x0, x1, [sp, #384] ; hv load L24
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #448] ; hv store L28
    ldp x0, x1, [sp, #448] ; hv load L28
    stp x0, x1, [sp, #384] ; hv store L24
    b __L62a9_rt_str_center_bb8 ; branch
__L62a9_rt_str_center_bb8:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #464] ; hv load L29
    stp x0, x1, [sp, #480] ; hv store L30
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #496] ; hv store L31
    b __L62a9_rt_str_center_bb9 ; branch
__L62a9_rt_str_center_bb9:
    ldp x0, x1, [sp, #496] ; hv load L31
    ldp x2, x3, [sp, #288] ; hv load L18
    bl _hexa_cmp_lt ; binop <
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb11 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb10 ; branch -> then
__L62a9_rt_str_center_bb10:
    ldp x0, x1, [sp, #480] ; hv load L30
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_array_push ; call hexa_array_push
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    ldp x0, x1, [sp, #496] ; hv load L31
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    add x15, sp, #544 ; hv frame base
    stp x0, x1, [x15] ; hv store L34
    add x15, sp, #544 ; hv frame base
    ldp x0, x1, [x15] ; hv load L34
    stp x0, x1, [sp, #496] ; hv store L31
    b __L62a9_rt_str_center_bb9 ; branch
__L62a9_rt_str_center_bb11:
    ldp x0, x1, [sp, #480] ; hv load L30
    ldp x2, x3, [sp, #0] ; hv load L0
    bl _hexa_array_push ; call hexa_array_push
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    b __L62a9_rt_str_center_bb12 ; branch
__L62a9_rt_str_center_bb12:
    add x15, sp, #576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L36
    ldp x2, x3, [sp, #384] ; hv load L24
    bl _hexa_cmp_lt ; binop <
    add x15, sp, #592 ; hv frame base
    stp x0, x1, [x15] ; hv store L37
    add x15, sp, #592 ; hv frame base
    ldp x0, x1, [x15] ; hv load L37
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_center_bb14 ; br_cond: !truthy -> else
    b __L62a9_rt_str_center_bb13 ; branch -> then
__L62a9_rt_str_center_bb13:
    ldp x0, x1, [sp, #480] ; hv load L30
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_array_push ; call hexa_array_push
    add x15, sp, #608 ; hv frame base
    stp x0, x1, [x15] ; hv store L38
    add x15, sp, #576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L36
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    add x15, sp, #624 ; hv frame base
    stp x0, x1, [x15] ; hv store L39
    add x15, sp, #624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L39
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    b __L62a9_rt_str_center_bb12 ; branch
__L62a9_rt_str_center_bb14:
    ldp x0, x1, [sp, #480] ; hv load L30
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    add x15, sp, #640 ; hv frame base
    stp x0, x1, [x15] ; hv store L40
    add x15, sp, #640 ; hv frame base
    ldp x0, x1, [x15] ; hv load L40
    add sp, sp, #656 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_to_upper
.private_extern _rt_str_to_upper
    .p2align 2
_rt_str_to_upper:
    .loc 1 134 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #384 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_to_upper_bb0:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr2@PAGE ; hv str ptr page
    add x1, x1, .LCstr2@PAGEOFF ; hv str ptr off
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_to_upper_bb1 ; branch
__L62a9_rt_str_to_upper_bb1:
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_upper_bb3 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_upper_bb2 ; branch -> then
__L62a9_rt_str_to_upper_bb2:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #97 ; hv const_int val
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_upper_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_upper_bb4 ; branch -> then
__L62a9_rt_str_to_upper_bb3:
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_to_upper_bb4:
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #122 ; hv const_int val
    bl _hexa_cmp_le ; binop <=
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_to_upper_bb6 ; branch
__L62a9_rt_str_to_upper_bb5:
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_to_upper_bb6 ; branch
__L62a9_rt_str_to_upper_bb6:
    ldp x0, x1, [sp, #176] ; hv load L11
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_upper_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_upper_bb7 ; branch -> then
__L62a9_rt_str_to_upper_bb7:
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #97 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #97 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #224] ; hv load L14
    ldp x4, x5, [sp, #256] ; hv load L16
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #272] ; hv load L17
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_to_upper_bb9 ; branch
__L62a9_rt_str_to_upper_bb8:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #96] ; hv load L6
    ldp x4, x5, [sp, #304] ; hv load L19
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #320] ; hv load L20
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_to_upper_bb9 ; branch
__L62a9_rt_str_to_upper_bb9:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_to_upper_bb1 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_to_lower
.private_extern _rt_str_to_lower
    .p2align 2
_rt_str_to_lower:
    .loc 1 151 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #384 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_to_lower_bb0:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr3@PAGE ; hv str ptr page
    add x1, x1, .LCstr3@PAGEOFF ; hv str ptr off
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_to_lower_bb1 ; branch
__L62a9_rt_str_to_lower_bb1:
    ldp x0, x1, [sp, #96] ; hv load L6
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_lower_bb3 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_lower_bb2 ; branch -> then
__L62a9_rt_str_to_lower_bb2:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #96] ; hv load L6
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #65 ; hv const_int val
    bl _hexa_cmp_ge ; binop >=
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_lower_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_lower_bb4 ; branch -> then
__L62a9_rt_str_to_lower_bb3:
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_to_lower_bb4:
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #90 ; hv const_int val
    bl _hexa_cmp_le ; binop <=
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_to_lower_bb6 ; branch
__L62a9_rt_str_to_lower_bb5:
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_to_lower_bb6 ; branch
__L62a9_rt_str_to_lower_bb6:
    ldp x0, x1, [sp, #176] ; hv load L11
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_to_lower_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_to_lower_bb7 ; branch -> then
__L62a9_rt_str_to_lower_bb7:
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #65 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #144] ; hv load L9
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #65 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #224] ; hv load L14
    ldp x4, x5, [sp, #256] ; hv load L16
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #272] ; hv load L17
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_to_lower_bb9 ; branch
__L62a9_rt_str_to_lower_bb8:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #96] ; hv load L6
    ldp x4, x5, [sp, #304] ; hv load L19
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #320] ; hv load L20
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_to_lower_bb9 ; branch
__L62a9_rt_str_to_lower_bb9:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #96] ; hv store L6
    b __L62a9_rt_str_to_lower_bb1 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_trim
.private_extern _rt_str_trim
    .p2align 2
_rt_str_trim:
    .loc 1 170 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #496 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_trim_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_bb1 ; branch
__L62a9_rt_str_trim_bb1:
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb3 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb2 ; branch -> then
__L62a9_rt_str_trim_bb2:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb4 ; branch -> then
__L62a9_rt_str_trim_bb3:
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #256] ; hv store L16
    b __L62a9_rt_str_trim_bb16 ; branch
__L62a9_rt_str_trim_bb4:
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_trim_bb6 ; branch
__L62a9_rt_str_trim_bb5:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #9 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_trim_bb6 ; branch
__L62a9_rt_str_trim_bb6:
    ldp x0, x1, [sp, #128] ; hv load L8
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb7 ; branch -> then
__L62a9_rt_str_trim_bb7:
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_trim_bb9 ; branch
__L62a9_rt_str_trim_bb8:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_trim_bb9 ; branch
__L62a9_rt_str_trim_bb9:
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb11 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb10 ; branch -> then
__L62a9_rt_str_trim_bb10:
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #192] ; hv store L12
    b __L62a9_rt_str_trim_bb12 ; branch
__L62a9_rt_str_trim_bb11:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #13 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    stp x0, x1, [sp, #192] ; hv store L12
    b __L62a9_rt_str_trim_bb12 ; branch
__L62a9_rt_str_trim_bb12:
    ldp x0, x1, [sp, #192] ; hv load L12
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb14 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb13 ; branch -> then
__L62a9_rt_str_trim_bb13:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_bb15 ; branch
__L62a9_rt_str_trim_bb14:
    b __L62a9_rt_str_trim_bb3 ; branch
__L62a9_rt_str_trim_bb15:
    b __L62a9_rt_str_trim_bb1 ; branch
__L62a9_rt_str_trim_bb16:
    ldp x0, x1, [sp, #256] ; hv load L16
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb18 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb17 ; branch -> then
__L62a9_rt_str_trim_bb17:
    ldp x0, x1, [sp, #256] ; hv load L16
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #288] ; hv load L18
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb20 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb19 ; branch -> then
__L62a9_rt_str_trim_bb18:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #48] ; hv load L3
    ldp x4, x5, [sp, #256] ; hv load L16
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #480] ; hv store L30
    ldp x0, x1, [sp, #480] ; hv load L30
    add sp, sp, #496 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_trim_bb19:
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #352] ; hv store L22
    b __L62a9_rt_str_trim_bb21 ; branch
__L62a9_rt_str_trim_bb20:
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #9 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    stp x0, x1, [sp, #352] ; hv store L22
    b __L62a9_rt_str_trim_bb21 ; branch
__L62a9_rt_str_trim_bb21:
    ldp x0, x1, [sp, #352] ; hv load L22
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb23 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb22 ; branch -> then
__L62a9_rt_str_trim_bb22:
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #384] ; hv store L24
    b __L62a9_rt_str_trim_bb24 ; branch
__L62a9_rt_str_trim_bb23:
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #400] ; hv load L25
    stp x0, x1, [sp, #384] ; hv store L24
    b __L62a9_rt_str_trim_bb24 ; branch
__L62a9_rt_str_trim_bb24:
    ldp x0, x1, [sp, #384] ; hv load L24
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb26 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb25 ; branch -> then
__L62a9_rt_str_trim_bb25:
    ldp x0, x1, [sp, #384] ; hv load L24
    stp x0, x1, [sp, #416] ; hv store L26
    b __L62a9_rt_str_trim_bb27 ; branch
__L62a9_rt_str_trim_bb26:
    ldp x0, x1, [sp, #320] ; hv load L20
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #13 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #432] ; hv load L27
    stp x0, x1, [sp, #416] ; hv store L26
    b __L62a9_rt_str_trim_bb27 ; branch
__L62a9_rt_str_trim_bb27:
    ldp x0, x1, [sp, #416] ; hv load L26
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_bb29 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_bb28 ; branch -> then
__L62a9_rt_str_trim_bb28:
    ldp x0, x1, [sp, #256] ; hv load L16
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #464] ; hv load L29
    stp x0, x1, [sp, #256] ; hv store L16
    b __L62a9_rt_str_trim_bb30 ; branch
__L62a9_rt_str_trim_bb29:
    b __L62a9_rt_str_trim_bb18 ; branch
__L62a9_rt_str_trim_bb30:
    b __L62a9_rt_str_trim_bb16 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #496 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_trim_start
.private_extern _rt_str_trim_start
    .p2align 2
_rt_str_trim_start:
    .loc 1 196 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #272 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_trim_start_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_start_bb1 ; branch
__L62a9_rt_str_trim_start_bb1:
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #32] ; hv load L2
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_start_bb3 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_start_bb2 ; branch -> then
__L62a9_rt_str_trim_start_bb2:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_start_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_start_bb4 ; branch -> then
__L62a9_rt_str_trim_start_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #48] ; hv load L3
    ldp x4, x5, [sp, #32] ; hv load L2
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    add sp, sp, #272 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_trim_start_bb4:
    ldp x0, x1, [sp, #112] ; hv load L7
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_trim_start_bb6 ; branch
__L62a9_rt_str_trim_start_bb5:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #9 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_trim_start_bb6 ; branch
__L62a9_rt_str_trim_start_bb6:
    ldp x0, x1, [sp, #128] ; hv load L8
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_start_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_start_bb7 ; branch -> then
__L62a9_rt_str_trim_start_bb7:
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_trim_start_bb9 ; branch
__L62a9_rt_str_trim_start_bb8:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_trim_start_bb9 ; branch
__L62a9_rt_str_trim_start_bb9:
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_start_bb11 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_start_bb10 ; branch -> then
__L62a9_rt_str_trim_start_bb10:
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #192] ; hv store L12
    b __L62a9_rt_str_trim_start_bb12 ; branch
__L62a9_rt_str_trim_start_bb11:
    ldp x0, x1, [sp, #96] ; hv load L6
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #13 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    stp x0, x1, [sp, #192] ; hv store L12
    b __L62a9_rt_str_trim_start_bb12 ; branch
__L62a9_rt_str_trim_start_bb12:
    ldp x0, x1, [sp, #192] ; hv load L12
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_start_bb14 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_start_bb13 ; branch -> then
__L62a9_rt_str_trim_start_bb13:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_start_bb15 ; branch
__L62a9_rt_str_trim_start_bb14:
    b __L62a9_rt_str_trim_start_bb3 ; branch
__L62a9_rt_str_trim_start_bb15:
    b __L62a9_rt_str_trim_start_bb1 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #272 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_trim_end
.private_extern _rt_str_trim_end
    .p2align 2
_rt_str_trim_end:
    .loc 1 210 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #288 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_trim_end_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_end_bb1 ; branch
__L62a9_rt_str_trim_end_bb1:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_end_bb3 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_end_bb2 ; branch -> then
__L62a9_rt_str_trim_end_bb2:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_end_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_end_bb4 ; branch -> then
__L62a9_rt_str_trim_end_bb3:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    ldp x4, x5, [sp, #48] ; hv load L3
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_trim_end_bb4:
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    b __L62a9_rt_str_trim_end_bb6 ; branch
__L62a9_rt_str_trim_end_bb5:
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #9 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #144] ; hv store L9
    b __L62a9_rt_str_trim_end_bb6 ; branch
__L62a9_rt_str_trim_end_bb6:
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_end_bb8 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_end_bb7 ; branch -> then
__L62a9_rt_str_trim_end_bb7:
    ldp x0, x1, [sp, #144] ; hv load L9
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_trim_end_bb9 ; branch
__L62a9_rt_str_trim_end_bb8:
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #176] ; hv store L11
    b __L62a9_rt_str_trim_end_bb9 ; branch
__L62a9_rt_str_trim_end_bb9:
    ldp x0, x1, [sp, #176] ; hv load L11
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_end_bb11 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_end_bb10 ; branch -> then
__L62a9_rt_str_trim_end_bb10:
    ldp x0, x1, [sp, #176] ; hv load L11
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_trim_end_bb12 ; branch
__L62a9_rt_str_trim_end_bb11:
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #13 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_trim_end_bb12 ; branch
__L62a9_rt_str_trim_end_bb12:
    ldp x0, x1, [sp, #208] ; hv load L13
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_trim_end_bb14 ; br_cond: !truthy -> else
    b __L62a9_rt_str_trim_end_bb13 ; branch -> then
__L62a9_rt_str_trim_end_bb13:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    stp x0, x1, [sp, #48] ; hv store L3
    b __L62a9_rt_str_trim_end_bb15 ; branch
__L62a9_rt_str_trim_end_bb14:
    b __L62a9_rt_str_trim_end_bb3 ; branch
__L62a9_rt_str_trim_end_bb15:
    b __L62a9_rt_str_trim_end_bb1 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_starts_with_b
.private_extern _rt_str_starts_with_b
    .p2align 2
_rt_str_starts_with_b:
    .loc 1 233 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #240 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L62a9_rt_str_starts_with_b_bb0:
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_starts_with_b_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_starts_with_b_bb1 ; branch -> then
__L62a9_rt_str_starts_with_b_bb1:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_starts_with_b_bb2:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_starts_with_b_bb3 ; branch
__L62a9_rt_str_starts_with_b_bb3:
    ldp x0, x1, [sp, #128] ; hv load L8
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #144] ; hv store L9
    ldp x0, x1, [sp, #144] ; hv load L9
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_starts_with_b_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_starts_with_b_bb4 ; branch -> then
__L62a9_rt_str_starts_with_b_bb4:
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #128] ; hv load L8
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #128] ; hv load L8
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #160] ; hv load L10
    ldp x2, x3, [sp, #176] ; hv load L11
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_starts_with_b_bb7 ; br_cond: !truthy -> else
    b __L62a9_rt_str_starts_with_b_bb6 ; branch -> then
__L62a9_rt_str_starts_with_b_bb5:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #1 ; hv const_bool payload
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_starts_with_b_bb6:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_starts_with_b_bb7:
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_starts_with_b_bb3 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #240 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_ends_with_b
.private_extern _rt_str_ends_with_b
    .p2align 2
_rt_str_ends_with_b:
    .loc 1 245 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #288 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L62a9_rt_str_ends_with_b_bb0:
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_ends_with_b_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_ends_with_b_bb1 ; branch -> then
__L62a9_rt_str_ends_with_b_bb1:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_ends_with_b_bb2:
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_sub ; binop -
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_ends_with_b_bb3 ; branch
__L62a9_rt_str_ends_with_b_bb3:
    ldp x0, x1, [sp, #160] ; hv load L10
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_ends_with_b_bb5 ; br_cond: !truthy -> else
    b __L62a9_rt_str_ends_with_b_bb4 ; branch -> then
__L62a9_rt_str_ends_with_b_bb4:
    ldp x0, x1, [sp, #144] ; hv load L9
    ldp x2, x3, [sp, #160] ; hv load L10
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #192] ; hv load L12
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #160] ; hv load L10
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #224] ; hv load L14
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_ends_with_b_bb7 ; br_cond: !truthy -> else
    b __L62a9_rt_str_ends_with_b_bb6 ; branch -> then
__L62a9_rt_str_ends_with_b_bb5:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #1 ; hv const_bool payload
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_ends_with_b_bb6:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_ends_with_b_bb7:
    ldp x0, x1, [sp, #160] ; hv load L10
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_ends_with_b_bb3 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #288 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_contains_b
.private_extern _rt_str_contains_b
    .p2align 2
_rt_str_contains_b:
    .loc 1 258 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #384 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
    stp x2, x3, [sp, #16] ; ingress param 1
__L62a9_rt_str_contains_b_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #32] ; hv store L2
    ldp x0, x1, [sp, #32] ; hv load L2
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb1 ; branch -> then
__L62a9_rt_str_contains_b_bb1:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #1 ; hv const_bool payload
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_contains_b_bb2:
    ldp x0, x1, [sp, #80] ; hv load L5
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_gt ; binop >
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb4 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb3 ; branch -> then
__L62a9_rt_str_contains_b_bb3:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_contains_b_bb4:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_contains_b_bb5 ; branch
__L62a9_rt_str_contains_b_bb5:
    ldp x0, x1, [sp, #160] ; hv load L10
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #48] ; hv load L3
    bl _hexa_cmp_le ; binop <=
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb7 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb6 ; branch -> then
__L62a9_rt_str_contains_b_bb6:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #208] ; hv store L13
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #1 ; hv const_bool payload
    stp x0, x1, [sp, #224] ; hv store L14
    b __L62a9_rt_str_contains_b_bb8 ; branch
__L62a9_rt_str_contains_b_bb7:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_contains_b_bb8:
    ldp x0, x1, [sp, #208] ; hv load L13
    ldp x2, x3, [sp, #80] ; hv load L5
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #240] ; hv load L15
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb10 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb9 ; branch -> then
__L62a9_rt_str_contains_b_bb9:
    ldp x0, x1, [sp, #160] ; hv load L10
    ldp x2, x3, [sp, #208] ; hv load L13
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #0] ; hv load L0
    ldp x2, x3, [sp, #256] ; hv load L16
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #16] ; hv load L1
    ldp x2, x3, [sp, #208] ; hv load L13
    bl _hexa_str_byte_at ; call hexa_str_byte_at
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #272] ; hv load L17
    ldp x2, x3, [sp, #288] ; hv load L18
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #304] ; hv load L19
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb12 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb11 ; branch -> then
__L62a9_rt_str_contains_b_bb10:
    ldp x0, x1, [sp, #224] ; hv load L14
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_contains_b_bb15 ; br_cond: !truthy -> else
    b __L62a9_rt_str_contains_b_bb14 ; branch -> then
__L62a9_rt_str_contains_b_bb11:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #0 ; hv const_bool payload
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #80] ; hv load L5
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_contains_b_bb13 ; branch
__L62a9_rt_str_contains_b_bb12:
    ldp x0, x1, [sp, #208] ; hv load L13
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_contains_b_bb13 ; branch
__L62a9_rt_str_contains_b_bb13:
    b __L62a9_rt_str_contains_b_bb8 ; branch
__L62a9_rt_str_contains_b_bb14:
    movz x0, #2 ; hv const_bool: TAG_BOOL
    movz x1, #1 ; hv const_bool payload
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_contains_b_bb15:
    ldp x0, x1, [sp, #160] ; hv load L10
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    stp x0, x1, [sp, #160] ; hv store L10
    b __L62a9_rt_str_contains_b_bb5 ; branch
    movz x0, #4 ; ret void: TAG_VOID
    movz x1, #0 ; ret void: payload 0
    add sp, sp, #384 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.globl _rt_str_from_int
.private_extern _rt_str_from_int
    .p2align 2
_rt_str_from_int:
    .loc 1 294 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #656 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__L62a9_rt_str_from_int_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; binop ==
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb2 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb1 ; branch -> then
__L62a9_rt_str_from_int_bb1:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr4@PAGE ; hv str ptr page
    add x1, x1, .LCstr4@PAGEOFF ; hv str ptr off
    add sp, sp, #656 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L62a9_rt_str_from_int_bb2:
    movz x0, #3 ; hv const_str: TAG_STR
    adrp x1, .LCstr5@PAGE ; hv str ptr page
    add x1, x1, .LCstr5@PAGEOFF ; hv str ptr off
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #64] ; hv store L4
    ldp x0, x1, [sp, #64] ; hv load L4
    stp x0, x1, [sp, #80] ; hv store L5
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #0] ; hv load L0
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb4 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb3 ; branch -> then
__L62a9_rt_str_from_int_bb3:
    b __L62a9_rt_str_from_int_bb5 ; branch
__L62a9_rt_str_from_int_bb4:
    b __L62a9_rt_str_from_int_bb10 ; branch
__L62a9_rt_str_from_int_bb5:
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb7 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb6 ; branch -> then
__L62a9_rt_str_from_int_bb6:
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_mod ; binop %
    stp x0, x1, [sp, #176] ; hv store L11
    movz x0, #0 ; unop -: a.tag=TAG_INT
    movz x1, #0 ; unop -: a.val=0
    ldp x2, x3, [sp, #176] ; hv load L11
    bl _hexa_sub ; unop -: 0 - x
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #208] ; hv load L13
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_lt ; binop <
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb9 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb8 ; branch -> then
__L62a9_rt_str_from_int_bb7:
    b __L62a9_rt_str_from_int_bb13 ; branch
__L62a9_rt_str_from_int_bb8:
    movz x0, #0 ; unop -: a.tag=TAG_INT
    movz x1, #0 ; unop -: a.val=0
    ldp x2, x3, [sp, #208] ; hv load L13
    bl _hexa_sub ; unop -: 0 - x
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    stp x0, x1, [sp, #208] ; hv store L13
    b __L62a9_rt_str_from_int_bb9 ; branch
__L62a9_rt_str_from_int_bb9:
    ldp x0, x1, [sp, #208] ; hv load L13
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #208] ; hv load L13
    ldp x4, x5, [sp, #272] ; hv load L17
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #288] ; hv load L18
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #304] ; hv store L19
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_from_int_bb5 ; branch
__L62a9_rt_str_from_int_bb10:
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_eq ; ne: eq
    bl _hexa_truthy ; ne: truthy(eq) → w0
    eor x0, x0, #1 ; ne: !truthy
    bl _hexa_bool ; ne: box bool
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb12 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb11 ; branch -> then
__L62a9_rt_str_from_int_bb11:
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_mod ; binop %
    stp x0, x1, [sp, #352] ; hv store L22
    ldp x0, x1, [sp, #352] ; hv load L22
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_add_slow ; binop +
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #48] ; hv load L3
    ldp x2, x3, [sp, #368] ; hv load L23
    ldp x4, x5, [sp, #384] ; hv load L24
    bl _hexa_str_substring ; call hexa_str_substring
    stp x0, x1, [sp, #400] ; hv store L25
    ldp x0, x1, [sp, #112] ; hv load L7
    ldp x2, x3, [sp, #400] ; hv load L25
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #128] ; hv load L8
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    bl _hexa_div ; binop /
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #432] ; hv load L27
    stp x0, x1, [sp, #128] ; hv store L8
    b __L62a9_rt_str_from_int_bb10 ; branch
__L62a9_rt_str_from_int_bb12:
    b __L62a9_rt_str_from_int_bb13 ; branch
__L62a9_rt_str_from_int_bb13:
    bl _hexa_array_new ; array_lit: new array
    stp x0, x1, [sp, #448] ; hv store L28
    ldp x0, x1, [sp, #448] ; hv load L28
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb15 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb14 ; branch -> then
__L62a9_rt_str_from_int_bb14:
    ldp x0, x1, [sp, #464] ; hv load L29
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr6@PAGE ; hv str ptr page
    add x3, x3, .LCstr6@PAGEOFF ; hv str ptr off
    bl _hexa_array_push ; call hexa_array_push
    stp x0, x1, [sp, #496] ; hv store L31
    b __L62a9_rt_str_from_int_bb15 ; branch
__L62a9_rt_str_from_int_bb15:
    ldp x0, x1, [sp, #112] ; hv load L7
    bl _hexa_len ; call hexa_len
    sxtw x0, w0 ; ret int: sign-ext
    bl _hexa_int ; ret int: box → HexaVal
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    add x15, sp, #528 ; hv frame base
    ldp x0, x1, [x15] ; hv load L33
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    add x15, sp, #544 ; hv frame base
    stp x0, x1, [x15] ; hv store L34
    add x15, sp, #544 ; hv frame base
    ldp x0, x1, [x15] ; hv load L34
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    b __L62a9_rt_str_from_int_bb16 ; branch
__L62a9_rt_str_from_int_bb16:
    add x15, sp, #560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L35
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    bl _hexa_cmp_ge ; binop >=
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    add x15, sp, #576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L36
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L62a9_rt_str_from_int_bb18 ; br_cond: !truthy -> else
    b __L62a9_rt_str_from_int_bb17 ; branch -> then
__L62a9_rt_str_from_int_bb17:
    ldp x0, x1, [sp, #112] ; hv load L7
    add x15, sp, #560 ; hv frame base
    ldp x2, x3, [x15] ; hv load L35
    bl _hexa_index_get ; index: hexa_index_get
    add x15, sp, #592 ; hv frame base
    stp x0, x1, [x15] ; hv store L37
    ldp x0, x1, [sp, #464] ; hv load L29
    add x15, sp, #592 ; hv frame base
    ldp x2, x3, [x15] ; hv load L37
    bl _hexa_array_push ; call hexa_array_push
    add x15, sp, #608 ; hv frame base
    stp x0, x1, [x15] ; hv store L38
    add x15, sp, #560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L35
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    bl _hexa_sub ; binop -
    add x15, sp, #624 ; hv frame base
    stp x0, x1, [x15] ; hv store L39
    add x15, sp, #624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L39
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    b __L62a9_rt_str_from_int_bb16 ; branch
__L62a9_rt_str_from_int_bb18:
    ldp x0, x1, [sp, #464] ; hv load L29
    movz x2, #3 ; hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE ; hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF ; hv str ptr off
    bl _hexa_str_join ; call hexa_str_join
    add x15, sp, #640 ; hv frame base
    stp x0, x1, [x15] ; hv store L40
    add x15, sp, #640 ; hv frame base
    ldp x0, x1, [x15] ; hv load L40
    add sp, sp, #656 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __TEXT,__const
.LCstr0:
    .byte 0x0a, 0x00
.section __TEXT,__const
.LCstr1:
    .byte 0x00
.section __TEXT,__const
.LCstr2:
    .byte 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50
    .byte 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x00
.section __TEXT,__const
.LCstr3:
    .byte 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70
    .byte 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x00
.section __TEXT,__const
.LCstr4:
    .byte 0x30, 0x00
.section __TEXT,__const
.LCstr5:
    .byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x00
.section __TEXT,__const
.LCstr6:
    .byte 0x2d, 0x00
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
