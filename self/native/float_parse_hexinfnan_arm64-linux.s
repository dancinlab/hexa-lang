// float_parse_hexinfnan_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-hexinfnan).
// GENERATED: tool/regen_float_parse_hexinfnan_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o float_parse_hexinfnan_arm64-linux.s stdlib/runtime/float_parse_hexinfnan.hexa.
//   Provides the STRTOD TAIL (rt_str_parse_float_hexinfnan) — the native
//   IEEE-bit-exact hex-float / inf / nan(payload) / malformed string->f64 body
//   (hex exact-by-construction integer round-half-even + inf/nan constants +
//   glibc/Apple nan-payload parse) that replaces the LAST inputs libc strtod
//   served, after the Clinger fast + big-integer EXACT finite tiers decline.
//   Bit-exact to the LINKED host libc strtod (glibc + Apple, cross-probed);
//   returns a TAG_VOID sentinel for true junk so the C wrapper still falls back.
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF aarch64, rt_str_parse_float_hexinfnan no underscore. External: hexa string/value runtime (resolved within runtime.a).
//   Lets stage_resolve_runtime_a define HEXA_RT_STRTOD_TAIL_NATIVE (opt-IN,
//   default-OFF) + ar this .o into runtime.a so __hexa_num_parse_float composes
//   fast(Clinger) -> exact(big-int) -> tail(this) -> C strtod.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/float_parse_hexinfnan.hexa
.file 1 "stdlib/runtime/float_parse_hexinfnan.hexa"
.text
.globl hpx_assemble
.hidden hpx_assemble
    .p2align 2
hpx_assemble:
    .loc 1 59 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #192 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_La4b0_hpx_assemble_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_mul // binop *
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #32] // hv load L2
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _La4b0_hpx_assemble_bb2 // br_cond: !payload -> else
    b _La4b0_hpx_assemble_bb1 // branch -> then
_La4b0_hpx_assemble_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    movk x3, #65535, lsl #32 // imm 32-47
    movk x3, #32767, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #80] // hv store L5
    b _La4b0_hpx_assemble_bb2 // branch
_La4b0_hpx_assemble_bb2:
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_bits_to_float // call hexa_bits_to_float
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    add sp, sp, #192 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hpx_pack
.hidden hpx_pack
    .p2align 2
