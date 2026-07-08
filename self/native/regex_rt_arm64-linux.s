// regex_rt_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE zero-c #29 — regex-rt).
// GENERATED: tool/regen_regex_rt_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o regex_rt_arm64-linux.s regex_rt.hexa thompson.hexa backtrack.hexa, then a
//   .globl DEMOTION post-pass keeping ONLY the 6 rt_regex_* shim globals.
//   Provides the 6 rt_regex_* (match/match_full/search/findall/split/replace)
//   the emitted runtime.c hexa_regex_* bodies delegate to under
//   HEXA_REGEX_NATIVE, backed by a Thompson NFA + backtrack VM. Every other
//   symbol is demoted to local so the seed exports a 6-symbol contract only
//   (thompson/backtrack are public stdlib modules — undemoted globals would
//   collide at ld with a user program that also imports them).
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF aarch64, rt_regex_* no underscore. External: hexa string/value/array runtime (resolved within runtime.a).
//   Lets stage_resolve_runtime_a define HEXA_REGEX_NATIVE (opt-IN, default-OFF)
//   + ar this .o into runtime.a so the regcomp/regexec/regfree seams route
//   native, dropping those libc symbols from the nm-UND floor on flip.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/regex_rt.hexa
.file 1 "stdlib/runtime/regex_rt.hexa"
.text
.hidden bt_needs_backtrack
    .p2align 2
bt_needs_backtrack:
    .loc 1 105 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1312 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_bt_needs_backtrack_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb1 // branch
_Lb2dd_bt_needs_backtrack_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_bt_needs_backtrack_bb3 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb2 // branch -> then
_Lb2dd_bt_needs_backtrack_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd_bt_needs_backtrack_bb5 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb4 // branch -> then
_Lb2dd_bt_needs_backtrack_bb3:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #1312 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_needs_backtrack_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd_bt_needs_backtrack_bb7 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb6 // branch -> then
_Lb2dd_bt_needs_backtrack_bb5:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #91 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd_bt_needs_backtrack_bb14 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb13 // branch -> then
_Lb2dd_bt_needs_backtrack_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #49 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd_bt_needs_backtrack_bb9 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb8 // branch -> then
_Lb2dd_bt_needs_backtrack_bb7:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb1 // branch
_Lb2dd_bt_needs_backtrack_bb8:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd_bt_needs_backtrack_bb10 // branch
_Lb2dd_bt_needs_backtrack_bb9:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd_bt_needs_backtrack_bb10 // branch
_Lb2dd_bt_needs_backtrack_bb10:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd_bt_needs_backtrack_bb12 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb11 // branch -> then
_Lb2dd_bt_needs_backtrack_bb11:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #1312 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_needs_backtrack_bb12:
    b _Lb2dd_bt_needs_backtrack_bb7 // branch
