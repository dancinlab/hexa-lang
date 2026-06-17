// hexa-lang emit pass — target=arm64-linux-gnu
// source: /tmp/runtime_hi_lib.hexa
.file 1 "/tmp/runtime_hi_lib.hexa"
.text
.globl rt_str_split
.hidden rt_str_split
    .p2align 2
rt_str_split:
    .loc 1 22 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #416 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb8b9_rt_str_split_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_split_bb2 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_split_bb1 // branch -> then
_Lb8b9_rt_str_split_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_split_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #176] // hv store L11
    b _Lb8b9_rt_str_split_bb3 // branch
_Lb8b9_rt_str_split_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_sub // binop -
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_split_bb5 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_split_bb4 // branch -> then
_Lb8b9_rt_str_split_bb4:
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #176] // hv load L11
    ldp x4, x5, [sp, #240] // hv load L15
    bl hexa_str_substring // call hexa_str_substring
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_split_bb7 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_split_bb6 // branch -> then
_Lb8b9_rt_str_split_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #160] // hv load L10
    ldp x4, x5, [sp, #368] // hv load L23
    bl hexa_str_substring // call hexa_str_substring
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_split_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #160] // hv load L10
    ldp x4, x5, [sp, #176] // hv load L11
    bl hexa_str_substring // call hexa_str_substring
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    b _Lb8b9_rt_str_split_bb8 // branch
_Lb8b9_rt_str_split_bb7:
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #176] // hv store L11
    b _Lb8b9_rt_str_split_bb8 // branch
_Lb8b9_rt_str_split_bb8:
    b _Lb8b9_rt_str_split_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_lines
.hidden rt_str_lines
    .p2align 2
rt_str_lines:
    .loc 1 45 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #32 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb8b9_rt_str_lines_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr0@PAGE // hv str ptr page
    add x3, x3, .LCstr0@PAGEOFF // hv str ptr off
    bl rt_str_split // call rt_str_split
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #32 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_pad_left
.hidden rt_str_pad_left
    .p2align 2
rt_str_pad_left:
    .loc 1 52 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #432 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb8b9_rt_str_pad_left_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_left_bb2 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_left_bb1 // branch -> then
_Lb8b9_rt_str_pad_left_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_pad_left_bb2:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_left_bb4 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_left_bb3 // branch -> then
_Lb8b9_rt_str_pad_left_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_pad_left_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_sub // binop -
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_div // binop /
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_mul // binop *
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_left_bb6 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_left_bb5 // branch -> then
_Lb8b9_rt_str_pad_left_bb5:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb8b9_rt_str_pad_left_bb6 // branch
_Lb8b9_rt_str_pad_left_bb6:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb8b9_rt_str_pad_left_bb7 // branch
_Lb8b9_rt_str_pad_left_bb7:
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_left_bb9 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_left_bb8 // branch -> then
_Lb8b9_rt_str_pad_left_bb8:
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb8b9_rt_str_pad_left_bb7 // branch
_Lb8b9_rt_str_pad_left_bb9:
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE // hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF // hv str ptr off
    bl hexa_str_join // call hexa_str_join
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_pad_right
.hidden rt_str_pad_right
    .p2align 2
rt_str_pad_right:
    .loc 1 70 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #432 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb8b9_rt_str_pad_right_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_right_bb2 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_right_bb1 // branch -> then
_Lb8b9_rt_str_pad_right_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_pad_right_bb2:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_right_bb4 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_right_bb3 // branch -> then
_Lb8b9_rt_str_pad_right_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_pad_right_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_sub // binop -
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_div // binop /
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_mul // binop *
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_right_bb6 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_right_bb5 // branch -> then
_Lb8b9_rt_str_pad_right_bb5:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb8b9_rt_str_pad_right_bb6 // branch
_Lb8b9_rt_str_pad_right_bb6:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #336] // hv store L21
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb8b9_rt_str_pad_right_bb7 // branch
_Lb8b9_rt_str_pad_right_bb7:
    ldp x0, x1, [sp, #352] // hv load L22
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_pad_right_bb9 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_pad_right_bb8 // branch -> then
_Lb8b9_rt_str_pad_right_bb8:
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb8b9_rt_str_pad_right_bb7 // branch
_Lb8b9_rt_str_pad_right_bb9:
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE // hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF // hv str ptr off
    bl hexa_str_join // call hexa_str_join
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    add sp, sp, #432 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_repeat
.hidden rt_str_repeat
    .p2align 2
rt_str_repeat:
    .loc 1 89 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #176 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb8b9_rt_str_repeat_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_repeat_bb2 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_repeat_bb1 // branch -> then
_Lb8b9_rt_str_repeat_bb1:
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr1@PAGE // hv str ptr page
    add x1, x1, .LCstr1@PAGEOFF // hv str ptr off
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_repeat_bb2:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb8b9_rt_str_repeat_bb3 // branch
_Lb8b9_rt_str_repeat_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_repeat_bb5 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_repeat_bb4 // branch -> then
_Lb8b9_rt_str_repeat_bb4:
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb8b9_rt_str_repeat_bb3 // branch
_Lb8b9_rt_str_repeat_bb5:
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE // hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF // hv str ptr off
    bl hexa_str_join // call hexa_str_join
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_center
.hidden rt_str_center
    .p2align 2
rt_str_center:
    .loc 1 101 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #656 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb8b9_rt_str_center_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb2 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb1 // branch -> then
_Lb8b9_rt_str_center_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #656 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_center_bb2:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb4 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb3 // branch -> then
_Lb8b9_rt_str_center_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #656 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb8b9_rt_str_center_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_sub // binop -
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_sub // binop -
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_div // binop /
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_mul // binop *
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb6 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb5 // branch -> then
_Lb8b9_rt_str_center_bb5:
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb8b9_rt_str_center_bb6 // branch
_Lb8b9_rt_str_center_bb6:
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_div // binop /
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_mul // binop *
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb8 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb7 // branch -> then
_Lb8b9_rt_str_center_bb7:
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb8b9_rt_str_center_bb8 // branch
_Lb8b9_rt_str_center_bb8:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb8b9_rt_str_center_bb9 // branch
_Lb8b9_rt_str_center_bb9:
    ldp x0, x1, [sp, #496] // hv load L31
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_cmp_lt // binop <
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb11 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb10 // branch -> then
_Lb8b9_rt_str_center_bb10:
    ldp x0, x1, [sp, #480] // hv load L30
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb8b9_rt_str_center_bb9 // branch
_Lb8b9_rt_str_center_bb11:
    ldp x0, x1, [sp, #480] // hv load L30
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb8b9_rt_str_center_bb12 // branch
_Lb8b9_rt_str_center_bb12:
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_cmp_lt // binop <
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    bl hexa_truthy // br_cond: truthy → w0
    uxtw x0, w0 // br_cond: zext w0
    cbz x0, _Lb8b9_rt_str_center_bb14 // br_cond: !truthy -> else
    b _Lb8b9_rt_str_center_bb13 // branch -> then
_Lb8b9_rt_str_center_bb13:
    ldp x0, x1, [sp, #480] // hv load L30
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb8b9_rt_str_center_bb12 // branch
_Lb8b9_rt_str_center_bb14:
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr1@PAGE // hv str ptr page
    add x3, x3, .LCstr1@PAGEOFF // hv str ptr off
    bl hexa_str_join // call hexa_str_join
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add sp, sp, #656 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .rodata
.LCstr0:
    .byte 0x0a, 0x00
.section .rodata
.LCstr1:
    .byte 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