hpx_pack:
    .loc 1 72 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #800 // sp adj
    stp x0, x1, [sp, #16] // ingress param 0
    stp x2, x3, [sp, #32] // ingress param 1
    stp x4, x5, [sp, #48] // ingress param 2
    stp x6, x7, [sp, #64] // ingress param 3
_La4b0_hpx_pack_bb0:
    ldp x0, x1, [sp, #32] // hv load L1
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #80] // hv store L4
    ldp x0, x1, [sp, #80] // hv load L4
    cbz x1, _La4b0_hpx_pack_bb2 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb1 // branch -> then
_La4b0_hpx_pack_bb1:
    ldp x0, x1, [sp, #16] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    stp x0, x1, [sp, #112] // hv store L6
    ldp x0, x1, [sp, #112] // hv load L6
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_pack_bb2:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L7
    ldp x0, x1, [sp, #32] // hv load L1
    stp x0, x1, [sp, #144] // hv store L8
    b _La4b0_hpx_pack_bb3 // branch
_La4b0_hpx_pack_bb3:
    ldp x0, x1, [sp, #144] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #160] // hv store L9
    ldp x0, x1, [sp, #160] // hv load L9
    cbz x1, _La4b0_hpx_pack_bb5 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb4 // branch -> then
_La4b0_hpx_pack_bb4:
    ldp x0, x1, [sp, #144] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #176] // hv store L10
    ldp x0, x1, [sp, #176] // hv load L10
    stp x0, x1, [sp, #144] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #192] // hv store L11
    ldp x0, x1, [sp, #192] // hv load L11
    stp x0, x1, [sp, #128] // hv store L7
    b _La4b0_hpx_pack_bb3 // branch
_La4b0_hpx_pack_bb5:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #128] // hv load L7
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #208] // hv store L12
    ldp x0, x1, [sp, #208] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #224] // hv store L13
    ldp x0, x1, [sp, #224] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1023 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #240] // hv store L14
    ldp x0, x1, [sp, #240] // hv load L14
    stp x0, x1, [sp, #256] // hv store L15
    ldp x0, x1, [sp, #256] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #272] // hv store L16
    ldp x0, x1, [sp, #272] // hv load L16
    cbz x1, _La4b0_hpx_pack_bb7 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb6 // branch -> then
_La4b0_hpx_pack_bb6:
    ldp x0, x1, [sp, #16] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    stp x0, x1, [sp, #304] // hv store L18
    ldp x0, x1, [sp, #304] // hv load L18
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_pack_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L19
    ldp x0, x1, [sp, #256] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #336] // hv store L20
    ldp x0, x1, [sp, #336] // hv load L20
    cbz x1, _La4b0_hpx_pack_bb9 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb8 // branch -> then
_La4b0_hpx_pack_bb8:
    ldp x0, x1, [sp, #128] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #53 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #368] // hv store L22
    ldp x0, x1, [sp, #368] // hv load L22
    stp x0, x1, [sp, #320] // hv store L19
    b _La4b0_hpx_pack_bb10 // branch
_La4b0_hpx_pack_bb9:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1074 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #384] // hv store L23
    ldp x0, x1, [sp, #384] // hv load L23
    ldp x2, x3, [sp, #48] // hv load L2
    bl hexa_sub // binop -
    stp x0, x1, [sp, #400] // hv store L24
    ldp x0, x1, [sp, #400] // hv load L24
    stp x0, x1, [sp, #320] // hv store L19
    b _La4b0_hpx_pack_bb10 // branch
_La4b0_hpx_pack_bb10:
    ldp x0, x1, [sp, #320] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #416] // hv store L25
    ldp x0, x1, [sp, #416] // hv load L25
    cbz x1, _La4b0_hpx_pack_bb12 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb11 // branch -> then
_La4b0_hpx_pack_bb11:
    ldp x0, x1, [sp, #256] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #448] // hv store L27
    ldp x0, x1, [sp, #448] // hv load L27
    cbz x1, _La4b0_hpx_pack_bb14 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb13 // branch -> then
_La4b0_hpx_pack_bb12:
    ldp x0, x1, [sp, #16] // hv load L0
    ldp x2, x3, [sp, #32] // hv load L1
    ldp x4, x5, [sp, #320] // hv load L19
    ldp x6, x7, [sp, #64] // hv load L3
    ldp x9, x10, [sp, #256] // hv load L15
    stp x9, x10, [sp, #0] // C7: stack arg 4
    bl hpx_round_shift // call hpx_round_shift
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_pack_bb13:
    ldp x0, x1, [sp, #32] // hv load L1
    stp x0, x1, [sp, #480] // hv store L29
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #53 // hv const_int val
    ldp x2, x3, [sp, #128] // hv load L7
    bl hexa_sub // binop -
    stp x0, x1, [sp, #496] // hv store L30
    ldp x0, x1, [sp, #496] // hv load L30
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L31
    b _La4b0_hpx_pack_bb15 // branch
_La4b0_hpx_pack_bb14:
    ldp x0, x1, [sp, #32] // hv load L1
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L37
    ldp x0, x1, [sp, #48] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1074 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _La4b0_hpx_pack_bb18 // branch
_La4b0_hpx_pack_bb15:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _La4b0_hpx_pack_bb17 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb16 // branch -> then
_La4b0_hpx_pack_bb16:
    ldp x0, x1, [sp, #480] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    stp x0, x1, [sp, #480] // hv store L29
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L31
    b _La4b0_hpx_pack_bb15 // branch
_La4b0_hpx_pack_bb17:
    ldp x0, x1, [sp, #480] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L35
    ldp x0, x1, [sp, #16] // hv load L0
    ldp x2, x3, [sp, #256] // hv load L15
    add x15, sp, #576 // hv frame base
    ldp x4, x5, [x15] // hv load L35
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_pack_bb18:
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    cbz x1, _La4b0_hpx_pack_bb20 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb19 // branch -> then
_La4b0_hpx_pack_bb19:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L39
    b _La4b0_hpx_pack_bb18 // branch
_La4b0_hpx_pack_bb20:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_cmp_ge // binop >=
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _La4b0_hpx_pack_bb22 // br_cond: !payload -> else
    b _La4b0_hpx_pack_bb21 // branch -> then
_La4b0_hpx_pack_bb21:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L45
    ldp x0, x1, [sp, #16] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x15, sp, #736 // hv frame base
    ldp x4, x5, [x15] // hv load L45
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_pack_bb22:
    ldp x0, x1, [sp, #16] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x15, sp, #608 // hv frame base
    ldp x4, x5, [x15] // hv load L37
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add sp, sp, #800 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hpx_round_shift
.hidden hpx_round_shift
    .p2align 2
hpx_round_shift:
    .loc 1 132 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #928 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
    stp x6, x7, [sp, #48] // ingress param 3
    ldp x9, x10, [x29, #16] // ingress stack param 4
    stp x9, x10, [sp, #64] // store stack param 4
_La4b0_hpx_round_shift_bb0:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #64 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    cbz x1, _La4b0_hpx_round_shift_bb2 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb1 // branch -> then
_La4b0_hpx_round_shift_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    add sp, sp, #928 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_round_shift_bb2:
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #48] // hv load L3
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_hpx_round_shift_bb3 // branch
_La4b0_hpx_round_shift_bb3:
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #62 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _La4b0_hpx_round_shift_bb5 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb4 // branch -> then
_La4b0_hpx_round_shift_bb4:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    cbz x1, _La4b0_hpx_round_shift_bb7 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb6 // branch -> then
_La4b0_hpx_round_shift_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #288] // hv store L18
    b _La4b0_hpx_round_shift_bb8 // branch
_La4b0_hpx_round_shift_bb6:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_hpx_round_shift_bb7 // branch
_La4b0_hpx_round_shift_bb7:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #144] // hv store L9
    b _La4b0_hpx_round_shift_bb3 // branch
_La4b0_hpx_round_shift_bb8:
    ldp x0, x1, [sp, #288] // hv load L18
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _La4b0_hpx_round_shift_bb10 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb9 // branch -> then
_La4b0_hpx_round_shift_bb9:
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mul // binop *
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #288] // hv load L18
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #288] // hv store L18
    b _La4b0_hpx_round_shift_bb8 // branch
_La4b0_hpx_round_shift_bb10:
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_div // binop /
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #128] // hv load L8
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_mod // binop %
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #400] // hv load L25
    ldp x2, x3, [sp, #432] // hv load L27
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _La4b0_hpx_round_shift_bb12 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb11 // branch -> then
_La4b0_hpx_round_shift_bb11:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    stp x0, x1, [sp, #448] // hv store L28
    b _La4b0_hpx_round_shift_bb20 // branch
_La4b0_hpx_round_shift_bb12:
    ldp x0, x1, [sp, #400] // hv load L25
    ldp x2, x3, [sp, #432] // hv load L27
    bl hexa_eq // binop ==
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _La4b0_hpx_round_shift_bb14 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb13 // branch -> then
_La4b0_hpx_round_shift_bb13:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _La4b0_hpx_round_shift_bb16 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb15 // branch -> then
_La4b0_hpx_round_shift_bb14:
    b _La4b0_hpx_round_shift_bb20 // branch
_La4b0_hpx_round_shift_bb15:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    stp x0, x1, [sp, #448] // hv store L28
    b _La4b0_hpx_round_shift_bb19 // branch
_La4b0_hpx_round_shift_bb16:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _La4b0_hpx_round_shift_bb18 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb17 // branch -> then
_La4b0_hpx_round_shift_bb17:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    stp x0, x1, [sp, #448] // hv store L28
    b _La4b0_hpx_round_shift_bb18 // branch
_La4b0_hpx_round_shift_bb18:
    b _La4b0_hpx_round_shift_bb19 // branch
_La4b0_hpx_round_shift_bb19:
    b _La4b0_hpx_round_shift_bb14 // branch
_La4b0_hpx_round_shift_bb20:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    cbz x1, _La4b0_hpx_round_shift_bb22 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb21 // branch -> then
_La4b0_hpx_round_shift_bb21:
    ldp x0, x1, [sp, #64] // hv load L4
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #32, lsl #48 // imm 48-63
    bl hexa_cmp_ge // binop >=
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _La4b0_hpx_round_shift_bb24 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb23 // branch -> then
_La4b0_hpx_round_shift_bb22:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_cmp_ge // binop >=
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _La4b0_hpx_round_shift_bb28 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb27 // branch -> then
_La4b0_hpx_round_shift_bb23:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #448] // hv store L28
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _La4b0_hpx_round_shift_bb26 // br_cond: !payload -> else
    b _La4b0_hpx_round_shift_bb25 // branch -> then
_La4b0_hpx_round_shift_bb24:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #688 // hv frame base
    ldp x2, x3, [x15] // hv load L43
    add x15, sp, #816 // hv frame base
    ldp x4, x5, [x15] // hv load L51
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add sp, sp, #928 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_round_shift_bb25:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add sp, sp, #928 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_round_shift_bb26:
    b _La4b0_hpx_round_shift_bb24 // branch
_La4b0_hpx_round_shift_bb27:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    bl hexa_sub // binop -
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x15, sp, #880 // hv frame base
    ldp x4, x5, [x15] // hv load L55
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add sp, sp, #928 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_round_shift_bb28:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    ldp x4, x5, [sp, #448] // hv load L28
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add sp, sp, #928 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hpx_hexfloat
.hidden hpx_hexfloat
    .p2align 2
hpx_hexfloat:
    .loc 1 193 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1712 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
    stp x6, x7, [sp, #48] // ingress param 3
_La4b0_hpx_hexfloat_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L5
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #96] // hv store L6
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #112] // hv store L7
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_hpx_hexfloat_bb1 // branch
_La4b0_hpx_hexfloat_bb1:
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _La4b0_hpx_hexfloat_bb5 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb4 // branch -> then
_La4b0_hpx_hexfloat_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    cbz x1, _La4b0_hpx_hexfloat_bb8 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb7 // branch -> then
_La4b0_hpx_hexfloat_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _La4b0_hpx_hexfloat_bb43 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb42 // branch -> then
_La4b0_hpx_hexfloat_bb4:
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _La4b0_hpx_hexfloat_bb6 // branch
_La4b0_hpx_hexfloat_bb5:
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #192] // hv store L12
    b _La4b0_hpx_hexfloat_bb6 // branch
_La4b0_hpx_hexfloat_bb6:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _La4b0_hpx_hexfloat_bb3 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb2 // branch -> then
_La4b0_hpx_hexfloat_bb7:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #304] // hv store L19
    b _La4b0_hpx_hexfloat_bb9 // branch
_La4b0_hpx_hexfloat_bb8:
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    b _La4b0_hpx_hexfloat_bb9 // branch
_La4b0_hpx_hexfloat_bb9:
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _La4b0_hpx_hexfloat_bb11 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb10 // branch -> then
_La4b0_hpx_hexfloat_bb10:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #272] // hv store L17
    b _La4b0_hpx_hexfloat_bb23 // branch
_La4b0_hpx_hexfloat_bb11:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    cbz x1, _La4b0_hpx_hexfloat_bb13 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb12 // branch -> then
_La4b0_hpx_hexfloat_bb12:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #384] // hv store L24
    b _La4b0_hpx_hexfloat_bb14 // branch
_La4b0_hpx_hexfloat_bb13:
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    b _La4b0_hpx_hexfloat_bb14 // branch
_La4b0_hpx_hexfloat_bb14:
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _La4b0_hpx_hexfloat_bb16 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb15 // branch -> then
_La4b0_hpx_hexfloat_bb15:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #87 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #272] // hv store L17
    b _La4b0_hpx_hexfloat_bb22 // branch
_La4b0_hpx_hexfloat_bb16:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    cbz x1, _La4b0_hpx_hexfloat_bb18 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb17 // branch -> then
_La4b0_hpx_hexfloat_bb17:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #70 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #464] // hv store L29
    b _La4b0_hpx_hexfloat_bb19 // branch
_La4b0_hpx_hexfloat_bb18:
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #464] // hv store L29
    b _La4b0_hpx_hexfloat_bb19 // branch
_La4b0_hpx_hexfloat_bb19:
    ldp x0, x1, [sp, #464] // hv load L29
    cbz x1, _La4b0_hpx_hexfloat_bb21 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb20 // branch -> then
_La4b0_hpx_hexfloat_bb20:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #55 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    stp x0, x1, [sp, #272] // hv store L17
    b _La4b0_hpx_hexfloat_bb21 // branch
_La4b0_hpx_hexfloat_bb21:
    b _La4b0_hpx_hexfloat_bb22 // branch
_La4b0_hpx_hexfloat_bb22:
    b _La4b0_hpx_hexfloat_bb23 // branch
_La4b0_hpx_hexfloat_bb23:
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    cbz x1, _La4b0_hpx_hexfloat_bb25 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb24 // branch -> then
_La4b0_hpx_hexfloat_bb24:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #2048, lsl #48 // imm 48-63
    bl hexa_cmp_lt // binop <
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _La4b0_hpx_hexfloat_bb27 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb26 // branch -> then
_La4b0_hpx_hexfloat_bb25:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    cbz x1, _La4b0_hpx_hexfloat_bb36 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb35 // branch -> then
_La4b0_hpx_hexfloat_bb26:
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #16 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    ldp x2, x3, [sp, #272] // hv load L17
    bl hexa_add_slow // binop +
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _La4b0_hpx_hexfloat_bb29 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb28 // branch -> then
_La4b0_hpx_hexfloat_bb27:
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    cbz x1, _La4b0_hpx_hexfloat_bb31 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb30 // branch -> then
_La4b0_hpx_hexfloat_bb28:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    stp x0, x1, [sp, #128] // hv store L8
    b _La4b0_hpx_hexfloat_bb29 // branch
_La4b0_hpx_hexfloat_bb29:
    b _La4b0_hpx_hexfloat_bb34 // branch
_La4b0_hpx_hexfloat_bb30:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #144] // hv store L9
    b _La4b0_hpx_hexfloat_bb31 // branch
_La4b0_hpx_hexfloat_bb31:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    cbz x1, _La4b0_hpx_hexfloat_bb33 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb32 // branch -> then
_La4b0_hpx_hexfloat_bb32:
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    stp x0, x1, [sp, #128] // hv store L8
    b _La4b0_hpx_hexfloat_bb33 // branch
_La4b0_hpx_hexfloat_bb33:
    b _La4b0_hpx_hexfloat_bb34 // branch
_La4b0_hpx_hexfloat_bb34:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    stp x0, x1, [sp, #64] // hv store L4
    b _La4b0_hpx_hexfloat_bb41 // branch
_La4b0_hpx_hexfloat_bb35:
    ldp x0, x1, [sp, #112] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    cbz x1, _La4b0_hpx_hexfloat_bb38 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb37 // branch -> then
_La4b0_hpx_hexfloat_bb36:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_hpx_hexfloat_bb40 // branch
_La4b0_hpx_hexfloat_bb37:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_hpx_hexfloat_bb39 // branch
_La4b0_hpx_hexfloat_bb38:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    stp x0, x1, [sp, #64] // hv store L4
    b _La4b0_hpx_hexfloat_bb39 // branch
_La4b0_hpx_hexfloat_bb39:
    b _La4b0_hpx_hexfloat_bb40 // branch
_La4b0_hpx_hexfloat_bb40:
    b _La4b0_hpx_hexfloat_bb41 // branch
_La4b0_hpx_hexfloat_bb41:
    b _La4b0_hpx_hexfloat_bb1 // branch
_La4b0_hpx_hexfloat_bb42:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add sp, sp, #1712 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_hexfloat_bb43:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    ldp x0, x1, [sp, #64] // hv load L4
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _La4b0_hpx_hexfloat_bb45 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb44 // branch -> then
_La4b0_hpx_hexfloat_bb44:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #64] // hv load L4
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
    movz x3, #112 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _La4b0_hpx_hexfloat_bb47 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb46 // branch -> then
_La4b0_hpx_hexfloat_bb45:
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    add x15, sp, #1552 // hv frame base
    ldp x0, x1, [x15] // hv load L97
    cbz x1, _La4b0_hpx_hexfloat_bb72 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb71 // branch -> then
_La4b0_hpx_hexfloat_bb46:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _La4b0_hpx_hexfloat_bb48 // branch
_La4b0_hpx_hexfloat_bb47:
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #80 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _La4b0_hpx_hexfloat_bb48 // branch
_La4b0_hpx_hexfloat_bb48:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _La4b0_hpx_hexfloat_bb50 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb49 // branch -> then
_La4b0_hpx_hexfloat_bb49:
    ldp x0, x1, [sp, #64] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    cbz x1, _La4b0_hpx_hexfloat_bb52 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb51 // branch -> then
_La4b0_hpx_hexfloat_bb50:
    b _La4b0_hpx_hexfloat_bb45 // branch
_La4b0_hpx_hexfloat_bb51:
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1072 // hv frame base
    ldp x2, x3, [x15] // hv load L67
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    cbz x1, _La4b0_hpx_hexfloat_bb54 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb53 // branch -> then
_La4b0_hpx_hexfloat_bb52:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    b _La4b0_hpx_hexfloat_bb58 // branch
_La4b0_hpx_hexfloat_bb53:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    b _La4b0_hpx_hexfloat_bb57 // branch
_La4b0_hpx_hexfloat_bb54:
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    cbz x1, _La4b0_hpx_hexfloat_bb56 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb55 // branch -> then
_La4b0_hpx_hexfloat_bb55:
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    b _La4b0_hpx_hexfloat_bb56 // branch
_La4b0_hpx_hexfloat_bb56:
    b _La4b0_hpx_hexfloat_bb57 // branch
_La4b0_hpx_hexfloat_bb57:
    b _La4b0_hpx_hexfloat_bb52 // branch
_La4b0_hpx_hexfloat_bb58:
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    cbz x1, _La4b0_hpx_hexfloat_bb60 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb59 // branch -> then
_La4b0_hpx_hexfloat_bb59:
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1072 // hv frame base
    ldp x2, x3, [x15] // hv load L67
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    cbz x1, _La4b0_hpx_hexfloat_bb62 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb61 // branch -> then
_La4b0_hpx_hexfloat_bb60:
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L95
    cbz x1, _La4b0_hpx_hexfloat_bb70 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb69 // branch -> then
_La4b0_hpx_hexfloat_bb61:
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _La4b0_hpx_hexfloat_bb63 // branch
_La4b0_hpx_hexfloat_bb62:
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _La4b0_hpx_hexfloat_bb63 // branch
_La4b0_hpx_hexfloat_bb63:
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    cbz x1, _La4b0_hpx_hexfloat_bb65 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb64 // branch -> then
_La4b0_hpx_hexfloat_bb64:
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    bl hexa_add_slow // binop +
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #34464 // imm 0-15
    movk x3, #1, lsl #16 // imm 16-31
    bl hexa_cmp_gt // binop >
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    cbz x1, _La4b0_hpx_hexfloat_bb67 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb66 // branch -> then
_La4b0_hpx_hexfloat_bb65:
    b _La4b0_hpx_hexfloat_bb60 // branch
_La4b0_hpx_hexfloat_bb66:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #34464 // imm 0-15
    movk x1, #1, lsl #16 // imm 16-31
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    b _La4b0_hpx_hexfloat_bb67 // branch
_La4b0_hpx_hexfloat_bb67:
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    b _La4b0_hpx_hexfloat_bb68 // branch
_La4b0_hpx_hexfloat_bb68:
    b _La4b0_hpx_hexfloat_bb58 // branch
_La4b0_hpx_hexfloat_bb69:
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    stp x0, x1, [sp, #64] // hv store L4
    b _La4b0_hpx_hexfloat_bb70 // branch
_La4b0_hpx_hexfloat_bb70:
    b _La4b0_hpx_hexfloat_bb50 // branch
_La4b0_hpx_hexfloat_bb71:
    ldp x0, x1, [sp, #144] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    cbz x1, _La4b0_hpx_hexfloat_bb74 // br_cond: !payload -> else
    b _La4b0_hpx_hexfloat_bb73 // branch -> then
_La4b0_hpx_hexfloat_bb72:
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    ldp x2, x3, [x15] // hv load L57
    bl hexa_mul // binop *
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    ldp x0, x1, [sp, #128] // hv load L8
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    bl hexa_add_slow // binop +
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #80] // hv load L5
    add x15, sp, #1680 // hv frame base
    ldp x4, x5, [x15] // hv load L105
    ldp x6, x7, [sp, #144] // hv load L9
    bl hpx_pack // call hpx_pack
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add sp, sp, #1712 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_hexfloat_bb73:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #1616 // hv frame base
    stp x0, x1, [x15] // hv store L101
    add x15, sp, #1616 // hv frame base
    ldp x0, x1, [x15] // hv load L101
    add sp, sp, #1712 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_hexfloat_bb74:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    add sp, sp, #1712 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl hpx_nan_payload
.hidden hpx_nan_payload
    .p2align 2
hpx_nan_payload:
    .loc 1 288 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1520 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
    stp x4, x5, [sp, #32] // ingress param 2
_La4b0_hpx_nan_payload_bb0:
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _La4b0_hpx_nan_payload_bb2 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb1 // branch -> then
_La4b0_hpx_nan_payload_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #112] // hv store L7
    b _La4b0_hpx_nan_payload_bb3 // branch
_La4b0_hpx_nan_payload_bb2:
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    b _La4b0_hpx_nan_payload_bb3 // branch
_La4b0_hpx_nan_payload_bb3:
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _La4b0_hpx_nan_payload_bb5 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb4 // branch -> then
_La4b0_hpx_nan_payload_bb4:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #8 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _La4b0_hpx_nan_payload_bb7 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb6 // branch -> then
_La4b0_hpx_nan_payload_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    b _La4b0_hpx_nan_payload_bb34 // branch
_La4b0_hpx_nan_payload_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #120 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _La4b0_hpx_nan_payload_bb9 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb8 // branch -> then
_La4b0_hpx_nan_payload_bb7:
    b _La4b0_hpx_nan_payload_bb5 // branch
_La4b0_hpx_nan_payload_bb8:
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    b _La4b0_hpx_nan_payload_bb10 // branch
_La4b0_hpx_nan_payload_bb9:
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #88 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #272] // hv store L17
    b _La4b0_hpx_nan_payload_bb10 // branch
_La4b0_hpx_nan_payload_bb10:
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _La4b0_hpx_nan_payload_bb12 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb11 // branch -> then
_La4b0_hpx_nan_payload_bb11:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    cbz x1, _La4b0_hpx_nan_payload_bb14 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb13 // branch -> then
_La4b0_hpx_nan_payload_bb12:
    b _La4b0_hpx_nan_payload_bb7 // branch
_La4b0_hpx_nan_payload_bb13:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #384] // hv load L24
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _La4b0_hpx_nan_payload_bb16 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb15 // branch -> then
_La4b0_hpx_nan_payload_bb14:
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _La4b0_hpx_nan_payload_bb33 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb32 // branch -> then
_La4b0_hpx_nan_payload_bb15:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #448] // hv store L28
    b _La4b0_hpx_nan_payload_bb17 // branch
_La4b0_hpx_nan_payload_bb16:
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    b _La4b0_hpx_nan_payload_bb17 // branch
_La4b0_hpx_nan_payload_bb17:
    ldp x0, x1, [sp, #448] // hv load L28
    cbz x1, _La4b0_hpx_nan_payload_bb19 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb18 // branch -> then
_La4b0_hpx_nan_payload_bb18:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    b _La4b0_hpx_nan_payload_bb31 // branch
_La4b0_hpx_nan_payload_bb19:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    cbz x1, _La4b0_hpx_nan_payload_bb21 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb20 // branch -> then
_La4b0_hpx_nan_payload_bb20:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _La4b0_hpx_nan_payload_bb22 // branch
_La4b0_hpx_nan_payload_bb21:
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _La4b0_hpx_nan_payload_bb22 // branch
_La4b0_hpx_nan_payload_bb22:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _La4b0_hpx_nan_payload_bb24 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb23 // branch -> then
_La4b0_hpx_nan_payload_bb23:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    b _La4b0_hpx_nan_payload_bb30 // branch
_La4b0_hpx_nan_payload_bb24:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    cbz x1, _La4b0_hpx_nan_payload_bb26 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb25 // branch -> then
_La4b0_hpx_nan_payload_bb25:
    ldp x0, x1, [sp, #416] // hv load L26
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #70 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _La4b0_hpx_nan_payload_bb27 // branch
_La4b0_hpx_nan_payload_bb26:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    b _La4b0_hpx_nan_payload_bb27 // branch
_La4b0_hpx_nan_payload_bb27:
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _La4b0_hpx_nan_payload_bb29 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb28 // branch -> then
_La4b0_hpx_nan_payload_bb28:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    b _La4b0_hpx_nan_payload_bb29 // branch
_La4b0_hpx_nan_payload_bb29:
    b _La4b0_hpx_nan_payload_bb30 // branch
_La4b0_hpx_nan_payload_bb30:
    b _La4b0_hpx_nan_payload_bb31 // branch
_La4b0_hpx_nan_payload_bb31:
    b _La4b0_hpx_nan_payload_bb14 // branch
_La4b0_hpx_nan_payload_bb32:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add sp, sp, #1520 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_nan_payload_bb33:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #16 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_hpx_nan_payload_bb12 // branch
_La4b0_hpx_nan_payload_bb34:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _La4b0_hpx_nan_payload_bb36 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb35 // branch -> then
_La4b0_hpx_nan_payload_bb35:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    cbz x1, _La4b0_hpx_nan_payload_bb38 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb37 // branch -> then
_La4b0_hpx_nan_payload_bb36:
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    cbz x1, _La4b0_hpx_nan_payload_bb62 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb61 // branch -> then
_La4b0_hpx_nan_payload_bb37:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _La4b0_hpx_nan_payload_bb39 // branch
_La4b0_hpx_nan_payload_bb38:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _La4b0_hpx_nan_payload_bb39 // branch
_La4b0_hpx_nan_payload_bb39:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _La4b0_hpx_nan_payload_bb41 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb40 // branch -> then
_La4b0_hpx_nan_payload_bb40:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _La4b0_hpx_nan_payload_bb53 // branch
_La4b0_hpx_nan_payload_bb41:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    cbz x1, _La4b0_hpx_nan_payload_bb43 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb42 // branch -> then
_La4b0_hpx_nan_payload_bb42:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    b _La4b0_hpx_nan_payload_bb44 // branch
_La4b0_hpx_nan_payload_bb43:
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    b _La4b0_hpx_nan_payload_bb44 // branch
_La4b0_hpx_nan_payload_bb44:
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    cbz x1, _La4b0_hpx_nan_payload_bb46 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb45 // branch -> then
_La4b0_hpx_nan_payload_bb45:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #87 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _La4b0_hpx_nan_payload_bb52 // branch
_La4b0_hpx_nan_payload_bb46:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _La4b0_hpx_nan_payload_bb48 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb47 // branch -> then
_La4b0_hpx_nan_payload_bb47:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #70 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _La4b0_hpx_nan_payload_bb49 // branch
_La4b0_hpx_nan_payload_bb48:
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    b _La4b0_hpx_nan_payload_bb49 // branch
_La4b0_hpx_nan_payload_bb49:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _La4b0_hpx_nan_payload_bb51 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb50 // branch -> then
_La4b0_hpx_nan_payload_bb50:
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #55 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    b _La4b0_hpx_nan_payload_bb51 // branch
_La4b0_hpx_nan_payload_bb51:
    b _La4b0_hpx_nan_payload_bb52 // branch
_La4b0_hpx_nan_payload_bb52:
    b _La4b0_hpx_nan_payload_bb53 // branch
_La4b0_hpx_nan_payload_bb53:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    cbz x1, _La4b0_hpx_nan_payload_bb55 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb54 // branch -> then
_La4b0_hpx_nan_payload_bb54:
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    b _La4b0_hpx_nan_payload_bb56 // branch
_La4b0_hpx_nan_payload_bb55:
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    b _La4b0_hpx_nan_payload_bb56 // branch
_La4b0_hpx_nan_payload_bb56:
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    cbz x1, _La4b0_hpx_nan_payload_bb58 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb57 // branch -> then
_La4b0_hpx_nan_payload_bb57:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add sp, sp, #1520 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_nan_payload_bb58:
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_mul // binop *
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    add x15, sp, #816 // hv frame base
    ldp x2, x3, [x15] // hv load L51
    bl hexa_add_slow // binop +
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    ldp x2, x3, [sp, #64] // hv load L4
    bl hexa_mul // binop *
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #1, lsl #32 // imm 32-47
    bl hexa_div // binop /
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    bl hexa_add_slow // binop +
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #1, lsl #32 // imm 32-47
    bl hexa_mod // binop %
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #1, lsl #32 // imm 32-47
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    cbz x1, _La4b0_hpx_nan_payload_bb60 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb59 // branch -> then
_La4b0_hpx_nan_payload_bb59:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    b _La4b0_hpx_nan_payload_bb60 // branch
_La4b0_hpx_nan_payload_bb60:
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #1, lsl #32 // imm 32-47
    bl hexa_mod // binop %
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_hpx_nan_payload_bb34 // branch
_La4b0_hpx_nan_payload_bb61:
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _La4b0_hpx_nan_payload_bb63 // branch
_La4b0_hpx_nan_payload_bb62:
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    b _La4b0_hpx_nan_payload_bb63 // branch
_La4b0_hpx_nan_payload_bb63:
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    cbz x1, _La4b0_hpx_nan_payload_bb65 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb64 // branch -> then
_La4b0_hpx_nan_payload_bb64:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    add sp, sp, #1520 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_nan_payload_bb65:
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    cbz x1, _La4b0_hpx_nan_payload_bb67 // br_cond: !payload -> else
    b _La4b0_hpx_nan_payload_bb66 // branch -> then
_La4b0_hpx_nan_payload_bb66:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #65535 // imm 0-15
    movk x1, #65535, lsl #16 // imm 16-31
    movk x1, #65535, lsl #32 // imm 32-47
    movk x1, #7, lsl #48 // imm 48-63
    add sp, sp, #1520 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_hpx_nan_payload_bb67:
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #8, lsl #16 // imm 16-31
    bl hexa_mod // binop %
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #1, lsl #32 // imm 32-47
    bl hexa_mul // binop *
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    bl hexa_add_slow // binop +
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    add sp, sp, #1520 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_str_parse_float_hexinfnan
.hidden rt_str_parse_float_hexinfnan
    .p2align 2
rt_str_parse_float_hexinfnan:
    .loc 1 339 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #2288 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_La4b0_rt_str_parse_float_hexinfnan_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    bl hexa_byte_len // call hexa_byte_len
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_rt_str_parse_float_hexinfnan_bb1 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb1:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb3 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb2 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb5 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb4 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb3:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb23 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb22 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb4:
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    b _La4b0_rt_str_parse_float_hexinfnan_bb6 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb5:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #128] // hv store L8
    b _La4b0_rt_str_parse_float_hexinfnan_bb6 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb6:
    ldp x0, x1, [sp, #128] // hv load L8
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb8 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb7 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb7:
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_rt_str_parse_float_hexinfnan_bb9 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb8:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #160] // hv store L10
    b _La4b0_rt_str_parse_float_hexinfnan_bb9 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb9:
    ldp x0, x1, [sp, #160] // hv load L10
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb11 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb10 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb10:
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #192] // hv store L12
    b _La4b0_rt_str_parse_float_hexinfnan_bb12 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb11:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #11 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #192] // hv store L12
    b _La4b0_rt_str_parse_float_hexinfnan_bb12 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb12:
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb14 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb13 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb13:
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #224] // hv store L14
    b _La4b0_rt_str_parse_float_hexinfnan_bb15 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb14:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #12 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #224] // hv store L14
    b _La4b0_rt_str_parse_float_hexinfnan_bb15 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb15:
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb17 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb16 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb16:
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #256] // hv store L16
    b _La4b0_rt_str_parse_float_hexinfnan_bb18 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb17:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #13 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    stp x0, x1, [sp, #256] // hv store L16
    b _La4b0_rt_str_parse_float_hexinfnan_bb18 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb18:
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb20 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb19 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb19:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_rt_str_parse_float_hexinfnan_bb21 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb20:
    b _La4b0_rt_str_parse_float_hexinfnan_bb3 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb21:
    b _La4b0_rt_str_parse_float_hexinfnan_bb1 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb22:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb25 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb24 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb23:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb30 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb29 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb24:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_rt_str_parse_float_hexinfnan_bb28 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb25:
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb27 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb26 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb26:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #48] // hv store L3
    b _La4b0_rt_str_parse_float_hexinfnan_bb27 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb27:
    b _La4b0_rt_str_parse_float_hexinfnan_bb28 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb28:
    b _La4b0_rt_str_parse_float_hexinfnan_bb23 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb29:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb30:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #105 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb32 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb31 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb31:
    movz x0, #3 // hv const_str: TAG_STR
    adrp x1, .LCstr0@PAGE // hv str ptr page
    add x1, x1, .LCstr0@PAGEOFF // hv str ptr off
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _La4b0_rt_str_parse_float_hexinfnan_bb33 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb32:
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb47 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb46 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb33:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb37 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb36 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb34:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #656 // hv frame base
    ldp x2, x3, [x15] // hv load L41
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    ldp x2, x3, [x15] // hv load L48
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb40 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb39 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb35:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb42 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb41 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb36:
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    b _La4b0_rt_str_parse_float_hexinfnan_bb38 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb37:
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    b _La4b0_rt_str_parse_float_hexinfnan_bb38 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb38:
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb35 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb34 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb39:
    b _La4b0_rt_str_parse_float_hexinfnan_bb35 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb40:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    stp x0, x1, [sp, #48] // hv store L3
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _La4b0_rt_str_parse_float_hexinfnan_bb33 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb41:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    b _La4b0_rt_str_parse_float_hexinfnan_bb43 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb42:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    b _La4b0_rt_str_parse_float_hexinfnan_bb43 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb43:
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb45 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb44 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb44:
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb45:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb46:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb49 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb48 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb47:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    add x15, sp, #2048 // hv frame base
    ldp x0, x1, [x15] // hv load L128
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb97 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb96 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb48:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1072 // hv frame base
    ldp x2, x3, [x15] // hv load L67
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1136 // hv frame base
    ldp x2, x3, [x15] // hv load L71
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb51 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb50 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb49:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #2032 // hv frame base
    stp x0, x1, [x15] // hv store L127
    add x15, sp, #2032 // hv frame base
    ldp x0, x1, [x15] // hv load L127
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb50:
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    b _La4b0_rt_str_parse_float_hexinfnan_bb52 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb51:
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    b _La4b0_rt_str_parse_float_hexinfnan_bb52 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb52:
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb54 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb53 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb53:
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    b _La4b0_rt_str_parse_float_hexinfnan_bb55 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb54:
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    b _La4b0_rt_str_parse_float_hexinfnan_bb55 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb55:
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb57 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb56 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb56:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    b _La4b0_rt_str_parse_float_hexinfnan_bb57 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb57:
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb59 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb58 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb58:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    stp x0, x1, [sp, #48] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // imm 0-15
    movk x1, #8, lsl #48 // imm 48-63
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    ldp x0, x1, [sp, #48] // hv load L3
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb61 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb60 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb59:
    b _La4b0_rt_str_parse_float_hexinfnan_bb49 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb60:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #48] // hv load L3
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1408 // hv frame base
    stp x0, x1, [x15] // hv store L88
    add x15, sp, #1408 // hv frame base
    ldp x0, x1, [x15] // hv load L88
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #40 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb63 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb62 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb61:
    ldp x0, x1, [sp, #320] // hv load L20
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    add x15, sp, #1360 // hv frame base
    ldp x4, x5, [x15] // hv load L85
    bl hpx_assemble // call hpx_assemble
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb62:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    b _La4b0_rt_str_parse_float_hexinfnan_bb64 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb63:
    b _La4b0_rt_str_parse_float_hexinfnan_bb61 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb64:
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb66 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb65 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb65:
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1488 // hv frame base
    ldp x2, x3, [x15] // hv load L93
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L95
    add x15, sp, #1536 // hv frame base
    stp x0, x1, [x15] // hv store L96
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb68 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb67 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb66:
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #1840 // hv frame base
    stp x0, x1, [x15] // hv store L115
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb90 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb89 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb67:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #57 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    b _La4b0_rt_str_parse_float_hexinfnan_bb69 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb68:
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    b _La4b0_rt_str_parse_float_hexinfnan_bb69 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb69:
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb71 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb70 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb70:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    b _La4b0_rt_str_parse_float_hexinfnan_bb86 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb71:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb73 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb72 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb72:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #122 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    b _La4b0_rt_str_parse_float_hexinfnan_bb74 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb73:
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    b _La4b0_rt_str_parse_float_hexinfnan_bb74 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb74:
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv load L103
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb76 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb75 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb75:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    b _La4b0_rt_str_parse_float_hexinfnan_bb85 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb76:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb78 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb77 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb77:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #90 // hv const_int val
    bl hexa_cmp_le // binop <=
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L108
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    b _La4b0_rt_str_parse_float_hexinfnan_bb79 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb78:
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    b _La4b0_rt_str_parse_float_hexinfnan_bb79 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb79:
    add x15, sp, #1712 // hv frame base
    ldp x0, x1, [x15] // hv load L107
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb81 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb80 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb80:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    b _La4b0_rt_str_parse_float_hexinfnan_bb84 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb81:
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #95 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1760 // hv frame base
    stp x0, x1, [x15] // hv store L110
    add x15, sp, #1760 // hv frame base
    ldp x0, x1, [x15] // hv load L110
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb83 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb82 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb82:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    b _La4b0_rt_str_parse_float_hexinfnan_bb83 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb83:
    b _La4b0_rt_str_parse_float_hexinfnan_bb84 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb84:
    b _La4b0_rt_str_parse_float_hexinfnan_bb85 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb85:
    b _La4b0_rt_str_parse_float_hexinfnan_bb86 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb86:
    add x15, sp, #1552 // hv frame base
    ldp x0, x1, [x15] // hv load L97
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1792 // hv frame base
    ldp x0, x1, [x15] // hv load L112
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb88 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb87 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb87:
    b _La4b0_rt_str_parse_float_hexinfnan_bb66 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb88:
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    b _La4b0_rt_str_parse_float_hexinfnan_bb64 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb89:
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1488 // hv frame base
    ldp x2, x3, [x15] // hv load L93
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L117
    add x15, sp, #1872 // hv frame base
    ldp x0, x1, [x15] // hv load L117
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #41 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L118
    add x15, sp, #1888 // hv frame base
    ldp x0, x1, [x15] // hv load L118
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    b _La4b0_rt_str_parse_float_hexinfnan_bb91 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb90:
    add x15, sp, #1840 // hv frame base
    ldp x0, x1, [x15] // hv load L115
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    b _La4b0_rt_str_parse_float_hexinfnan_bb91 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb91:
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb93 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb92 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb92:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #1920 // hv frame base
    ldp x2, x3, [x15] // hv load L120
    add x15, sp, #1488 // hv frame base
    ldp x4, x5, [x15] // hv load L93
    bl hpx_nan_payload // call hpx_nan_payload
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    add x15, sp, #1952 // hv frame base
    stp x0, x1, [x15] // hv store L122
    add x15, sp, #1952 // hv frame base
    ldp x0, x1, [x15] // hv load L122
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb95 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb94 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb93:
    b _La4b0_rt_str_parse_float_hexinfnan_bb63 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb94:
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #1952 // hv frame base
    ldp x2, x3, [x15] // hv load L122
    bl hexa_add_slow // binop +
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    b _La4b0_rt_str_parse_float_hexinfnan_bb95 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb95:
    b _La4b0_rt_str_parse_float_hexinfnan_bb93 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb96:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    ldp x2, x3, [sp, #32] // hv load L2
    bl hexa_cmp_lt // binop <
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    b _La4b0_rt_str_parse_float_hexinfnan_bb98 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb97:
    add x15, sp, #2048 // hv frame base
    ldp x0, x1, [x15] // hv load L128
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    b _La4b0_rt_str_parse_float_hexinfnan_bb98 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb98:
    add x15, sp, #2064 // hv frame base
    ldp x0, x1, [x15] // hv load L129
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb100 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb99 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb99:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2128 // hv frame base
    ldp x2, x3, [x15] // hv load L133
    bl hexa_str_byte_at // call hexa_str_byte_at
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #120 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2176 // hv frame base
    stp x0, x1, [x15] // hv store L136
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb102 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb101 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb100:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    add x15, sp, #2272 // hv frame base
    ldp x0, x1, [x15] // hv load L142
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb101:
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    b _La4b0_rt_str_parse_float_hexinfnan_bb103 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb102:
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #88 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv load L138
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    b _La4b0_rt_str_parse_float_hexinfnan_bb103 // branch
_La4b0_rt_str_parse_float_hexinfnan_bb103:
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    cbz x1, _La4b0_rt_str_parse_float_hexinfnan_bb105 // br_cond: !payload -> else
    b _La4b0_rt_str_parse_float_hexinfnan_bb104 // branch -> then
_La4b0_rt_str_parse_float_hexinfnan_bb104:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L140
    ldp x0, x1, [sp, #0] // hv load L0
    add x15, sp, #2240 // hv frame base
    ldp x2, x3, [x15] // hv load L140
    ldp x4, x5, [sp, #32] // hv load L2
    ldp x6, x7, [sp, #320] // hv load L20
    bl hpx_hexfloat // call hpx_hexfloat
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv load L141
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_La4b0_rt_str_parse_float_hexinfnan_bb105:
    b _La4b0_rt_str_parse_float_hexinfnan_bb100 // branch
    movz x0, #4 // ret void: TAG_VOID
    movz x1, #0 // ret void: payload 0
    add sp, sp, #2288 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .rodata
.LCstr0:
    .byte 0x69, 0x6e, 0x66, 0x69, 0x6e, 0x69, 0x74, 0x79, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