_Lb2dd_bt_needs_backtrack_bb13:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd_bt_needs_backtrack_bb16 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb15 // branch -> then
_Lb2dd_bt_needs_backtrack_bb14:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _Lb2dd_bt_needs_backtrack_bb37 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb36 // branch -> then
_Lb2dd_bt_needs_backtrack_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd_bt_needs_backtrack_bb17 // branch
_Lb2dd_bt_needs_backtrack_bb16:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd_bt_needs_backtrack_bb17 // branch
_Lb2dd_bt_needs_backtrack_bb17:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd_bt_needs_backtrack_bb19 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb18 // branch -> then
_Lb2dd_bt_needs_backtrack_bb18:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb19 // branch
_Lb2dd_bt_needs_backtrack_bb19:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _Lb2dd_bt_needs_backtrack_bb21 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb20 // branch -> then
_Lb2dd_bt_needs_backtrack_bb20:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    stp x0, x1, [sp, #480] // hv store L30
    b _Lb2dd_bt_needs_backtrack_bb22 // branch
_Lb2dd_bt_needs_backtrack_bb21:
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    b _Lb2dd_bt_needs_backtrack_bb22 // branch
_Lb2dd_bt_needs_backtrack_bb22:
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd_bt_needs_backtrack_bb24 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb23 // branch -> then
_Lb2dd_bt_needs_backtrack_bb23:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb24 // branch
_Lb2dd_bt_needs_backtrack_bb24:
    b _Lb2dd_bt_needs_backtrack_bb25 // branch
_Lb2dd_bt_needs_backtrack_bb25:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _Lb2dd_bt_needs_backtrack_bb29 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb28 // branch -> then
_Lb2dd_bt_needs_backtrack_bb26:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd_bt_needs_backtrack_bb32 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb31 // branch -> then
_Lb2dd_bt_needs_backtrack_bb27:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd_bt_needs_backtrack_bb35 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb34 // branch -> then
_Lb2dd_bt_needs_backtrack_bb28:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd_bt_needs_backtrack_bb30 // branch
_Lb2dd_bt_needs_backtrack_bb29:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd_bt_needs_backtrack_bb30 // branch
_Lb2dd_bt_needs_backtrack_bb30:
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _Lb2dd_bt_needs_backtrack_bb27 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb26 // branch -> then
_Lb2dd_bt_needs_backtrack_bb31:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb33 // branch
_Lb2dd_bt_needs_backtrack_bb32:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb33 // branch
_Lb2dd_bt_needs_backtrack_bb33:
    b _Lb2dd_bt_needs_backtrack_bb25 // branch
_Lb2dd_bt_needs_backtrack_bb34:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb35 // branch
_Lb2dd_bt_needs_backtrack_bb35:
    b _Lb2dd_bt_needs_backtrack_bb1 // branch
_Lb2dd_bt_needs_backtrack_bb36:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _Lb2dd_bt_needs_backtrack_bb38 // branch
_Lb2dd_bt_needs_backtrack_bb37:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _Lb2dd_bt_needs_backtrack_bb38 // branch
_Lb2dd_bt_needs_backtrack_bb38:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _Lb2dd_bt_needs_backtrack_bb40 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb39 // branch -> then
_Lb2dd_bt_needs_backtrack_bb39:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _Lb2dd_bt_needs_backtrack_bb41 // branch
_Lb2dd_bt_needs_backtrack_bb40:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _Lb2dd_bt_needs_backtrack_bb41 // branch
_Lb2dd_bt_needs_backtrack_bb41:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    cbz x1, _Lb2dd_bt_needs_backtrack_bb43 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb42 // branch -> then
_Lb2dd_bt_needs_backtrack_bb42:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    cbz x1, _Lb2dd_bt_needs_backtrack_bb45 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb44 // branch -> then
_Lb2dd_bt_needs_backtrack_bb43:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #123 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    cbz x1, _Lb2dd_bt_needs_backtrack_bb55 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb54 // branch -> then
_Lb2dd_bt_needs_backtrack_bb44:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #61 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd_bt_needs_backtrack_bb47 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb46 // branch -> then
_Lb2dd_bt_needs_backtrack_bb45:
    b _Lb2dd_bt_needs_backtrack_bb43 // branch
_Lb2dd_bt_needs_backtrack_bb46:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _Lb2dd_bt_needs_backtrack_bb48 // branch
_Lb2dd_bt_needs_backtrack_bb47:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #33 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _Lb2dd_bt_needs_backtrack_bb48 // branch
_Lb2dd_bt_needs_backtrack_bb48:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _Lb2dd_bt_needs_backtrack_bb50 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb49 // branch -> then
_Lb2dd_bt_needs_backtrack_bb49:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    b _Lb2dd_bt_needs_backtrack_bb51 // branch
_Lb2dd_bt_needs_backtrack_bb50:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #60 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    b _Lb2dd_bt_needs_backtrack_bb51 // branch
_Lb2dd_bt_needs_backtrack_bb51:
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _Lb2dd_bt_needs_backtrack_bb53 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb52 // branch -> then
_Lb2dd_bt_needs_backtrack_bb52:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #1312 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_needs_backtrack_bb53:
    b _Lb2dd_bt_needs_backtrack_bb45 // branch
_Lb2dd_bt_needs_backtrack_bb54:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd_bt_needs_backtrack_bb56 // branch
_Lb2dd_bt_needs_backtrack_bb55:
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd_bt_needs_backtrack_bb56 // branch
_Lb2dd_bt_needs_backtrack_bb56:
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    cbz x1, _Lb2dd_bt_needs_backtrack_bb58 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb57 // branch -> then
_Lb2dd_bt_needs_backtrack_bb57:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1168 // hv frame base
    ldp x2, x3, [x15] // hv load L73
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    b _Lb2dd_bt_needs_backtrack_bb59 // branch
_Lb2dd_bt_needs_backtrack_bb58:
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    b _Lb2dd_bt_needs_backtrack_bb59 // branch
_Lb2dd_bt_needs_backtrack_bb59:
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    cbz x1, _Lb2dd_bt_needs_backtrack_bb61 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb60 // branch -> then
_Lb2dd_bt_needs_backtrack_bb60:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    b _Lb2dd_bt_needs_backtrack_bb62 // branch
_Lb2dd_bt_needs_backtrack_bb61:
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    b _Lb2dd_bt_needs_backtrack_bb62 // branch
_Lb2dd_bt_needs_backtrack_bb62:
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    cbz x1, _Lb2dd_bt_needs_backtrack_bb64 // br_cond: !payload -> else
    b _Lb2dd_bt_needs_backtrack_bb63 // branch -> then
_Lb2dd_bt_needs_backtrack_bb63:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #1312 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_needs_backtrack_bb64:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd_bt_needs_backtrack_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1312 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_peek
    .p2align 2
_bt_peek:
    .loc 1 151 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_peek_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__bt_peek_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_peek_bb1 // branch -> then
_Lb2dd__bt_peek_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_peek_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_adv
    .p2align 2
_bt_adv:
    .loc 1 156 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #80 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_adv_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #64] // hv load L4
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #16] // hv store L1
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #80 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_emit
    .p2align 2
_bt_emit:
    .loc 1 160 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_emit_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_class_for_escape
    .p2align 2
_bt_class_for_escape:
    .loc 1 167 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_class_for_escape_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #100 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _Lb2dd__bt_class_for_escape_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb1 // branch -> then
_Lb2dd__bt_class_for_escape_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #68 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__bt_class_for_escape_bb4 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb3 // branch -> then
_Lb2dd__bt_class_for_escape_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #119 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__bt_class_for_escape_bb6 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb5 // branch -> then
_Lb2dd__bt_class_for_escape_bb5:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_array_push // array_lit: push elem 5
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #122 // hv const_int val
    bl hexa_array_push // array_lit: push elem 6
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 7
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #87 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__bt_class_for_escape_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb7 // branch -> then
_Lb2dd__bt_class_for_escape_bb7:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_array_push // array_lit: push elem 5
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #122 // hv const_int val
    bl hexa_array_push // array_lit: push elem 6
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 7
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 8
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #115 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__bt_class_for_escape_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb9 // branch -> then
_Lb2dd__bt_class_for_escape_bb9:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #83 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__bt_class_for_escape_bb12 // br_cond: !payload -> else
    b _Lb2dd__bt_class_for_escape_bb11 // branch -> then
_Lb2dd__bt_class_for_escape_bb11:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_for_escape_bb12:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_lit_for_escape
    .p2align 2
_bt_lit_for_escape:
    .loc 1 179 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_lit_for_escape_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _Lb2dd__bt_lit_for_escape_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_lit_for_escape_bb1 // branch -> then
_Lb2dd__bt_lit_for_escape_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_lit_for_escape_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #116 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_lit_for_escape_bb4 // br_cond: !payload -> else
    b _Lb2dd__bt_lit_for_escape_bb3 // branch -> then
_Lb2dd__bt_lit_for_escape_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_lit_for_escape_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #114 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_lit_for_escape_bb6 // br_cond: !payload -> else
    b _Lb2dd__bt_lit_for_escape_bb5 // branch -> then
_Lb2dd__bt_lit_for_escape_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #13 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_lit_for_escape_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__bt_lit_for_escape_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_lit_for_escape_bb7 // branch -> then
_Lb2dd__bt_lit_for_escape_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_lit_for_escape_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_push_class
    .p2align 2
_bt_push_class:
    .loc 1 187 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #288 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__bt_push_class_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__bt_push_class_bb1 // branch
_Lb2dd__bt_push_class_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__bt_push_class_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_push_class_bb2 // branch -> then
_Lb2dd__bt_push_class_bb2:
    ldp x9, x10, [sp, #80] // hv load L5
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__bt_push_class_bb1 // branch
_Lb2dd__bt_push_class_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #240] // hv store L15
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    ldp x2, x3, [sp, #240] // hv load L15
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #256] // hv load L16
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    add sp, sp, #288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_parse_class
    .p2align 2
_bt_parse_class:
    .loc 1 196 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1360 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_parse_class_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_parse_class_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb1 // branch -> then
_Lb2dd__bt_parse_class_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__bt_parse_class_bb2 // branch
_Lb2dd__bt_parse_class_bb2:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__bt_parse_class_bb3 // branch
_Lb2dd__bt_parse_class_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_parse_class_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb4 // branch -> then
_Lb2dd__bt_parse_class_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__bt_parse_class_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb6 // branch -> then
_Lb2dd__bt_parse_class_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_class_bb6:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__bt_parse_class_bb8 // branch
_Lb2dd__bt_parse_class_bb7:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__bt_parse_class_bb8 // branch
_Lb2dd__bt_parse_class_bb8:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__bt_parse_class_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb9 // branch -> then
_Lb2dd__bt_parse_class_bb9:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #32] // hv load L2
    ldp x4, x5, [sp, #48] // hv load L3
    bl _bt_push_class // call _bt_push_class
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_class_bb10:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #336] // hv store L21
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__bt_parse_class_bb12 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb11 // branch -> then
_Lb2dd__bt_parse_class_bb11:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #432] // hv load L27
    bl _bt_class_for_escape // call _bt_class_for_escape
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _Lb2dd__bt_parse_class_bb14 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb13 // branch -> then
_Lb2dd__bt_parse_class_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__bt_parse_class_bb22 // branch
_Lb2dd__bt_parse_class_bb13:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd__bt_parse_class_bb15 // branch
_Lb2dd__bt_parse_class_bb14:
    ldp x0, x1, [sp, #432] // hv load L27
    bl _bt_lit_for_escape // call _bt_lit_for_escape
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
    bl hexa_cmp_ge // binop >=
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    cbz x1, _Lb2dd__bt_parse_class_bb19 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb18 // branch -> then
_Lb2dd__bt_parse_class_bb15:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #480] // hv load L30
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_cmp_lt // binop <
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__bt_parse_class_bb17 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb16 // branch -> then
_Lb2dd__bt_parse_class_bb16:
    add x15, sp, #544 // hv frame base
    ldp x9, x10, [x15] // hv load L34
    ldp x0, x1, [sp, #480] // hv load L30
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x9, x10, [x15] // hv load L40
    ldp x0, x1, [sp, #480] // hv load L30
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #656 // hv frame base
    ldp x2, x3, [x15] // hv load L41
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd__bt_parse_class_bb15 // branch
_Lb2dd__bt_parse_class_bb17:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd__bt_parse_class_bb21 // branch
_Lb2dd__bt_parse_class_bb18:
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__bt_parse_class_bb20 // branch
_Lb2dd__bt_parse_class_bb19:
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__bt_parse_class_bb20 // branch
_Lb2dd__bt_parse_class_bb20:
    b _Lb2dd__bt_parse_class_bb21 // branch
_Lb2dd__bt_parse_class_bb21:
    b _Lb2dd__bt_parse_class_bb22 // branch
_Lb2dd__bt_parse_class_bb22:
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _Lb2dd__bt_parse_class_bb24 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb23 // branch -> then
_Lb2dd__bt_parse_class_bb23:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd__bt_parse_class_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb25 // branch -> then
_Lb2dd__bt_parse_class_bb24:
    b _Lb2dd__bt_parse_class_bb3 // branch
_Lb2dd__bt_parse_class_bb25:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_cmp_lt // binop <
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__bt_parse_class_bb27 // branch
_Lb2dd__bt_parse_class_bb26:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__bt_parse_class_bb27 // branch
_Lb2dd__bt_parse_class_bb27:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _Lb2dd__bt_parse_class_bb29 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb28 // branch -> then
_Lb2dd__bt_parse_class_bb28:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #1008 // hv frame base
    ldp x2, x3, [x15] // hv load L63
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__bt_parse_class_bb30 // branch
_Lb2dd__bt_parse_class_bb29:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__bt_parse_class_bb30 // branch
_Lb2dd__bt_parse_class_bb30:
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _Lb2dd__bt_parse_class_bb32 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb31 // branch -> then
_Lb2dd__bt_parse_class_bb31:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    cbz x1, _Lb2dd__bt_parse_class_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb33 // branch -> then
_Lb2dd__bt_parse_class_bb32:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__bt_parse_class_bb38 // branch
_Lb2dd__bt_parse_class_bb33:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    bl _bt_lit_for_escape // call _bt_lit_for_escape
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    cbz x1, _Lb2dd__bt_parse_class_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_class_bb35 // branch -> then
_Lb2dd__bt_parse_class_bb34:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #1104 // hv frame base
    ldp x2, x3, [x15] // hv load L69
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__bt_parse_class_bb38 // branch
_Lb2dd__bt_parse_class_bb35:
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd__bt_parse_class_bb37 // branch
_Lb2dd__bt_parse_class_bb36:
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd__bt_parse_class_bb37 // branch
_Lb2dd__bt_parse_class_bb37:
    b _Lb2dd__bt_parse_class_bb34 // branch
_Lb2dd__bt_parse_class_bb38:
    b _Lb2dd__bt_parse_class_bb24 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_parse_alt
    .p2align 2
_bt_parse_alt:
    .loc 1 248 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_parse_alt_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_concat // call _bt_parse_concat
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_alt_bb1 // branch
_Lb2dd__bt_parse_alt_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__bt_parse_alt_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_alt_bb2 // branch -> then
_Lb2dd__bt_parse_alt_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_concat // call _bt_parse_concat
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #128] // hv load L8
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_alt_bb1 // branch
_Lb2dd__bt_parse_alt_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_parse_concat
    .p2align 2
_bt_parse_concat:
    .loc 1 259 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #400 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_parse_concat_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_parse_concat_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb1 // branch -> then
_Lb2dd__bt_parse_concat_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_parse_concat_bb3 // branch
_Lb2dd__bt_parse_concat_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_parse_concat_bb3 // branch
_Lb2dd__bt_parse_concat_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__bt_parse_concat_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb4 // branch -> then
_Lb2dd__bt_parse_concat_bb4:
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd__bt_parse_concat_bb6 // branch
_Lb2dd__bt_parse_concat_bb5:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd__bt_parse_concat_bb6 // branch
_Lb2dd__bt_parse_concat_bb6:
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__bt_parse_concat_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb7 // branch -> then
_Lb2dd__bt_parse_concat_bb7:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #144] // hv load L9
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_concat_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_repeat // call _bt_parse_repeat
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_parse_concat_bb9 // branch
_Lb2dd__bt_parse_concat_bb9:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    cbz x1, _Lb2dd__bt_parse_concat_bb11 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb10 // branch -> then
_Lb2dd__bt_parse_concat_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__bt_parse_concat_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb12 // branch -> then
_Lb2dd__bt_parse_concat_bb11:
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_concat_bb12:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__bt_parse_concat_bb14 // branch
_Lb2dd__bt_parse_concat_bb13:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__bt_parse_concat_bb14 // branch
_Lb2dd__bt_parse_concat_bb14:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__bt_parse_concat_bb16 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb15 // branch -> then
_Lb2dd__bt_parse_concat_bb15:
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_parse_concat_bb17 // branch
_Lb2dd__bt_parse_concat_bb16:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_parse_concat_bb17 // branch
_Lb2dd__bt_parse_concat_bb17:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__bt_parse_concat_bb19 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_concat_bb18 // branch -> then
_Lb2dd__bt_parse_concat_bb18:
    b _Lb2dd__bt_parse_concat_bb11 // branch
_Lb2dd__bt_parse_concat_bb19:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_repeat // call _bt_parse_repeat
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    ldp x2, x3, [sp, #352] // hv load L22
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #368] // hv load L23
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_parse_concat_bb9 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _BT_MAX_REPEAT
    .p2align 2
_BT_MAX_REPEAT:
    .loc 1 275 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_Lb2dd__BT_MAX_REPEAT_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #34464 // imm 0-15
    movk x1, #1, lsl #16 // imm 16-31
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_parse_repeat
    .p2align 2
_bt_parse_repeat:
    .loc 1 278 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1104 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_parse_repeat_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_atom // call _bt_parse_atom
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_repeat_bb1 // branch
_Lb2dd__bt_parse_repeat_bb1:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    cbz x1, _Lb2dd__bt_parse_repeat_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb2 // branch -> then
_Lb2dd__bt_parse_repeat_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #42 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_parse_repeat_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb4 // branch -> then
_Lb2dd__bt_parse_repeat_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_repeat_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #128] // hv load L8
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_repeat_bb40 // branch
_Lb2dd__bt_parse_repeat_bb5:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__bt_parse_repeat_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb6 // branch -> then
_Lb2dd__bt_parse_repeat_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #192] // hv store L12
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #208] // hv load L13
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_repeat_bb39 // branch
_Lb2dd__bt_parse_repeat_bb7:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__bt_parse_repeat_bb9 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb8 // branch -> then
_Lb2dd__bt_parse_repeat_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #272] // hv store L17
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #288] // hv load L18
    bl _bt_emit // call _bt_emit
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_repeat_bb38 // branch
_Lb2dd__bt_parse_repeat_bb9:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #123 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__bt_parse_repeat_bb11 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb10 // branch -> then
_Lb2dd__bt_parse_repeat_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #352] // hv store L22
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #368] // hv store L23
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_parse_repeat_bb12 // branch
_Lb2dd__bt_parse_repeat_bb11:
    b _Lb2dd__bt_parse_repeat_bb3 // branch
_Lb2dd__bt_parse_repeat_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    cbz x1, _Lb2dd__bt_parse_repeat_bb16 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb15 // branch -> then
_Lb2dd__bt_parse_repeat_bb13:
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #480] // hv load L30
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_add_slow // binop +
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #384] // hv store L24
    bl _BT_MAX_REPEAT // call _BT_MAX_REPEAT
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #368] // hv load L23
    add x15, sp, #560 // hv frame base
    ldp x2, x3, [x15] // hv load L35
    bl hexa_cmp_gt // binop >
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _Lb2dd__bt_parse_repeat_bb19 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb18 // branch -> then
_Lb2dd__bt_parse_repeat_bb14:
    ldp x0, x1, [sp, #368] // hv load L23
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #44 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _Lb2dd__bt_parse_repeat_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb20 // branch -> then
_Lb2dd__bt_parse_repeat_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #432] // hv store L27
    b _Lb2dd__bt_parse_repeat_bb17 // branch
_Lb2dd__bt_parse_repeat_bb16:
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    b _Lb2dd__bt_parse_repeat_bb17 // branch
_Lb2dd__bt_parse_repeat_bb17:
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd__bt_parse_repeat_bb14 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb13 // branch -> then
_Lb2dd__bt_parse_repeat_bb18:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_repeat_bb19:
    b _Lb2dd__bt_parse_repeat_bb12 // branch
_Lb2dd__bt_parse_repeat_bb20:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #125 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    cbz x1, _Lb2dd__bt_parse_repeat_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb22 // branch -> then
_Lb2dd__bt_parse_repeat_bb21:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #125 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd__bt_parse_repeat_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb33 // branch -> then
_Lb2dd__bt_parse_repeat_bb22:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _Lb2dd__bt_parse_repeat_bb32 // branch
_Lb2dd__bt_parse_repeat_bb23:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _Lb2dd__bt_parse_repeat_bb24 // branch
_Lb2dd__bt_parse_repeat_bb24:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _Lb2dd__bt_parse_repeat_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb27 // branch -> then
_Lb2dd__bt_parse_repeat_bb25:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #864 // hv frame base
    ldp x2, x3, [x15] // hv load L54
    bl hexa_add_slow // binop +
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    bl _BT_MAX_REPEAT // call _BT_MAX_REPEAT
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_cmp_gt // binop >
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _Lb2dd__bt_parse_repeat_bb31 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb30 // branch -> then
_Lb2dd__bt_parse_repeat_bb26:
    b _Lb2dd__bt_parse_repeat_bb32 // branch
_Lb2dd__bt_parse_repeat_bb27:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    b _Lb2dd__bt_parse_repeat_bb29 // branch
_Lb2dd__bt_parse_repeat_bb28:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    b _Lb2dd__bt_parse_repeat_bb29 // branch
_Lb2dd__bt_parse_repeat_bb29:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _Lb2dd__bt_parse_repeat_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb25 // branch -> then
_Lb2dd__bt_parse_repeat_bb30:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_repeat_bb31:
    b _Lb2dd__bt_parse_repeat_bb24 // branch
_Lb2dd__bt_parse_repeat_bb32:
    b _Lb2dd__bt_parse_repeat_bb21 // branch
_Lb2dd__bt_parse_repeat_bb33:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    b _Lb2dd__bt_parse_repeat_bb34 // branch
_Lb2dd__bt_parse_repeat_bb34:
    ldp x0, x1, [sp, #384] // hv load L24
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _Lb2dd__bt_parse_repeat_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_repeat_bb35 // branch -> then
_Lb2dd__bt_parse_repeat_bb35:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #368] // hv store L23
    b _Lb2dd__bt_parse_repeat_bb36 // branch
_Lb2dd__bt_parse_repeat_bb36:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv reload L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv reload L67
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv reload L67
    ldp x2, x3, [sp, #368] // hv load L23
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv reload L67
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1072 // hv frame base
    ldp x2, x3, [x15] // hv load L67
    bl _bt_emit // call _bt_emit
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_parse_repeat_bb37 // branch
_Lb2dd__bt_parse_repeat_bb37:
    b _Lb2dd__bt_parse_repeat_bb38 // branch
_Lb2dd__bt_parse_repeat_bb38:
    b _Lb2dd__bt_parse_repeat_bb39 // branch
_Lb2dd__bt_parse_repeat_bb39:
    b _Lb2dd__bt_parse_repeat_bb40 // branch
_Lb2dd__bt_parse_repeat_bb40:
    b _Lb2dd__bt_parse_repeat_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_parse_atom
    .p2align 2
_bt_parse_atom:
    .loc 1 315 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #2336 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_parse_atom_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_parse_atom_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb1 // branch -> then
_Lb2dd__bt_parse_atom_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__bt_parse_atom_bb4 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb3 // branch -> then
_Lb2dd__bt_parse_atom_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #91 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    cbz x1, _Lb2dd__bt_parse_atom_bb39 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb38 // branch -> then
_Lb2dd__bt_parse_atom_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #58 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_parse_atom_bb6 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb5 // branch -> then
_Lb2dd__bt_parse_atom_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr6@PAGE // cstr key page
    add x2, x2, .LCstr6@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr6@PAGE // cstr key page
    add x2, x2, .LCstr6@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x15, sp, #1248 // hv frame base
    ldp x4, x5, [x15] // hv load L78
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr6@PAGE // cstr key page
    add x2, x2, .LCstr6@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_alt // call _bt_parse_alt
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    cbz x1, _Lb2dd__bt_parse_atom_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb35 // branch -> then
_Lb2dd__bt_parse_atom_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_alt // call _bt_parse_alt
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__bt_parse_atom_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb7 // branch -> then
_Lb2dd__bt_parse_atom_bb6:
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #61 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd__bt_parse_atom_bb11 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb10 // branch -> then
_Lb2dd__bt_parse_atom_bb7:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_parse_atom_bb9 // branch
_Lb2dd__bt_parse_atom_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__bt_parse_atom_bb9 // branch
_Lb2dd__bt_parse_atom_bb9:
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_alt // call _bt_parse_alt
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    cbz x1, _Lb2dd__bt_parse_atom_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb12 // branch -> then
_Lb2dd__bt_parse_atom_bb11:
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #33 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _Lb2dd__bt_parse_atom_bb16 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb15 // branch -> then
_Lb2dd__bt_parse_atom_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    stp x0, x1, [sp, #480] // hv store L30
    b _Lb2dd__bt_parse_atom_bb14 // branch
_Lb2dd__bt_parse_atom_bb13:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb2dd__bt_parse_atom_bb14 // branch
_Lb2dd__bt_parse_atom_bb14:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv reload L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv reload L32
    ldp x2, x3, [sp, #416] // hv load L26
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv reload L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv reload L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl _bt_emit // call _bt_emit
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_alt // call _bt_parse_alt
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd__bt_parse_atom_bb18 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb17 // branch -> then
_Lb2dd__bt_parse_atom_bb16:
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #60 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    cbz x1, _Lb2dd__bt_parse_atom_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb20 // branch -> then
_Lb2dd__bt_parse_atom_bb17:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    b _Lb2dd__bt_parse_atom_bb19 // branch
_Lb2dd__bt_parse_atom_bb18:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    b _Lb2dd__bt_parse_atom_bb19 // branch
_Lb2dd__bt_parse_atom_bb19:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv reload L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv reload L44
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv reload L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv reload L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    bl _bt_emit // call _bt_emit
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb20:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #61 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    cbz x1, _Lb2dd__bt_parse_atom_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb22 // branch -> then
_Lb2dd__bt_parse_atom_bb21:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb22:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    b _Lb2dd__bt_parse_atom_bb24 // branch
_Lb2dd__bt_parse_atom_bb23:
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #33 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    b _Lb2dd__bt_parse_atom_bb24 // branch
_Lb2dd__bt_parse_atom_bb24:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd__bt_parse_atom_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb25 // branch -> then
_Lb2dd__bt_parse_atom_bb25:
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #33 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    cbz x1, _Lb2dd__bt_parse_atom_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb27 // branch -> then
_Lb2dd__bt_parse_atom_bb26:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb27:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    b _Lb2dd__bt_parse_atom_bb29 // branch
_Lb2dd__bt_parse_atom_bb28:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    b _Lb2dd__bt_parse_atom_bb29 // branch
_Lb2dd__bt_parse_atom_bb29:
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_alt // call _bt_parse_alt
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd__bt_parse_atom_bb31 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb30 // branch -> then
_Lb2dd__bt_parse_atom_bb30:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    b _Lb2dd__bt_parse_atom_bb32 // branch
_Lb2dd__bt_parse_atom_bb31:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    b _Lb2dd__bt_parse_atom_bb32 // branch
_Lb2dd__bt_parse_atom_bb32:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #960 // hv frame base
    ldp x2, x3, [x15] // hv load L60
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    cbz x1, _Lb2dd__bt_parse_atom_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb33 // branch -> then
_Lb2dd__bt_parse_atom_bb33:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb34:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv reload L71
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #15 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv reload L71
    add x15, sp, #960 // hv frame base
    ldp x2, x3, [x15] // hv load L60
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv reload L71
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv reload L71
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1136 // hv frame base
    ldp x2, x3, [x15] // hv load L71
    bl _bt_emit // call _bt_emit
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb35:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    b _Lb2dd__bt_parse_atom_bb37 // branch
_Lb2dd__bt_parse_atom_bb36:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1408 // hv frame base
    stp x0, x1, [x15] // hv store L88
    add x15, sp, #1408 // hv frame base
    ldp x0, x1, [x15] // hv load L88
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1408 // hv frame base
    stp x0, x1, [x15] // hv store L88
    b _Lb2dd__bt_parse_atom_bb37 // branch
_Lb2dd__bt_parse_atom_bb37:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv reload L89
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv reload L89
    add x15, sp, #1328 // hv frame base
    ldp x2, x3, [x15] // hv load L83
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv reload L89
    add x15, sp, #1296 // hv frame base
    ldp x2, x3, [x15] // hv load L81
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv reload L89
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1424 // hv frame base
    ldp x2, x3, [x15] // hv load L89
    bl _bt_emit // call _bt_emit
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb38:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_parse_class // call _bt_parse_class
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb39:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L95
    cbz x1, _Lb2dd__bt_parse_atom_bb41 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb40 // branch -> then
_Lb2dd__bt_parse_atom_bb40:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv reload L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv reload L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv reload L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv reload L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1568 // hv frame base
    ldp x2, x3, [x15] // hv load L98
    bl _bt_emit // call _bt_emit
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb41:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    cbz x1, _Lb2dd__bt_parse_atom_bb43 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb42 // branch -> then
_Lb2dd__bt_parse_atom_bb42:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv reload L103
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv reload L103
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv reload L103
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv reload L103
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    bl _bt_emit // call _bt_emit
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb43:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #36 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    cbz x1, _Lb2dd__bt_parse_atom_bb45 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb44 // branch -> then
_Lb2dd__bt_parse_atom_bb44:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1728 // hv frame base
    ldp x2, x3, [x15] // hv load L108
    bl _bt_emit // call _bt_emit
    add x15, sp, #1744 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1744 // hv frame base
    ldp x0, x1, [x15] // hv load L109
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb45:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1760 // hv frame base
    stp x0, x1, [x15] // hv store L110
    add x15, sp, #1760 // hv frame base
    ldp x0, x1, [x15] // hv load L110
    cbz x1, _Lb2dd__bt_parse_atom_bb47 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb46 // branch -> then
_Lb2dd__bt_parse_atom_bb46:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_peek // call _bt_peek
    add x15, sp, #1808 // hv frame base
    stp x0, x1, [x15] // hv store L113
    add x15, sp, #1808 // hv frame base
    ldp x0, x1, [x15] // hv load L113
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #49 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    cbz x1, _Lb2dd__bt_parse_atom_bb49 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb48 // branch -> then
_Lb2dd__bt_parse_atom_bb47:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _bt_adv // call _bt_adv
    add x15, sp, #2288 // hv frame base
    stp x0, x1, [x15] // hv store L143
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    add x15, sp, #2304 // hv frame base
    ldp x0, x1, [x15] // hv reload L144
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    add x15, sp, #2304 // hv frame base
    ldp x0, x1, [x15] // hv reload L144
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    add x15, sp, #2304 // hv frame base
    ldp x0, x1, [x15] // hv reload L144
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    add x15, sp, #2304 // hv frame base
    ldp x0, x1, [x15] // hv reload L144
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2304 // hv frame base
    ldp x2, x3, [x15] // hv load L144
    bl _bt_emit // call _bt_emit
    add x15, sp, #2320 // hv frame base
    stp x0, x1, [x15] // hv store L145
    add x15, sp, #2320 // hv frame base
    ldp x0, x1, [x15] // hv load L145
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb48:
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L118
    add x15, sp, #1888 // hv frame base
    ldp x0, x1, [x15] // hv load L118
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L117
    b _Lb2dd__bt_parse_atom_bb50 // branch
_Lb2dd__bt_parse_atom_bb49:
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L117
    b _Lb2dd__bt_parse_atom_bb50 // branch
_Lb2dd__bt_parse_atom_bb50:
    add x15, sp, #1872 // hv frame base
    ldp x0, x1, [x15] // hv load L117
    cbz x1, _Lb2dd__bt_parse_atom_bb52 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb51 // branch -> then
_Lb2dd__bt_parse_atom_bb51:
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv reload L121
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv reload L121
    add x15, sp, #1920 // hv frame base
    ldp x2, x3, [x15] // hv load L120
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv reload L121
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv reload L121
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1936 // hv frame base
    ldp x2, x3, [x15] // hv load L121
    bl _bt_emit // call _bt_emit
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb52:
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    bl _bt_class_for_escape // call _bt_class_for_escape
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    add x15, sp, #1984 // hv frame base
    stp x0, x1, [x15] // hv store L124
    add x15, sp, #1984 // hv frame base
    ldp x0, x1, [x15] // hv load L124
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    cbz x1, _Lb2dd__bt_parse_atom_bb54 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb53 // branch -> then
_Lb2dd__bt_parse_atom_bb53:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    add x15, sp, #2048 // hv frame base
    ldp x0, x1, [x15] // hv load L128
    add x15, sp, #1984 // hv frame base
    ldp x2, x3, [x15] // hv load L124
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L132
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv reload L133
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv reload L133
    add x15, sp, #2112 // hv frame base
    ldp x2, x3, [x15] // hv load L132
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv reload L133
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv reload L133
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2128 // hv frame base
    ldp x2, x3, [x15] // hv load L133
    bl _bt_emit // call _bt_emit
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb54:
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    bl _bt_lit_for_escape // call _bt_lit_for_escape
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    add x15, sp, #2176 // hv frame base
    stp x0, x1, [x15] // hv store L136
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    cbz x1, _Lb2dd__bt_parse_atom_bb56 // br_cond: !payload -> else
    b _Lb2dd__bt_parse_atom_bb55 // branch -> then
_Lb2dd__bt_parse_atom_bb55:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv reload L139
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv reload L139
    add x15, sp, #2176 // hv frame base
    ldp x2, x3, [x15] // hv load L136
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv reload L139
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv reload L139
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2224 // hv frame base
    ldp x2, x3, [x15] // hv load L139
    bl _bt_emit // call _bt_emit
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L140
    add x15, sp, #2240 // hv frame base
    ldp x0, x1, [x15] // hv load L140
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_parse_atom_bb56:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv reload L141
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv reload L141
    add x15, sp, #1824 // hv frame base
    ldp x2, x3, [x15] // hv load L114
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv reload L141
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv reload L141
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2256 // hv frame base
    ldp x2, x3, [x15] // hv load L141
    bl _bt_emit // call _bt_emit
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    add x15, sp, #2272 // hv frame base
    ldp x0, x1, [x15] // hv load L142
    add sp, sp, #2336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_width
    .p2align 2
_bt_width:
    .loc 1 387 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1184 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_width_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd__bt_width_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb1 // branch -> then
_Lb2dd__bt_width_bb1:
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_width_bb3 // branch
_Lb2dd__bt_width_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_width_bb3 // branch
_Lb2dd__bt_width_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_width_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb4 // branch -> then
_Lb2dd__bt_width_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__bt_width_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb6 // branch -> then
_Lb2dd__bt_width_bb6:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_width_bb8 // branch
_Lb2dd__bt_width_bb7:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_width_bb8 // branch
_Lb2dd__bt_width_bb8:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_width_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb9 // branch -> then
_Lb2dd__bt_width_bb9:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_width_bb11 // branch
_Lb2dd__bt_width_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_width_bb11 // branch
_Lb2dd__bt_width_bb11:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd__bt_width_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb12 // branch -> then
_Lb2dd__bt_width_bb12:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb13:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd__bt_width_bb15 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb14 // branch -> then
_Lb2dd__bt_width_bb14:
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_width_bb16 // branch
_Lb2dd__bt_width_bb15:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_width_bb16 // branch
_Lb2dd__bt_width_bb16:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__bt_width_bb18 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb17 // branch -> then
_Lb2dd__bt_width_bb17:
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_width_bb19 // branch
_Lb2dd__bt_width_bb18:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_width_bb19 // branch
_Lb2dd__bt_width_bb19:
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__bt_width_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb20 // branch -> then
_Lb2dd__bt_width_bb20:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb21:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__bt_width_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb22 // branch -> then
_Lb2dd__bt_width_bb22:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_width_bb24 // branch
_Lb2dd__bt_width_bb23:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #15 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_width_bb24 // branch
_Lb2dd__bt_width_bb24:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd__bt_width_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb25 // branch -> then
_Lb2dd__bt_width_bb25:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb26:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd__bt_width_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb27 // branch -> then
_Lb2dd__bt_width_bb27:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #464] // hv load L29
    bl _bt_width // call _bt_width
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb28:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    cbz x1, _Lb2dd__bt_width_bb30 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb29 // branch -> then
_Lb2dd__bt_width_bb29:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    bl _bt_width // call _bt_width
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl _bt_width // call _bt_width
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _Lb2dd__bt_width_bb32 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb31 // branch -> then
_Lb2dd__bt_width_bb30:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd__bt_width_bb37 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb36 // branch -> then
_Lb2dd__bt_width_bb31:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd__bt_width_bb33 // branch
_Lb2dd__bt_width_bb32:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd__bt_width_bb33 // branch
_Lb2dd__bt_width_bb33:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd__bt_width_bb35 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb34 // branch -> then
_Lb2dd__bt_width_bb34:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb35:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_add_slow // binop +
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb36:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #736 // hv frame base
    ldp x2, x3, [x15] // hv load L46
    bl _bt_width // call _bt_width
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #784 // hv frame base
    ldp x2, x3, [x15] // hv load L49
    bl _bt_width // call _bt_width
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd__bt_width_bb39 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb38 // branch -> then
_Lb2dd__bt_width_bb37:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _Lb2dd__bt_width_bb47 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb46 // branch -> then
_Lb2dd__bt_width_bb38:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__bt_width_bb40 // branch
_Lb2dd__bt_width_bb39:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__bt_width_bb40 // branch
_Lb2dd__bt_width_bb40:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _Lb2dd__bt_width_bb42 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb41 // branch -> then
_Lb2dd__bt_width_bb41:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _Lb2dd__bt_width_bb43 // branch
_Lb2dd__bt_width_bb42:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #816 // hv frame base
    ldp x2, x3, [x15] // hv load L51
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _Lb2dd__bt_width_bb43 // branch
_Lb2dd__bt_width_bb43:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    cbz x1, _Lb2dd__bt_width_bb45 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb44 // branch -> then
_Lb2dd__bt_width_bb44:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb45:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb46:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    cbz x1, _Lb2dd__bt_width_bb49 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb48 // branch -> then
_Lb2dd__bt_width_bb47:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb48:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1024 // hv frame base
    ldp x2, x3, [x15] // hv load L64
    bl hexa_eq // binop ==
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    b _Lb2dd__bt_width_bb50 // branch
_Lb2dd__bt_width_bb49:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    b _Lb2dd__bt_width_bb50 // branch
_Lb2dd__bt_width_bb50:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd__bt_width_bb52 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb51 // branch -> then
_Lb2dd__bt_width_bb51:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1072 // hv frame base
    ldp x2, x3, [x15] // hv load L67
    bl _bt_width // call _bt_width
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    cbz x1, _Lb2dd__bt_width_bb54 // br_cond: !payload -> else
    b _Lb2dd__bt_width_bb53 // branch -> then
_Lb2dd__bt_width_bb52:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb53:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_width_bb54:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    add x15, sp, #1152 // hv frame base
    ldp x2, x3, [x15] // hv load L72
    bl hexa_mul // binop *
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    add sp, sp, #1184 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_minwidth
    .p2align 2
_bt_minwidth:
    .loc 1 422 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1024 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_minwidth_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd__bt_minwidth_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb1 // branch -> then
_Lb2dd__bt_minwidth_bb1:
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_minwidth_bb3 // branch
_Lb2dd__bt_minwidth_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_minwidth_bb3 // branch
_Lb2dd__bt_minwidth_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_minwidth_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb4 // branch -> then
_Lb2dd__bt_minwidth_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__bt_minwidth_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb6 // branch -> then
_Lb2dd__bt_minwidth_bb6:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_minwidth_bb8 // branch
_Lb2dd__bt_minwidth_bb7:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_minwidth_bb8 // branch
_Lb2dd__bt_minwidth_bb8:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_minwidth_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb9 // branch -> then
_Lb2dd__bt_minwidth_bb9:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_minwidth_bb11 // branch
_Lb2dd__bt_minwidth_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_minwidth_bb11 // branch
_Lb2dd__bt_minwidth_bb11:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd__bt_minwidth_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb12 // branch -> then
_Lb2dd__bt_minwidth_bb12:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb13:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd__bt_minwidth_bb15 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb14 // branch -> then
_Lb2dd__bt_minwidth_bb14:
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_minwidth_bb16 // branch
_Lb2dd__bt_minwidth_bb15:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_minwidth_bb16 // branch
_Lb2dd__bt_minwidth_bb16:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__bt_minwidth_bb18 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb17 // branch -> then
_Lb2dd__bt_minwidth_bb17:
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_minwidth_bb19 // branch
_Lb2dd__bt_minwidth_bb18:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_minwidth_bb19 // branch
_Lb2dd__bt_minwidth_bb19:
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__bt_minwidth_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb20 // branch -> then
_Lb2dd__bt_minwidth_bb20:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb21:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__bt_minwidth_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb22 // branch -> then
_Lb2dd__bt_minwidth_bb22:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_minwidth_bb24 // branch
_Lb2dd__bt_minwidth_bb23:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #15 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_minwidth_bb24 // branch
_Lb2dd__bt_minwidth_bb24:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd__bt_minwidth_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb25 // branch -> then
_Lb2dd__bt_minwidth_bb25:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb26:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd__bt_minwidth_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb27 // branch -> then
_Lb2dd__bt_minwidth_bb27:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb28:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _Lb2dd__bt_minwidth_bb30 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb29 // branch -> then
_Lb2dd__bt_minwidth_bb29:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #496] // hv load L31
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb30:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd__bt_minwidth_bb32 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb31 // branch -> then
_Lb2dd__bt_minwidth_bb31:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #560 // hv frame base
    ldp x2, x3, [x15] // hv load L35
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #592 // hv frame base
    ldp x2, x3, [x15] // hv load L37
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_add_slow // binop +
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb32:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd__bt_minwidth_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb33 // branch -> then
_Lb2dd__bt_minwidth_bb33:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #720 // hv frame base
    ldp x2, x3, [x15] // hv load L45
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add x15, sp, #752 // hv frame base
    ldp x2, x3, [x15] // hv load L47
    bl hexa_cmp_lt // binop <
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _Lb2dd__bt_minwidth_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb35 // branch -> then
_Lb2dd__bt_minwidth_bb34:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _Lb2dd__bt_minwidth_bb38 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb37 // branch -> then
_Lb2dd__bt_minwidth_bb35:
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb36:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb37:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb38:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    cbz x1, _Lb2dd__bt_minwidth_bb40 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb39 // branch -> then
_Lb2dd__bt_minwidth_bb39:
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _Lb2dd__bt_minwidth_bb41 // branch
_Lb2dd__bt_minwidth_bb40:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _Lb2dd__bt_minwidth_bb41 // branch
_Lb2dd__bt_minwidth_bb41:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    cbz x1, _Lb2dd__bt_minwidth_bb43 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb42 // branch -> then
_Lb2dd__bt_minwidth_bb42:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb43:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _Lb2dd__bt_minwidth_bb45 // br_cond: !payload -> else
    b _Lb2dd__bt_minwidth_bb44 // branch -> then
_Lb2dd__bt_minwidth_bb44:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #960 // hv frame base
    ldp x2, x3, [x15] // hv load L60
    bl _bt_minwidth // call _bt_minwidth
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #992 // hv frame base
    ldp x2, x3, [x15] // hv load L62
    bl hexa_mul // binop *
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_minwidth_bb45:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1024 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_maxwidth
    .p2align 2
_bt_maxwidth:
    .loc 1 449 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1216 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_maxwidth_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd__bt_maxwidth_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb1 // branch -> then
_Lb2dd__bt_maxwidth_bb1:
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_maxwidth_bb3 // branch
_Lb2dd__bt_maxwidth_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_maxwidth_bb3 // branch
_Lb2dd__bt_maxwidth_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__bt_maxwidth_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb4 // branch -> then
_Lb2dd__bt_maxwidth_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__bt_maxwidth_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb6 // branch -> then
_Lb2dd__bt_maxwidth_bb6:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_maxwidth_bb8 // branch
_Lb2dd__bt_maxwidth_bb7:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_maxwidth_bb8 // branch
_Lb2dd__bt_maxwidth_bb8:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_maxwidth_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb9 // branch -> then
_Lb2dd__bt_maxwidth_bb9:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_maxwidth_bb11 // branch
_Lb2dd__bt_maxwidth_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_maxwidth_bb11 // branch
_Lb2dd__bt_maxwidth_bb11:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd__bt_maxwidth_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb12 // branch -> then
_Lb2dd__bt_maxwidth_bb12:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb13:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd__bt_maxwidth_bb15 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb14 // branch -> then
_Lb2dd__bt_maxwidth_bb14:
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_maxwidth_bb16 // branch
_Lb2dd__bt_maxwidth_bb15:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__bt_maxwidth_bb16 // branch
_Lb2dd__bt_maxwidth_bb16:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__bt_maxwidth_bb18 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb17 // branch -> then
_Lb2dd__bt_maxwidth_bb17:
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_maxwidth_bb19 // branch
_Lb2dd__bt_maxwidth_bb18:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__bt_maxwidth_bb19 // branch
_Lb2dd__bt_maxwidth_bb19:
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__bt_maxwidth_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb20 // branch -> then
_Lb2dd__bt_maxwidth_bb20:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb21:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__bt_maxwidth_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb22 // branch -> then
_Lb2dd__bt_maxwidth_bb22:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_maxwidth_bb24 // branch
_Lb2dd__bt_maxwidth_bb23:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #15 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__bt_maxwidth_bb24 // branch
_Lb2dd__bt_maxwidth_bb24:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd__bt_maxwidth_bb26 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb25 // branch -> then
_Lb2dd__bt_maxwidth_bb25:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb26:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd__bt_maxwidth_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb27 // branch -> then
_Lb2dd__bt_maxwidth_bb27:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb28:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _Lb2dd__bt_maxwidth_bb30 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb29 // branch -> then
_Lb2dd__bt_maxwidth_bb29:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #496] // hv load L31
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb30:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd__bt_maxwidth_bb32 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb31 // branch -> then
_Lb2dd__bt_maxwidth_bb31:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #560 // hv frame base
    ldp x2, x3, [x15] // hv load L35
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb32:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__bt_maxwidth_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb33 // branch -> then
_Lb2dd__bt_maxwidth_bb33:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    cbz x1, _Lb2dd__bt_maxwidth_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb35 // branch -> then
_Lb2dd__bt_maxwidth_bb34:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _Lb2dd__bt_maxwidth_bb41 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb40 // branch -> then
_Lb2dd__bt_maxwidth_bb35:
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    b _Lb2dd__bt_maxwidth_bb37 // branch
_Lb2dd__bt_maxwidth_bb36:
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    b _Lb2dd__bt_maxwidth_bb37 // branch
_Lb2dd__bt_maxwidth_bb37:
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    cbz x1, _Lb2dd__bt_maxwidth_bb39 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb38 // branch -> then
_Lb2dd__bt_maxwidth_bb38:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb39:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    bl hexa_add_slow // binop +
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb40:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _Lb2dd__bt_maxwidth_bb43 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb42 // branch -> then
_Lb2dd__bt_maxwidth_bb41:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    cbz x1, _Lb2dd__bt_maxwidth_bb50 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb49 // branch -> then
_Lb2dd__bt_maxwidth_bb42:
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__bt_maxwidth_bb44 // branch
_Lb2dd__bt_maxwidth_bb43:
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__bt_maxwidth_bb44 // branch
_Lb2dd__bt_maxwidth_bb44:
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _Lb2dd__bt_maxwidth_bb46 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb45 // branch -> then
_Lb2dd__bt_maxwidth_bb45:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb46:
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_cmp_gt // binop >
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd__bt_maxwidth_bb48 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb47 // branch -> then
_Lb2dd__bt_maxwidth_bb47:
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb48:
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb49:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    cbz x1, _Lb2dd__bt_maxwidth_bb52 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb51 // branch -> then
_Lb2dd__bt_maxwidth_bb50:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb51:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb52:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1104 // hv frame base
    ldp x2, x3, [x15] // hv load L69
    bl _bt_maxwidth // call _bt_maxwidth
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    cbz x1, _Lb2dd__bt_maxwidth_bb54 // br_cond: !payload -> else
    b _Lb2dd__bt_maxwidth_bb53 // branch -> then
_Lb2dd__bt_maxwidth_bb53:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_maxwidth_bb54:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1184 // hv frame base
    ldp x2, x3, [x15] // hv load L74
    bl hexa_mul // binop *
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_empty
    .p2align 2
bt_empty:
    .loc 1 484 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #64 // sp adj
_Lb2dd_bt_empty_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #0] // hv store L0
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv reload L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #32] // hv store L2
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    movz x3, #2 // hv const_bool: TAG_BOOL
    movz x4, #0 // hv const_bool payload
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #0] // hv load L0
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #16] // hv load L1
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // imm 0-15
    mvn x4, x4 // hv const_int: negate
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #32] // hv load L2
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #64 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_compile
    .p2align 2
bt_compile:
    .loc 1 489 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #464 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_bt_compile_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #32] // hv store L2
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #48] // hv store L3
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv reload L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #64] // hv store L4
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv reload L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #80] // hv store L5
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #96] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #0] // hv load L0
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #32] // hv load L2
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #48] // hv load L3
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #64] // hv load L4
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr6@PAGE // cstr key page
    add x2, x2, .LCstr6@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #80] // hv load L5
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #96] // hv load L6
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #112] // hv load L7
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    bl _bt_parse_alt // call _bt_parse_alt
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_bt_compile_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_compile_bb1 // branch -> then
_Lb2dd_bt_compile_bb1:
    bl bt_empty // call bt_empty
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #464 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_compile_bb2:
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd_bt_compile_bb4 // br_cond: !payload -> else
    b _Lb2dd_bt_compile_bb3 // branch -> then
_Lb2dd_bt_compile_bb3:
    bl bt_empty // call bt_empty
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #464 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_compile_bb4:
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #144] // hv load L9
    adrp x2, .LCstr6@PAGE // cstr key page
    add x2, x2, .LCstr6@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L26
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv reload L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #432] // hv store L27
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    movz x3, #2 // hv const_bool: TAG_BOOL
    movz x4, #1 // hv const_bool payload
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #368] // hv load L23
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #384] // hv load L24
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #176] // hv load L11
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #416] // hv load L26
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #16] // hv load L1
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv reload L28
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #432] // hv load L27
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    add sp, sp, #464 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_class_match
    .p2align 2
_bt_class_match:
    .loc 1 524 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #368 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__bt_class_match_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #112] // hv store L7
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__bt_class_match_bb1 // branch
_Lb2dd__bt_class_match_bb1:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #160] // hv load L10
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__bt_class_match_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_class_match_bb2 // branch -> then
_Lb2dd__bt_class_match_bb2:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__bt_class_match_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_class_match_bb4 // branch -> then
_Lb2dd__bt_class_match_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__bt_class_match_bb10 // br_cond: !payload -> else
    b _Lb2dd__bt_class_match_bb9 // branch -> then
_Lb2dd__bt_class_match_bb4:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #240] // hv load L15
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_class_match_bb6 // branch
_Lb2dd__bt_class_match_bb5:
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__bt_class_match_bb6 // branch
_Lb2dd__bt_class_match_bb6:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd__bt_class_match_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_class_match_bb7 // branch -> then
_Lb2dd__bt_class_match_bb7:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__bt_class_match_bb8 // branch
_Lb2dd__bt_class_match_bb8:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__bt_class_match_bb1 // branch
_Lb2dd__bt_class_match_bb9:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_class_match_bb10:
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_fill
    .p2align 2
_bt_fill:
    .loc 1 538 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #128 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_fill_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_fill_bb1 // branch
_Lb2dd__bt_fill_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_fill_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_fill_bb2 // branch -> then
_Lb2dd__bt_fill_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_fill_bb1 // branch
_Lb2dd__bt_fill_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #128 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_copy
    .p2align 2
_bt_copy:
    .loc 1 546 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_copy_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_copy_bb1 // branch
_Lb2dd__bt_copy_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_copy_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_copy_bb2 // branch -> then
_Lb2dd__bt_copy_bb2:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_copy_bb1 // branch
_Lb2dd__bt_copy_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_restore
    .p2align 2
_bt_restore:
    .loc 1 553 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_restore_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_restore_bb1 // branch
_Lb2dd__bt_restore_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__bt_restore_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_restore_bb2 // branch -> then
_Lb2dd__bt_restore_bb2:
    ldp x9, x10, [sp, #32] // hv load L2
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #80] // hv store L5
    ldp x9, x10, [sp, #32] // hv load L2
    ldp x3, x4, [sp, #80] // hv load L5
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #0] // hv store L0
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_restore_bb1 // branch
_Lb2dd__bt_restore_bb3:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_cons
    .p2align 2
_bt_cons:
    .loc 1 559 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_cons_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv reload L2
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_cons_bb1 // branch
_Lb2dd__bt_cons_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__bt_cons_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_cons_bb2 // branch -> then
_Lb2dd__bt_cons_bb2:
    ldp x9, x10, [sp, #64] // hv load L4
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__bt_cons_bb1 // branch
_Lb2dd__bt_cons_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_tail
    .p2align 2
_bt_tail:
    .loc 1 567 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__bt_tail_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_tail_bb1 // branch
_Lb2dd__bt_tail_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__bt_tail_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_tail_bb2 // branch -> then
_Lb2dd__bt_tail_bb2:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__bt_tail_bb1 // branch
_Lb2dd__bt_tail_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_marker
    .p2align 2
_bt_marker:
    .loc 1 575 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_marker_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_star_view
    .p2align 2
_bt_star_view:
    .loc 1 581 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #368 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__bt_star_view_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__bt_star_view_bb1 // branch
_Lb2dd__bt_star_view_bb1:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__bt_star_view_bb3 // br_cond: !payload -> else
    b _Lb2dd__bt_star_view_bb2 // branch -> then
_Lb2dd__bt_star_view_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__bt_star_view_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_star_view_bb4 // branch -> then
_Lb2dd__bt_star_view_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #272] // hv store L17
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #272] // hv load L17
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_star_view_bb4:
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_star_view_bb6 // branch
_Lb2dd__bt_star_view_bb5:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__bt_star_view_bb6 // branch
_Lb2dd__bt_star_view_bb6:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__bt_star_view_bb8 // br_cond: !payload -> else
    b _Lb2dd__bt_star_view_bb7 // branch -> then
_Lb2dd__bt_star_view_bb7:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_star_view_bb8:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__bt_star_view_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_run
    .p2align 2
_bt_run:
    .loc 1 593 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    movz x15, #4976 // imm 0-15
    sub sp, sp, x15 // sp adj (big frame)
    stp x0, x1, [sp, #96] // ingress param 0
    stp x2, x3, [sp, #112] // ingress param 1
    stp x4, x5, [sp, #128] // ingress param 2
    stp x6, x7, [sp, #144] // ingress param 3
    ldp x9, x10, [x29, #16] // ingress stack param 4
    stp x9, x10, [sp, #160] // store stack param 4
    ldp x9, x10, [x29, #32] // ingress stack param 5
    stp x9, x10, [sp, #176] // store stack param 5
    ldp x9, x10, [x29, #48] // ingress stack param 6
    stp x9, x10, [sp, #192] // store stack param 6
_Lb2dd__bt_run_bb0:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #208] // hv store L7
    ldp x0, x1, [sp, #208] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L8
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x3, x4, [sp, #224] // hv load L8
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L2
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #240] // hv store L9
    ldp x0, x1, [sp, #240] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #256] // hv store L10
    ldp x0, x1, [sp, #256] // hv load L10
    cbz x1, _Lb2dd__bt_run_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb1 // branch -> then
_Lb2dd__bt_run_bb1:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #288] // hv store L12
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #304] // hv store L13
    ldp x0, x1, [sp, #288] // hv load L12
    ldp x2, x3, [sp, #304] // hv load L13
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #320] // hv store L14
    ldp x0, x1, [sp, #320] // hv load L14
    stp x0, x1, [sp, #272] // hv store L11
    b _Lb2dd__bt_run_bb3 // branch
_Lb2dd__bt_run_bb2:
    ldp x0, x1, [sp, #256] // hv load L10
    stp x0, x1, [sp, #272] // hv store L11
    b _Lb2dd__bt_run_bb3 // branch
_Lb2dd__bt_run_bb3:
    ldp x0, x1, [sp, #272] // hv load L11
    cbz x1, _Lb2dd__bt_run_bb5 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb4 // branch -> then
_Lb2dd__bt_run_bb4:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #2 // hv const_int val
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #1 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L2
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb5:
    ldp x0, x1, [sp, #144] // hv load L3
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #352] // hv store L16
    ldp x0, x1, [sp, #352] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L17
    ldp x0, x1, [sp, #368] // hv load L17
    cbz x1, _Lb2dd__bt_run_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb6 // branch -> then
_Lb2dd__bt_run_bb6:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb7:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #144] // hv load L3
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #400] // hv store L19
    ldp x0, x1, [sp, #400] // hv load L19
    stp x0, x1, [sp, #416] // hv store L20
    ldp x0, x1, [sp, #144] // hv load L3
    bl _bt_tail // call _bt_tail
    stp x0, x1, [sp, #432] // hv store L21
    ldp x0, x1, [sp, #432] // hv load L21
    stp x0, x1, [sp, #448] // hv store L22
    ldp x0, x1, [sp, #96] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #464] // hv store L23
    ldp x0, x1, [sp, #464] // hv load L23
    ldp x2, x3, [sp, #416] // hv load L20
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #480] // hv store L24
    ldp x0, x1, [sp, #480] // hv load L24
    stp x0, x1, [sp, #496] // hv store L25
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L26
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L26
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L27
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L28
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L28
    cbz x1, _Lb2dd__bt_run_bb9 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb8 // branch -> then
_Lb2dd__bt_run_bb8:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L30
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb9:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    cbz x1, _Lb2dd__bt_run_bb11 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb10 // branch -> then
_Lb2dd__bt_run_bb10:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd__bt_run_bb13 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb12 // branch -> then
_Lb2dd__bt_run_bb11:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _Lb2dd__bt_run_bb15 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb14 // branch -> then
_Lb2dd__bt_run_bb12:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb13:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb14:
    ldp x0, x1, [sp, #176] // hv load L5
    ldp x2, x3, [sp, #192] // hv load L6
    bl hexa_eq // binop ==
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _Lb2dd__bt_run_bb17 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb16 // branch -> then
_Lb2dd__bt_run_bb15:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #23 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _Lb2dd__bt_run_bb19 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb18 // branch -> then
_Lb2dd__bt_run_bb16:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb17:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb18:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L43
    ldp x0, x1, [sp, #176] // hv load L5
    add x15, sp, #784 // hv frame base
    ldp x2, x3, [x15] // hv load L43
    bl hexa_eq // binop ==
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd__bt_run_bb21 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb20 // branch -> then
_Lb2dd__bt_run_bb19:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _Lb2dd__bt_run_bb23 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb22 // branch -> then
_Lb2dd__bt_run_bb20:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb21:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb22:
    ldp x0, x1, [sp, #176] // hv load L5
    ldp x2, x3, [sp, #192] // hv load L6
    bl hexa_cmp_lt // binop <
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _Lb2dd__bt_run_bb25 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb24 // branch -> then
_Lb2dd__bt_run_bb23:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    cbz x1, _Lb2dd__bt_run_bb30 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb29 // branch -> then
_Lb2dd__bt_run_bb24:
    ldp x0, x1, [sp, #160] // hv load L4
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L51
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #928 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_eq // binop ==
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L50
    b _Lb2dd__bt_run_bb26 // branch
_Lb2dd__bt_run_bb25:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L50
    b _Lb2dd__bt_run_bb26 // branch
_Lb2dd__bt_run_bb26:
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _Lb2dd__bt_run_bb28 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb27 // branch -> then
_Lb2dd__bt_run_bb27:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #976 // hv frame base
    ldp x9, x10, [x15] // hv load L55
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb28:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb29:
    ldp x0, x1, [sp, #176] // hv load L5
    ldp x2, x3, [sp, #192] // hv load L6
    bl hexa_cmp_lt // binop <
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _Lb2dd__bt_run_bb32 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb31 // branch -> then
_Lb2dd__bt_run_bb30:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _Lb2dd__bt_run_bb34 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb33 // branch -> then
_Lb2dd__bt_run_bb31:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L61
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #1072 // hv frame base
    ldp x9, x10, [x15] // hv load L61
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb32:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb33:
    ldp x0, x1, [sp, #176] // hv load L5
    ldp x2, x3, [sp, #192] // hv load L6
    bl hexa_cmp_lt // binop <
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _Lb2dd__bt_run_bb36 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb35 // branch -> then
_Lb2dd__bt_run_bb34:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    cbz x1, _Lb2dd__bt_run_bb41 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb40 // branch -> then
_Lb2dd__bt_run_bb35:
    ldp x0, x1, [sp, #96] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L68
    ldp x0, x1, [sp, #160] // hv load L4
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add x15, sp, #1184 // hv frame base
    ldp x2, x3, [x15] // hv load L68
    add x15, sp, #1200 // hv frame base
    ldp x4, x5, [x15] // hv load L69
    bl _bt_class_match // call _bt_class_match
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__bt_run_bb37 // branch
_Lb2dd__bt_run_bb36:
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__bt_run_bb37 // branch
_Lb2dd__bt_run_bb37:
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    cbz x1, _Lb2dd__bt_run_bb39 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb38 // branch -> then
_Lb2dd__bt_run_bb38:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L72
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #1248 // hv frame base
    ldp x9, x10, [x15] // hv load L72
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb39:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb40:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L76
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1344 // hv frame base
    ldp x2, x3, [x15] // hv load L78
    bl _bt_cons // call _bt_cons
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L79
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #1360 // hv frame base
    ldp x6, x7, [x15] // hv load L79
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L80
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb41:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    cbz x1, _Lb2dd__bt_run_bb43 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb42 // branch -> then
_Lb2dd__bt_run_bb42:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L84
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #1440 // hv frame base
    ldp x6, x7, [x15] // hv load L84
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L86
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    cbz x1, _Lb2dd__bt_run_bb45 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb44 // branch -> then
_Lb2dd__bt_run_bb43:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    cbz x1, _Lb2dd__bt_run_bb49 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb48 // branch -> then
_Lb2dd__bt_run_bb44:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb45:
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    cbz x1, _Lb2dd__bt_run_bb47 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb46 // branch -> then
_Lb2dd__bt_run_bb46:
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb47:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1552 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L92
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #1568 // hv frame base
    ldp x6, x7, [x15] // hv load L92
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L93
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb48:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L96
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L97
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #1648 // hv frame base
    ldp x6, x7, [x15] // hv load L97
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    cbz x1, _Lb2dd__bt_run_bb51 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb50 // branch -> then
_Lb2dd__bt_run_bb49:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1776 // hv frame base
    stp x0, x1, [x15] // hv store L105
    add x15, sp, #1776 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    cbz x1, _Lb2dd__bt_run_bb55 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb54 // branch -> then
_Lb2dd__bt_run_bb50:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb51:
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    cbz x1, _Lb2dd__bt_run_bb53 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb52 // branch -> then
_Lb2dd__bt_run_bb52:
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb53:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1760 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1760 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb54:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1808 // hv frame base
    stp x0, x1, [x15] // hv store L107
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #21 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    add x15, sp, #1808 // hv frame base
    ldp x2, x3, [x15] // hv load L107
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv reload L108
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L108
    ldp x0, x1, [sp, #96] // hv load L0
    add x15, sp, #1824 // hv frame base
    ldp x2, x3, [x15] // hv load L108
    bl _bt_marker // call _bt_marker
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv load L109
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L110
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L111
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L110
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1872 // hv frame base
    ldp x0, x1, [x15] // hv load L111
    add x15, sp, #1888 // hv frame base
    ldp x2, x3, [x15] // hv load L112
    bl _bt_cons // call _bt_cons
    add x15, sp, #1904 // hv frame base
    stp x0, x1, [x15] // hv store L113
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #1904 // hv frame base
    ldp x6, x7, [x15] // hv load L113
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L114
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    cbz x1, _Lb2dd__bt_run_bb57 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb56 // branch -> then
_Lb2dd__bt_run_bb55:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2032 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #2032 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    cbz x1, _Lb2dd__bt_run_bb61 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb60 // branch -> then
_Lb2dd__bt_run_bb56:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb57:
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1984 // hv frame base
    stp x0, x1, [x15] // hv store L118
    add x15, sp, #1984 // hv frame base
    ldp x0, x1, [x15] // hv load L118
    cbz x1, _Lb2dd__bt_run_bb59 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb58 // branch -> then
_Lb2dd__bt_run_bb58:
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb59:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L120
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb60:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L123
    ldp x0, x1, [sp, #96] // hv load L0
    add x15, sp, #2064 // hv frame base
    ldp x2, x3, [x15] // hv load L123
    bl _bt_star_view // call _bt_star_view
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L124
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L124
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L125
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L127
    add x15, sp, #2112 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    add x15, sp, #2128 // hv frame base
    ldp x2, x3, [x15] // hv load L127
    bl _bt_cons // call _bt_cons
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L128
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #2144 // hv frame base
    ldp x6, x7, [x15] // hv load L128
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L129
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L129
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb61:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2176 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    cbz x1, _Lb2dd__bt_run_bb63 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb62 // branch -> then
_Lb2dd__bt_run_bb62:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L132
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L133
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L134
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #2208 // hv frame base
    ldp x6, x7, [x15] // hv load L132
    add x15, sp, #2224 // hv frame base
    ldp x9, x10, [x15] // hv load L133
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #2240 // hv frame base
    ldp x9, x10, [x15] // hv load L134
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #448] // hv load L22
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #48] // C7: stack arg 7
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #64] // C7: stack arg 8
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #80] // C7: stack arg 9
    bl _bt_run_repeat // call _bt_run_repeat
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb63:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #20 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L136
    add x15, sp, #2272 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    cbz x1, _Lb2dd__bt_run_bb65 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb64 // branch -> then
_Lb2dd__bt_run_bb64:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L138
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2320 // hv frame base
    stp x0, x1, [x15] // hv store L139
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2336 // hv frame base
    stp x0, x1, [x15] // hv store L140
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #2304 // hv frame base
    ldp x6, x7, [x15] // hv load L138
    add x15, sp, #2320 // hv frame base
    ldp x9, x10, [x15] // hv load L139
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #2336 // hv frame base
    ldp x9, x10, [x15] // hv load L140
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #448] // hv load L22
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #48] // C7: stack arg 7
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #64] // C7: stack arg 8
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #80] // C7: stack arg 9
    bl _bt_run_repeat // call _bt_run_repeat
    add x15, sp, #2352 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2352 // hv frame base
    ldp x0, x1, [x15] // hv load L141
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb65:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #21 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2368 // hv frame base
    stp x0, x1, [x15] // hv store L142
    add x15, sp, #2368 // hv frame base
    ldp x0, x1, [x15] // hv load L142
    cbz x1, _Lb2dd__bt_run_bb67 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb66 // branch -> then
_Lb2dd__bt_run_bb66:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2400 // hv frame base
    stp x0, x1, [x15] // hv store L144
    ldp x0, x1, [sp, #176] // hv load L5
    add x15, sp, #2400 // hv frame base
    ldp x2, x3, [x15] // hv load L144
    bl hexa_eq // binop ==
    add x15, sp, #2416 // hv frame base
    stp x0, x1, [x15] // hv store L145
    add x15, sp, #2416 // hv frame base
    ldp x0, x1, [x15] // hv load L145
    cbz x1, _Lb2dd__bt_run_bb69 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb68 // branch -> then
_Lb2dd__bt_run_bb67:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L162
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L162
    cbz x1, _Lb2dd__bt_run_bb75 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb74 // branch -> then
_Lb2dd__bt_run_bb68:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L147
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L147
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb69:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2464 // hv frame base
    stp x0, x1, [x15] // hv store L148
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L149
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv reload L149
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #21 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L149
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv reload L149
    add x15, sp, #2464 // hv frame base
    ldp x2, x3, [x15] // hv load L148
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L149
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv reload L149
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L149
    ldp x0, x1, [sp, #96] // hv load L0
    add x15, sp, #2480 // hv frame base
    ldp x2, x3, [x15] // hv load L149
    bl _bt_marker // call _bt_marker
    add x15, sp, #2496 // hv frame base
    stp x0, x1, [x15] // hv store L150
    add x15, sp, #2496 // hv frame base
    ldp x0, x1, [x15] // hv load L150
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L151
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L152
    add x15, sp, #2512 // hv frame base
    ldp x0, x1, [x15] // hv load L151
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #2544 // hv frame base
    stp x0, x1, [x15] // hv store L153
    add x15, sp, #2528 // hv frame base
    ldp x0, x1, [x15] // hv load L152
    add x15, sp, #2544 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl _bt_cons // call _bt_cons
    add x15, sp, #2560 // hv frame base
    stp x0, x1, [x15] // hv store L154
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #2560 // hv frame base
    ldp x6, x7, [x15] // hv load L154
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2576 // hv frame base
    stp x0, x1, [x15] // hv store L155
    add x15, sp, #2576 // hv frame base
    ldp x0, x1, [x15] // hv load L155
    add x15, sp, #2592 // hv frame base
    stp x0, x1, [x15] // hv store L156
    add x15, sp, #2592 // hv frame base
    ldp x0, x1, [x15] // hv load L156
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #2608 // hv frame base
    stp x0, x1, [x15] // hv store L157
    add x15, sp, #2608 // hv frame base
    ldp x0, x1, [x15] // hv load L157
    cbz x1, _Lb2dd__bt_run_bb71 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb70 // branch -> then
_Lb2dd__bt_run_bb70:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb71:
    add x15, sp, #2592 // hv frame base
    ldp x0, x1, [x15] // hv load L156
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2640 // hv frame base
    stp x0, x1, [x15] // hv store L159
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L159
    cbz x1, _Lb2dd__bt_run_bb73 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb72 // branch -> then
_Lb2dd__bt_run_bb72:
    add x15, sp, #2592 // hv frame base
    ldp x0, x1, [x15] // hv load L156
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb73:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2672 // hv frame base
    stp x0, x1, [x15] // hv store L161
    add x15, sp, #2672 // hv frame base
    ldp x0, x1, [x15] // hv load L161
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb74:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2720 // hv frame base
    stp x0, x1, [x15] // hv store L164
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2736 // hv frame base
    ldp x0, x1, [x15] // hv reload L165
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #22 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2736 // hv frame base
    ldp x0, x1, [x15] // hv reload L165
    add x15, sp, #2720 // hv frame base
    ldp x2, x3, [x15] // hv load L164
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2736 // hv frame base
    ldp x0, x1, [x15] // hv reload L165
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L165
    ldp x0, x1, [sp, #96] // hv load L0
    add x15, sp, #2736 // hv frame base
    ldp x2, x3, [x15] // hv load L165
    bl _bt_marker // call _bt_marker
    add x15, sp, #2752 // hv frame base
    stp x0, x1, [x15] // hv store L166
    add x15, sp, #2752 // hv frame base
    ldp x0, x1, [x15] // hv load L166
    add x15, sp, #2768 // hv frame base
    stp x0, x1, [x15] // hv store L167
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2784 // hv frame base
    stp x0, x1, [x15] // hv store L168
    add x15, sp, #2768 // hv frame base
    ldp x0, x1, [x15] // hv load L167
    ldp x2, x3, [sp, #448] // hv load L22
    bl _bt_cons // call _bt_cons
    add x15, sp, #2800 // hv frame base
    stp x0, x1, [x15] // hv store L169
    add x15, sp, #2784 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    add x15, sp, #2800 // hv frame base
    ldp x2, x3, [x15] // hv load L169
    bl _bt_cons // call _bt_cons
    add x15, sp, #2816 // hv frame base
    stp x0, x1, [x15] // hv store L170
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #2816 // hv frame base
    ldp x6, x7, [x15] // hv load L170
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #2832 // hv frame base
    stp x0, x1, [x15] // hv store L171
    add x15, sp, #2832 // hv frame base
    ldp x0, x1, [x15] // hv load L171
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb75:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #22 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L172
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L172
    cbz x1, _Lb2dd__bt_run_bb77 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb76 // branch -> then
_Lb2dd__bt_run_bb76:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2880 // hv frame base
    stp x0, x1, [x15] // hv store L174
    add x15, sp, #2880 // hv frame base
    ldp x0, x1, [x15] // hv load L174
    add x15, sp, #2896 // hv frame base
    stp x0, x1, [x15] // hv store L175
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #2912 // hv frame base
    stp x0, x1, [x15] // hv store L176
    add x15, sp, #2912 // hv frame base
    ldp x9, x10, [x15] // hv load L176
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #2928 // hv frame base
    stp x0, x1, [x15] // hv store L177
    add x15, sp, #2928 // hv frame base
    ldp x0, x1, [x15] // hv load L177
    add x15, sp, #2944 // hv frame base
    stp x0, x1, [x15] // hv store L178
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #2960 // hv frame base
    stp x0, x1, [x15] // hv store L179
    add x15, sp, #2960 // hv frame base
    ldp x0, x1, [x15] // hv load L179
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2976 // hv frame base
    stp x0, x1, [x15] // hv store L180
    add x15, sp, #2976 // hv frame base
    ldp x9, x10, [x15] // hv load L180
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #2992 // hv frame base
    stp x0, x1, [x15] // hv store L181
    add x15, sp, #2992 // hv frame base
    ldp x0, x1, [x15] // hv load L181
    add x15, sp, #3008 // hv frame base
    stp x0, x1, [x15] // hv store L182
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L183
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3040 // hv frame base
    stp x0, x1, [x15] // hv store L184
    add x15, sp, #3024 // hv frame base
    ldp x9, x10, [x15] // hv load L183
    add x15, sp, #3040 // hv frame base
    ldp x3, x4, [x15] // hv load L184
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L1
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #3056 // hv frame base
    stp x0, x1, [x15] // hv store L185
    add x15, sp, #3056 // hv frame base
    ldp x0, x1, [x15] // hv load L185
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3072 // hv frame base
    stp x0, x1, [x15] // hv store L186
    add x15, sp, #3072 // hv frame base
    ldp x9, x10, [x15] // hv load L186
    ldp x3, x4, [sp, #176] // hv load L5
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L1
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #3088 // hv frame base
    stp x0, x1, [x15] // hv store L187
    add x15, sp, #3088 // hv frame base
    ldp x0, x1, [x15] // hv load L187
    add x15, sp, #3104 // hv frame base
    stp x0, x1, [x15] // hv store L188
    add x15, sp, #3104 // hv frame base
    ldp x0, x1, [x15] // hv load L188
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #3120 // hv frame base
    stp x0, x1, [x15] // hv store L189
    add x15, sp, #3120 // hv frame base
    ldp x0, x1, [x15] // hv load L189
    cbz x1, _Lb2dd__bt_run_bb79 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb78 // branch -> then
_Lb2dd__bt_run_bb77:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3232 // hv frame base
    stp x0, x1, [x15] // hv store L196
    add x15, sp, #3232 // hv frame base
    ldp x0, x1, [x15] // hv load L196
    cbz x1, _Lb2dd__bt_run_bb83 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb82 // branch -> then
_Lb2dd__bt_run_bb78:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb79:
    add x15, sp, #3104 // hv frame base
    ldp x0, x1, [x15] // hv load L188
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3152 // hv frame base
    stp x0, x1, [x15] // hv store L191
    add x15, sp, #3152 // hv frame base
    ldp x0, x1, [x15] // hv load L191
    cbz x1, _Lb2dd__bt_run_bb81 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb80 // branch -> then
_Lb2dd__bt_run_bb80:
    add x15, sp, #3104 // hv frame base
    ldp x0, x1, [x15] // hv load L188
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb81:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #3184 // hv frame base
    stp x0, x1, [x15] // hv store L193
    add x15, sp, #3184 // hv frame base
    ldp x9, x10, [x15] // hv load L193
    add x15, sp, #2944 // hv frame base
    ldp x3, x4, [x15] // hv load L178
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L1
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #2896 // hv frame base
    ldp x2, x3, [x15] // hv load L175
    bl hexa_mul // binop *
    add x15, sp, #3200 // hv frame base
    stp x0, x1, [x15] // hv store L194
    add x15, sp, #3200 // hv frame base
    ldp x0, x1, [x15] // hv load L194
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3216 // hv frame base
    stp x0, x1, [x15] // hv store L195
    add x15, sp, #3216 // hv frame base
    ldp x9, x10, [x15] // hv load L195
    add x15, sp, #3008 // hv frame base
    ldp x3, x4, [x15] // hv load L182
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L1
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb82:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3264 // hv frame base
    stp x0, x1, [x15] // hv store L198
    add x15, sp, #3264 // hv frame base
    ldp x0, x1, [x15] // hv load L198
    add x15, sp, #3280 // hv frame base
    stp x0, x1, [x15] // hv store L199
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #3280 // hv frame base
    ldp x2, x3, [x15] // hv load L199
    bl hexa_mul // binop *
    add x15, sp, #3296 // hv frame base
    stp x0, x1, [x15] // hv store L200
    add x15, sp, #3296 // hv frame base
    ldp x0, x1, [x15] // hv load L200
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3312 // hv frame base
    stp x0, x1, [x15] // hv store L201
    ldp x0, x1, [sp, #112] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #3328 // hv frame base
    stp x0, x1, [x15] // hv store L202
    add x15, sp, #3312 // hv frame base
    ldp x0, x1, [x15] // hv load L201
    add x15, sp, #3328 // hv frame base
    ldp x2, x3, [x15] // hv load L202
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3344 // hv frame base
    stp x0, x1, [x15] // hv store L203
    add x15, sp, #3344 // hv frame base
    ldp x0, x1, [x15] // hv load L203
    cbz x1, _Lb2dd__bt_run_bb85 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb84 // branch -> then
_Lb2dd__bt_run_bb83:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3824 // hv frame base
    stp x0, x1, [x15] // hv store L233
    add x15, sp, #3824 // hv frame base
    ldp x0, x1, [x15] // hv load L233
    cbz x1, _Lb2dd__bt_run_bb99 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb98 // branch -> then
_Lb2dd__bt_run_bb84:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb85:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #3280 // hv frame base
    ldp x2, x3, [x15] // hv load L199
    bl hexa_mul // binop *
    add x15, sp, #3376 // hv frame base
    stp x0, x1, [x15] // hv store L205
    add x15, sp, #3376 // hv frame base
    ldp x9, x10, [x15] // hv load L205
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #3392 // hv frame base
    stp x0, x1, [x15] // hv store L206
    add x15, sp, #3392 // hv frame base
    ldp x0, x1, [x15] // hv load L206
    add x15, sp, #3408 // hv frame base
    stp x0, x1, [x15] // hv store L207
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #3280 // hv frame base
    ldp x2, x3, [x15] // hv load L199
    bl hexa_mul // binop *
    add x15, sp, #3424 // hv frame base
    stp x0, x1, [x15] // hv store L208
    add x15, sp, #3424 // hv frame base
    ldp x0, x1, [x15] // hv load L208
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3440 // hv frame base
    stp x0, x1, [x15] // hv store L209
    add x15, sp, #3440 // hv frame base
    ldp x9, x10, [x15] // hv load L209
    ldp x0, x1, [sp, #112] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #3456 // hv frame base
    stp x0, x1, [x15] // hv store L210
    add x15, sp, #3456 // hv frame base
    ldp x0, x1, [x15] // hv load L210
    add x15, sp, #3472 // hv frame base
    stp x0, x1, [x15] // hv store L211
    add x15, sp, #3408 // hv frame base
    ldp x0, x1, [x15] // hv load L207
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #3488 // hv frame base
    stp x0, x1, [x15] // hv store L212
    add x15, sp, #3488 // hv frame base
    ldp x0, x1, [x15] // hv load L212
    cbz x1, _Lb2dd__bt_run_bb87 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb86 // branch -> then
_Lb2dd__bt_run_bb86:
    add x15, sp, #3488 // hv frame base
    ldp x0, x1, [x15] // hv load L212
    add x15, sp, #3504 // hv frame base
    stp x0, x1, [x15] // hv store L213
    b _Lb2dd__bt_run_bb88 // branch
_Lb2dd__bt_run_bb87:
    add x15, sp, #3472 // hv frame base
    ldp x0, x1, [x15] // hv load L211
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #3520 // hv frame base
    stp x0, x1, [x15] // hv store L214
    add x15, sp, #3520 // hv frame base
    ldp x0, x1, [x15] // hv load L214
    add x15, sp, #3504 // hv frame base
    stp x0, x1, [x15] // hv store L213
    b _Lb2dd__bt_run_bb88 // branch
_Lb2dd__bt_run_bb88:
    add x15, sp, #3504 // hv frame base
    ldp x0, x1, [x15] // hv load L213
    cbz x1, _Lb2dd__bt_run_bb90 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb89 // branch -> then
_Lb2dd__bt_run_bb89:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #3552 // hv frame base
    stp x0, x1, [x15] // hv store L216
    add x15, sp, #3552 // hv frame base
    ldp x0, x1, [x15] // hv load L216
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb90:
    add x15, sp, #3472 // hv frame base
    ldp x0, x1, [x15] // hv load L211
    add x15, sp, #3408 // hv frame base
    ldp x2, x3, [x15] // hv load L207
    bl hexa_sub // binop -
    add x15, sp, #3568 // hv frame base
    stp x0, x1, [x15] // hv store L217
    add x15, sp, #3568 // hv frame base
    ldp x0, x1, [x15] // hv load L217
    add x15, sp, #3584 // hv frame base
    stp x0, x1, [x15] // hv store L218
    ldp x0, x1, [sp, #176] // hv load L5
    add x15, sp, #3584 // hv frame base
    ldp x2, x3, [x15] // hv load L218
    bl hexa_add_slow // binop +
    add x15, sp, #3600 // hv frame base
    stp x0, x1, [x15] // hv store L219
    add x15, sp, #3600 // hv frame base
    ldp x0, x1, [x15] // hv load L219
    ldp x2, x3, [sp, #192] // hv load L6
    bl hexa_cmp_gt // binop >
    add x15, sp, #3616 // hv frame base
    stp x0, x1, [x15] // hv store L220
    add x15, sp, #3616 // hv frame base
    ldp x0, x1, [x15] // hv load L220
    cbz x1, _Lb2dd__bt_run_bb92 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb91 // branch -> then
_Lb2dd__bt_run_bb91:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb92:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #3648 // hv frame base
    stp x0, x1, [x15] // hv store L222
    b _Lb2dd__bt_run_bb93 // branch
_Lb2dd__bt_run_bb93:
    add x15, sp, #3648 // hv frame base
    ldp x0, x1, [x15] // hv load L222
    add x15, sp, #3584 // hv frame base
    ldp x2, x3, [x15] // hv load L218
    bl hexa_cmp_lt // binop <
    add x15, sp, #3664 // hv frame base
    stp x0, x1, [x15] // hv store L223
    add x15, sp, #3664 // hv frame base
    ldp x0, x1, [x15] // hv load L223
    cbz x1, _Lb2dd__bt_run_bb95 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb94 // branch -> then
_Lb2dd__bt_run_bb94:
    ldp x0, x1, [sp, #176] // hv load L5
    add x15, sp, #3648 // hv frame base
    ldp x2, x3, [x15] // hv load L222
    bl hexa_add_slow // binop +
    add x15, sp, #3680 // hv frame base
    stp x0, x1, [x15] // hv store L224
    ldp x0, x1, [sp, #160] // hv load L4
    add x15, sp, #3680 // hv frame base
    ldp x2, x3, [x15] // hv load L224
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #3696 // hv frame base
    stp x0, x1, [x15] // hv store L225
    add x15, sp, #3408 // hv frame base
    ldp x0, x1, [x15] // hv load L207
    add x15, sp, #3648 // hv frame base
    ldp x2, x3, [x15] // hv load L222
    bl hexa_add_slow // binop +
    add x15, sp, #3712 // hv frame base
    stp x0, x1, [x15] // hv store L226
    ldp x0, x1, [sp, #160] // hv load L4
    add x15, sp, #3712 // hv frame base
    ldp x2, x3, [x15] // hv load L226
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #3728 // hv frame base
    stp x0, x1, [x15] // hv store L227
    add x15, sp, #3696 // hv frame base
    ldp x0, x1, [x15] // hv load L225
    add x15, sp, #3728 // hv frame base
    ldp x2, x3, [x15] // hv load L227
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #3744 // hv frame base
    stp x0, x1, [x15] // hv store L228
    add x15, sp, #3744 // hv frame base
    ldp x0, x1, [x15] // hv load L228
    cbz x1, _Lb2dd__bt_run_bb97 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb96 // branch -> then
_Lb2dd__bt_run_bb95:
    ldp x0, x1, [sp, #176] // hv load L5
    add x15, sp, #3584 // hv frame base
    ldp x2, x3, [x15] // hv load L218
    bl hexa_add_slow // binop +
    add x15, sp, #3792 // hv frame base
    stp x0, x1, [x15] // hv store L231
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #3792 // hv frame base
    ldp x9, x10, [x15] // hv load L231
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #3808 // hv frame base
    stp x0, x1, [x15] // hv store L232
    add x15, sp, #3808 // hv frame base
    ldp x0, x1, [x15] // hv load L232
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb96:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb97:
    add x15, sp, #3648 // hv frame base
    ldp x0, x1, [x15] // hv load L222
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3776 // hv frame base
    stp x0, x1, [x15] // hv store L230
    add x15, sp, #3776 // hv frame base
    ldp x0, x1, [x15] // hv load L230
    add x15, sp, #3648 // hv frame base
    stp x0, x1, [x15] // hv store L222
    b _Lb2dd__bt_run_bb93 // branch
_Lb2dd__bt_run_bb98:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3856 // hv frame base
    stp x0, x1, [x15] // hv store L235
    add x15, sp, #3856 // hv frame base
    ldp x0, x1, [x15] // hv load L235
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3872 // hv frame base
    stp x0, x1, [x15] // hv store L236
    add x15, sp, #3872 // hv frame base
    ldp x0, x1, [x15] // hv load L236
    cbz x1, _Lb2dd__bt_run_bb101 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb100 // branch -> then
_Lb2dd__bt_run_bb99:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #15 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #4240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L259
    movz x15, #4240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L259
    cbz x1, _Lb2dd__bt_run_bb111 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb110 // branch -> then
_Lb2dd__bt_run_bb100:
    ldp x0, x1, [sp, #112] // hv load L1
    bl _bt_copy // call _bt_copy
    add x15, sp, #3904 // hv frame base
    stp x0, x1, [x15] // hv store L238
    add x15, sp, #3904 // hv frame base
    ldp x0, x1, [x15] // hv load L238
    add x15, sp, #3920 // hv frame base
    stp x0, x1, [x15] // hv store L239
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3936 // hv frame base
    stp x0, x1, [x15] // hv store L240
    bl hexa_array_new // array_lit: new array
    add x15, sp, #3952 // hv frame base
    stp x0, x1, [x15] // hv store L241
    add x15, sp, #3952 // hv frame base
    ldp x0, x1, [x15] // hv reload L241
    add x15, sp, #3936 // hv frame base
    ldp x2, x3, [x15] // hv load L240
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #3952 // hv frame base
    stp x0, x1, [x15] // hv store L241
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    add x15, sp, #3952 // hv frame base
    ldp x6, x7, [x15] // hv load L241
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #3968 // hv frame base
    stp x0, x1, [x15] // hv store L242
    add x15, sp, #3968 // hv frame base
    ldp x0, x1, [x15] // hv load L242
    add x15, sp, #3984 // hv frame base
    stp x0, x1, [x15] // hv store L243
    ldp x0, x1, [sp, #112] // hv load L1
    add x15, sp, #3920 // hv frame base
    ldp x2, x3, [x15] // hv load L239
    bl _bt_restore // call _bt_restore
    add x15, sp, #4000 // hv frame base
    stp x0, x1, [x15] // hv store L244
    add x15, sp, #3984 // hv frame base
    ldp x0, x1, [x15] // hv load L243
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #4016 // hv frame base
    stp x0, x1, [x15] // hv store L245
    add x15, sp, #4016 // hv frame base
    ldp x0, x1, [x15] // hv load L245
    cbz x1, _Lb2dd__bt_run_bb103 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb102 // branch -> then
_Lb2dd__bt_run_bb101:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L250
    bl hexa_array_new // array_lit: new array
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L251
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L251
    movz x15, #4096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L250
    bl hexa_array_push // array_lit: push elem 0
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L251
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x6, x7, [x15] // hv load L251
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    movz x15, #4128 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L252
    movz x15, #4128 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L252
    movz x15, #4144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L253
    movz x15, #4144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L253
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L254
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L254
    cbz x1, _Lb2dd__bt_run_bb107 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb106 // branch -> then
_Lb2dd__bt_run_bb102:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb103:
    add x15, sp, #3984 // hv frame base
    ldp x0, x1, [x15] // hv load L243
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #4048 // hv frame base
    stp x0, x1, [x15] // hv store L247
    add x15, sp, #4048 // hv frame base
    ldp x0, x1, [x15] // hv load L247
    cbz x1, _Lb2dd__bt_run_bb105 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb104 // branch -> then
_Lb2dd__bt_run_bb104:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #4080 // hv frame base
    stp x0, x1, [x15] // hv store L249
    add x15, sp, #4080 // hv frame base
    ldp x0, x1, [x15] // hv load L249
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb105:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb106:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb107:
    movz x15, #4144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L253
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    movz x15, #4192 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L256
    movz x15, #4192 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L256
    cbz x1, _Lb2dd__bt_run_bb109 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb108 // branch -> then
_Lb2dd__bt_run_bb108:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    movz x15, #4224 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L258
    movz x15, #4224 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L258
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb109:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb110:
    ldp x0, x1, [sp, #96] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L261
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L262
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L261
    movz x15, #4288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L262
    bl _bt_minwidth // call _bt_minwidth
    movz x15, #4304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L263
    movz x15, #4304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L263
    movz x15, #4320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L264
    ldp x0, x1, [sp, #96] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    movz x15, #4336 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L265
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L266
    movz x15, #4336 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L265
    movz x15, #4352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L266
    bl _bt_maxwidth // call _bt_maxwidth
    movz x15, #4368 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L267
    movz x15, #4368 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L267
    movz x15, #4384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L268
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L269
    ldp x0, x1, [sp, #112] // hv load L1
    bl _bt_copy // call _bt_copy
    movz x15, #4416 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L270
    movz x15, #4416 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L270
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L271
    movz x15, #4384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L268
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    movz x15, #4448 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L272
    movz x15, #4448 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L272
    cbz x1, _Lb2dd__bt_run_bb113 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb112 // branch -> then
_Lb2dd__bt_run_bb111:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb112:
    bl hexa_array_new // array_lit: new array
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L274
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #23 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L274
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_array_push // array_lit: push elem 1
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L274
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L274
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    ldp x0, x1, [sp, #96] // hv load L0
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L274
    bl _bt_marker // call _bt_marker
    movz x15, #4496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L275
    movz x15, #4496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L275
    movz x15, #4512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L276
    movz x15, #4384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L268
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L277
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L277
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_cmp_gt // binop >
    movz x15, #4544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L278
    movz x15, #4544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L278
    cbz x1, _Lb2dd__bt_run_bb115 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb114 // branch -> then
_Lb2dd__bt_run_bb113:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L295
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L295
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #4832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L296
    movz x15, #4832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L296
    cbz x1, _Lb2dd__bt_run_bb126 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb125 // branch -> then
_Lb2dd__bt_run_bb114:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L277
    b _Lb2dd__bt_run_bb115 // branch
_Lb2dd__bt_run_bb115:
    b _Lb2dd__bt_run_bb116 // branch
_Lb2dd__bt_run_bb116:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L277
    movz x15, #4320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L264
    bl hexa_cmp_ge // binop >=
    movz x15, #4576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L280
    movz x15, #4576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L280
    cbz x1, _Lb2dd__bt_run_bb118 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb117 // branch -> then
_Lb2dd__bt_run_bb117:
    ldp x0, x1, [sp, #176] // hv load L5
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L277
    bl hexa_sub // binop -
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L281
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L281
    movz x15, #4608 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L282
    movz x15, #4608 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L282
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    movz x15, #4624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L283
    movz x15, #4624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    cbz x1, _Lb2dd__bt_run_bb120 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb119 // branch -> then
_Lb2dd__bt_run_bb118:
    b _Lb2dd__bt_run_bb113 // branch
_Lb2dd__bt_run_bb119:
    ldp x0, x1, [sp, #496] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L285
    bl hexa_array_new // array_lit: new array
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L286
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L286
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L285
    bl hexa_array_push // array_lit: push elem 0
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L286
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv reload L286
    movz x15, #4512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L276
    bl hexa_array_push // array_lit: push elem 1
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L286
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x6, x7, [x15] // hv load L286
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    movz x15, #4608 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x9, x10, [x15] // hv load L282
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    movz x15, #4688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L287
    movz x15, #4688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L287
    movz x15, #4704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L288
    movz x15, #4704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L288
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    movz x15, #4720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L289
    movz x15, #4720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L289
    cbz x1, _Lb2dd__bt_run_bb122 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb121 // branch -> then
_Lb2dd__bt_run_bb120:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L277
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    movz x15, #4800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L294
    movz x15, #4800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L294
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L277
    b _Lb2dd__bt_run_bb116 // branch
_Lb2dd__bt_run_bb121:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb122:
    movz x15, #4704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L288
    ldp x2, x3, [sp, #176] // hv load L5
    bl hexa_eq // binop ==
    movz x15, #4752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L291
    movz x15, #4752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L291
    cbz x1, _Lb2dd__bt_run_bb124 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb123 // branch -> then
_Lb2dd__bt_run_bb123:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L269
    b _Lb2dd__bt_run_bb118 // branch
_Lb2dd__bt_run_bb124:
    ldp x0, x1, [sp, #112] // hv load L1
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L271
    bl _bt_restore // call _bt_restore
    movz x15, #4784 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L293
    b _Lb2dd__bt_run_bb120 // branch
_Lb2dd__bt_run_bb125:
    ldp x0, x1, [sp, #112] // hv load L1
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L271
    bl _bt_restore // call _bt_restore
    movz x15, #4864 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L298
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L269
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    movz x15, #4880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L299
    movz x15, #4880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L299
    cbz x1, _Lb2dd__bt_run_bb128 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb127 // branch -> then
_Lb2dd__bt_run_bb126:
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L269
    cbz x1, _Lb2dd__bt_run_bb130 // br_cond: !payload -> else
    b _Lb2dd__bt_run_bb129 // branch -> then
_Lb2dd__bt_run_bb127:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    movz x15, #4912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L301
    movz x15, #4912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L301
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb128:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb129:
    ldp x0, x1, [sp, #96] // hv load L0
    ldp x2, x3, [sp, #112] // hv load L1
    ldp x4, x5, [sp, #128] // hv load L2
    ldp x6, x7, [sp, #448] // hv load L22
    ldp x9, x10, [sp, #160] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L5
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    movz x15, #4944 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L303
    movz x15, #4944 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L303
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_bb130:
    ldp x0, x1, [sp, #112] // hv load L1
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L271
    bl _bt_restore // call _bt_restore
    movz x15, #4960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L304
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    movz x15, #4976 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _bt_run_repeat
    .p2align 2
_bt_run_repeat:
    .loc 1 755 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #720 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
    stp x4, x5, [sp, #80] // ingress param 2
    stp x6, x7, [sp, #96] // ingress param 3
    ldp x9, x10, [x29, #16] // ingress stack param 4
    stp x9, x10, [sp, #112] // store stack param 4
    ldp x9, x10, [x29, #32] // ingress stack param 5
    stp x9, x10, [sp, #128] // store stack param 5
    ldp x9, x10, [x29, #48] // ingress stack param 6
    stp x9, x10, [sp, #144] // store stack param 6
    ldp x9, x10, [x29, #64] // ingress stack param 7
    stp x9, x10, [sp, #160] // store stack param 7
    ldp x9, x10, [x29, #80] // ingress stack param 8
    stp x9, x10, [sp, #176] // store stack param 8
    ldp x9, x10, [x29, #96] // ingress stack param 9
    stp x9, x10, [sp, #192] // store stack param 9
_Lb2dd__bt_run_repeat_bb0:
    ldp x0, x1, [sp, #112] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv load L10
    cbz x1, _Lb2dd__bt_run_repeat_bb2 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb1 // branch -> then
_Lb2dd__bt_run_repeat_bb1:
    ldp x0, x1, [sp, #112] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #240] // hv store L12
    ldp x0, x1, [sp, #128] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #256] // hv store L13
    ldp x0, x1, [sp, #256] // hv load L13
    cbz x1, _Lb2dd__bt_run_repeat_bb4 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb3 // branch -> then
_Lb2dd__bt_run_repeat_bb2:
    ldp x0, x1, [sp, #128] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #400] // hv load L22
    cbz x1, _Lb2dd__bt_run_repeat_bb7 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb6 // branch -> then
_Lb2dd__bt_run_repeat_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #272] // hv store L14
    b _Lb2dd__bt_run_repeat_bb5 // branch
_Lb2dd__bt_run_repeat_bb4:
    ldp x0, x1, [sp, #128] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #288] // hv store L15
    ldp x0, x1, [sp, #288] // hv load L15
    stp x0, x1, [sp, #272] // hv store L14
    b _Lb2dd__bt_run_repeat_bb5 // branch
_Lb2dd__bt_run_repeat_bb5:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #20 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv reload L16
    ldp x2, x3, [sp, #96] // hv load L3
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv reload L16
    ldp x2, x3, [sp, #240] // hv load L12
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv reload L16
    ldp x2, x3, [sp, #272] // hv load L14
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #304] // hv load L16
    bl _bt_marker // call _bt_marker
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #336] // hv load L18
    ldp x2, x3, [sp, #144] // hv load L6
    bl _bt_cons // call _bt_cons
    stp x0, x1, [sp, #352] // hv store L19
    ldp x0, x1, [sp, #96] // hv load L3
    ldp x2, x3, [sp, #352] // hv load L19
    bl _bt_cons // call _bt_cons
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L1
    ldp x4, x5, [sp, #80] // hv load L2
    ldp x6, x7, [sp, #368] // hv load L20
    ldp x9, x10, [sp, #160] // hv load L7
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L8
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L9
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv load L21
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_repeat_bb6:
    ldp x0, x1, [sp, #128] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    cbz x1, _Lb2dd__bt_run_repeat_bb9 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb8 // branch -> then
_Lb2dd__bt_run_repeat_bb7:
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L1
    ldp x4, x5, [sp, #80] // hv load L2
    ldp x6, x7, [sp, #144] // hv load L6
    ldp x9, x10, [sp, #160] // hv load L7
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L8
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L9
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_repeat_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #448] // hv store L25
    b _Lb2dd__bt_run_repeat_bb10 // branch
_Lb2dd__bt_run_repeat_bb9:
    ldp x0, x1, [sp, #128] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #464] // hv store L26
    ldp x0, x1, [sp, #464] // hv load L26
    stp x0, x1, [sp, #448] // hv store L25
    b _Lb2dd__bt_run_repeat_bb10 // branch
_Lb2dd__bt_run_repeat_bb10:
    ldp x0, x1, [sp, #448] // hv load L25
    stp x0, x1, [sp, #480] // hv store L27
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv reload L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #20 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv reload L28
    ldp x2, x3, [sp, #96] // hv load L3
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv reload L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv reload L28
    ldp x2, x3, [sp, #480] // hv load L27
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #496] // hv load L28
    bl _bt_marker // call _bt_marker
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L29
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L29
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L30
    ldp x2, x3, [sp, #144] // hv load L6
    bl _bt_cons // call _bt_cons
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    ldp x0, x1, [sp, #96] // hv load L3
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L31
    bl _bt_cons // call _bt_cons
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L1
    ldp x4, x5, [sp, #80] // hv load L2
    add x15, sp, #560 // hv frame base
    ldp x6, x7, [x15] // hv load L32
    ldp x9, x10, [sp, #160] // hv load L7
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #176] // hv load L8
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L9
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _Lb2dd__bt_run_repeat_bb12 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb11 // branch -> then
_Lb2dd__bt_run_repeat_bb11:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_repeat_bb12:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__bt_run_repeat_bb14 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb13 // branch -> then
_Lb2dd__bt_run_repeat_bb13:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    ldp x2, x3, [sp, #176] // hv load L8
    bl hexa_cmp_gt // binop >
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L38
    b _Lb2dd__bt_run_repeat_bb15 // branch
_Lb2dd__bt_run_repeat_bb14:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L38
    b _Lb2dd__bt_run_repeat_bb15 // branch
_Lb2dd__bt_run_repeat_bb15:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _Lb2dd__bt_run_repeat_bb17 // br_cond: !payload -> else
    b _Lb2dd__bt_run_repeat_bb16 // branch -> then
_Lb2dd__bt_run_repeat_bb16:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__bt_run_repeat_bb17:
    b _Lb2dd__bt_run_repeat_bb7 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_match_full
    .p2align 2
bt_match_full:
    .loc 1 777 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #496 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
_Lb2dd_bt_match_full_bb0:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #80] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #96] // hv load L3
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    cbz x1, _Lb2dd_bt_match_full_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_match_full_bb1 // branch -> then
_Lb2dd_bt_match_full_bb1:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_match_full_bb2:
    ldp x0, x1, [sp, #64] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #144] // hv store L6
    ldp x0, x1, [sp, #144] // hv load L6
    stp x0, x1, [sp, #160] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #176] // hv load L8
    bl _bt_marker // call _bt_marker
    stp x0, x1, [sp, #192] // hv store L9
    ldp x0, x1, [sp, #192] // hv load L9
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L12
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #240] // hv load L12
    bl hexa_mul // binop *
    stp x0, x1, [sp, #256] // hv store L13
    ldp x0, x1, [sp, #256] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl _bt_fill // call _bt_fill
    stp x0, x1, [sp, #272] // hv store L14
    ldp x0, x1, [sp, #272] // hv load L14
    stp x0, x1, [sp, #288] // hv store L15
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #304] // hv store L16
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv reload L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv reload L17
    ldp x2, x3, [sp, #304] // hv load L16
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv reload L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #352] // hv store L19
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #368] // hv reload L20
    ldp x2, x3, [sp, #352] // hv load L19
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #368] // hv reload L20
    ldp x2, x3, [sp, #208] // hv load L10
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #288] // hv load L15
    ldp x4, x5, [sp, #336] // hv load L18
    ldp x6, x7, [sp, #368] // hv load L20
    ldp x9, x10, [sp, #64] // hv load L1
    stp x9, x10, [sp, #0] // C7: stack arg 4
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #160] // hv load L7
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv load L21
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #336] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L23
    ldp x0, x1, [sp, #416] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    cbz x1, _Lb2dd_bt_match_full_bb4 // br_cond: !payload -> else
    b _Lb2dd_bt_match_full_bb3 // branch -> then
_Lb2dd_bt_match_full_bb3:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #464] // hv store L26
    ldp x0, x1, [sp, #464] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #464] // hv store L26
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_match_full_bb4:
    ldp x0, x1, [sp, #400] // hv load L22
    ldp x2, x3, [sp, #160] // hv load L7
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #480] // hv load L27
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_search
    .p2align 2
bt_search:
    .loc 1 792 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #576 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
_Lb2dd_bt_search_bb0:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #80] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #96] // hv load L3
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    cbz x1, _Lb2dd_bt_search_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_search_bb1 // branch -> then
_Lb2dd_bt_search_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L6
    ldp x0, x1, [sp, #144] // hv load L6
    add sp, sp, #576 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_bb2:
    ldp x0, x1, [sp, #64] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #160] // hv store L7
    ldp x0, x1, [sp, #160] // hv load L7
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #192] // hv store L9
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    ldp x2, x3, [sp, #192] // hv load L9
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv load L10
    stp x0, x1, [sp, #224] // hv store L11
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #240] // hv store L12
    b _Lb2dd_bt_search_bb3 // branch
_Lb2dd_bt_search_bb3:
    ldp x0, x1, [sp, #240] // hv load L12
    ldp x2, x3, [sp, #176] // hv load L8
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #256] // hv store L13
    ldp x0, x1, [sp, #256] // hv load L13
    cbz x1, _Lb2dd_bt_search_bb5 // br_cond: !payload -> else
    b _Lb2dd_bt_search_bb4 // branch -> then
_Lb2dd_bt_search_bb4:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #272] // hv store L14
    ldp x0, x1, [sp, #272] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #288] // hv store L15
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #288] // hv load L15
    bl hexa_mul // binop *
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl _bt_fill // call _bt_fill
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #352] // hv store L19
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #368] // hv reload L20
    ldp x2, x3, [sp, #352] // hv load L19
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #336] // hv load L18
    ldp x4, x5, [sp, #224] // hv load L11
    ldp x6, x7, [sp, #368] // hv load L20
    ldp x9, x10, [sp, #64] // hv load L1
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #240] // hv load L12
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #176] // hv load L8
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv load L21
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #224] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L23
    ldp x0, x1, [sp, #416] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    cbz x1, _Lb2dd_bt_search_bb7 // br_cond: !payload -> else
    b _Lb2dd_bt_search_bb6 // branch -> then
_Lb2dd_bt_search_bb5:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add sp, sp, #576 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_bb6:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #464] // hv store L26
    ldp x0, x1, [sp, #464] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #464] // hv store L26
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #480] // hv load L27
    add sp, sp, #576 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_bb7:
    ldp x0, x1, [sp, #400] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv load L28
    cbz x1, _Lb2dd_bt_search_bb9 // br_cond: !payload -> else
    b _Lb2dd_bt_search_bb8 // branch -> then
_Lb2dd_bt_search_bb8:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv reload L30
    ldp x2, x3, [sp, #240] // hv load L12
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv reload L30
    ldp x2, x3, [sp, #400] // hv load L22
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L30
    add sp, sp, #576 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_bb9:
    ldp x0, x1, [sp, #240] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    stp x0, x1, [sp, #240] // hv store L12
    b _Lb2dd_bt_search_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #576 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_search_captures
    .p2align 2
bt_search_captures:
    .loc 1 816 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #560 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
_Lb2dd_bt_search_captures_bb0:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #80] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #96] // hv load L3
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    cbz x1, _Lb2dd_bt_search_captures_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_search_captures_bb1 // branch -> then
_Lb2dd_bt_search_captures_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L6
    ldp x0, x1, [sp, #144] // hv load L6
    add sp, sp, #560 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_captures_bb2:
    ldp x0, x1, [sp, #64] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #160] // hv store L7
    ldp x0, x1, [sp, #160] // hv load L7
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #192] // hv store L9
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    ldp x2, x3, [sp, #192] // hv load L9
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv reload L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #208] // hv store L10
    ldp x0, x1, [sp, #208] // hv load L10
    stp x0, x1, [sp, #224] // hv store L11
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #240] // hv store L12
    b _Lb2dd_bt_search_captures_bb3 // branch
_Lb2dd_bt_search_captures_bb3:
    ldp x0, x1, [sp, #240] // hv load L12
    ldp x2, x3, [sp, #176] // hv load L8
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #256] // hv store L13
    ldp x0, x1, [sp, #256] // hv load L13
    cbz x1, _Lb2dd_bt_search_captures_bb5 // br_cond: !payload -> else
    b _Lb2dd_bt_search_captures_bb4 // branch -> then
_Lb2dd_bt_search_captures_bb4:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #272] // hv store L14
    ldp x0, x1, [sp, #272] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #288] // hv store L15
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #288] // hv load L15
    bl hexa_mul // binop *
    stp x0, x1, [sp, #304] // hv store L16
    ldp x0, x1, [sp, #304] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl _bt_fill // call _bt_fill
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #352] // hv store L19
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #368] // hv reload L20
    ldp x2, x3, [sp, #352] // hv load L19
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #368] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #336] // hv load L18
    ldp x4, x5, [sp, #224] // hv load L11
    ldp x6, x7, [sp, #368] // hv load L20
    ldp x9, x10, [sp, #64] // hv load L1
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #240] // hv load L12
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #176] // hv load L8
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv load L21
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #224] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L23
    ldp x0, x1, [sp, #416] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    cbz x1, _Lb2dd_bt_search_captures_bb7 // br_cond: !payload -> else
    b _Lb2dd_bt_search_captures_bb6 // branch -> then
_Lb2dd_bt_search_captures_bb5:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    add sp, sp, #560 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_captures_bb6:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #464] // hv store L26
    ldp x0, x1, [sp, #464] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #464] // hv store L26
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #480] // hv load L27
    add sp, sp, #560 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_captures_bb7:
    ldp x0, x1, [sp, #400] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv load L28
    cbz x1, _Lb2dd_bt_search_captures_bb9 // br_cond: !payload -> else
    b _Lb2dd_bt_search_captures_bb8 // branch -> then
_Lb2dd_bt_search_captures_bb8:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x3, x4, [sp, #240] // hv load L12
    ldp x0, x1, [sp, #336] // hv load L18
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #336] // hv store L18
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x3, x4, [sp, #400] // hv load L22
    ldp x0, x1, [sp, #336] // hv load L18
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #336] // hv load L18
    add sp, sp, #560 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_captures_bb9:
    ldp x0, x1, [sp, #240] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L30
    stp x0, x1, [sp, #240] // hv store L12
    b _Lb2dd_bt_search_captures_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #560 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_find_all
    .p2align 2
bt_find_all:
    .loc 1 838 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #624 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
_Lb2dd_bt_find_all_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L2
    ldp x0, x1, [sp, #80] // hv load L2
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #128] // hv store L5
    ldp x0, x1, [sp, #128] // hv load L5
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #144] // hv store L6
    ldp x0, x1, [sp, #144] // hv load L6
    cbz x1, _Lb2dd_bt_find_all_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_find_all_bb1 // branch -> then
_Lb2dd_bt_find_all_bb1:
    ldp x0, x1, [sp, #96] // hv load L3
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_find_all_bb2:
    ldp x0, x1, [sp, #64] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv load L8
    stp x0, x1, [sp, #192] // hv store L9
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #208] // hv store L10
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    ldp x2, x3, [sp, #208] // hv load L10
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv load L11
    stp x0, x1, [sp, #240] // hv store L12
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_find_all_bb3 // branch
_Lb2dd_bt_find_all_bb3:
    ldp x0, x1, [sp, #256] // hv load L13
    ldp x2, x3, [sp, #192] // hv load L9
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L14
    ldp x0, x1, [sp, #272] // hv load L14
    cbz x1, _Lb2dd_bt_find_all_bb5 // br_cond: !payload -> else
    b _Lb2dd_bt_find_all_bb4 // branch -> then
_Lb2dd_bt_find_all_bb4:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #288] // hv store L15
    ldp x0, x1, [sp, #288] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L16
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #304] // hv load L16
    bl hexa_mul // binop *
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl _bt_fill // call _bt_fill
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #336] // hv load L18
    stp x0, x1, [sp, #352] // hv store L19
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #368] // hv store L20
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv reload L21
    ldp x2, x3, [sp, #368] // hv load L20
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #352] // hv load L19
    ldp x4, x5, [sp, #240] // hv load L12
    ldp x6, x7, [sp, #384] // hv load L21
    ldp x9, x10, [sp, #64] // hv load L1
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #256] // hv load L13
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L9
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #400] // hv load L22
    stp x0, x1, [sp, #416] // hv store L23
    ldp x0, x1, [sp, #240] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L25
    ldp x0, x1, [sp, #448] // hv load L25
    cbz x1, _Lb2dd_bt_find_all_bb7 // br_cond: !payload -> else
    b _Lb2dd_bt_find_all_bb6 // branch -> then
_Lb2dd_bt_find_all_bb5:
    ldp x0, x1, [sp, #96] // hv load L3
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_find_all_bb6:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #480] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #96] // hv load L3
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_find_all_bb7:
    ldp x0, x1, [sp, #416] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv load L28
    cbz x1, _Lb2dd_bt_find_all_bb9 // br_cond: !payload -> else
    b _Lb2dd_bt_find_all_bb8 // branch -> then
_Lb2dd_bt_find_all_bb8:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv reload L30
    ldp x2, x3, [sp, #256] // hv load L13
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv reload L30
    ldp x2, x3, [sp, #416] // hv load L23
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L30
    ldp x0, x1, [sp, #96] // hv load L3
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L30
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    ldp x0, x1, [sp, #416] // hv load L23
    ldp x2, x3, [sp, #256] // hv load L13
    bl hexa_cmp_gt // binop >
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _Lb2dd_bt_find_all_bb11 // br_cond: !payload -> else
    b _Lb2dd_bt_find_all_bb10 // branch -> then
_Lb2dd_bt_find_all_bb9:
    ldp x0, x1, [sp, #256] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_find_all_bb13 // branch
_Lb2dd_bt_find_all_bb10:
    ldp x0, x1, [sp, #416] // hv load L23
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_find_all_bb12 // branch
_Lb2dd_bt_find_all_bb11:
    ldp x0, x1, [sp, #256] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_find_all_bb12 // branch
_Lb2dd_bt_find_all_bb12:
    b _Lb2dd_bt_find_all_bb13 // branch
_Lb2dd_bt_find_all_bb13:
    b _Lb2dd_bt_find_all_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden bt_search_from
    .p2align 2
bt_search_from:
    .loc 1 867 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #592 // sp adj
    stp x0, x1, [sp, #48] // ingress param 0
    stp x2, x3, [sp, #64] // ingress param 1
    stp x4, x5, [sp, #80] // ingress param 2
_Lb2dd_bt_search_from_bb0:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #96] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #96] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L4
    ldp x0, x1, [sp, #112] // hv load L4
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #128] // hv store L5
    ldp x0, x1, [sp, #128] // hv load L5
    cbz x1, _Lb2dd_bt_search_from_bb2 // br_cond: !payload -> else
    b _Lb2dd_bt_search_from_bb1 // branch -> then
_Lb2dd_bt_search_from_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #160] // hv store L7
    ldp x0, x1, [sp, #160] // hv load L7
    add sp, sp, #592 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_from_bb2:
    ldp x0, x1, [sp, #64] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #176] // hv store L8
    ldp x0, x1, [sp, #176] // hv load L8
    stp x0, x1, [sp, #192] // hv store L9
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr10@PAGE // cstr key page
    add x2, x2, .LCstr10@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #208] // hv store L10
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    ldp x2, x3, [sp, #208] // hv load L10
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv reload L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #224] // hv store L11
    ldp x0, x1, [sp, #224] // hv load L11
    stp x0, x1, [sp, #240] // hv store L12
    ldp x0, x1, [sp, #80] // hv load L2
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_search_from_bb3 // branch
_Lb2dd_bt_search_from_bb3:
    ldp x0, x1, [sp, #256] // hv load L13
    ldp x2, x3, [sp, #192] // hv load L9
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L14
    ldp x0, x1, [sp, #272] // hv load L14
    cbz x1, _Lb2dd_bt_search_from_bb5 // br_cond: !payload -> else
    b _Lb2dd_bt_search_from_bb4 // branch -> then
_Lb2dd_bt_search_from_bb4:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr9@PAGE // cstr key page
    add x2, x2, .LCstr9@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #288] // hv store L15
    ldp x0, x1, [sp, #288] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L16
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #304] // hv load L16
    bl hexa_mul // binop *
    stp x0, x1, [sp, #320] // hv store L17
    ldp x0, x1, [sp, #320] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl _bt_fill // call _bt_fill
    stp x0, x1, [sp, #336] // hv store L18
    ldp x0, x1, [sp, #336] // hv load L18
    stp x0, x1, [sp, #352] // hv store L19
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr8@PAGE // cstr key page
    add x2, x2, .LCstr8@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #368] // hv store L20
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #384] // hv reload L21
    ldp x2, x3, [sp, #368] // hv load L20
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #384] // hv store L21
    ldp x0, x1, [sp, #48] // hv load L0
    ldp x2, x3, [sp, #352] // hv load L19
    ldp x4, x5, [sp, #240] // hv load L12
    ldp x6, x7, [sp, #384] // hv load L21
    ldp x9, x10, [sp, #64] // hv load L1
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #256] // hv load L13
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #192] // hv load L9
    stp x9, x10, [sp, #32] // C7: stack arg 6
    bl _bt_run // call _bt_run
    stp x0, x1, [sp, #400] // hv store L22
    ldp x0, x1, [sp, #400] // hv load L22
    stp x0, x1, [sp, #416] // hv store L23
    ldp x0, x1, [sp, #240] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #432] // hv store L24
    ldp x0, x1, [sp, #432] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L25
    ldp x0, x1, [sp, #448] // hv load L25
    cbz x1, _Lb2dd_bt_search_from_bb7 // br_cond: !payload -> else
    b _Lb2dd_bt_search_from_bb6 // branch -> then
_Lb2dd_bt_search_from_bb5:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add sp, sp, #592 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_from_bb6:
    ldp x0, x1, [sp, #48] // hv load L0
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #480] // hv store L27
    ldp x0, x1, [sp, #480] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #1 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #480] // hv store L27
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #496] // hv store L28
    ldp x0, x1, [sp, #496] // hv load L28
    add sp, sp, #592 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_from_bb7:
    ldp x0, x1, [sp, #416] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L29
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L29
    cbz x1, _Lb2dd_bt_search_from_bb9 // br_cond: !payload -> else
    b _Lb2dd_bt_search_from_bb8 // branch -> then
_Lb2dd_bt_search_from_bb8:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv reload L31
    ldp x2, x3, [sp, #256] // hv load L13
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv reload L31
    ldp x2, x3, [sp, #416] // hv load L23
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    add sp, sp, #592 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_bt_search_from_bb9:
    ldp x0, x1, [sp, #256] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    stp x0, x1, [sp, #256] // hv store L13
    b _Lb2dd_bt_search_from_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #592 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _REGEX_DEFAULT_STEP_CAP
    .p2align 2
_REGEX_DEFAULT_STEP_CAP:
    .loc 1 97 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
_Lb2dd__REGEX_DEFAULT_STEP_CAP_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #16960 // imm 0-15
    movk x1, #15, lsl #16 // imm 16-31
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_peek
    .p2align 2
_re_peek:
    .loc 1 136 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_peek_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__re_peek_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_peek_bb1 // branch -> then
_Lb2dd__re_peek_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_peek_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_adv
    .p2align 2
_re_adv:
    .loc 1 141 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #80 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_adv_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #64] // hv load L4
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #16] // hv store L1
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #80 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_emit
    .p2align 2
_re_emit:
    .loc 1 146 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__re_emit_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_class_for_escape
    .p2align 2
_re_class_for_escape:
    .loc 1 153 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_class_for_escape_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #100 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _Lb2dd__re_class_for_escape_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb1 // branch -> then
_Lb2dd__re_class_for_escape_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #68 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__re_class_for_escape_bb4 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb3 // branch -> then
_Lb2dd__re_class_for_escape_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #119 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__re_class_for_escape_bb6 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb5 // branch -> then
_Lb2dd__re_class_for_escape_bb5:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_array_push // array_lit: push elem 5
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #122 // hv const_int val
    bl hexa_array_push // array_lit: push elem 6
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 7
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #87 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__re_class_for_escape_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb7 // branch -> then
_Lb2dd__re_class_for_escape_bb7:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_array_push // array_lit: push elem 5
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #122 // hv const_int val
    bl hexa_array_push // array_lit: push elem 6
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 7
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv reload L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_array_push // array_lit: push elem 8
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #115 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__re_class_for_escape_bb10 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb9 // branch -> then
_Lb2dd__re_class_for_escape_bb9:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv reload L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #83 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__re_class_for_escape_bb12 // br_cond: !payload -> else
    b _Lb2dd__re_class_for_escape_bb11 // branch -> then
_Lb2dd__re_class_for_escape_bb11:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_array_push // array_lit: push elem 4
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_for_escape_bb12:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_lit_for_escape
    .p2align 2
_re_lit_for_escape:
    .loc 1 165 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_lit_for_escape_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _Lb2dd__re_lit_for_escape_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_lit_for_escape_bb1 // branch -> then
_Lb2dd__re_lit_for_escape_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_lit_for_escape_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #116 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__re_lit_for_escape_bb4 // br_cond: !payload -> else
    b _Lb2dd__re_lit_for_escape_bb3 // branch -> then
_Lb2dd__re_lit_for_escape_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_lit_for_escape_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #114 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__re_lit_for_escape_bb6 // br_cond: !payload -> else
    b _Lb2dd__re_lit_for_escape_bb5 // branch -> then
_Lb2dd__re_lit_for_escape_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #13 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_lit_for_escape_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__re_lit_for_escape_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_lit_for_escape_bb7 // branch -> then
_Lb2dd__re_lit_for_escape_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_lit_for_escape_bb8:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_push_class
    .p2align 2
_re_push_class:
    .loc 1 174 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #288 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__re_push_class_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv reload L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__re_push_class_bb1 // branch
_Lb2dd__re_push_class_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__re_push_class_bb3 // br_cond: !payload -> else
    b _Lb2dd__re_push_class_bb2 // branch -> then
_Lb2dd__re_push_class_bb2:
    ldp x9, x10, [sp, #80] // hv load L5
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__re_push_class_bb1 // branch
_Lb2dd__re_push_class_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #240] // hv store L15
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    ldp x2, x3, [sp, #240] // hv load L15
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv reload L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #256] // hv load L16
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    add sp, sp, #288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_parse_class
    .p2align 2
_re_parse_class:
    .loc 1 183 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1360 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_parse_class_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__re_parse_class_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb1 // branch -> then
_Lb2dd__re_parse_class_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__re_parse_class_bb2 // branch
_Lb2dd__re_parse_class_bb2:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__re_parse_class_bb3 // branch
_Lb2dd__re_parse_class_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__re_parse_class_bb5 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb4 // branch -> then
_Lb2dd__re_parse_class_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__re_parse_class_bb7 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb6 // branch -> then
_Lb2dd__re_parse_class_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_class_bb6:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__re_parse_class_bb8 // branch
_Lb2dd__re_parse_class_bb7:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__re_parse_class_bb8 // branch
_Lb2dd__re_parse_class_bb8:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__re_parse_class_bb10 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb9 // branch -> then
_Lb2dd__re_parse_class_bb9:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #32] // hv load L2
    ldp x4, x5, [sp, #48] // hv load L3
    bl _re_push_class // call _re_push_class
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_class_bb10:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #336] // hv store L21
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__re_parse_class_bb12 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb11 // branch -> then
_Lb2dd__re_parse_class_bb11:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #432] // hv load L27
    bl _re_class_for_escape // call _re_class_for_escape
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _Lb2dd__re_parse_class_bb14 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb13 // branch -> then
_Lb2dd__re_parse_class_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__re_parse_class_bb22 // branch
_Lb2dd__re_parse_class_bb13:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd__re_parse_class_bb15 // branch
_Lb2dd__re_parse_class_bb14:
    ldp x0, x1, [sp, #432] // hv load L27
    bl _re_lit_for_escape // call _re_lit_for_escape
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
    bl hexa_cmp_ge // binop >=
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    cbz x1, _Lb2dd__re_parse_class_bb19 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb18 // branch -> then
_Lb2dd__re_parse_class_bb15:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #480] // hv load L30
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_cmp_lt // binop <
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__re_parse_class_bb17 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb16 // branch -> then
_Lb2dd__re_parse_class_bb16:
    add x15, sp, #544 // hv frame base
    ldp x9, x10, [x15] // hv load L34
    ldp x0, x1, [sp, #480] // hv load L30
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x9, x10, [x15] // hv load L40
    ldp x0, x1, [sp, #480] // hv load L30
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #656 // hv frame base
    ldp x2, x3, [x15] // hv load L41
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd__re_parse_class_bb15 // branch
_Lb2dd__re_parse_class_bb17:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd__re_parse_class_bb21 // branch
_Lb2dd__re_parse_class_bb18:
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__re_parse_class_bb20 // branch
_Lb2dd__re_parse_class_bb19:
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #336] // hv store L21
    b _Lb2dd__re_parse_class_bb20 // branch
_Lb2dd__re_parse_class_bb20:
    b _Lb2dd__re_parse_class_bb21 // branch
_Lb2dd__re_parse_class_bb21:
    b _Lb2dd__re_parse_class_bb22 // branch
_Lb2dd__re_parse_class_bb22:
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _Lb2dd__re_parse_class_bb24 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb23 // branch -> then
_Lb2dd__re_parse_class_bb23:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd__re_parse_class_bb26 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb25 // branch -> then
_Lb2dd__re_parse_class_bb24:
    b _Lb2dd__re_parse_class_bb3 // branch
_Lb2dd__re_parse_class_bb25:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_cmp_lt // binop <
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__re_parse_class_bb27 // branch
_Lb2dd__re_parse_class_bb26:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd__re_parse_class_bb27 // branch
_Lb2dd__re_parse_class_bb27:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _Lb2dd__re_parse_class_bb29 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb28 // branch -> then
_Lb2dd__re_parse_class_bb28:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #1008 // hv frame base
    ldp x2, x3, [x15] // hv load L63
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__re_parse_class_bb30 // branch
_Lb2dd__re_parse_class_bb29:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    b _Lb2dd__re_parse_class_bb30 // branch
_Lb2dd__re_parse_class_bb30:
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _Lb2dd__re_parse_class_bb32 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb31 // branch -> then
_Lb2dd__re_parse_class_bb31:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    cbz x1, _Lb2dd__re_parse_class_bb34 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb33 // branch -> then
_Lb2dd__re_parse_class_bb32:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__re_parse_class_bb38 // branch
_Lb2dd__re_parse_class_bb33:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    bl _re_lit_for_escape // call _re_lit_for_escape
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    cbz x1, _Lb2dd__re_parse_class_bb36 // br_cond: !payload -> else
    b _Lb2dd__re_parse_class_bb35 // branch -> then
_Lb2dd__re_parse_class_bb34:
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    ldp x0, x1, [sp, #32] // hv load L2
    add x15, sp, #1104 // hv frame base
    ldp x2, x3, [x15] // hv load L69
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    b _Lb2dd__re_parse_class_bb38 // branch
_Lb2dd__re_parse_class_bb35:
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd__re_parse_class_bb37 // branch
_Lb2dd__re_parse_class_bb36:
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    b _Lb2dd__re_parse_class_bb37 // branch
_Lb2dd__re_parse_class_bb37:
    b _Lb2dd__re_parse_class_bb34 // branch
_Lb2dd__re_parse_class_bb38:
    b _Lb2dd__re_parse_class_bb24 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1360 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_parse_alt
    .p2align 2
_re_parse_alt:
    .loc 1 246 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_parse_alt_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_concat // call _re_parse_concat
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_alt_bb1 // branch
_Lb2dd__re_parse_alt_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__re_parse_alt_bb3 // br_cond: !payload -> else
    b _Lb2dd__re_parse_alt_bb2 // branch -> then
_Lb2dd__re_parse_alt_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_concat // call _re_parse_concat
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #128] // hv load L8
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_alt_bb1 // branch
_Lb2dd__re_parse_alt_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_parse_concat
    .p2align 2
_re_parse_concat:
    .loc 1 257 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #400 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_parse_concat_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__re_parse_concat_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb1 // branch -> then
_Lb2dd__re_parse_concat_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__re_parse_concat_bb3 // branch
_Lb2dd__re_parse_concat_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__re_parse_concat_bb3 // branch
_Lb2dd__re_parse_concat_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__re_parse_concat_bb5 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb4 // branch -> then
_Lb2dd__re_parse_concat_bb4:
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd__re_parse_concat_bb6 // branch
_Lb2dd__re_parse_concat_bb5:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd__re_parse_concat_bb6 // branch
_Lb2dd__re_parse_concat_bb6:
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__re_parse_concat_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb7 // branch -> then
_Lb2dd__re_parse_concat_bb7:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv reload L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #144] // hv load L9
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_concat_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_repeat // call _re_parse_repeat
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__re_parse_concat_bb9 // branch
_Lb2dd__re_parse_concat_bb9:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    cbz x1, _Lb2dd__re_parse_concat_bb11 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb10 // branch -> then
_Lb2dd__re_parse_concat_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__re_parse_concat_bb13 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb12 // branch -> then
_Lb2dd__re_parse_concat_bb11:
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_concat_bb12:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__re_parse_concat_bb14 // branch
_Lb2dd__re_parse_concat_bb13:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #124 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__re_parse_concat_bb14 // branch
_Lb2dd__re_parse_concat_bb14:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__re_parse_concat_bb16 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb15 // branch -> then
_Lb2dd__re_parse_concat_bb15:
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__re_parse_concat_bb17 // branch
_Lb2dd__re_parse_concat_bb16:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__re_parse_concat_bb17 // branch
_Lb2dd__re_parse_concat_bb17:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__re_parse_concat_bb19 // br_cond: !payload -> else
    b _Lb2dd__re_parse_concat_bb18 // branch -> then
_Lb2dd__re_parse_concat_bb18:
    b _Lb2dd__re_parse_concat_bb11 // branch
_Lb2dd__re_parse_concat_bb19:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_repeat // call _re_parse_repeat
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    ldp x2, x3, [sp, #352] // hv load L22
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv reload L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #368] // hv load L23
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__re_parse_concat_bb9 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #400 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_parse_repeat
    .p2align 2
_re_parse_repeat:
    .loc 1 273 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_parse_repeat_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_atom // call _re_parse_atom
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_repeat_bb1 // branch
_Lb2dd__re_parse_repeat_bb1:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    cbz x1, _Lb2dd__re_parse_repeat_bb3 // br_cond: !payload -> else
    b _Lb2dd__re_parse_repeat_bb2 // branch -> then
_Lb2dd__re_parse_repeat_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #42 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__re_parse_repeat_bb5 // br_cond: !payload -> else
    b _Lb2dd__re_parse_repeat_bb4 // branch -> then
_Lb2dd__re_parse_repeat_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_repeat_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #128] // hv load L8
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_repeat_bb12 // branch
_Lb2dd__re_parse_repeat_bb5:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__re_parse_repeat_bb7 // br_cond: !payload -> else
    b _Lb2dd__re_parse_repeat_bb6 // branch -> then
_Lb2dd__re_parse_repeat_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #192] // hv store L12
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv reload L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #208] // hv load L13
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_repeat_bb11 // branch
_Lb2dd__re_parse_repeat_bb7:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__re_parse_repeat_bb9 // br_cond: !payload -> else
    b _Lb2dd__re_parse_repeat_bb8 // branch -> then
_Lb2dd__re_parse_repeat_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #272] // hv store L17
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #288] // hv load L18
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__re_parse_repeat_bb10 // branch
_Lb2dd__re_parse_repeat_bb9:
    b _Lb2dd__re_parse_repeat_bb3 // branch
_Lb2dd__re_parse_repeat_bb10:
    b _Lb2dd__re_parse_repeat_bb11 // branch
_Lb2dd__re_parse_repeat_bb11:
    b _Lb2dd__re_parse_repeat_bb12 // branch
_Lb2dd__re_parse_repeat_bb12:
    b _Lb2dd__re_parse_repeat_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_parse_atom
    .p2align 2
_re_parse_atom:
    .loc 1 286 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #976 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_parse_atom_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__re_parse_atom_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb1 // branch -> then
_Lb2dd__re_parse_atom_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_alt // call _re_parse_alt
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    cbz x1, _Lb2dd__re_parse_atom_bb4 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb3 // branch -> then
_Lb2dd__re_parse_atom_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #91 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__re_parse_atom_bb7 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb6 // branch -> then
_Lb2dd__re_parse_atom_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #176] // hv store L11
    b _Lb2dd__re_parse_atom_bb5 // branch
_Lb2dd__re_parse_atom_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #192] // hv store L12
    b _Lb2dd__re_parse_atom_bb5 // branch
_Lb2dd__re_parse_atom_bb5:
    ldp x0, x1, [sp, #112] // hv load L7
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_parse_class // call _re_parse_class
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb7:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd__re_parse_atom_bb9 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb8 // branch -> then
_Lb2dd__re_parse_atom_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #304] // hv store L19
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #320] // hv load L20
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb9:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd__re_parse_atom_bb11 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb10 // branch -> then
_Lb2dd__re_parse_atom_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #384] // hv store L24
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv reload L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv reload L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv reload L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv reload L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #400] // hv load L25
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb11:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #36 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd__re_parse_atom_bb13 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb12 // branch -> then
_Lb2dd__re_parse_atom_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    stp x0, x1, [sp, #464] // hv store L29
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #480] // hv load L30
    bl _re_emit // call _re_emit
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb13:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _Lb2dd__re_parse_atom_bb15 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb14 // branch -> then
_Lb2dd__re_parse_atom_bb14:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_peek // call _re_peek
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    bl _re_class_for_escape // call _re_class_for_escape
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _Lb2dd__re_parse_atom_bb17 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb16 // branch -> then
_Lb2dd__re_parse_atom_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _re_adv // call _re_adv
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    bl hexa_array_new // array_lit: new array
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv reload L59
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv reload L59
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv reload L59
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv reload L59
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    bl _re_emit // call _re_emit
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb16:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    bl hexa_array_new // array_lit: new array
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    add x15, sp, #752 // hv frame base
    ldp x2, x3, [x15] // hv load L47
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #768 // hv frame base
    ldp x2, x3, [x15] // hv load L48
    bl _re_emit // call _re_emit
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb17:
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    bl _re_lit_for_escape // call _re_lit_for_escape
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd__re_parse_atom_bb19 // br_cond: !payload -> else
    b _Lb2dd__re_parse_atom_bb18 // branch -> then
_Lb2dd__re_parse_atom_bb18:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv reload L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv reload L54
    add x15, sp, #816 // hv frame base
    ldp x2, x3, [x15] // hv load L51
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv reload L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv reload L54
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #864 // hv frame base
    ldp x2, x3, [x15] // hv load L54
    bl _re_emit // call _re_emit
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_parse_atom_bb19:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv reload L56
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv reload L56
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv reload L56
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv reload L56
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 3
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #896 // hv frame base
    ldp x2, x3, [x15] // hv load L56
    bl _re_emit // call _re_emit
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add sp, sp, #976 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _nfa_new
    .p2align 2
_nfa_new:
    .loc 1 326 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__nfa_new_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _nfa_patch
    .p2align 2
_nfa_patch:
    .loc 1 335 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #272 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__nfa_patch_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__nfa_patch_bb1 // branch
_Lb2dd__nfa_patch_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__nfa_patch_bb3 // br_cond: !payload -> else
    b _Lb2dd__nfa_patch_bb2 // branch -> then
_Lb2dd__nfa_patch_bb2:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__nfa_patch_bb5 // br_cond: !payload -> else
    b _Lb2dd__nfa_patch_bb4 // branch -> then
_Lb2dd__nfa_patch_bb3:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #272 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__nfa_patch_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #144] // hv load L9
    ldp x4, x5, [sp, #32] // hv load L2
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__nfa_patch_bb6 // branch
_Lb2dd__nfa_patch_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #144] // hv load L9
    ldp x4, x5, [sp, #32] // hv load L2
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #240] // hv store L15
    b _Lb2dd__nfa_patch_bb6 // branch
_Lb2dd__nfa_patch_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__nfa_patch_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #272 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _frag_dangle
    .p2align 2
_frag_dangle:
    .loc 1 347 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #144 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__frag_dangle_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__frag_dangle_bb1 // branch
_Lb2dd__frag_dangle_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__frag_dangle_bb3 // br_cond: !payload -> else
    b _Lb2dd__frag_dangle_bb2 // branch -> then
_Lb2dd__frag_dangle_bb2:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #96] // hv load L6
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__frag_dangle_bb1 // branch
_Lb2dd__frag_dangle_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #144 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _concat_int
    .p2align 2
_concat_int:
    .loc 1 355 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #256 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd__concat_int_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__concat_int_bb1 // branch
_Lb2dd__concat_int_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #80] // hv load L5
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__concat_int_bb3 // br_cond: !payload -> else
    b _Lb2dd__concat_int_bb2 // branch -> then
_Lb2dd__concat_int_bb2:
    ldp x9, x10, [sp, #64] // hv load L4
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__concat_int_bb1 // branch
_Lb2dd__concat_int_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__concat_int_bb4 // branch
_Lb2dd__concat_int_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd__concat_int_bb6 // br_cond: !payload -> else
    b _Lb2dd__concat_int_bb5 // branch -> then
_Lb2dd__concat_int_bb5:
    ldp x9, x10, [sp, #160] // hv load L10
    ldp x0, x1, [sp, #16] // hv load L1
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__concat_int_bb4 // branch
_Lb2dd__concat_int_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #256 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_compile_node
    .p2align 2
_re_compile_node:
    .loc 1 365 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #2224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__re_compile_node_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__re_compile_node_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb1 // branch -> then
_Lb2dd__re_compile_node_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #144] // hv load L9
    bl _nfa_new // call _nfa_new
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #208] // hv store L13
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv reload L14
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv reload L14
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb2:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__re_compile_node_bb4 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb3 // branch -> then
_Lb2dd__re_compile_node_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #320] // hv store L20
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv reload L21
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv reload L21
    ldp x2, x3, [sp, #320] // hv load L20
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb4:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd__re_compile_node_bb6 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb5 // branch -> then
_Lb2dd__re_compile_node_bb5:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    ldp x4, x5, [sp, #384] // hv load L24
    bl _nfa_new // call _nfa_new
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #448] // hv store L28
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv reload L29
    ldp x2, x3, [sp, #416] // hv load L26
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv reload L29
    ldp x2, x3, [sp, #448] // hv load L28
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb6:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd__re_compile_node_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb7 // branch -> then
_Lb2dd__re_compile_node_bb7:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    bl hexa_array_new // array_lit: new array
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv reload L36
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv reload L36
    add x15, sp, #560 // hv frame base
    ldp x2, x3, [x15] // hv load L35
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb8:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__re_compile_node_bb10 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb9 // branch -> then
_Lb2dd__re_compile_node_bb9:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    bl hexa_array_new // array_lit: new array
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv reload L43
    add x15, sp, #640 // hv frame base
    ldp x2, x3, [x15] // hv load L40
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv reload L43
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb10:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd__re_compile_node_bb12 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb11 // branch -> then
_Lb2dd__re_compile_node_bb11:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    bl hexa_array_new // array_lit: new array
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv reload L52
    add x15, sp, #752 // hv frame base
    ldp x2, x3, [x15] // hv load L47
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv reload L52
    add x15, sp, #784 // hv frame base
    ldp x2, x3, [x15] // hv load L49
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv reload L52
    add x15, sp, #816 // hv frame base
    ldp x2, x3, [x15] // hv load L51
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb12:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _Lb2dd__re_compile_node_bb14 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb13 // branch -> then
_Lb2dd__re_compile_node_bb13:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #880 // hv frame base
    ldp x4, x5, [x15] // hv load L55
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #928 // hv frame base
    ldp x4, x5, [x15] // hv load L58
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #976 // hv frame base
    ldp x2, x3, [x15] // hv load L61
    add x15, sp, #992 // hv frame base
    ldp x4, x5, [x15] // hv load L62
    bl _nfa_patch // call _nfa_patch
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv reload L65
    add x15, sp, #1024 // hv frame base
    ldp x2, x3, [x15] // hv load L64
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #1056 // hv frame base
    ldp x2, x3, [x15] // hv load L66
    bl _concat_int // call _concat_int
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb14:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #7 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    cbz x1, _Lb2dd__re_compile_node_bb16 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb15 // branch -> then
_Lb2dd__re_compile_node_bb15:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #1120 // hv frame base
    ldp x4, x5, [x15] // hv load L70
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #1168 // hv frame base
    ldp x4, x5, [x15] // hv load L73
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    add x15, sp, #1264 // hv frame base
    ldp x4, x5, [x15] // hv load L79
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    add x15, sp, #1296 // hv frame base
    ldp x4, x5, [x15] // hv load L81
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv reload L82
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #1344 // hv frame base
    ldp x2, x3, [x15] // hv load L84
    bl _concat_int // call _concat_int
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    add x15, sp, #1360 // hv frame base
    ldp x2, x3, [x15] // hv load L85
    bl _concat_int // call _concat_int
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb16:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    cbz x1, _Lb2dd__re_compile_node_bb18 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb17 // branch -> then
_Lb2dd__re_compile_node_bb17:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #1424 // hv frame base
    ldp x4, x5, [x15] // hv load L89
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    add x15, sp, #1488 // hv frame base
    ldp x2, x3, [x15] // hv load L93
    add x15, sp, #1520 // hv frame base
    ldp x4, x5, [x15] // hv load L95
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #1536 // hv frame base
    stp x0, x1, [x15] // hv store L96
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1536 // hv frame base
    ldp x2, x3, [x15] // hv load L96
    add x15, sp, #1488 // hv frame base
    ldp x4, x5, [x15] // hv load L93
    bl _nfa_patch // call _nfa_patch
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv reload L100
    add x15, sp, #1488 // hv frame base
    ldp x2, x3, [x15] // hv load L93
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv reload L100
    add x15, sp, #1584 // hv frame base
    ldp x2, x3, [x15] // hv load L99
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb18:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1616 // hv frame base
    stp x0, x1, [x15] // hv store L101
    add x15, sp, #1616 // hv frame base
    ldp x0, x1, [x15] // hv load L101
    cbz x1, _Lb2dd__re_compile_node_bb20 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb19 // branch -> then
_Lb2dd__re_compile_node_bb19:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #1648 // hv frame base
    ldp x4, x5, [x15] // hv load L103
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1744 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L108
    add x15, sp, #1712 // hv frame base
    ldp x2, x3, [x15] // hv load L107
    add x15, sp, #1744 // hv frame base
    ldp x4, x5, [x15] // hv load L109
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #1760 // hv frame base
    stp x0, x1, [x15] // hv store L110
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1760 // hv frame base
    ldp x2, x3, [x15] // hv load L110
    add x15, sp, #1712 // hv frame base
    ldp x4, x5, [x15] // hv load L107
    bl _nfa_patch // call _nfa_patch
    add x15, sp, #1776 // hv frame base
    stp x0, x1, [x15] // hv store L111
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1712 // hv frame base
    ldp x0, x1, [x15] // hv load L107
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #1808 // hv frame base
    stp x0, x1, [x15] // hv store L113
    add x15, sp, #1808 // hv frame base
    ldp x0, x1, [x15] // hv load L113
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    bl hexa_array_new // array_lit: new array
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv reload L115
    add x15, sp, #1792 // hv frame base
    ldp x2, x3, [x15] // hv load L112
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv reload L115
    add x15, sp, #1824 // hv frame base
    ldp x2, x3, [x15] // hv load L114
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb20:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    cbz x1, _Lb2dd__re_compile_node_bb22 // br_cond: !payload -> else
    b _Lb2dd__re_compile_node_bb21 // branch -> then
_Lb2dd__re_compile_node_bb21:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L118
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x15, sp, #1888 // hv frame base
    ldp x4, x5, [x15] // hv load L118
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #1904 // hv frame base
    stp x0, x1, [x15] // hv store L119
    add x15, sp, #1904 // hv frame base
    ldp x0, x1, [x15] // hv load L119
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #1984 // hv frame base
    stp x0, x1, [x15] // hv store L124
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    add x15, sp, #1952 // hv frame base
    ldp x2, x3, [x15] // hv load L122
    add x15, sp, #1984 // hv frame base
    ldp x4, x5, [x15] // hv load L124
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv reload L125
    add x15, sp, #1952 // hv frame base
    ldp x2, x3, [x15] // hv load L122
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #2032 // hv frame base
    stp x0, x1, [x15] // hv store L127
    add x15, sp, #2032 // hv frame base
    ldp x0, x1, [x15] // hv load L127
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    add x15, sp, #2064 // hv frame base
    ldp x0, x1, [x15] // hv reload L129
    add x15, sp, #2048 // hv frame base
    ldp x2, x3, [x15] // hv load L128
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    add x15, sp, #2064 // hv frame base
    ldp x2, x3, [x15] // hv load L129
    bl _concat_int // call _concat_int
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    add x15, sp, #2080 // hv frame base
    ldp x2, x3, [x15] // hv load L130
    bl _concat_int // call _concat_int
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_compile_node_bb22:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L132
    add x15, sp, #2112 // hv frame base
    ldp x0, x1, [x15] // hv load L132
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv load L133
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv load L133
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #2176 // hv frame base
    stp x0, x1, [x15] // hv store L136
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    bl hexa_array_new // array_lit: new array
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv reload L138
    add x15, sp, #2128 // hv frame base
    ldp x2, x3, [x15] // hv load L133
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv reload L138
    add x15, sp, #2160 // hv frame base
    ldp x2, x3, [x15] // hv load L135
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv reload L138
    add x15, sp, #2192 // hv frame base
    ldp x2, x3, [x15] // hv load L137
    bl hexa_array_push // array_lit: push elem 2
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv load L138
    add sp, sp, #2224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_bad
    .p2align 2
_re_bad:
    .loc 1 416 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
_Lb2dd__re_bad_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #0] // hv store L0
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #64] // hv store L4
    bl bt_empty // call bt_empty
    stp x0, x1, [sp, #80] // hv store L5
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    movz x3, #2 // hv const_bool: TAG_BOOL
    movz x4, #0 // hv const_bool payload
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr18@PAGE // cstr key page
    add x2, x2, .LCstr18@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // imm 0-15
    mvn x4, x4 // hv const_int: negate
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr19@PAGE // cstr key page
    add x2, x2, .LCstr19@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #0] // hv load L0
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #16] // hv load L1
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #32] // hv load L2
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #48] // hv load L3
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #64] // hv load L4
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv reload L6
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #80] // hv load L5
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_from_bt
    .p2align 2
_re_from_bt:
    .loc 1 421 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #176 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_from_bt_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd__re_from_bt_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_from_bt_bb1 // branch -> then
_Lb2dd__re_from_bt_bb1:
    bl _re_bad // call _re_bad
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_from_bt_bb2:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #96] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    movz x3, #2 // hv const_bool: TAG_BOOL
    movz x4, #1 // hv const_bool payload
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr18@PAGE // cstr key page
    add x2, x2, .LCstr18@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // imm 0-15
    mvn x4, x4 // hv const_int: negate
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr19@PAGE // cstr key page
    add x2, x2, .LCstr19@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #80] // hv load L5
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #96] // hv load L6
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #112] // hv load L7
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #128] // hv load L8
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #144] // hv load L9
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #1 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv reload L10
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #0] // hv load L0
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_compile
    .p2align 2
regex_compile:
    .loc 1 427 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #48 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_regex_compile_bb0:
    bl _REGEX_DEFAULT_STEP_CAP // call _REGEX_DEFAULT_STEP_CAP
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl regex_compile_capped // call regex_compile_capped
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #48 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_compile_capped
    .p2align 2
regex_compile_capped:
    .loc 1 436 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #784 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_compile_capped_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl bt_needs_backtrack // call bt_needs_backtrack
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd_regex_compile_capped_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_compile_capped_bb1 // branch -> then
_Lb2dd_regex_compile_capped_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_compile // call bt_compile
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl _re_from_bt // call _re_from_bt
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_compile_capped_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #96] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv reload L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #112] // hv store L7
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv reload L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #128] // hv store L8
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #144] // hv store L9
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #160] // hv store L10
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr2@PAGE // cstr key page
    add x2, x2, .LCstr2@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #0] // hv load L0
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #96] // hv load L6
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #112] // hv load L7
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #128] // hv load L8
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #144] // hv load L9
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #160] // hv load L10
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    bl _re_parse_alt // call _re_parse_alt
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #192] // hv load L12
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd_regex_compile_capped_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_compile_capped_bb3 // branch -> then
_Lb2dd_regex_compile_capped_bb3:
    bl _re_bad // call _re_bad
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_compile_capped_bb4:
    ldp x0, x1, [sp, #192] // hv load L12
    adrp x2, .LCstr0@PAGE // cstr key page
    add x2, x2, .LCstr0@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #192] // hv load L12
    adrp x2, .LCstr1@PAGE // cstr key page
    add x2, x2, .LCstr1@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #352] // hv load L22
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd_regex_compile_capped_bb6 // br_cond: !payload -> else
    b _Lb2dd_regex_compile_capped_bb5 // branch -> then
_Lb2dd_regex_compile_capped_bb5:
    bl _re_bad // call _re_bad
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_compile_capped_bb6:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #416] // hv store L26
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #432] // hv store L27
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #448] // hv store L28
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #464] // hv store L29
    bl hexa_map_new // struct_lit: new map
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #416] // hv load L26
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #432] // hv load L27
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #448] // hv load L28
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    ldp x3, x4, [sp, #464] // hv load L29
    bl hexa_map_set // struct_lit: set field
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #192] // hv load L12
    adrp x2, .LCstr3@PAGE // cstr key page
    add x2, x2, .LCstr3@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    ldp x4, x5, [sp, #224] // hv load L14
    bl _re_compile_node // call _re_compile_node
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl _nfa_new // call _nfa_new
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    bl _frag_dangle // call _frag_dangle
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #592 // hv frame base
    ldp x2, x3, [x15] // hv load L37
    add x15, sp, #576 // hv frame base
    ldp x4, x5, [x15] // hv load L36
    bl _nfa_patch // call _nfa_patch
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    ldp x0, x1, [sp, #496] // hv load L31
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    ldp x0, x1, [sp, #496] // hv load L31
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    ldp x0, x1, [sp, #496] // hv load L31
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    ldp x0, x1, [sp, #496] // hv load L31
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    ldp x0, x1, [sp, #496] // hv load L31
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    ldp x0, x1, [sp, #192] // hv load L12
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    bl bt_empty // call bt_empty
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    bl hexa_map_new // struct_lit: new map
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    movz x3, #2 // hv const_bool: TAG_BOOL
    movz x4, #1 // hv const_bool payload
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr18@PAGE // cstr key page
    add x2, x2, .LCstr18@PAGEOFF // cstr key off
    add x15, sp, #624 // hv frame base
    ldp x3, x4, [x15] // hv load L39
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr19@PAGE // cstr key page
    add x2, x2, .LCstr19@PAGEOFF // cstr key off
    add x15, sp, #656 // hv frame base
    ldp x3, x4, [x15] // hv load L41
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    add x15, sp, #672 // hv frame base
    ldp x3, x4, [x15] // hv load L42
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    add x15, sp, #688 // hv frame base
    ldp x3, x4, [x15] // hv load L43
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    add x15, sp, #704 // hv frame base
    ldp x3, x4, [x15] // hv load L44
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    add x15, sp, #720 // hv frame base
    ldp x3, x4, [x15] // hv load L45
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    add x15, sp, #736 // hv frame base
    ldp x3, x4, [x15] // hv load L46
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #0 // hv const_int val
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv reload L48
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    add x15, sp, #752 // hv frame base
    ldp x3, x4, [x15] // hv load L47
    bl hexa_map_set // struct_lit: set field
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_compile_captures
    .p2align 2
regex_compile_captures:
    .loc 1 484 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #48 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_regex_compile_captures_bb0:
    bl _REGEX_DEFAULT_STEP_CAP // call _REGEX_DEFAULT_STEP_CAP
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl regex_compile_captures_capped // call regex_compile_captures_capped
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #48 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_compile_captures_capped
    .p2align 2
regex_compile_captures_capped:
    .loc 1 489 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #64 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_compile_captures_capped_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_compile // call bt_compile
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    bl _re_from_bt // call _re_from_bt
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #64 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_captures
    .p2align 2
regex_captures:
    .loc 1 498 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_captures_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_regex_captures_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_captures_bb1 // branch -> then
_Lb2dd_regex_captures_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_captures_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd_regex_captures_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_captures_bb3 // branch -> then
_Lb2dd_regex_captures_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_search_captures // call bt_search_captures
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_captures_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl regex_search // call regex_search
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_regex_captures_bb6 // br_cond: !payload -> else
    b _Lb2dd_regex_captures_bb5 // branch -> then
_Lb2dd_regex_captures_bb5:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_captures_bb6:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #192] // hv load L12
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #272] // hv store L17
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #192] // hv load L12
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #288] // hv store L18
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_cap_count
    .p2align 2
regex_cap_count:
    .loc 1 508 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #48 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_regex_cap_count_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #48 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_cap_span
    .p2align 2
regex_cap_span:
    .loc 1 514 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #368 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_cap_span_bb0:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_mul // binop *
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_regex_cap_span_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_cap_span_bb1 // branch -> then
_Lb2dd_regex_cap_span_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd_regex_cap_span_bb3 // branch
_Lb2dd_regex_cap_span_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd_regex_cap_span_bb3 // branch
_Lb2dd_regex_cap_span_bb3:
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_regex_cap_span_bb5 // br_cond: !payload -> else
    b _Lb2dd_regex_cap_span_bb4 // branch -> then
_Lb2dd_regex_cap_span_bb4:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_cap_span_bb5:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd_regex_cap_span_bb7 // br_cond: !payload -> else
    b _Lb2dd_regex_cap_span_bb6 // branch -> then
_Lb2dd_regex_cap_span_bb6:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd_regex_cap_span_bb8 // branch
_Lb2dd_regex_cap_span_bb7:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L14
    ldp x9, x10, [sp, #224] // hv load L14
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd_regex_cap_span_bb8 // branch
_Lb2dd_regex_cap_span_bb8:
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd_regex_cap_span_bb10 // br_cond: !payload -> else
    b _Lb2dd_regex_cap_span_bb9 // branch -> then
_Lb2dd_regex_cap_span_bb9:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_cap_span_bb10:
    ldp x9, x10, [sp, #48] // hv load L3
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #320] // hv store L20
    ldp x9, x10, [sp, #320] // hv load L20
    ldp x0, x1, [sp, #0] // hv load L0
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #336] // hv store L21
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv reload L22
    ldp x2, x3, [sp, #304] // hv load L19
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv reload L22
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_cap_text
    .p2align 2
regex_cap_text:
    .loc 1 523 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #176 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd_regex_cap_text_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #32] // hv load L2
    bl regex_cap_span // call regex_cap_span
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd_regex_cap_text_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_cap_text_bb1 // branch -> then
_Lb2dd_regex_cap_text_bb1:
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr24@PAGE // hv str ptr page
    add x1, x1, .LCstr24@PAGEOFF // hv str ptr off
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_cap_text_bb2:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #64] // hv load L4
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L8
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #64] // hv load L4
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #16] // hv load L1
    ldp x2, x3, [sp, #128] // hv load L8
    ldp x4, x5, [sp, #144] // hv load L9
    bl hexa_str_substring // call hexa_str_substring
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_class_match
    .p2align 2
_re_class_match:
    .loc 1 543 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #368 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd__re_class_match_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #112] // hv store L7
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__re_class_match_bb1 // branch
_Lb2dd__re_class_match_bb1:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #160] // hv load L10
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _Lb2dd__re_class_match_bb3 // br_cond: !payload -> else
    b _Lb2dd__re_class_match_bb2 // branch -> then
_Lb2dd__re_class_match_bb2:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #112] // hv load L7
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__re_class_match_bb5 // br_cond: !payload -> else
    b _Lb2dd__re_class_match_bb4 // branch -> then
_Lb2dd__re_class_match_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__re_class_match_bb10 // br_cond: !payload -> else
    b _Lb2dd__re_class_match_bb9 // branch -> then
_Lb2dd__re_class_match_bb4:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #240] // hv load L15
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__re_class_match_bb6 // branch
_Lb2dd__re_class_match_bb5:
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd__re_class_match_bb6 // branch
_Lb2dd__re_class_match_bb6:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd__re_class_match_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_class_match_bb7 // branch -> then
_Lb2dd__re_class_match_bb7:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd__re_class_match_bb8 // branch
_Lb2dd__re_class_match_bb8:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__re_class_match_bb1 // branch
_Lb2dd__re_class_match_bb9:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_class_match_bb10:
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #368 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_zeros
    .p2align 2
_re_zeros:
    .loc 1 557 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__re_zeros_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__re_zeros_bb1 // branch
_Lb2dd__re_zeros_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__re_zeros_bb3 // br_cond: !payload -> else
    b _Lb2dd__re_zeros_bb2 // branch -> then
_Lb2dd__re_zeros_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__re_zeros_bb1 // branch
_Lb2dd__re_zeros_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_add
    .p2align 2
_re_add:
    .loc 1 566 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #720 // sp adj
    stp x0, x1, [sp, #64] // ingress param 0
    stp x2, x3, [sp, #80] // ingress param 1
    stp x4, x5, [sp, #96] // ingress param 2
    stp x6, x7, [sp, #112] // ingress param 3
    ldp x9, x10, [x29, #16] // ingress stack param 4
    stp x9, x10, [sp, #128] // store stack param 4
    ldp x9, x10, [x29, #32] // ingress stack param 5
    stp x9, x10, [sp, #144] // store stack param 5
    ldp x9, x10, [x29, #48] // ingress stack param 6
    stp x9, x10, [sp, #160] // store stack param 6
    ldp x9, x10, [x29, #64] // ingress stack param 7
    stp x9, x10, [sp, #176] // store stack param 7
_Lb2dd__re_add_bb0:
    ldp x0, x1, [sp, #144] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L8
    ldp x0, x1, [sp, #192] // hv load L8
    cbz x1, _Lb2dd__re_add_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb1 // branch -> then
_Lb2dd__re_add_bb1:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb2:
    ldp x9, x10, [sp, #144] // hv load L5
    ldp x0, x1, [sp, #96] // hv load L2
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    stp x0, x1, [sp, #224] // hv store L10
    ldp x0, x1, [sp, #224] // hv load L10
    ldp x2, x3, [sp, #112] // hv load L3
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L11
    ldp x0, x1, [sp, #240] // hv load L11
    cbz x1, _Lb2dd__re_add_bb4 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb3 // branch -> then
_Lb2dd__re_add_bb3:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb4:
    ldp x9, x10, [sp, #144] // hv load L5
    ldp x3, x4, [sp, #112] // hv load L3
    ldp x0, x1, [sp, #96] // hv load L2
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #96] // hv store L2
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #272] // hv store L13
    ldp x0, x1, [sp, #272] // hv load L13
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #288] // hv store L14
    ldp x0, x1, [sp, #288] // hv load L14
    stp x0, x1, [sp, #304] // hv store L15
    ldp x0, x1, [sp, #304] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L16
    ldp x0, x1, [sp, #320] // hv load L16
    cbz x1, _Lb2dd__re_add_bb6 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb5 // branch -> then
_Lb2dd__re_add_bb5:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #352] // hv store L18
    ldp x0, x1, [sp, #352] // hv load L18
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #368] // hv store L19
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #80] // hv load L1
    ldp x4, x5, [sp, #96] // hv load L2
    ldp x6, x7, [sp, #112] // hv load L3
    ldp x9, x10, [sp, #128] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #368] // hv load L19
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #160] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #176] // hv load L7
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    stp x0, x1, [sp, #384] // hv store L20
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr16@PAGE // cstr key page
    add x2, x2, .LCstr16@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #400] // hv store L21
    ldp x0, x1, [sp, #400] // hv load L21
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L22
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #80] // hv load L1
    ldp x4, x5, [sp, #96] // hv load L2
    ldp x6, x7, [sp, #112] // hv load L3
    ldp x9, x10, [sp, #128] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #416] // hv load L22
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #160] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #176] // hv load L7
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    stp x0, x1, [sp, #432] // hv store L23
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb6:
    ldp x0, x1, [sp, #304] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L24
    ldp x0, x1, [sp, #448] // hv load L24
    cbz x1, _Lb2dd__re_add_bb8 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb7 // branch -> then
_Lb2dd__re_add_bb7:
    ldp x0, x1, [sp, #160] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L26
    ldp x0, x1, [sp, #480] // hv load L26
    cbz x1, _Lb2dd__re_add_bb10 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb9 // branch -> then
_Lb2dd__re_add_bb8:
    ldp x0, x1, [sp, #304] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #6 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    cbz x1, _Lb2dd__re_add_bb12 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb11 // branch -> then
_Lb2dd__re_add_bb9:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L28
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L28
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L29
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #80] // hv load L1
    ldp x4, x5, [sp, #96] // hv load L2
    ldp x6, x7, [sp, #112] // hv load L3
    ldp x9, x10, [sp, #128] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #528 // hv frame base
    ldp x9, x10, [x15] // hv load L29
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #160] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #176] // hv load L7
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L30
    b _Lb2dd__re_add_bb10 // branch
_Lb2dd__re_add_bb10:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb11:
    ldp x0, x1, [sp, #160] // hv load L6
    ldp x2, x3, [sp, #176] // hv load L7
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd__re_add_bb14 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb13 // branch -> then
_Lb2dd__re_add_bb12:
    ldp x0, x1, [sp, #304] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _Lb2dd__re_add_bb16 // br_cond: !payload -> else
    b _Lb2dd__re_add_bb15 // branch -> then
_Lb2dd__re_add_bb13:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #80] // hv load L1
    ldp x4, x5, [sp, #96] // hv load L2
    ldp x6, x7, [sp, #112] // hv load L3
    ldp x9, x10, [sp, #128] // hv load L4
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #640 // hv frame base
    ldp x9, x10, [x15] // hv load L36
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #160] // hv load L6
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #176] // hv load L7
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L37
    b _Lb2dd__re_add_bb14 // branch
_Lb2dd__re_add_bb14:
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb15:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    movz x3, #0 // hv const_int: TAG_INT
    movz x4, #1 // hv const_int val
    ldp x0, x1, [sp, #128] // hv load L4
    mov x2, x10 // index_set: raw idx payload → x2
    bl hexa_arr_poly_set // index_set: hexa_arr_poly_set (runtime discriminate)
    stp x0, x1, [sp, #128] // hv store L4
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_add_bb16:
    ldp x0, x1, [sp, #80] // hv load L1
    ldp x2, x3, [sp, #144] // hv load L5
    bl hexa_arr_poly_push // call hexa_arr_poly_push
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add sp, sp, #720 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _re_longest_from
    .p2align 2
_re_longest_from:
    .loc 1 593 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1056 // sp adj
    stp x0, x1, [sp, #64] // ingress param 0
    stp x2, x3, [sp, #80] // ingress param 1
    stp x4, x5, [sp, #96] // ingress param 2
    stp x6, x7, [sp, #112] // ingress param 3
_Lb2dd__re_longest_from_bb0:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr19@PAGE // cstr key page
    add x2, x2, .LCstr19@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #128] // hv store L4
    ldp x0, x1, [sp, #128] // hv load L4
    bl _re_zeros // call _re_zeros
    stp x0, x1, [sp, #144] // hv store L5
    ldp x0, x1, [sp, #144] // hv load L5
    stp x0, x1, [sp, #160] // hv store L6
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #176] // hv store L7
    ldp x0, x1, [sp, #176] // hv reload L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #176] // hv store L7
    ldp x0, x1, [sp, #176] // hv load L7
    stp x0, x1, [sp, #192] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #208] // hv store L9
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #224] // hv store L10
    ldp x0, x1, [sp, #224] // hv load L10
    stp x0, x1, [sp, #240] // hv store L11
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr18@PAGE // cstr key page
    add x2, x2, .LCstr18@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #256] // hv store L12
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #240] // hv load L11
    ldp x4, x5, [sp, #160] // hv load L6
    ldp x6, x7, [sp, #208] // hv load L9
    ldp x9, x10, [sp, #192] // hv load L8
    stp x9, x10, [sp, #0] // C7: stack arg 4
    ldp x9, x10, [sp, #256] // hv load L12
    stp x9, x10, [sp, #16] // C7: stack arg 5
    ldp x9, x10, [sp, #96] // hv load L2
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #112] // hv load L3
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    stp x0, x1, [sp, #272] // hv store L13
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #288] // hv store L14
    ldp x0, x1, [sp, #192] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #304] // hv store L15
    ldp x0, x1, [sp, #304] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L16
    ldp x0, x1, [sp, #320] // hv load L16
    cbz x1, _Lb2dd__re_longest_from_bb2 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb1 // branch -> then
_Lb2dd__re_longest_from_bb1:
    ldp x0, x1, [sp, #96] // hv load L2
    stp x0, x1, [sp, #288] // hv store L14
    b _Lb2dd__re_longest_from_bb2 // branch
_Lb2dd__re_longest_from_bb2:
    ldp x0, x1, [sp, #96] // hv load L2
    stp x0, x1, [sp, #352] // hv store L18
    b _Lb2dd__re_longest_from_bb3 // branch
_Lb2dd__re_longest_from_bb3:
    ldp x0, x1, [sp, #352] // hv load L18
    ldp x2, x3, [sp, #112] // hv load L3
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #368] // hv store L19
    ldp x0, x1, [sp, #368] // hv load L19
    cbz x1, _Lb2dd__re_longest_from_bb7 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb6 // branch -> then
_Lb2dd__re_longest_from_bb4:
    ldp x0, x1, [sp, #80] // hv load L1
    ldp x2, x3, [sp, #352] // hv load L18
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #432] // hv store L23
    ldp x0, x1, [sp, #432] // hv load L23
    stp x0, x1, [sp, #448] // hv store L24
    ldp x0, x1, [sp, #208] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #464] // hv store L25
    ldp x0, x1, [sp, #464] // hv load L25
    stp x0, x1, [sp, #208] // hv store L9
    ldp x0, x1, [sp, #192] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    stp x0, x1, [sp, #192] // hv store L8
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #480] // hv store L26
    ldp x0, x1, [sp, #480] // hv load L26
    stp x0, x1, [sp, #496] // hv store L27
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L28
    b _Lb2dd__re_longest_from_bb9 // branch
_Lb2dd__re_longest_from_bb5:
    ldp x0, x1, [sp, #288] // hv load L14
    add sp, sp, #1056 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__re_longest_from_bb6:
    ldp x0, x1, [sp, #240] // hv load L11
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #400] // hv store L21
    ldp x0, x1, [sp, #400] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #416] // hv store L22
    ldp x0, x1, [sp, #416] // hv load L22
    stp x0, x1, [sp, #384] // hv store L20
    b _Lb2dd__re_longest_from_bb8 // branch
_Lb2dd__re_longest_from_bb7:
    ldp x0, x1, [sp, #368] // hv load L19
    stp x0, x1, [sp, #384] // hv store L20
    b _Lb2dd__re_longest_from_bb8 // branch
_Lb2dd__re_longest_from_bb8:
    ldp x0, x1, [sp, #384] // hv load L20
    cbz x1, _Lb2dd__re_longest_from_bb5 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb4 // branch -> then
_Lb2dd__re_longest_from_bb9:
    ldp x0, x1, [sp, #240] // hv load L11
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L29
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L28
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L29
    bl hexa_cmp_lt // binop <
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L30
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L30
    cbz x1, _Lb2dd__re_longest_from_bb11 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb10 // branch -> then
_Lb2dd__re_longest_from_bb10:
    ldp x0, x1, [sp, #240] // hv load L11
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L28
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L31
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr13@PAGE // cstr key page
    add x2, x2, .LCstr13@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L35
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd__re_longest_from_bb13 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb12 // branch -> then
_Lb2dd__re_longest_from_bb11:
    ldp x0, x1, [sp, #496] // hv load L27
    stp x0, x1, [sp, #240] // hv store L11
    ldp x0, x1, [sp, #352] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    stp x0, x1, [sp, #352] // hv store L18
    ldp x0, x1, [sp, #192] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    cbz x1, _Lb2dd__re_longest_from_bb27 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb26 // branch -> then
_Lb2dd__re_longest_from_bb12:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    ldp x2, x3, [sp, #448] // hv load L24
    bl hexa_eq // binop ==
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _Lb2dd__re_longest_from_bb15 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb14 // branch -> then
_Lb2dd__re_longest_from_bb13:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _Lb2dd__re_longest_from_bb17 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb16 // branch -> then
_Lb2dd__re_longest_from_bb14:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd__re_longest_from_bb15 // branch
_Lb2dd__re_longest_from_bb15:
    b _Lb2dd__re_longest_from_bb23 // branch
_Lb2dd__re_longest_from_bb16:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd__re_longest_from_bb22 // branch
_Lb2dd__re_longest_from_bb17:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    cbz x1, _Lb2dd__re_longest_from_bb19 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb18 // branch -> then
_Lb2dd__re_longest_from_bb18:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr4@PAGE // cstr key page
    add x2, x2, .LCstr4@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L47
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr14@PAGE // cstr key page
    add x2, x2, .LCstr14@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L49
    ldp x4, x5, [sp, #448] // hv load L24
    bl _re_class_match // call _re_class_match
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _Lb2dd__re_longest_from_bb21 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb20 // branch -> then
_Lb2dd__re_longest_from_bb19:
    b _Lb2dd__re_longest_from_bb22 // branch
_Lb2dd__re_longest_from_bb20:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd__re_longest_from_bb21 // branch
_Lb2dd__re_longest_from_bb21:
    b _Lb2dd__re_longest_from_bb19 // branch
_Lb2dd__re_longest_from_bb22:
    b _Lb2dd__re_longest_from_bb23 // branch
_Lb2dd__re_longest_from_bb23:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _Lb2dd__re_longest_from_bb25 // br_cond: !payload -> else
    b _Lb2dd__re_longest_from_bb24 // branch -> then
_Lb2dd__re_longest_from_bb24:
    ldp x0, x1, [sp, #64] // hv load L0
    adrp x2, .LCstr15@PAGE // cstr key page
    add x2, x2, .LCstr15@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L54
    ldp x0, x1, [sp, #352] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #64] // hv load L0
    ldp x2, x3, [sp, #496] // hv load L27
    ldp x4, x5, [sp, #160] // hv load L6
    ldp x6, x7, [sp, #208] // hv load L9
    ldp x9, x10, [sp, #192] // hv load L8
    stp x9, x10, [sp, #0] // C7: stack arg 4
    add x15, sp, #928 // hv frame base
    ldp x9, x10, [x15] // hv load L54
    stp x9, x10, [sp, #16] // C7: stack arg 5
    add x15, sp, #944 // hv frame base
    ldp x9, x10, [x15] // hv load L55
    stp x9, x10, [sp, #32] // C7: stack arg 6
    ldp x9, x10, [sp, #112] // hv load L3
    stp x9, x10, [sp, #48] // C7: stack arg 7
    bl _re_add // call _re_add
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L56
    b _Lb2dd__re_longest_from_bb25 // branch
_Lb2dd__re_longest_from_bb25:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L28
    b _Lb2dd__re_longest_from_bb9 // branch
_Lb2dd__re_longest_from_bb26:
    ldp x0, x1, [sp, #352] // hv load L18
    stp x0, x1, [sp, #288] // hv store L14
    b _Lb2dd__re_longest_from_bb27 // branch
_Lb2dd__re_longest_from_bb27:
    b _Lb2dd__re_longest_from_bb3 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1056 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_valid
    .p2align 2
regex_valid:
    .loc 1 630 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #32 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_regex_valid_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #32 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_last_error
    .p2align 2
regex_last_error:
    .loc 1 638 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd_regex_last_error_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd_regex_last_error_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_last_error_bb1 // branch -> then
_Lb2dd_regex_last_error_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    adrp x2, .LCstr11@PAGE // cstr key page
    add x2, x2, .LCstr11@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_last_error_bb2:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_match
    .p2align 2
regex_match:
    .loc 1 645 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #224 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_match_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_regex_match_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_match_bb1 // branch -> then
_Lb2dd_regex_match_bb1:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_match_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd_regex_match_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_match_bb3 // branch -> then
_Lb2dd_regex_match_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_match_full // call bt_match_full
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_match_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    ldp x6, x7, [sp, #176] // hv load L11
    bl _re_longest_from // call _re_longest_from
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    ldp x2, x3, [sp, #176] // hv load L11
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #224 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_search
    .p2align 2
regex_search:
    .loc 1 655 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #352 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_search_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_regex_search_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_search_bb1 // branch -> then
_Lb2dd_regex_search_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd_regex_search_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_search_bb3 // branch -> then
_Lb2dd_regex_search_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_search // call bt_search
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd_regex_search_bb5 // branch
_Lb2dd_regex_search_bb5:
    ldp x0, x1, [sp, #208] // hv load L13
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_regex_search_bb7 // br_cond: !payload -> else
    b _Lb2dd_regex_search_bb6 // branch -> then
_Lb2dd_regex_search_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #208] // hv load L13
    ldp x6, x7, [sp, #192] // hv load L12
    bl _re_longest_from // call _re_longest_from
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd_regex_search_bb9 // br_cond: !payload -> else
    b _Lb2dd_regex_search_bb8 // branch -> then
_Lb2dd_regex_search_bb7:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_bb8:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_bb9:
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd_regex_search_bb5 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_find_all
    .p2align 2
regex_find_all:
    .loc 1 671 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #416 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_regex_find_all_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_regex_find_all_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_find_all_bb1 // branch -> then
_Lb2dd_regex_find_all_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_find_all_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    cbz x1, _Lb2dd_regex_find_all_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_find_all_bb3 // branch -> then
_Lb2dd_regex_find_all_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    ldp x2, x3, [sp, #16] // hv load L1
    bl bt_find_all // call bt_find_all
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_find_all_bb4:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd_regex_find_all_bb5 // branch
_Lb2dd_regex_find_all_bb5:
    ldp x0, x1, [sp, #224] // hv load L14
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd_regex_find_all_bb7 // br_cond: !payload -> else
    b _Lb2dd_regex_find_all_bb6 // branch -> then
_Lb2dd_regex_find_all_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #224] // hv load L14
    ldp x6, x7, [sp, #208] // hv load L13
    bl _re_longest_from // call _re_longest_from
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd_regex_find_all_bb9 // br_cond: !payload -> else
    b _Lb2dd_regex_find_all_bb8 // branch -> then
_Lb2dd_regex_find_all_bb7:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_find_all_bb8:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv reload L20
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #320] // hv load L20
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #272] // hv load L17
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd_regex_find_all_bb11 // br_cond: !payload -> else
    b _Lb2dd_regex_find_all_bb10 // branch -> then
_Lb2dd_regex_find_all_bb9:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd_regex_find_all_bb13 // branch
_Lb2dd_regex_find_all_bb10:
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd_regex_find_all_bb12 // branch
_Lb2dd_regex_find_all_bb11:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #224] // hv store L14
    b _Lb2dd_regex_find_all_bb12 // branch
_Lb2dd_regex_find_all_bb12:
    b _Lb2dd_regex_find_all_bb13 // branch
_Lb2dd_regex_find_all_bb13:
    b _Lb2dd_regex_find_all_bb5 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #416 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden regex_search_from
    .p2align 2
regex_search_from:
    .loc 1 704 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #528 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
    stp x6, x7, [sp, #48] // ingress param 3
_Lb2dd_regex_search_from_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr5@PAGE // cstr key page
    add x2, x2, .LCstr5@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_regex_search_from_bb2 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb1 // branch -> then
_Lb2dd_regex_search_from_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_from_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd_regex_search_from_bb4 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb3 // branch -> then
_Lb2dd_regex_search_from_bb3:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_from_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr20@PAGE // cstr key page
    add x2, x2, .LCstr20@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_regex_search_from_bb6 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb5 // branch -> then
_Lb2dd_regex_search_from_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    adrp x2, .LCstr21@PAGE // cstr key page
    add x2, x2, .LCstr21@PAGEOFF // cstr key off
    bl hexa_map_get // field: hexa_map_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #32] // hv load L2
    bl bt_search_from // call bt_search_from
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_from_bb6:
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd_regex_search_from_bb7 // branch
_Lb2dd_regex_search_from_bb7:
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _Lb2dd_regex_search_from_bb9 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb8 // branch -> then
_Lb2dd_regex_search_from_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    ldp x4, x5, [sp, #288] // hv load L18
    ldp x6, x7, [sp, #144] // hv load L9
    bl _re_longest_from // call _re_longest_from
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd_regex_search_from_bb11 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb10 // branch -> then
_Lb2dd_regex_search_from_bb9:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_regex_search_from_bb10:
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_regex_search_from_bb13 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb12 // branch -> then
_Lb2dd_regex_search_from_bb11:
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd_regex_search_from_bb7 // branch
_Lb2dd_regex_search_from_bb12:
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd_regex_search_from_bb14 // branch
_Lb2dd_regex_search_from_bb13:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd_regex_search_from_bb14 // branch
_Lb2dd_regex_search_from_bb14:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd_regex_search_from_bb16 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb15 // branch -> then
_Lb2dd_regex_search_from_bb15:
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #416] // hv store L26
    b _Lb2dd_regex_search_from_bb17 // branch
_Lb2dd_regex_search_from_bb16:
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #416] // hv store L26
    b _Lb2dd_regex_search_from_bb17 // branch
_Lb2dd_regex_search_from_bb17:
    ldp x0, x1, [sp, #416] // hv load L26
    cbz x1, _Lb2dd_regex_search_from_bb19 // br_cond: !payload -> else
    b _Lb2dd_regex_search_from_bb18 // branch -> then
_Lb2dd_regex_search_from_bb18:
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd_regex_search_from_bb7 // branch
_Lb2dd_regex_search_from_bb19:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv reload L30
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    add sp, sp, #528 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_fold_byte
    .p2align 2
_rt_re_fold_byte:
    .loc 1 53 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #96 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_fold_byte_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _Lb2dd__rt_re_fold_byte_bb2 // br_cond: !payload -> else
    b _Lb2dd__rt_re_fold_byte_bb1 // branch -> then
_Lb2dd__rt_re_fold_byte_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__rt_re_fold_byte_bb3 // branch
_Lb2dd__rt_re_fold_byte_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    b _Lb2dd__rt_re_fold_byte_bb3 // branch
_Lb2dd__rt_re_fold_byte_bb3:
    ldp x0, x1, [sp, #32] // hv load L2
    cbz x1, _Lb2dd__rt_re_fold_byte_bb5 // br_cond: !payload -> else
    b _Lb2dd__rt_re_fold_byte_bb4 // branch -> then
_Lb2dd__rt_re_fold_byte_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    add sp, sp, #96 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_fold_byte_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #96 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_ascii_fold
    .p2align 2
_rt_re_ascii_fold:
    .loc 1 61 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #176 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_ascii_fold_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr24@PAGE // hv str ptr page
    add x1, x1, .LCstr24@PAGEOFF // hv str ptr off
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_ascii_fold_bb1 // branch
_Lb2dd__rt_re_ascii_fold_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd__rt_re_ascii_fold_bb3 // br_cond: !payload -> else
    b _Lb2dd__rt_re_ascii_fold_bb2 // branch -> then
_Lb2dd__rt_re_ascii_fold_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    bl _rt_re_fold_byte // call _rt_re_fold_byte
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    bl hexa_chr_byte // call hexa_chr_byte
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_ascii_fold_bb1 // branch
_Lb2dd__rt_re_ascii_fold_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #176 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_strip_iflag
    .p2align 2
_rt_re_strip_iflag:
    .loc 1 76 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #320 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_strip_iflag_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd__rt_re_strip_iflag_bb2 // br_cond: !payload -> else
    b _Lb2dd__rt_re_strip_iflag_bb1 // branch -> then
_Lb2dd__rt_re_strip_iflag_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_strip_iflag_bb3 // branch
_Lb2dd__rt_re_strip_iflag_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_strip_iflag_bb3 // branch
_Lb2dd__rt_re_strip_iflag_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__rt_re_strip_iflag_bb5 // br_cond: !payload -> else
    b _Lb2dd__rt_re_strip_iflag_bb4 // branch -> then
_Lb2dd__rt_re_strip_iflag_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__rt_re_strip_iflag_bb6 // branch
_Lb2dd__rt_re_strip_iflag_bb5:
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #112] // hv store L7
    b _Lb2dd__rt_re_strip_iflag_bb6 // branch
_Lb2dd__rt_re_strip_iflag_bb6:
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__rt_re_strip_iflag_bb8 // br_cond: !payload -> else
    b _Lb2dd__rt_re_strip_iflag_bb7 // branch -> then
_Lb2dd__rt_re_strip_iflag_bb7:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #105 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__rt_re_strip_iflag_bb9 // branch
_Lb2dd__rt_re_strip_iflag_bb8:
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__rt_re_strip_iflag_bb9 // branch
_Lb2dd__rt_re_strip_iflag_bb9:
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__rt_re_strip_iflag_bb11 // br_cond: !payload -> else
    b _Lb2dd__rt_re_strip_iflag_bb10 // branch -> then
_Lb2dd__rt_re_strip_iflag_bb10:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd__rt_re_strip_iflag_bb12 // branch
_Lb2dd__rt_re_strip_iflag_bb11:
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #208] // hv store L13
    b _Lb2dd__rt_re_strip_iflag_bb12 // branch
_Lb2dd__rt_re_strip_iflag_bb12:
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd__rt_re_strip_iflag_bb14 // br_cond: !payload -> else
    b _Lb2dd__rt_re_strip_iflag_bb13 // branch -> then
_Lb2dd__rt_re_strip_iflag_bb13:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    ldp x4, x5, [sp, #32] // hv load L2
    bl hexa_str_substring // call hexa_str_substring
    stp x0, x1, [sp, #272] // hv store L17
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv reload L18
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_strip_iflag_bb14:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    ldp x2, x3, [sp, #0] // hv load L0
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv reload L19
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr26@PAGE // hv str ptr page
    add x3, x3, .LCstr26@PAGEOFF // hv str ptr off
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #320 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_pcre_literal
    .p2align 2
_rt_re_pcre_literal:
    .loc 1 94 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #784 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_pcre_literal_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr24@PAGE // hv str ptr page
    add x1, x1, .LCstr24@PAGEOFF // hv str ptr off
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__rt_re_pcre_literal_bb1 // branch
_Lb2dd__rt_re_pcre_literal_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb3 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb2 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb5 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb4 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb3:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_pcre_literal_bb4:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__rt_re_pcre_literal_bb6 // branch
_Lb2dd__rt_re_pcre_literal_bb5:
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    b _Lb2dd__rt_re_pcre_literal_bb6 // branch
_Lb2dd__rt_re_pcre_literal_bb6:
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb8 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb7 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb7:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #224] // hv load L14
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb10 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb9 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb8:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #91 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb30 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb29 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb9:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #100 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb12 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb11 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb10:
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__rt_re_pcre_literal_bb26 // branch
_Lb2dd__rt_re_pcre_literal_bb11:
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__rt_re_pcre_literal_bb13 // branch
_Lb2dd__rt_re_pcre_literal_bb12:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #68 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #320] // hv store L20
    b _Lb2dd__rt_re_pcre_literal_bb13 // branch
_Lb2dd__rt_re_pcre_literal_bb13:
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb15 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb14 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb14:
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd__rt_re_pcre_literal_bb16 // branch
_Lb2dd__rt_re_pcre_literal_bb15:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #119 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd__rt_re_pcre_literal_bb16 // branch
_Lb2dd__rt_re_pcre_literal_bb16:
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb18 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb17 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb17:
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__rt_re_pcre_literal_bb19 // branch
_Lb2dd__rt_re_pcre_literal_bb18:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #87 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__rt_re_pcre_literal_bb19 // branch
_Lb2dd__rt_re_pcre_literal_bb19:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb21 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb20 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb20:
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #416] // hv store L26
    b _Lb2dd__rt_re_pcre_literal_bb22 // branch
_Lb2dd__rt_re_pcre_literal_bb21:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #115 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #416] // hv store L26
    b _Lb2dd__rt_re_pcre_literal_bb22 // branch
_Lb2dd__rt_re_pcre_literal_bb22:
    ldp x0, x1, [sp, #416] // hv load L26
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb24 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb23 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb23:
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #448] // hv store L28
    b _Lb2dd__rt_re_pcre_literal_bb25 // branch
_Lb2dd__rt_re_pcre_literal_bb24:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #83 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #448] // hv store L28
    b _Lb2dd__rt_re_pcre_literal_bb25 // branch
_Lb2dd__rt_re_pcre_literal_bb25:
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #288] // hv store L18
    b _Lb2dd__rt_re_pcre_literal_bb26 // branch
_Lb2dd__rt_re_pcre_literal_bb26:
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb28 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb27 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb27:
    ldp x0, x1, [sp, #256] // hv load L16
    bl hexa_chr_byte // call hexa_chr_byte
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #496] // hv load L31
    bl hexa_add_slow // binop +
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_pcre_literal_bb1 // branch
_Lb2dd__rt_re_pcre_literal_bb28:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_chr_byte // call hexa_chr_byte
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    bl hexa_add_slow // binop +
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #256] // hv load L16
    bl hexa_chr_byte // call hexa_chr_byte
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_add_slow // binop +
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_pcre_literal_bb1 // branch
_Lb2dd__rt_re_pcre_literal_bb29:
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd__rt_re_pcre_literal_bb31 // branch
_Lb2dd__rt_re_pcre_literal_bb30:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd__rt_re_pcre_literal_bb31 // branch
_Lb2dd__rt_re_pcre_literal_bb31:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb33 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb32 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb32:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__rt_re_pcre_literal_bb39 // branch
_Lb2dd__rt_re_pcre_literal_bb33:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb35 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb34 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb34:
    ldp x0, x1, [sp, #80] // hv load L5
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    b _Lb2dd__rt_re_pcre_literal_bb36 // branch
_Lb2dd__rt_re_pcre_literal_bb35:
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    b _Lb2dd__rt_re_pcre_literal_bb36 // branch
_Lb2dd__rt_re_pcre_literal_bb36:
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd__rt_re_pcre_literal_bb38 // br_cond: !payload -> else
    b _Lb2dd__rt_re_pcre_literal_bb37 // branch -> then
_Lb2dd__rt_re_pcre_literal_bb37:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd__rt_re_pcre_literal_bb38 // branch
_Lb2dd__rt_re_pcre_literal_bb38:
    b _Lb2dd__rt_re_pcre_literal_bb39 // branch
_Lb2dd__rt_re_pcre_literal_bb39:
    ldp x0, x1, [sp, #128] // hv load L8
    bl hexa_chr_byte // call hexa_chr_byte
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #736 // hv frame base
    ldp x2, x3, [x15] // hv load L46
    bl hexa_add_slow // binop +
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_pcre_literal_bb1 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #784 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_has_backref_lookaround
    .p2align 2
_rt_re_has_backref_lookaround:
    .loc 1 132 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1104 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_has_backref_lookaround_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb1 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb3 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb2 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb5 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb4 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb3:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_has_backref_lookaround_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb7 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb6 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb5:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #91 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb14 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb13 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #192] // hv load L12
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #49 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb9 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb8 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb7:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb1 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb8:
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__rt_re_has_backref_lookaround_bb10 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb9:
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _Lb2dd__rt_re_has_backref_lookaround_bb10 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb10:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb12 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb11 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb11:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_has_backref_lookaround_bb12:
    b _Lb2dd__rt_re_has_backref_lookaround_bb7 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb13:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb16 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb15 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb14:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb37 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb36 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #94 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__rt_re_has_backref_lookaround_bb17 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb16:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd__rt_re_has_backref_lookaround_bb17 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb17:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb19 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb18 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb18:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb19 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb19:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb21 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb20 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb20:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    stp x0, x1, [sp, #480] // hv store L30
    b _Lb2dd__rt_re_has_backref_lookaround_bb22 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb21:
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    b _Lb2dd__rt_re_has_backref_lookaround_bb22 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb22:
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb24 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb23 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb23:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb24 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb24:
    b _Lb2dd__rt_re_has_backref_lookaround_bb25 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb25:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb29 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb28 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb26:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #92 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb32 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb31 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb27:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb35 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb34 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb28:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #93 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd__rt_re_has_backref_lookaround_bb30 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb29:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _Lb2dd__rt_re_has_backref_lookaround_bb30 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb30:
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb27 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb26 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb31:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb33 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb32:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb33 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb33:
    b _Lb2dd__rt_re_has_backref_lookaround_bb25 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb34:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb35 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb35:
    b _Lb2dd__rt_re_has_backref_lookaround_bb1 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb36:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _Lb2dd__rt_re_has_backref_lookaround_bb38 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb37:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _Lb2dd__rt_re_has_backref_lookaround_bb38 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb38:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb40 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb39 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb39:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _Lb2dd__rt_re_has_backref_lookaround_bb41 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb40:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _Lb2dd__rt_re_has_backref_lookaround_bb41 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb41:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb43 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb42 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb42:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb45 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb44 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb43:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    stp x0, x1, [sp, #48] // hv store L3
    b _Lb2dd__rt_re_has_backref_lookaround_bb1 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb44:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #61 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb47 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb46 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb45:
    b _Lb2dd__rt_re_has_backref_lookaround_bb43 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb46:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _Lb2dd__rt_re_has_backref_lookaround_bb48 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb47:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #33 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _Lb2dd__rt_re_has_backref_lookaround_bb48 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb48:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb50 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb49 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb49:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    b _Lb2dd__rt_re_has_backref_lookaround_bb51 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb50:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #60 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    b _Lb2dd__rt_re_has_backref_lookaround_bb51 // branch
_Lb2dd__rt_re_has_backref_lookaround_bb51:
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _Lb2dd__rt_re_has_backref_lookaround_bb53 // br_cond: !payload -> else
    b _Lb2dd__rt_re_has_backref_lookaround_bb52 // branch -> then
_Lb2dd__rt_re_has_backref_lookaround_bb52:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd__rt_re_has_backref_lookaround_bb53:
    b _Lb2dd__rt_re_has_backref_lookaround_bb45 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #1104 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.hidden _rt_re_prep_pat
    .p2align 2
_rt_re_prep_pat:
    .loc 1 171 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #192 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_Lb2dd__rt_re_prep_pat_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl _rt_re_strip_iflag // call _rt_re_strip_iflag
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    bl _rt_re_pcre_literal // call _rt_re_pcre_literal
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _Lb2dd__rt_re_prep_pat_bb2 // br_cond: !payload -> else
    b _Lb2dd__rt_re_prep_pat_bb1 // branch -> then
_Lb2dd__rt_re_prep_pat_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd__rt_re_prep_pat_bb2 // branch
_Lb2dd__rt_re_prep_pat_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #160] // hv store L10
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_array_push // array_lit: push elem 0
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv reload L11
    ldp x2, x3, [sp, #160] // hv load L10
    bl hexa_array_push // array_lit: push elem 1
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #192 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_match
.hidden rt_regex_match
    .p2align 2
rt_regex_match:
    .loc 1 188 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #512 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_rt_regex_match_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_rt_regex_match_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb1 // branch -> then
_Lb2dd_rt_regex_match_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_match_bb3 // branch
_Lb2dd_rt_regex_match_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_match_bb3 // branch
_Lb2dd_rt_regex_match_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_rt_regex_match_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb4 // branch -> then
_Lb2dd_rt_regex_match_bb4:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #144] // hv load L9
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd_rt_regex_match_bb7 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb6 // branch -> then
_Lb2dd_rt_regex_match_bb6:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_bb7:
    ldp x0, x1, [sp, #144] // hv load L9
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd_rt_regex_match_bb9 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb8 // branch -> then
_Lb2dd_rt_regex_match_bb8:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_bb9:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd_rt_regex_match_bb11 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb10 // branch -> then
_Lb2dd_rt_regex_match_bb10:
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd_rt_regex_match_bb11 // branch
_Lb2dd_rt_regex_match_bb11:
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #352] // hv load L22
    bl regex_search // call regex_search
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd_rt_regex_match_bb13 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_bb12 // branch -> then
_Lb2dd_rt_regex_match_bb12:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_bb13:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #512 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_match_full
.hidden rt_regex_match_full
    .p2align 2
rt_regex_match_full:
    .loc 1 205 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #624 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_rt_regex_match_full_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_rt_regex_match_full_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb1 // branch -> then
_Lb2dd_rt_regex_match_full_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_match_full_bb3 // branch
_Lb2dd_rt_regex_match_full_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_match_full_bb3 // branch
_Lb2dd_rt_regex_match_full_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_rt_regex_match_full_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb4 // branch -> then
_Lb2dd_rt_regex_match_full_bb4:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_full_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #144] // hv load L9
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _Lb2dd_rt_regex_match_full_bb7 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb6 // branch -> then
_Lb2dd_rt_regex_match_full_bb6:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_full_bb7:
    ldp x0, x1, [sp, #144] // hv load L9
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _Lb2dd_rt_regex_match_full_bb9 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb8 // branch -> then
_Lb2dd_rt_regex_match_full_bb8:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_full_bb9:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _Lb2dd_rt_regex_match_full_bb11 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb10 // branch -> then
_Lb2dd_rt_regex_match_full_bb10:
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #352] // hv store L22
    b _Lb2dd_rt_regex_match_full_bb11 // branch
_Lb2dd_rt_regex_match_full_bb11:
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #352] // hv load L22
    bl regex_search // call regex_search
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd_rt_regex_match_full_bb13 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb12 // branch -> then
_Lb2dd_rt_regex_match_full_bb12:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_full_bb13:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #448] // hv load L28
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd_rt_regex_match_full_bb15 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb14 // branch -> then
_Lb2dd_rt_regex_match_full_bb14:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #448] // hv load L28
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_byte_len // call hexa_byte_len
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd_rt_regex_match_full_bb16 // branch
_Lb2dd_rt_regex_match_full_bb15:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _Lb2dd_rt_regex_match_full_bb16 // branch
_Lb2dd_rt_regex_match_full_bb16:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _Lb2dd_rt_regex_match_full_bb18 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_match_full_bb17 // branch -> then
_Lb2dd_rt_regex_match_full_bb17:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #1 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_match_full_bb18:
    movz x0, #2 // hv const_bool: TAG_BOOL
    movz x1, #0 // hv const_bool payload
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_search
.hidden rt_regex_search
    .p2align 2
rt_regex_search:
    .loc 1 223 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #624 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_rt_regex_search_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _Lb2dd_rt_regex_search_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb1 // branch -> then
_Lb2dd_rt_regex_search_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_search_bb3 // branch
_Lb2dd_rt_regex_search_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #64] // hv store L4
    b _Lb2dd_rt_regex_search_bb3 // branch
_Lb2dd_rt_regex_search_bb3:
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_rt_regex_search_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb4 // branch -> then
_Lb2dd_rt_regex_search_bb4:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_search_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #160] // hv load L10
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd_rt_regex_search_bb7 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb6 // branch -> then
_Lb2dd_rt_regex_search_bb6:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_search_bb7:
    ldp x0, x1, [sp, #160] // hv load L10
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd_rt_regex_search_bb9 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb8 // branch -> then
_Lb2dd_rt_regex_search_bb8:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_search_bb9:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _Lb2dd_rt_regex_search_bb11 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb10 // branch -> then
_Lb2dd_rt_regex_search_bb10:
    ldp x0, x1, [sp, #192] // hv load L12
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #400] // hv store L25
    b _Lb2dd_rt_regex_search_bb11 // branch
_Lb2dd_rt_regex_search_bb11:
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #400] // hv load L25
    bl regex_search // call regex_search
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _Lb2dd_rt_regex_search_bb13 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_search_bb12 // branch -> then
_Lb2dd_rt_regex_search_bb12:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_search_bb13:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    ldp x0, x1, [sp, #496] // hv load L31
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    ldp x0, x1, [sp, #496] // hv load L31
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    bl hexa_array_new // array_lit: new array
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv reload L38
    add x15, sp, #576 // hv frame base
    ldp x2, x3, [x15] // hv load L36
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv reload L38
    add x15, sp, #592 // hv frame base
    ldp x2, x3, [x15] // hv load L37
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add sp, sp, #624 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_findall
.hidden rt_regex_findall
    .p2align 2
rt_regex_findall:
    .loc 1 243 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #768 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_rt_regex_findall_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_rt_regex_findall_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb1 // branch -> then
_Lb2dd_rt_regex_findall_bb1:
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd_rt_regex_findall_bb3 // branch
_Lb2dd_rt_regex_findall_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd_rt_regex_findall_bb3 // branch
_Lb2dd_rt_regex_findall_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd_rt_regex_findall_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb4 // branch -> then
_Lb2dd_rt_regex_findall_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_findall_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_rt_regex_findall_bb7 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb6 // branch -> then
_Lb2dd_rt_regex_findall_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_findall_bb7:
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd_rt_regex_findall_bb9 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb8 // branch -> then
_Lb2dd_rt_regex_findall_bb8:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_findall_bb9:
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    cbz x1, _Lb2dd_rt_regex_findall_bb11 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb10 // branch -> then
_Lb2dd_rt_regex_findall_bb10:
    ldp x0, x1, [sp, #208] // hv load L13
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #384] // hv store L24
    b _Lb2dd_rt_regex_findall_bb11 // branch
_Lb2dd_rt_regex_findall_bb11:
    ldp x0, x1, [sp, #384] // hv load L24
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb2dd_rt_regex_findall_bb12 // branch
_Lb2dd_rt_regex_findall_bb12:
    ldp x0, x1, [sp, #496] // hv load L31
    ldp x2, x3, [sp, #480] // hv load L30
    bl hexa_cmp_le // binop <=
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _Lb2dd_rt_regex_findall_bb14 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb13 // branch -> then
_Lb2dd_rt_regex_findall_bb13:
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #384] // hv load L24
    ldp x4, x5, [sp, #496] // hv load L31
    add x15, sp, #528 // hv frame base
    ldp x6, x7, [x15] // hv load L33
    bl regex_search_from // call regex_search_from
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    cbz x1, _Lb2dd_rt_regex_findall_bb16 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb15 // branch -> then
_Lb2dd_rt_regex_findall_bb14:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_findall_bb15:
    b _Lb2dd_rt_regex_findall_bb14 // branch
_Lb2dd_rt_regex_findall_bb16:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add x15, sp, #640 // hv frame base
    ldp x2, x3, [x15] // hv load L40
    bl hexa_eq // binop ==
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _Lb2dd_rt_regex_findall_bb18 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_findall_bb17 // branch -> then
_Lb2dd_rt_regex_findall_bb17:
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb2dd_rt_regex_findall_bb12 // branch
_Lb2dd_rt_regex_findall_bb18:
    bl hexa_array_new // array_lit: new array
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv reload L46
    add x15, sp, #640 // hv frame base
    ldp x2, x3, [x15] // hv load L40
    bl hexa_array_push // array_lit: push elem 0
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv reload L46
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    bl hexa_array_push // array_lit: push elem 1
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #736 // hv frame base
    ldp x2, x3, [x15] // hv load L46
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    stp x0, x1, [sp, #496] // hv store L31
    b _Lb2dd_rt_regex_findall_bb12 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #768 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_split
.hidden rt_regex_split
    .p2align 2
rt_regex_split:
    .loc 1 275 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #864 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_Lb2dd_rt_regex_split_bb0:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_rt_regex_split_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb1 // branch -> then
_Lb2dd_rt_regex_split_bb1:
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd_rt_regex_split_bb3 // branch
_Lb2dd_rt_regex_split_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #96] // hv store L6
    b _Lb2dd_rt_regex_split_bb3 // branch
_Lb2dd_rt_regex_split_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _Lb2dd_rt_regex_split_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb4 // branch -> then
_Lb2dd_rt_regex_split_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #864 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_split_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _Lb2dd_rt_regex_split_bb7 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb6 // branch -> then
_Lb2dd_rt_regex_split_bb6:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #864 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_split_bb7:
    ldp x0, x1, [sp, #176] // hv load L11
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _Lb2dd_rt_regex_split_bb9 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb8 // branch -> then
_Lb2dd_rt_regex_split_bb8:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #208] // hv load L13
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #864 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_split_bb9:
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    cbz x1, _Lb2dd_rt_regex_split_bb11 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb10 // branch -> then
_Lb2dd_rt_regex_split_bb10:
    ldp x0, x1, [sp, #208] // hv load L13
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #416] // hv store L26
    b _Lb2dd_rt_regex_split_bb11 // branch
_Lb2dd_rt_regex_split_bb11:
    ldp x0, x1, [sp, #416] // hv load L26
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    b _Lb2dd_rt_regex_split_bb12 // branch
_Lb2dd_rt_regex_split_bb12:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_cmp_le // binop <=
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _Lb2dd_rt_regex_split_bb14 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb13 // branch -> then
_Lb2dd_rt_regex_split_bb13:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #416] // hv load L26
    add x15, sp, #528 // hv frame base
    ldp x4, x5, [x15] // hv load L33
    add x15, sp, #560 // hv frame base
    ldp x6, x7, [x15] // hv load L35
    bl regex_search_from // call regex_search_from
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _Lb2dd_rt_regex_split_bb16 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb15 // branch -> then
_Lb2dd_rt_regex_split_bb14:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    bl hexa_cmp_le // binop <=
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _Lb2dd_rt_regex_split_bb20 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb19 // branch -> then
_Lb2dd_rt_regex_split_bb15:
    b _Lb2dd_rt_regex_split_bb14 // branch
_Lb2dd_rt_regex_split_bb16:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    bl hexa_eq // binop ==
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    cbz x1, _Lb2dd_rt_regex_split_bb18 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_split_bb17 // branch -> then
_Lb2dd_rt_regex_split_bb17:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    b _Lb2dd_rt_regex_split_bb12 // branch
_Lb2dd_rt_regex_split_bb18:
    ldp x0, x1, [sp, #208] // hv load L13
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    add x15, sp, #672 // hv frame base
    ldp x4, x5, [x15] // hv load L42
    bl hexa_str_substring // call hexa_str_substring
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #768 // hv frame base
    ldp x2, x3, [x15] // hv load L48
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    b _Lb2dd_rt_regex_split_bb12 // branch
_Lb2dd_rt_regex_split_bb19:
    ldp x0, x1, [sp, #208] // hv load L13
    add x15, sp, #528 // hv frame base
    ldp x2, x3, [x15] // hv load L33
    add x15, sp, #512 // hv frame base
    ldp x4, x5, [x15] // hv load L32
    bl hexa_str_substring // call hexa_str_substring
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    ldp x0, x1, [sp, #48] // hv load L3
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _Lb2dd_rt_regex_split_bb20 // branch
_Lb2dd_rt_regex_split_bb20:
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #864 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_regex_replace
.hidden rt_regex_replace
    .p2align 2
rt_regex_replace:
    .loc 1 317 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1072 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_Lb2dd_rt_regex_replace_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _Lb2dd_rt_regex_replace_bb2 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb1 // branch -> then
_Lb2dd_rt_regex_replace_bb1:
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd_rt_regex_replace_bb3 // branch
_Lb2dd_rt_regex_replace_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #80] // hv store L5
    b _Lb2dd_rt_regex_replace_bb3 // branch
_Lb2dd_rt_regex_replace_bb3:
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _Lb2dd_rt_regex_replace_bb5 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb4 // branch -> then
_Lb2dd_rt_regex_replace_bb4:
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd_rt_regex_replace_bb6 // branch
_Lb2dd_rt_regex_replace_bb5:
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #128] // hv store L8
    b _Lb2dd_rt_regex_replace_bb6 // branch
_Lb2dd_rt_regex_replace_bb6:
    ldp x0, x1, [sp, #128] // hv load L8
    cbz x1, _Lb2dd_rt_regex_replace_bb8 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb7 // branch -> then
_Lb2dd_rt_regex_replace_bb7:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_type_of // call hexa_type_of
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr27@PAGE // hv str ptr page
    add x3, x3, .LCstr27@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _Lb2dd_rt_regex_replace_bb10 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb9 // branch -> then
_Lb2dd_rt_regex_replace_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #32] // hv load L2
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #272] // hv load L17
    bl _rt_re_has_backref_lookaround // call _rt_re_has_backref_lookaround
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _Lb2dd_rt_regex_replace_bb12 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb11 // branch -> then
_Lb2dd_rt_regex_replace_bb9:
    ldp x0, x1, [sp, #16] // hv load L1
    bl hexa_to_string // call hexa_to_string
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    add sp, sp, #1072 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_replace_bb10:
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr24@PAGE // hv str ptr page
    add x1, x1, .LCstr24@PAGEOFF // hv str ptr off
    add sp, sp, #1072 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_replace_bb11:
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #1072 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_replace_bb12:
    ldp x0, x1, [sp, #272] // hv load L17
    bl _rt_re_prep_pat // call _rt_re_prep_pat
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    bl regex_compile // call regex_compile
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    bl regex_valid // call regex_valid
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    bl hexa_truthy // unop !: truthy → w0
    eor x0, x0, #1 // unop !: !truthy
    bl hexa_bool // unop !: box bool
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _Lb2dd_rt_regex_replace_bb14 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb13 // branch -> then
_Lb2dd_rt_regex_replace_bb13:
    ldp x0, x1, [sp, #304] // hv load L19
    add sp, sp, #1072 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_Lb2dd_rt_regex_replace_bb14:
    ldp x0, x1, [sp, #304] // hv load L19
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    ldp x0, x1, [sp, #400] // hv load L25
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #3 // hv const_str: TAG_STR
    adrp x3, .LCstr25@PAGE // hv str ptr page
    add x3, x3, .LCstr25@PAGEOFF // hv str ptr off
    bl hexa_eq // binop ==
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _Lb2dd_rt_regex_replace_bb16 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb15 // branch -> then
_Lb2dd_rt_regex_replace_bb15:
    ldp x0, x1, [sp, #304] // hv load L19
    bl _rt_re_ascii_fold // call _rt_re_ascii_fold
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _Lb2dd_rt_regex_replace_bb16 // branch
_Lb2dd_rt_regex_replace_bb16:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    bl hexa_byte_len // call hexa_byte_len
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr24@PAGE // hv str ptr page
    add x1, x1, .LCstr24@PAGEOFF // hv str ptr off
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd_rt_regex_replace_bb17 // branch
_Lb2dd_rt_regex_replace_bb17:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_cmp_le // binop <=
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _Lb2dd_rt_regex_replace_bb19 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb18 // branch -> then
_Lb2dd_rt_regex_replace_bb18:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    ldp x0, x1, [sp, #448] // hv load L28
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    add x15, sp, #624 // hv frame base
    ldp x4, x5, [x15] // hv load L39
    add x15, sp, #672 // hv frame base
    ldp x6, x7, [x15] // hv load L42
    bl regex_search_from // call regex_search_from
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    bl hexa_arr_poly_len // call hexa_arr_poly_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    cbz x1, _Lb2dd_rt_regex_replace_bb21 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb20 // branch -> then
_Lb2dd_rt_regex_replace_bb19:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_cmp_le // binop <=
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _Lb2dd_rt_regex_replace_bb27 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb26 // branch -> then
_Lb2dd_rt_regex_replace_bb20:
    b _Lb2dd_rt_regex_replace_bb19 // branch
_Lb2dd_rt_regex_replace_bb21:
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #0 // hv const_int val
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    movz x9, #0 // hv const_int: TAG_INT
    movz x10, #1 // hv const_int val
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    mov x2, x10 // index: raw idx payload → x2
    bl hexa_arr_poly_get // index: hexa_arr_poly_get (runtime discriminate)
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #784 // hv frame base
    ldp x2, x3, [x15] // hv load L49
    bl hexa_eq // binop ==
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _Lb2dd_rt_regex_replace_bb23 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb22 // branch -> then
_Lb2dd_rt_regex_replace_bb22:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    bl hexa_cmp_lt // binop <
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    cbz x1, _Lb2dd_rt_regex_replace_bb25 // br_cond: !payload -> else
    b _Lb2dd_rt_regex_replace_bb24 // branch -> then
_Lb2dd_rt_regex_replace_bb23:
    ldp x0, x1, [sp, #304] // hv load L19
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    add x15, sp, #784 // hv frame base
    ldp x4, x5, [x15] // hv load L49
    bl hexa_str_substring // call hexa_str_substring
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #960 // hv frame base
    ldp x2, x3, [x15] // hv load L60
    bl hexa_add_slow // binop +
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    ldp x2, x3, [sp, #336] // hv load L21
    bl hexa_add_slow // binop +
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _Lb2dd_rt_regex_replace_bb17 // branch
_Lb2dd_rt_regex_replace_bb24:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    ldp x0, x1, [sp, #304] // hv load L19
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    add x15, sp, #896 // hv frame base
    ldp x4, x5, [x15] // hv load L56
    bl hexa_str_substring // call hexa_str_substring
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_add_slow // binop +
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd_rt_regex_replace_bb25 // branch
_Lb2dd_rt_regex_replace_bb25:
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _Lb2dd_rt_regex_replace_bb17 // branch
_Lb2dd_rt_regex_replace_bb26:
    ldp x0, x1, [sp, #304] // hv load L19
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    add x15, sp, #608 // hv frame base
    ldp x4, x5, [x15] // hv load L38
    bl hexa_str_substring // call hexa_str_substring
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #1040 // hv frame base
    ldp x2, x3, [x15] // hv load L65
    bl hexa_add_slow // binop +
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    b _Lb2dd_rt_regex_replace_bb27 // branch
_Lb2dd_rt_regex_replace_bb27:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add sp, sp, #1072 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .rodata
.LCstr0:
    .byte 0x70, 0x6f, 0x73, 0x00
.section .rodata
.LCstr1:
    .byte 0x70, 0x6c, 0x65, 0x6e, 0x00
.section .rodata
.LCstr2:
    .byte 0x70, 0x61, 0x74, 0x00
.section .rodata
.LCstr3:
    .byte 0x6e, 0x6f, 0x64, 0x65, 0x73, 0x00
.section .rodata
.LCstr4:
    .byte 0x63, 0x6c, 0x61, 0x73, 0x73, 0x65, 0x73, 0x00
.section .rodata
.LCstr5:
    .byte 0x6f, 0x6b, 0x00
.section .rodata
.LCstr6:
    .byte 0x6e, 0x67, 0x00
.section .rodata
.LCstr7:
    .byte 0x42, 0x74, 0x50, 0x72, 0x6f, 0x67, 0x00
.section .rodata
.LCstr8:
    .byte 0x72, 0x6f, 0x6f, 0x74, 0x00
.section .rodata
.LCstr9:
    .byte 0x6e, 0x67, 0x72, 0x6f, 0x75, 0x70, 0x73, 0x00
.section .rodata
.LCstr10:
    .byte 0x6d, 0x61, 0x78, 0x5f, 0x73, 0x74, 0x65, 0x70, 0x73, 0x00
.section .rodata
.LCstr11:
    .byte 0x73, 0x74, 0x00
.section .rodata
.LCstr12:
    .byte 0x42, 0x74, 0x50, 0x61, 0x72, 0x73, 0x65, 0x00
.section .rodata
.LCstr13:
    .byte 0x6e, 0x6b, 0x69, 0x6e, 0x64, 0x00
.section .rodata
.LCstr14:
    .byte 0x6e, 0x63, 0x00
.section .rodata
.LCstr15:
    .byte 0x6e, 0x6f, 0x75, 0x74, 0x00
.section .rodata
.LCstr16:
    .byte 0x6e, 0x6f, 0x75, 0x74, 0x31, 0x00
.section .rodata
.LCstr17:
    .byte 0x52, 0x65, 0x67, 0x65, 0x78, 0x00
.section .rodata
.LCstr18:
    .byte 0x73, 0x74, 0x61, 0x72, 0x74, 0x00
.section .rodata
.LCstr19:
    .byte 0x6e, 0x73, 0x74, 0x61, 0x74, 0x65, 0x73, 0x00
.section .rodata
.LCstr20:
    .byte 0x65, 0x6e, 0x67, 0x69, 0x6e, 0x65, 0x00
.section .rodata
.LCstr21:
    .byte 0x62, 0x74, 0x00
.section .rodata
.LCstr22:
    .byte 0x52, 0x65, 0x50, 0x61, 0x72, 0x73, 0x65, 0x00
.section .rodata
.LCstr23:
    .byte 0x4e, 0x66, 0x61, 0x42, 0x00
.section .rodata
.LCstr24:
    .byte 0x00
.section .rodata
.LCstr25:
    .byte 0x31, 0x00
.section .rodata
.LCstr26:
    .byte 0x30, 0x00
.section .rodata
.LCstr27:
    .byte 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",%progbits
