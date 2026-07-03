// num_float_core_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-num-float).
// GENERATED: tool/regen_num_float_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o num_float_core_arm64-linux.s stdlib/runtime/num_float_core.hexa.
//   Provides BOTH num-float halves as a native body: the PARSE half
//   (rt_parse_float_native) — raw-mem + float (__hx_ptr_load8 byte scan +
//   integer mantissa fold + __hx_to_double cast + __hx_payload_{fmul,fdiv}
//   Clinger fast-path scale, bit-exact to strtod on the mantissa<=2^53 AND
//   |exp10|<=22 domain; out of domain returns a TAG_VOID sentinel so the C
//   wrapper falls back to strtod) — AND the FORMAT half (rt_format_float_native,
//   a pure-i64 musl fmt_fp dtoa port, byte-exact to snprintf("%.*g") on its
//   verified domain). These leaves are gen2-native-only (the hexat C-transpile
//   bootstrap cannot lower them), so the body enters the shipped runtime.a ONLY
//   via this seed.
//   ABI: ELF aarch64, rt_parse_float_native no underscore. External: the PARSE half is self-contained (float leaves lower
//   inline, no libm call); the FORMAT half references the hexa string/array
//   runtime (hexa_array_new/push, hexa_bytes_to_str_raw, hexa_arena_alloc,
//   scalar ops) — resolved WITHIN runtime.a (the same archive this .o joins),
//   so no NEW undefined symbol appears at the app link.
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_NATIVE (parse,
//   default-ON) + HEXA_RT_FORMAT_FLOAT_NATIVE (format, R6 opt-IN) + ar this .o
//   into runtime.a so __hx_to_double and the float-repr path delegate to native.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/num_float_core.hexa
.file 1 "stdlib/runtime/num_float_core.hexa"
.text
.globl rt_parse_float_native
.hidden rt_parse_float_native
    .p2align 2
rt_parse_float_native:
    .loc 1 71 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #2880 // sp adj
    stp x0, x1, [sp, #16] // ingress param 0
_L22ed_rt_parse_float_native_bb0:
    ldp x0, x1, [sp, #16] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] // hv store L1
    ldp x0, x1, [sp, #32] // hv load L1
    stp x0, x1, [sp, #48] // hv store L2
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #64] // hv store L3
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L4
    b _L22ed_rt_parse_float_native_bb1 // branch
_L22ed_rt_parse_float_native_bb1:
    ldp x0, x1, [sp, #80] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #96] // hv store L5
    ldp x0, x1, [sp, #96] // hv load L5
    cbz x1, _L22ed_rt_parse_float_native_bb3 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb2 // branch -> then
_L22ed_rt_parse_float_native_bb2:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #112] // hv store L6
    ldp x0, x1, [sp, #112] // hv load L6
    stp x0, x1, [sp, #128] // hv store L7
    ldp x0, x1, [sp, #128] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #32 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #144] // hv store L8
    ldp x0, x1, [sp, #144] // hv load L8
    stp x0, x1, [sp, #160] // hv store L9
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #8 // hv const_int val
    ldp x2, x3, [sp, #128] // hv load L7
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #176] // hv store L10
    ldp x0, x1, [sp, #176] // hv load L10
    stp x0, x1, [sp, #192] // hv store L11
    ldp x0, x1, [sp, #128] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #14 // hv const_int val
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #208] // hv store L12
    ldp x0, x1, [sp, #208] // hv load L12
    stp x0, x1, [sp, #224] // hv store L13
    ldp x0, x1, [sp, #192] // hv load L11
    ldp x2, x3, [sp, #224] // hv load L13
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #240] // hv store L14
    ldp x0, x1, [sp, #240] // hv load L14
    stp x0, x1, [sp, #256] // hv store L15
    ldp x0, x1, [sp, #160] // hv load L9
    ldp x2, x3, [sp, #256] // hv load L15
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #272] // hv store L16
    ldp x0, x1, [sp, #272] // hv load L16
    stp x0, x1, [sp, #288] // hv store L17
    ldp x0, x1, [sp, #288] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #304] // hv store L18
    ldp x0, x1, [sp, #304] // hv load L18
    cbz x1, _L22ed_rt_parse_float_native_bb5 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb4 // branch -> then
_L22ed_rt_parse_float_native_bb3:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #352] // hv store L21
    ldp x0, x1, [sp, #352] // hv load L21
    stp x0, x1, [sp, #368] // hv store L22
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #0] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _L22ed_rt_parse_float_native_bb8 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb7 // branch -> then
_L22ed_rt_parse_float_native_bb4:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #336] // hv store L20
    ldp x0, x1, [sp, #336] // hv load L20
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb6 // branch
_L22ed_rt_parse_float_native_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #80] // hv store L4
    b _L22ed_rt_parse_float_native_bb6 // branch
_L22ed_rt_parse_float_native_bb6:
    b _L22ed_rt_parse_float_native_bb1 // branch
_L22ed_rt_parse_float_native_bb7:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb11 // branch
_L22ed_rt_parse_float_native_bb8:
    ldp x0, x1, [sp, #368] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    cbz x1, _L22ed_rt_parse_float_native_bb10 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb9 // branch -> then
_L22ed_rt_parse_float_native_bb9:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    stp x0, x1, [sp, #0] // hv store L23
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb10 // branch
_L22ed_rt_parse_float_native_bb10:
    b _L22ed_rt_parse_float_native_bb11 // branch
_L22ed_rt_parse_float_native_bb11:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #480] // hv store L30
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #496] // hv store L31
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    b _L22ed_rt_parse_float_native_bb12 // branch
_L22ed_rt_parse_float_native_bb12:
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _L22ed_rt_parse_float_native_bb14 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb13 // branch -> then
_L22ed_rt_parse_float_native_bb13:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #47 // hv const_int val
    add x15, sp, #608 // hv frame base
    ldp x2, x3, [x15] // hv load L38
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #58 // hv const_int val
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add x15, sp, #672 // hv frame base
    ldp x2, x3, [x15] // hv load L42
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _L22ed_rt_parse_float_native_bb16 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb15 // branch -> then
_L22ed_rt_parse_float_native_bb14:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #101 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #69 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1168 // hv frame base
    ldp x2, x3, [x15] // hv load L73
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    cbz x1, _L22ed_rt_parse_float_native_bb30 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb29 // branch -> then
_L22ed_rt_parse_float_native_bb15:
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #13107 // imm 0-15
    movk x1, #13107, lsl #16 // imm 16-31
    movk x1, #13107, lsl #32 // imm 32-47
    movk x1, #3, lsl #48 // imm 48-63
    ldp x2, x3, [sp, #480] // hv load L30
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    cbz x1, _L22ed_rt_parse_float_native_bb18 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb17 // branch -> then
_L22ed_rt_parse_float_native_bb16:
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    cbz x1, _L22ed_rt_parse_float_native_bb23 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb22 // branch -> then
_L22ed_rt_parse_float_native_bb17:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    b _L22ed_rt_parse_float_native_bb19 // branch
_L22ed_rt_parse_float_native_bb18:
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #800 // hv frame base
    ldp x2, x3, [x15] // hv load L50
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    stp x0, x1, [sp, #480] // hv store L30
    b _L22ed_rt_parse_float_native_bb19 // branch
_L22ed_rt_parse_float_native_bb19:
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    stp x0, x1, [sp, #496] // hv store L31
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    cbz x1, _L22ed_rt_parse_float_native_bb21 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb20 // branch -> then
_L22ed_rt_parse_float_native_bb20:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L22ed_rt_parse_float_native_bb21 // branch
_L22ed_rt_parse_float_native_bb21:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb28 // branch
_L22ed_rt_parse_float_native_bb22:
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _L22ed_rt_parse_float_native_bb25 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb24 // branch -> then
_L22ed_rt_parse_float_native_bb23:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    b _L22ed_rt_parse_float_native_bb27 // branch
_L22ed_rt_parse_float_native_bb24:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    b _L22ed_rt_parse_float_native_bb26 // branch
_L22ed_rt_parse_float_native_bb25:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb26 // branch
_L22ed_rt_parse_float_native_bb26:
    b _L22ed_rt_parse_float_native_bb27 // branch
_L22ed_rt_parse_float_native_bb27:
    b _L22ed_rt_parse_float_native_bb28 // branch
_L22ed_rt_parse_float_native_bb28:
    b _L22ed_rt_parse_float_native_bb12 // branch
_L22ed_rt_parse_float_native_bb29:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #1296 // hv frame base
    ldp x0, x1, [x15] // hv load L81
    stp x0, x1, [sp, #64] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1344 // hv frame base
    stp x0, x1, [x15] // hv store L84
    add x15, sp, #1344 // hv frame base
    ldp x0, x1, [x15] // hv load L84
    cbz x1, _L22ed_rt_parse_float_native_bb32 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb31 // branch -> then
_L22ed_rt_parse_float_native_bb30:
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1792 // hv frame base
    ldp x0, x1, [x15] // hv load L112
    cbz x1, _L22ed_rt_parse_float_native_bb45 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb44 // branch -> then
_L22ed_rt_parse_float_native_bb31:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb35 // branch
_L22ed_rt_parse_float_native_bb32:
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    cbz x1, _L22ed_rt_parse_float_native_bb34 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb33 // branch -> then
_L22ed_rt_parse_float_native_bb33:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb34 // branch
_L22ed_rt_parse_float_native_bb34:
    b _L22ed_rt_parse_float_native_bb35 // branch
_L22ed_rt_parse_float_native_bb35:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    b _L22ed_rt_parse_float_native_bb36 // branch
_L22ed_rt_parse_float_native_bb36:
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    cbz x1, _L22ed_rt_parse_float_native_bb38 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb37 // branch -> then
_L22ed_rt_parse_float_native_bb37:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    add x15, sp, #1472 // hv frame base
    stp x0, x1, [x15] // hv store L92
    add x15, sp, #1472 // hv frame base
    ldp x0, x1, [x15] // hv load L92
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #47 // hv const_int val
    add x15, sp, #1488 // hv frame base
    ldp x2, x3, [x15] // hv load L93
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #58 // hv const_int val
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #1536 // hv frame base
    stp x0, x1, [x15] // hv store L96
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    add x15, sp, #1520 // hv frame base
    ldp x0, x1, [x15] // hv load L95
    add x15, sp, #1552 // hv frame base
    ldp x2, x3, [x15] // hv load L97
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    add x15, sp, #1600 // hv frame base
    ldp x0, x1, [x15] // hv load L100
    cbz x1, _L22ed_rt_parse_float_native_bb40 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb39 // branch -> then
_L22ed_rt_parse_float_native_bb38:
    b _L22ed_rt_parse_float_native_bb30 // branch
_L22ed_rt_parse_float_native_bb39:
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1248 // hv frame base
    stp x0, x1, [x15] // hv store L78
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1000 // hv const_int val
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    add x15, sp, #1712 // hv frame base
    ldp x0, x1, [x15] // hv load L107
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L108
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1744 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1744 // hv frame base
    ldp x0, x1, [x15] // hv load L109
    cbz x1, _L22ed_rt_parse_float_native_bb42 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb41 // branch -> then
_L22ed_rt_parse_float_native_bb40:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    b _L22ed_rt_parse_float_native_bb43 // branch
_L22ed_rt_parse_float_native_bb41:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1000 // hv const_int val
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    b _L22ed_rt_parse_float_native_bb42 // branch
_L22ed_rt_parse_float_native_bb42:
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1776 // hv frame base
    stp x0, x1, [x15] // hv store L111
    add x15, sp, #1776 // hv frame base
    ldp x0, x1, [x15] // hv load L111
    stp x0, x1, [sp, #64] // hv store L3
    b _L22ed_rt_parse_float_native_bb43 // branch
_L22ed_rt_parse_float_native_bb43:
    b _L22ed_rt_parse_float_native_bb36 // branch
_L22ed_rt_parse_float_native_bb44:
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    cbz x1, _L22ed_rt_parse_float_native_bb47 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb46 // branch -> then
_L22ed_rt_parse_float_native_bb45:
    ldp x0, x1, [sp, #48] // hv load L2
    ldp x2, x3, [sp, #64] // hv load L3
    add x1, x1, x3 // __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] // __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 // __hx_ptr_load8: TAG_INT
    add x15, sp, #1888 // hv frame base
    stp x0, x1, [x15] // hv store L118
    add x15, sp, #1888 // hv frame base
    ldp x0, x1, [x15] // hv load L118
    add x15, sp, #1904 // hv frame base
    stp x0, x1, [x15] // hv store L119
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    cbz x1, _L22ed_rt_parse_float_native_bb50 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb49 // branch -> then
_L22ed_rt_parse_float_native_bb46:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L22ed_rt_parse_float_native_bb48 // branch
_L22ed_rt_parse_float_native_bb47:
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #1232 // hv frame base
    ldp x2, x3, [x15] // hv load L77
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L117
    add x15, sp, #1872 // hv frame base
    ldp x0, x1, [x15] // hv load L117
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    b _L22ed_rt_parse_float_native_bb48 // branch
_L22ed_rt_parse_float_native_bb48:
    b _L22ed_rt_parse_float_native_bb45 // branch
_L22ed_rt_parse_float_native_bb49:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb50 // branch
_L22ed_rt_parse_float_native_bb50:
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    cbz x1, _L22ed_rt_parse_float_native_bb52 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb51 // branch -> then
_L22ed_rt_parse_float_native_bb51:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb52 // branch
_L22ed_rt_parse_float_native_bb52:
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    cbz x1, _L22ed_rt_parse_float_native_bb54 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb53 // branch -> then
_L22ed_rt_parse_float_native_bb53:
    add x15, sp, #1248 // hv frame base
    ldp x0, x1, [x15] // hv load L78
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #2032 // hv frame base
    stp x0, x1, [x15] // hv store L127
    add x15, sp, #2032 // hv frame base
    ldp x0, x1, [x15] // hv load L127
    cbz x1, _L22ed_rt_parse_float_native_bb56 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb55 // branch -> then
_L22ed_rt_parse_float_native_bb54:
    add x15, sp, #1904 // hv frame base
    ldp x0, x1, [x15] // hv load L119
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    add x15, sp, #2064 // hv frame base
    ldp x0, x1, [x15] // hv load L129
    cbz x1, _L22ed_rt_parse_float_native_bb58 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb57 // branch -> then
_L22ed_rt_parse_float_native_bb55:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb56 // branch
_L22ed_rt_parse_float_native_bb56:
    b _L22ed_rt_parse_float_native_bb54 // branch
_L22ed_rt_parse_float_native_bb57:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb58 // branch
_L22ed_rt_parse_float_native_bb58:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #22 // hv const_int val
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L132
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv load L133
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2112 // hv frame base
    ldp x0, x1, [x15] // hv load L132
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    cbz x1, _L22ed_rt_parse_float_native_bb60 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb59 // branch -> then
_L22ed_rt_parse_float_native_bb59:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb60 // branch
_L22ed_rt_parse_float_native_bb60:
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    cbz x1, _L22ed_rt_parse_float_native_bb62 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb61 // branch -> then
_L22ed_rt_parse_float_native_bb61:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #2224 // hv frame base
    stp x0, x1, [x15] // hv store L139
    add x15, sp, #2224 // hv frame base
    ldp x0, x1, [x15] // hv load L139
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L140
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #22 // hv const_int val
    add x15, sp, #2240 // hv frame base
    ldp x2, x3, [x15] // hv load L140
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv load L141
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    add x15, sp, #2272 // hv frame base
    ldp x0, x1, [x15] // hv load L142
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2288 // hv frame base
    stp x0, x1, [x15] // hv store L143
    add x15, sp, #2288 // hv frame base
    ldp x0, x1, [x15] // hv load L143
    cbz x1, _L22ed_rt_parse_float_native_bb64 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb63 // branch -> then
_L22ed_rt_parse_float_native_bb62:
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2320 // hv frame base
    stp x0, x1, [x15] // hv store L145
    add x15, sp, #2320 // hv frame base
    ldp x0, x1, [x15] // hv load L145
    cbz x1, _L22ed_rt_parse_float_native_bb66 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb65 // branch -> then
_L22ed_rt_parse_float_native_bb63:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    b _L22ed_rt_parse_float_native_bb64 // branch
_L22ed_rt_parse_float_native_bb64:
    b _L22ed_rt_parse_float_native_bb62 // branch
_L22ed_rt_parse_float_native_bb65:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #4 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #2352 // hv frame base
    stp x0, x1, [x15] // hv store L147
    add x15, sp, #2352 // hv frame base
    ldp x0, x1, [x15] // hv load L147
    add sp, sp, #2880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L22ed_rt_parse_float_native_bb66:
    ldp x0, x1, [sp, #480] // hv load L30
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    add x15, sp, #2368 // hv frame base
    stp x0, x1, [x15] // hv store L148
    add x15, sp, #2368 // hv frame base
    ldp x0, x1, [x15] // hv load L148
    add x15, sp, #2384 // hv frame base
    stp x0, x1, [x15] // hv store L149
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #2400 // hv frame base
    stp x0, x1, [x15] // hv store L150
    add x15, sp, #2400 // hv frame base
    ldp x0, x1, [x15] // hv load L150
    add x15, sp, #2416 // hv frame base
    stp x0, x1, [x15] // hv store L151
    add x15, sp, #2416 // hv frame base
    ldp x0, x1, [x15] // hv load L151
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    add x15, sp, #2432 // hv frame base
    stp x0, x1, [x15] // hv store L152
    add x15, sp, #2432 // hv frame base
    ldp x0, x1, [x15] // hv load L152
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L153
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #2464 // hv frame base
    stp x0, x1, [x15] // hv store L154
    add x15, sp, #2464 // hv frame base
    ldp x0, x1, [x15] // hv load L154
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L155
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv load L155
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    add x15, sp, #2496 // hv frame base
    stp x0, x1, [x15] // hv store L156
    add x15, sp, #2496 // hv frame base
    ldp x0, x1, [x15] // hv load L156
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L157
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L158
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #2544 // hv frame base
    stp x0, x1, [x15] // hv store L159
    add x15, sp, #2544 // hv frame base
    ldp x0, x1, [x15] // hv load L159
    add x15, sp, #2560 // hv frame base
    stp x0, x1, [x15] // hv store L160
    add x15, sp, #2560 // hv frame base
    ldp x0, x1, [x15] // hv load L160
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2576 // hv frame base
    stp x0, x1, [x15] // hv store L161
    add x15, sp, #2576 // hv frame base
    ldp x0, x1, [x15] // hv load L161
    cbz x1, _L22ed_rt_parse_float_native_bb68 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb67 // branch -> then
_L22ed_rt_parse_float_native_bb67:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #512 // hv frame base
    ldp x2, x3, [x15] // hv load L32
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #2608 // hv frame base
    stp x0, x1, [x15] // hv store L163
    add x15, sp, #2608 // hv frame base
    ldp x0, x1, [x15] // hv load L163
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L158
    b _L22ed_rt_parse_float_native_bb68 // branch
_L22ed_rt_parse_float_native_bb68:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2624 // hv frame base
    stp x0, x1, [x15] // hv store L164
    b _L22ed_rt_parse_float_native_bb69 // branch
_L22ed_rt_parse_float_native_bb69:
    add x15, sp, #2624 // hv frame base
    ldp x0, x1, [x15] // hv load L164
    add x15, sp, #2528 // hv frame base
    ldp x2, x3, [x15] // hv load L158
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    add x15, sp, #2640 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L165
    cbz x1, _L22ed_rt_parse_float_native_bb71 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb70 // branch -> then
_L22ed_rt_parse_float_native_bb70:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    add x15, sp, #2512 // hv frame base
    ldp x2, x3, [x15] // hv load L157
    fmov d0, x1 // __hx_payload_fmul: d0 = a.f
    fmov d1, x3 // __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 // __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 // __hx_payload_fmul: x1 = result bits
    movz x0, #1 // __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2656 // hv frame base
    stp x0, x1, [x15] // hv store L166
    add x15, sp, #2656 // hv frame base
    ldp x0, x1, [x15] // hv load L166
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L153
    add x15, sp, #2624 // hv frame base
    ldp x0, x1, [x15] // hv load L164
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #2672 // hv frame base
    stp x0, x1, [x15] // hv store L167
    add x15, sp, #2672 // hv frame base
    ldp x0, x1, [x15] // hv load L167
    add x15, sp, #2624 // hv frame base
    stp x0, x1, [x15] // hv store L164
    b _L22ed_rt_parse_float_native_bb69 // branch
_L22ed_rt_parse_float_native_bb71:
    add x15, sp, #2384 // hv frame base
    ldp x0, x1, [x15] // hv load L149
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    add x15, sp, #2560 // hv frame base
    ldp x0, x1, [x15] // hv load L160
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2704 // hv frame base
    stp x0, x1, [x15] // hv store L169
    add x15, sp, #2704 // hv frame base
    ldp x0, x1, [x15] // hv load L169
    cbz x1, _L22ed_rt_parse_float_native_bb73 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb72 // branch -> then
_L22ed_rt_parse_float_native_bb72:
    add x15, sp, #2384 // hv frame base
    ldp x0, x1, [x15] // hv load L149
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    fmov d0, x1 // __hx_payload_fdiv: d0 = a.f
    fmov d1, x3 // __hx_payload_fdiv: d1 = b.f
    fdiv d0, d0, d1 // __hx_payload_fdiv: d0 = a.f fdiv b.f
    fmov x1, d0 // __hx_payload_fdiv: x1 = result bits
    movz x0, #1 // __hx_payload_fdiv: TAG_FLOAT
    add x15, sp, #2736 // hv frame base
    stp x0, x1, [x15] // hv store L171
    add x15, sp, #2736 // hv frame base
    ldp x0, x1, [x15] // hv load L171
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    b _L22ed_rt_parse_float_native_bb74 // branch
_L22ed_rt_parse_float_native_bb73:
    add x15, sp, #2384 // hv frame base
    ldp x0, x1, [x15] // hv load L149
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    fmov d0, x1 // __hx_payload_fmul: d0 = a.f
    fmov d1, x3 // __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 // __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 // __hx_payload_fmul: x1 = result bits
    movz x0, #1 // __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2752 // hv frame base
    stp x0, x1, [x15] // hv store L172
    add x15, sp, #2752 // hv frame base
    ldp x0, x1, [x15] // hv load L172
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    b _L22ed_rt_parse_float_native_bb74 // branch
_L22ed_rt_parse_float_native_bb74:
    ldp x0, x1, [sp, #0] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #2768 // hv frame base
    stp x0, x1, [x15] // hv store L173
    add x15, sp, #2768 // hv frame base
    ldp x0, x1, [x15] // hv load L173
    cbz x1, _L22ed_rt_parse_float_native_bb76 // br_cond: !payload -> else
    b _L22ed_rt_parse_float_native_bb75 // branch -> then
_L22ed_rt_parse_float_native_bb75:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    add x15, sp, #2800 // hv frame base
    stp x0, x1, [x15] // hv store L175
    add x15, sp, #2800 // hv frame base
    ldp x0, x1, [x15] // hv load L175
    add x15, sp, #2816 // hv frame base
    stp x0, x1, [x15] // hv store L176
    add x15, sp, #2816 // hv frame base
    ldp x0, x1, [x15] // hv load L176
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    add x15, sp, #2832 // hv frame base
    stp x0, x1, [x15] // hv store L177
    add x15, sp, #2832 // hv frame base
    ldp x0, x1, [x15] // hv load L177
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L178
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    add x15, sp, #2848 // hv frame base
    ldp x2, x3, [x15] // hv load L178
    fmov d0, x1 // __hx_payload_fmul: d0 = a.f
    fmov d1, x3 // __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 // __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 // __hx_payload_fmul: x1 = result bits
    movz x0, #1 // __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2864 // hv frame base
    stp x0, x1, [x15] // hv store L179
    add x15, sp, #2864 // hv frame base
    ldp x0, x1, [x15] // hv load L179
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    b _L22ed_rt_parse_float_native_bb76 // branch
_L22ed_rt_parse_float_native_bb76:
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    add sp, sp, #2880 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl _g_digits
.hidden _g_digits
    .p2align 2
_g_digits:
    .loc 1 297 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #336 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L22ed__g_digits_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    cbz x1, _L22ed__g_digits_bb2 // br_cond: !payload -> else
    b _L22ed__g_digits_bb1 // branch -> then
_L22ed__g_digits_bb1:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    add sp, sp, #336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L22ed__g_digits_bb2:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #0] // hv load L0
    stp x0, x1, [sp, #96] // hv store L6
    b _L22ed__g_digits_bb3 // branch
_L22ed__g_digits_bb3:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    cbz x1, _L22ed__g_digits_bb5 // br_cond: !payload -> else
    b _L22ed__g_digits_bb4 // branch -> then
_L22ed__g_digits_bb4:
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mod // binop %
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #48 // hv const_int val
    ldp x2, x3, [sp, #128] // hv load L8
    bl hexa_add_slow // binop +
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #144] // hv load L9
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_div // binop /
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    stp x0, x1, [sp, #96] // hv store L6
    b _L22ed__g_digits_bb3 // branch
_L22ed__g_digits_bb5:
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #80] // hv load L5
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    b _L22ed__g_digits_bb6 // branch
_L22ed__g_digits_bb6:
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _L22ed__g_digits_bb8 // br_cond: !payload -> else
    b _L22ed__g_digits_bb7 // branch -> then
_L22ed__g_digits_bb7:
    ldp x0, x1, [sp, #80] // hv load L5
    ldp x2, x3, [sp, #256] // hv load L16
    bl hexa_index_get // index: hexa_index_get
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #208] // hv load L13
    ldp x2, x3, [sp, #288] // hv load L18
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #256] // hv load L16
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #256] // hv store L16
    b _L22ed__g_digits_bb6 // branch
_L22ed__g_digits_bb8:
    ldp x0, x1, [sp, #208] // hv load L13
    add sp, sp, #336 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_format_float_native
.hidden rt_format_float_native
    .p2align 2
rt_format_float_native:
    .loc 1 314 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    movz x15, #7312 // imm 0-15
    sub sp, sp, x15 // sp adj (big frame)
    stp x0, x1, [sp, #16] // ingress param 0
    stp x2, x3, [sp, #32] // ingress param 1
_L22ed_rt_format_float_native_bb0:
    ldp x0, x1, [sp, #16] // hv load L0
    bl hexa_float_to_bits // call hexa_float_to_bits
    stp x0, x1, [sp, #48] // hv store L2
    ldp x0, x1, [sp, #48] // hv load L2
    stp x0, x1, [sp, #64] // hv store L3
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #63 // hv const_int val
    asr x1, x1, x3 // bitwise >>: payload
    movz x0, #0 // bitwise: TAG_INT
    stp x0, x1, [sp, #80] // hv store L4
    ldp x0, x1, [sp, #80] // hv load L4
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    stp x0, x1, [sp, #96] // hv store L5
    ldp x0, x1, [sp, #96] // hv load L5
    stp x0, x1, [sp, #112] // hv store L6
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #52 // hv const_int val
    asr x1, x1, x3 // bitwise >>: payload
    movz x0, #0 // bitwise: TAG_INT
    stp x0, x1, [sp, #128] // hv store L7
    ldp x0, x1, [sp, #128] // hv load L7
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    stp x0, x1, [sp, #144] // hv store L8
    ldp x0, x1, [sp, #144] // hv load L8
    stp x0, x1, [sp, #160] // hv store L9
    ldp x0, x1, [sp, #64] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #65535 // imm 0-15
    movk x3, #65535, lsl #16 // imm 16-31
    movk x3, #65535, lsl #32 // imm 32-47
    movk x3, #15, lsl #48 // imm 48-63
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    stp x0, x1, [sp, #176] // hv store L10
    ldp x0, x1, [sp, #176] // hv load L10
    stp x0, x1, [sp, #192] // hv store L11
    bl hexa_array_new // array_lit: new array
    stp x0, x1, [sp, #208] // hv store L12
    ldp x0, x1, [sp, #208] // hv load L12
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #160] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2047 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _L22ed_rt_format_float_native_bb2 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb1 // branch -> then
_L22ed_rt_format_float_native_bb1:
    ldp x0, x1, [sp, #112] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    cbz x1, _L22ed_rt_format_float_native_bb4 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb3 // branch -> then
_L22ed_rt_format_float_native_bb2:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #448] // hv store L28
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #160] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    cbz x1, _L22ed_rt_format_float_native_bb9 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb8 // branch -> then
_L22ed_rt_format_float_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb4 // branch
_L22ed_rt_format_float_native_bb4:
    ldp x0, x1, [sp, #192] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    cbz x1, _L22ed_rt_format_float_native_bb6 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb5 // branch -> then
_L22ed_rt_format_float_native_bb5:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #105 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb7 // branch
_L22ed_rt_format_float_native_bb6:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #97 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #110 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb7 // branch
_L22ed_rt_format_float_native_bb7:
    ldp x0, x1, [sp, #0] // hv load L13
    bl hexa_bytes_to_str_raw // call hexa_bytes_to_str_raw
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x15, #7312 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L22ed_rt_format_float_native_bb8:
    ldp x0, x1, [sp, #192] // hv load L11
    stp x0, x1, [sp, #448] // hv store L28
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1073 // imm 0-15
    mvn x1, x1 // hv const_int: negate
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    cbz x1, _L22ed_rt_format_float_native_bb11 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb10 // branch -> then
_L22ed_rt_format_float_native_bb9:
    ldp x0, x1, [sp, #192] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // imm 0-15
    movk x3, #16, lsl #48 // imm 48-63
    orr x1, x1, x3 // bitwise |: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #160] // hv load L9
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1075 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    stp x0, x1, [sp, #464] // hv store L29
    b _L22ed_rt_format_float_native_bb14 // branch
_L22ed_rt_format_float_native_bb10:
    ldp x0, x1, [sp, #112] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    cbz x1, _L22ed_rt_format_float_native_bb13 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb12 // branch -> then
_L22ed_rt_format_float_native_bb11:
    b _L22ed_rt_format_float_native_bb14 // branch
_L22ed_rt_format_float_native_bb12:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb13 // branch
_L22ed_rt_format_float_native_bb13:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #592 // hv frame base
    ldp x0, x1, [x15] // hv load L37
    stp x0, x1, [sp, #0] // hv store L13
    ldp x0, x1, [sp, #0] // hv load L13
    bl hexa_bytes_to_str_raw // call hexa_bytes_to_str_raw
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    movz x15, #7312 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L22ed_rt_format_float_native_bb14:
    ldp x0, x1, [sp, #32] // hv load L1
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    cbz x1, _L22ed_rt_format_float_native_bb16 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb15 // branch -> then
_L22ed_rt_format_float_native_bb15:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #6 // hv const_int val
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb16 // branch
_L22ed_rt_format_float_native_bb16:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #512 // hv const_int val
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #400 // hv const_int val
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    bl hexa_array_new // array_lit: new array
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _L22ed_rt_format_float_native_bb17 // branch
_L22ed_rt_format_float_native_bb17:
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    add x15, sp, #704 // hv frame base
    ldp x2, x3, [x15] // hv load L44
    bl hexa_cmp_lt // binop <
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    cbz x1, _L22ed_rt_format_float_native_bb19 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb18 // branch -> then
_L22ed_rt_format_float_native_bb18:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    b _L22ed_rt_format_float_native_bb17 // branch
_L22ed_rt_format_float_native_bb19:
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_cmp_ge // binop >=
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    cbz x1, _L22ed_rt_format_float_native_bb21 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb20 // branch -> then
_L22ed_rt_format_float_native_bb20:
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_mod // binop %
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    add x15, sp, #928 // hv frame base
    ldp x4, x5, [x15] // hv load L58
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    ldp x0, x1, [sp, #448] // hv load L28
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_div // binop /
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    add x15, sp, #960 // hv frame base
    ldp x4, x5, [x15] // hv load L60
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _L22ed_rt_format_float_native_bb22 // branch
_L22ed_rt_format_float_native_bb21:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    ldp x4, x5, [sp, #448] // hv load L28
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    b _L22ed_rt_format_float_native_bb22 // branch
_L22ed_rt_format_float_native_bb22:
    b _L22ed_rt_format_float_native_bb23 // branch
_L22ed_rt_format_float_native_bb23:
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _L22ed_rt_format_float_native_bb25 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb24 // branch -> then
_L22ed_rt_format_float_native_bb24:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    ldp x0, x1, [sp, #464] // hv load L29
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #29 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    cbz x1, _L22ed_rt_format_float_native_bb27 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb26 // branch -> then
_L22ed_rt_format_float_native_bb25:
    b _L22ed_rt_format_float_native_bb39 // branch
_L22ed_rt_format_float_native_bb26:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #29 // hv const_int val
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    b _L22ed_rt_format_float_native_bb27 // branch
_L22ed_rt_format_float_native_bb27:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    b _L22ed_rt_format_float_native_bb28 // branch
_L22ed_rt_format_float_native_bb28:
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_ge // binop >=
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    cbz x1, _L22ed_rt_format_float_native_bb30 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb29 // branch -> then
_L22ed_rt_format_float_native_bb29:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1088 // hv frame base
    ldp x2, x3, [x15] // hv load L68
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1024 // hv frame base
    ldp x2, x3, [x15] // hv load L64
    lsl x1, x1, x3 // bitwise <<: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    add x15, sp, #1008 // hv frame base
    ldp x2, x3, [x15] // hv load L63
    bl hexa_add_slow // binop +
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_mod // binop %
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1088 // hv frame base
    ldp x2, x3, [x15] // hv load L68
    add x15, sp, #1184 // hv frame base
    ldp x4, x5, [x15] // hv load L74
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_div // binop /
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    b _L22ed_rt_format_float_native_bb28 // branch
_L22ed_rt_format_float_native_bb30:
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    cbz x1, _L22ed_rt_format_float_native_bb32 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb31 // branch -> then
_L22ed_rt_format_float_native_bb31:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1264 // hv frame base
    stp x0, x1, [x15] // hv store L79
    add x15, sp, #1264 // hv frame base
    ldp x0, x1, [x15] // hv load L79
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    add x15, sp, #1008 // hv frame base
    ldp x4, x5, [x15] // hv load L63
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    b _L22ed_rt_format_float_native_bb32 // branch
_L22ed_rt_format_float_native_bb32:
    b _L22ed_rt_format_float_native_bb33 // branch
_L22ed_rt_format_float_native_bb33:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_gt // binop >
    add x15, sp, #1280 // hv frame base
    stp x0, x1, [x15] // hv store L80
    add x15, sp, #1280 // hv frame base
    ldp x0, x1, [x15] // hv load L80
    cbz x1, _L22ed_rt_format_float_native_bb35 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb34 // branch -> then
_L22ed_rt_format_float_native_bb34:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1296 // hv frame base
    stp x0, x1, [x15] // hv store L81
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1296 // hv frame base
    ldp x2, x3, [x15] // hv load L81
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1312 // hv frame base
    stp x0, x1, [x15] // hv store L82
    add x15, sp, #1312 // hv frame base
    ldp x0, x1, [x15] // hv load L82
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1328 // hv frame base
    stp x0, x1, [x15] // hv store L83
    add x15, sp, #1328 // hv frame base
    ldp x0, x1, [x15] // hv load L83
    cbz x1, _L22ed_rt_format_float_native_bb37 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb36 // branch -> then
_L22ed_rt_format_float_native_bb35:
    ldp x0, x1, [sp, #464] // hv load L29
    add x15, sp, #1024 // hv frame base
    ldp x2, x3, [x15] // hv load L64
    bl hexa_sub // binop -
    add x15, sp, #1376 // hv frame base
    stp x0, x1, [x15] // hv store L86
    add x15, sp, #1376 // hv frame base
    ldp x0, x1, [x15] // hv load L86
    stp x0, x1, [sp, #464] // hv store L29
    b _L22ed_rt_format_float_native_bb23 // branch
_L22ed_rt_format_float_native_bb36:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1360 // hv frame base
    stp x0, x1, [x15] // hv store L85
    add x15, sp, #1360 // hv frame base
    ldp x0, x1, [x15] // hv load L85
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb38 // branch
_L22ed_rt_format_float_native_bb37:
    b _L22ed_rt_format_float_native_bb35 // branch
_L22ed_rt_format_float_native_bb38:
    b _L22ed_rt_format_float_native_bb33 // branch
_L22ed_rt_format_float_native_bb39:
    ldp x0, x1, [sp, #464] // hv load L29
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #1392 // hv frame base
    stp x0, x1, [x15] // hv store L87
    add x15, sp, #1392 // hv frame base
    ldp x0, x1, [x15] // hv load L87
    cbz x1, _L22ed_rt_format_float_native_bb41 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb40 // branch -> then
_L22ed_rt_format_float_native_bb40:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #1408 // hv frame base
    stp x0, x1, [x15] // hv store L88
    movz x0, #0 // unop -: a.tag=TAG_INT
    movz x1, #0 // unop -: a.val=0
    ldp x2, x3, [sp, #464] // hv load L29
    bl hexa_sub // unop -: 0 - x
    add x15, sp, #1424 // hv frame base
    stp x0, x1, [x15] // hv store L89
    add x15, sp, #1424 // hv frame base
    ldp x0, x1, [x15] // hv load L89
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    add x15, sp, #1440 // hv frame base
    ldp x0, x1, [x15] // hv load L90
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_gt // binop >
    add x15, sp, #1456 // hv frame base
    stp x0, x1, [x15] // hv store L91
    add x15, sp, #1456 // hv frame base
    ldp x0, x1, [x15] // hv load L91
    cbz x1, _L22ed_rt_format_float_native_bb43 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb42 // branch -> then
_L22ed_rt_format_float_native_bb41:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_cmp_lt // binop <
    add x15, sp, #2016 // hv frame base
    stp x0, x1, [x15] // hv store L126
    add x15, sp, #2016 // hv frame base
    ldp x0, x1, [x15] // hv load L126
    cbz x1, _L22ed_rt_format_float_native_bb54 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb53 // branch -> then
_L22ed_rt_format_float_native_bb42:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #1440 // hv frame base
    stp x0, x1, [x15] // hv store L90
    b _L22ed_rt_format_float_native_bb43 // branch
_L22ed_rt_format_float_native_bb43:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #17 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1488 // hv frame base
    stp x0, x1, [x15] // hv store L93
    add x15, sp, #1488 // hv frame base
    ldp x0, x1, [x15] // hv load L93
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #8 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1504 // hv frame base
    stp x0, x1, [x15] // hv store L94
    add x15, sp, #1504 // hv frame base
    ldp x0, x1, [x15] // hv load L94
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #1520 // hv frame base
    stp x0, x1, [x15] // hv store L95
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1520 // hv frame base
    ldp x2, x3, [x15] // hv load L95
    bl hexa_add_slow // binop +
    add x15, sp, #1536 // hv frame base
    stp x0, x1, [x15] // hv store L96
    add x15, sp, #1536 // hv frame base
    ldp x0, x1, [x15] // hv load L96
    add x15, sp, #1552 // hv frame base
    stp x0, x1, [x15] // hv store L97
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    lsl x1, x1, x3 // bitwise <<: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1568 // hv frame base
    stp x0, x1, [x15] // hv store L98
    add x15, sp, #1568 // hv frame base
    ldp x0, x1, [x15] // hv load L98
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #1584 // hv frame base
    stp x0, x1, [x15] // hv store L99
    add x15, sp, #1584 // hv frame base
    ldp x0, x1, [x15] // hv load L99
    add x15, sp, #1600 // hv frame base
    stp x0, x1, [x15] // hv store L100
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #51712 // imm 0-15
    movk x1, #15258, lsl #16 // imm 16-31
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    asr x1, x1, x3 // bitwise >>: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1616 // hv frame base
    stp x0, x1, [x15] // hv store L101
    add x15, sp, #1616 // hv frame base
    ldp x0, x1, [x15] // hv load L101
    add x15, sp, #1632 // hv frame base
    stp x0, x1, [x15] // hv store L102
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    b _L22ed_rt_format_float_native_bb44 // branch
_L22ed_rt_format_float_native_bb44:
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv load L103
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_cmp_lt // binop <
    add x15, sp, #1664 // hv frame base
    stp x0, x1, [x15] // hv store L104
    add x15, sp, #1664 // hv frame base
    ldp x0, x1, [x15] // hv load L104
    cbz x1, _L22ed_rt_format_float_native_bb46 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb45 // branch -> then
_L22ed_rt_format_float_native_bb45:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1680 // hv frame base
    stp x0, x1, [x15] // hv store L105
    add x15, sp, #1680 // hv frame base
    ldp x0, x1, [x15] // hv load L105
    add x15, sp, #1600 // hv frame base
    ldp x2, x3, [x15] // hv load L100
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1696 // hv frame base
    stp x0, x1, [x15] // hv store L106
    add x15, sp, #1696 // hv frame base
    ldp x0, x1, [x15] // hv load L106
    add x15, sp, #1712 // hv frame base
    stp x0, x1, [x15] // hv store L107
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1728 // hv frame base
    stp x0, x1, [x15] // hv store L108
    add x15, sp, #1728 // hv frame base
    ldp x0, x1, [x15] // hv load L108
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    asr x1, x1, x3 // bitwise >>: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #1744 // hv frame base
    stp x0, x1, [x15] // hv store L109
    add x15, sp, #1744 // hv frame base
    ldp x0, x1, [x15] // hv load L109
    add x15, sp, #1408 // hv frame base
    ldp x2, x3, [x15] // hv load L88
    bl hexa_add_slow // binop +
    add x15, sp, #1760 // hv frame base
    stp x0, x1, [x15] // hv store L110
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #1648 // hv frame base
    ldp x2, x3, [x15] // hv load L103
    add x15, sp, #1760 // hv frame base
    ldp x4, x5, [x15] // hv load L110
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #1632 // hv frame base
    ldp x0, x1, [x15] // hv load L102
    add x15, sp, #1712 // hv frame base
    ldp x2, x3, [x15] // hv load L107
    bl hexa_mul // binop *
    add x15, sp, #1776 // hv frame base
    stp x0, x1, [x15] // hv store L111
    add x15, sp, #1776 // hv frame base
    ldp x0, x1, [x15] // hv load L111
    add x15, sp, #1408 // hv frame base
    stp x0, x1, [x15] // hv store L88
    add x15, sp, #1648 // hv frame base
    ldp x0, x1, [x15] // hv load L103
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1792 // hv frame base
    stp x0, x1, [x15] // hv store L112
    add x15, sp, #1792 // hv frame base
    ldp x0, x1, [x15] // hv load L112
    add x15, sp, #1648 // hv frame base
    stp x0, x1, [x15] // hv store L103
    b _L22ed_rt_format_float_native_bb44 // branch
_L22ed_rt_format_float_native_bb46:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #1808 // hv frame base
    stp x0, x1, [x15] // hv store L113
    add x15, sp, #1808 // hv frame base
    ldp x0, x1, [x15] // hv load L113
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #1824 // hv frame base
    stp x0, x1, [x15] // hv store L114
    add x15, sp, #1824 // hv frame base
    ldp x0, x1, [x15] // hv load L114
    cbz x1, _L22ed_rt_format_float_native_bb48 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb47 // branch -> then
_L22ed_rt_format_float_native_bb47:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1856 // hv frame base
    stp x0, x1, [x15] // hv store L116
    add x15, sp, #1856 // hv frame base
    ldp x0, x1, [x15] // hv load L116
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _L22ed_rt_format_float_native_bb48 // branch
_L22ed_rt_format_float_native_bb48:
    add x15, sp, #1408 // hv frame base
    ldp x0, x1, [x15] // hv load L88
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #1872 // hv frame base
    stp x0, x1, [x15] // hv store L117
    add x15, sp, #1872 // hv frame base
    ldp x0, x1, [x15] // hv load L117
    cbz x1, _L22ed_rt_format_float_native_bb50 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb49 // branch -> then
_L22ed_rt_format_float_native_bb49:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    add x15, sp, #1408 // hv frame base
    ldp x4, x5, [x15] // hv load L88
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #1904 // hv frame base
    stp x0, x1, [x15] // hv store L119
    add x15, sp, #1904 // hv frame base
    ldp x0, x1, [x15] // hv load L119
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb50 // branch
_L22ed_rt_format_float_native_bb50:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_sub // binop -
    add x15, sp, #1920 // hv frame base
    stp x0, x1, [x15] // hv store L120
    add x15, sp, #1920 // hv frame base
    ldp x0, x1, [x15] // hv load L120
    add x15, sp, #1552 // hv frame base
    ldp x2, x3, [x15] // hv load L97
    bl hexa_cmp_gt // binop >
    add x15, sp, #1936 // hv frame base
    stp x0, x1, [x15] // hv store L121
    add x15, sp, #1936 // hv frame base
    ldp x0, x1, [x15] // hv load L121
    cbz x1, _L22ed_rt_format_float_native_bb52 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb51 // branch -> then
_L22ed_rt_format_float_native_bb51:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #1552 // hv frame base
    ldp x2, x3, [x15] // hv load L97
    bl hexa_add_slow // binop +
    add x15, sp, #1968 // hv frame base
    stp x0, x1, [x15] // hv store L123
    add x15, sp, #1968 // hv frame base
    ldp x0, x1, [x15] // hv load L123
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb52 // branch
_L22ed_rt_format_float_native_bb52:
    ldp x0, x1, [sp, #464] // hv load L29
    add x15, sp, #1440 // hv frame base
    ldp x2, x3, [x15] // hv load L90
    bl hexa_add_slow // binop +
    add x15, sp, #1984 // hv frame base
    stp x0, x1, [x15] // hv store L124
    add x15, sp, #1984 // hv frame base
    ldp x0, x1, [x15] // hv load L124
    stp x0, x1, [sp, #464] // hv store L29
    b _L22ed_rt_format_float_native_bb39 // branch
_L22ed_rt_format_float_native_bb53:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_sub // binop -
    add x15, sp, #2064 // hv frame base
    stp x0, x1, [x15] // hv store L129
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #2064 // hv frame base
    ldp x2, x3, [x15] // hv load L129
    bl hexa_mul // binop *
    add x15, sp, #2080 // hv frame base
    stp x0, x1, [x15] // hv store L130
    add x15, sp, #2080 // hv frame base
    ldp x0, x1, [x15] // hv load L130
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    b _L22ed_rt_format_float_native_bb55 // branch
_L22ed_rt_format_float_native_bb54:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #103 // hv const_int val
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #2000 // hv frame base
    ldp x2, x3, [x15] // hv load L125
    bl hexa_sub // binop -
    add x15, sp, #2176 // hv frame base
    stp x0, x1, [x15] // hv store L136
    add x15, sp, #2176 // hv frame base
    ldp x0, x1, [x15] // hv load L136
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #2208 // hv frame base
    stp x0, x1, [x15] // hv store L138
    add x15, sp, #2208 // hv frame base
    ldp x0, x1, [x15] // hv load L138
    cbz x1, _L22ed_rt_format_float_native_bb59 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb58 // branch -> then
_L22ed_rt_format_float_native_bb55:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2096 // hv frame base
    stp x0, x1, [x15] // hv store L131
    add x15, sp, #2096 // hv frame base
    ldp x0, x1, [x15] // hv load L131
    add x15, sp, #2048 // hv frame base
    ldp x2, x3, [x15] // hv load L128
    bl hexa_cmp_ge // binop >=
    add x15, sp, #2112 // hv frame base
    stp x0, x1, [x15] // hv store L132
    add x15, sp, #2112 // hv frame base
    ldp x0, x1, [x15] // hv load L132
    cbz x1, _L22ed_rt_format_float_native_bb57 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb56 // branch -> then
_L22ed_rt_format_float_native_bb56:
    add x15, sp, #2048 // hv frame base
    ldp x0, x1, [x15] // hv load L128
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #2128 // hv frame base
    stp x0, x1, [x15] // hv store L133
    add x15, sp, #2128 // hv frame base
    ldp x0, x1, [x15] // hv load L133
    add x15, sp, #2048 // hv frame base
    stp x0, x1, [x15] // hv store L128
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2144 // hv frame base
    stp x0, x1, [x15] // hv store L134
    add x15, sp, #2144 // hv frame base
    ldp x0, x1, [x15] // hv load L134
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    b _L22ed_rt_format_float_native_bb55 // branch
_L22ed_rt_format_float_native_bb57:
    b _L22ed_rt_format_float_native_bb54 // branch
_L22ed_rt_format_float_native_bb58:
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2240 // hv frame base
    stp x0, x1, [x15] // hv store L140
    add x15, sp, #2240 // hv frame base
    ldp x0, x1, [x15] // hv load L140
    add x15, sp, #2192 // hv frame base
    stp x0, x1, [x15] // hv store L137
    b _L22ed_rt_format_float_native_bb59 // branch
_L22ed_rt_format_float_native_bb59:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_sub // binop -
    add x15, sp, #2256 // hv frame base
    stp x0, x1, [x15] // hv store L141
    add x15, sp, #2256 // hv frame base
    ldp x0, x1, [x15] // hv load L141
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2272 // hv frame base
    stp x0, x1, [x15] // hv store L142
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #2272 // hv frame base
    ldp x2, x3, [x15] // hv load L142
    bl hexa_mul // binop *
    add x15, sp, #2288 // hv frame base
    stp x0, x1, [x15] // hv store L143
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    add x15, sp, #2288 // hv frame base
    ldp x2, x3, [x15] // hv load L143
    bl hexa_cmp_lt // binop <
    add x15, sp, #2304 // hv frame base
    stp x0, x1, [x15] // hv store L144
    add x15, sp, #2304 // hv frame base
    ldp x0, x1, [x15] // hv load L144
    cbz x1, _L22ed_rt_format_float_native_bb61 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb60 // branch -> then
_L22ed_rt_format_float_native_bb60:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1024 // hv const_int val
    add x15, sp, #2336 // hv frame base
    stp x0, x1, [x15] // hv store L146
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2352 // hv frame base
    stp x0, x1, [x15] // hv store L147
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #2336 // hv frame base
    ldp x2, x3, [x15] // hv load L146
    bl hexa_mul // binop *
    add x15, sp, #2368 // hv frame base
    stp x0, x1, [x15] // hv store L148
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    add x15, sp, #2368 // hv frame base
    ldp x2, x3, [x15] // hv load L148
    bl hexa_add_slow // binop +
    add x15, sp, #2384 // hv frame base
    stp x0, x1, [x15] // hv store L149
    add x15, sp, #2384 // hv frame base
    ldp x0, x1, [x15] // hv load L149
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #2400 // hv frame base
    stp x0, x1, [x15] // hv store L150
    add x15, sp, #2400 // hv frame base
    ldp x0, x1, [x15] // hv load L150
    add x15, sp, #2336 // hv frame base
    ldp x2, x3, [x15] // hv load L146
    bl hexa_sub // binop -
    add x15, sp, #2416 // hv frame base
    stp x0, x1, [x15] // hv store L151
    add x15, sp, #2352 // hv frame base
    ldp x0, x1, [x15] // hv load L147
    add x15, sp, #2416 // hv frame base
    ldp x2, x3, [x15] // hv load L151
    bl hexa_add_slow // binop +
    add x15, sp, #2432 // hv frame base
    stp x0, x1, [x15] // hv store L152
    add x15, sp, #2432 // hv frame base
    ldp x0, x1, [x15] // hv load L152
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L153
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #2336 // hv frame base
    ldp x2, x3, [x15] // hv load L146
    bl hexa_mul // binop *
    add x15, sp, #2464 // hv frame base
    stp x0, x1, [x15] // hv store L154
    add x15, sp, #2192 // hv frame base
    ldp x0, x1, [x15] // hv load L137
    add x15, sp, #2464 // hv frame base
    ldp x2, x3, [x15] // hv load L154
    bl hexa_add_slow // binop +
    add x15, sp, #2480 // hv frame base
    stp x0, x1, [x15] // hv store L155
    add x15, sp, #2480 // hv frame base
    ldp x0, x1, [x15] // hv load L155
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_mod // binop %
    add x15, sp, #2496 // hv frame base
    stp x0, x1, [x15] // hv store L156
    add x15, sp, #2496 // hv frame base
    ldp x0, x1, [x15] // hv load L156
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L157
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L158
    add x15, sp, #2512 // hv frame base
    ldp x0, x1, [x15] // hv load L157
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2544 // hv frame base
    stp x0, x1, [x15] // hv store L159
    add x15, sp, #2544 // hv frame base
    ldp x0, x1, [x15] // hv load L159
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L157
    b _L22ed_rt_format_float_native_bb62 // branch
_L22ed_rt_format_float_native_bb61:
    b _L22ed_rt_format_float_native_bb99 // branch
_L22ed_rt_format_float_native_bb62:
    add x15, sp, #2512 // hv frame base
    ldp x0, x1, [x15] // hv load L157
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_lt // binop <
    add x15, sp, #2560 // hv frame base
    stp x0, x1, [x15] // hv store L160
    add x15, sp, #2560 // hv frame base
    ldp x0, x1, [x15] // hv load L160
    cbz x1, _L22ed_rt_format_float_native_bb64 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb63 // branch -> then
_L22ed_rt_format_float_native_bb63:
    add x15, sp, #2528 // hv frame base
    ldp x0, x1, [x15] // hv load L158
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #2576 // hv frame base
    stp x0, x1, [x15] // hv store L161
    add x15, sp, #2576 // hv frame base
    ldp x0, x1, [x15] // hv load L161
    add x15, sp, #2528 // hv frame base
    stp x0, x1, [x15] // hv store L158
    add x15, sp, #2512 // hv frame base
    ldp x0, x1, [x15] // hv load L157
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2592 // hv frame base
    stp x0, x1, [x15] // hv store L162
    add x15, sp, #2592 // hv frame base
    ldp x0, x1, [x15] // hv load L162
    add x15, sp, #2512 // hv frame base
    stp x0, x1, [x15] // hv store L157
    b _L22ed_rt_format_float_native_bb62 // branch
_L22ed_rt_format_float_native_bb64:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2608 // hv frame base
    stp x0, x1, [x15] // hv store L163
    add x15, sp, #2608 // hv frame base
    ldp x0, x1, [x15] // hv load L163
    add x15, sp, #2528 // hv frame base
    ldp x2, x3, [x15] // hv load L158
    bl hexa_mod // binop %
    add x15, sp, #2624 // hv frame base
    stp x0, x1, [x15] // hv store L164
    add x15, sp, #2624 // hv frame base
    ldp x0, x1, [x15] // hv load L164
    add x15, sp, #2640 // hv frame base
    stp x0, x1, [x15] // hv store L165
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L165
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #2656 // hv frame base
    stp x0, x1, [x15] // hv store L166
    add x15, sp, #2656 // hv frame base
    ldp x0, x1, [x15] // hv load L166
    cbz x1, _L22ed_rt_format_float_native_bb66 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb65 // branch -> then
_L22ed_rt_format_float_native_bb65:
    add x15, sp, #2656 // hv frame base
    ldp x0, x1, [x15] // hv load L166
    add x15, sp, #2672 // hv frame base
    stp x0, x1, [x15] // hv store L167
    b _L22ed_rt_format_float_native_bb67 // branch
_L22ed_rt_format_float_native_bb66:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #2688 // hv frame base
    stp x0, x1, [x15] // hv store L168
    add x15, sp, #2688 // hv frame base
    ldp x0, x1, [x15] // hv load L168
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #2704 // hv frame base
    stp x0, x1, [x15] // hv store L169
    add x15, sp, #2704 // hv frame base
    ldp x0, x1, [x15] // hv load L169
    add x15, sp, #2672 // hv frame base
    stp x0, x1, [x15] // hv store L167
    b _L22ed_rt_format_float_native_bb67 // branch
_L22ed_rt_format_float_native_bb67:
    add x15, sp, #2672 // hv frame base
    ldp x0, x1, [x15] // hv load L167
    add x15, sp, #2720 // hv frame base
    stp x0, x1, [x15] // hv store L170
    add x15, sp, #2720 // hv frame base
    ldp x0, x1, [x15] // hv load L170
    cbz x1, _L22ed_rt_format_float_native_bb69 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb68 // branch -> then
_L22ed_rt_format_float_native_bb68:
    add x15, sp, #2528 // hv frame base
    ldp x0, x1, [x15] // hv load L158
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_div // binop /
    add x15, sp, #2752 // hv frame base
    stp x0, x1, [x15] // hv store L172
    add x15, sp, #2752 // hv frame base
    ldp x0, x1, [x15] // hv load L172
    add x15, sp, #2768 // hv frame base
    stp x0, x1, [x15] // hv store L173
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #2784 // hv frame base
    stp x0, x1, [x15] // hv store L174
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2800 // hv frame base
    stp x0, x1, [x15] // hv store L175
    add x15, sp, #2800 // hv frame base
    ldp x0, x1, [x15] // hv load L175
    add x15, sp, #2528 // hv frame base
    ldp x2, x3, [x15] // hv load L158
    bl hexa_div // binop /
    add x15, sp, #2816 // hv frame base
    stp x0, x1, [x15] // hv store L176
    add x15, sp, #2816 // hv frame base
    ldp x0, x1, [x15] // hv load L176
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #2832 // hv frame base
    stp x0, x1, [x15] // hv store L177
    add x15, sp, #2832 // hv frame base
    ldp x0, x1, [x15] // hv load L177
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #2848 // hv frame base
    stp x0, x1, [x15] // hv store L178
    add x15, sp, #2848 // hv frame base
    ldp x0, x1, [x15] // hv load L178
    cbz x1, _L22ed_rt_format_float_native_bb71 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb70 // branch -> then
_L22ed_rt_format_float_native_bb69:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3488 // hv frame base
    stp x0, x1, [x15] // hv store L218
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #3488 // hv frame base
    ldp x2, x3, [x15] // hv load L218
    bl hexa_cmp_gt // binop >
    add x15, sp, #3504 // hv frame base
    stp x0, x1, [x15] // hv store L219
    add x15, sp, #3504 // hv frame base
    ldp x0, x1, [x15] // hv load L219
    cbz x1, _L22ed_rt_format_float_native_bb98 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb97 // branch -> then
_L22ed_rt_format_float_native_bb70:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2784 // hv frame base
    stp x0, x1, [x15] // hv store L174
    b _L22ed_rt_format_float_native_bb71 // branch
_L22ed_rt_format_float_native_bb71:
    add x15, sp, #2528 // hv frame base
    ldp x0, x1, [x15] // hv load L158
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51712 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_eq // binop ==
    add x15, sp, #2880 // hv frame base
    stp x0, x1, [x15] // hv store L180
    add x15, sp, #2880 // hv frame base
    ldp x0, x1, [x15] // hv load L180
    cbz x1, _L22ed_rt_format_float_native_bb73 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb72 // branch -> then
_L22ed_rt_format_float_native_bb72:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_gt // binop >
    add x15, sp, #2912 // hv frame base
    stp x0, x1, [x15] // hv store L182
    add x15, sp, #2912 // hv frame base
    ldp x0, x1, [x15] // hv load L182
    cbz x1, _L22ed_rt_format_float_native_bb75 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb74 // branch -> then
_L22ed_rt_format_float_native_bb73:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L165
    add x15, sp, #2768 // hv frame base
    ldp x2, x3, [x15] // hv load L173
    bl hexa_cmp_lt // binop <
    add x15, sp, #3040 // hv frame base
    stp x0, x1, [x15] // hv store L190
    add x15, sp, #3040 // hv frame base
    ldp x0, x1, [x15] // hv load L190
    cbz x1, _L22ed_rt_format_float_native_bb79 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb78 // branch -> then
_L22ed_rt_format_float_native_bb74:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #2944 // hv frame base
    stp x0, x1, [x15] // hv store L184
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2944 // hv frame base
    ldp x2, x3, [x15] // hv load L184
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #2960 // hv frame base
    stp x0, x1, [x15] // hv store L185
    add x15, sp, #2960 // hv frame base
    ldp x0, x1, [x15] // hv load L185
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    and x1, x1, x3 // bitwise &: payload
    movz x0, #0 // bitwise: TAG_INT
    add x15, sp, #2976 // hv frame base
    stp x0, x1, [x15] // hv store L186
    add x15, sp, #2976 // hv frame base
    ldp x0, x1, [x15] // hv load L186
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #2992 // hv frame base
    stp x0, x1, [x15] // hv store L187
    add x15, sp, #2992 // hv frame base
    ldp x0, x1, [x15] // hv load L187
    cbz x1, _L22ed_rt_format_float_native_bb77 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb76 // branch -> then
_L22ed_rt_format_float_native_bb75:
    b _L22ed_rt_format_float_native_bb73 // branch
_L22ed_rt_format_float_native_bb76:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #2784 // hv frame base
    stp x0, x1, [x15] // hv store L174
    b _L22ed_rt_format_float_native_bb77 // branch
_L22ed_rt_format_float_native_bb77:
    b _L22ed_rt_format_float_native_bb75 // branch
_L22ed_rt_format_float_native_bb78:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    b _L22ed_rt_format_float_native_bb86 // branch
_L22ed_rt_format_float_native_bb79:
    add x15, sp, #2640 // hv frame base
    ldp x0, x1, [x15] // hv load L165
    add x15, sp, #2768 // hv frame base
    ldp x2, x3, [x15] // hv load L173
    bl hexa_eq // binop ==
    add x15, sp, #3072 // hv frame base
    stp x0, x1, [x15] // hv store L192
    add x15, sp, #3072 // hv frame base
    ldp x0, x1, [x15] // hv load L192
    cbz x1, _L22ed_rt_format_float_native_bb81 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb80 // branch -> then
_L22ed_rt_format_float_native_bb80:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3104 // hv frame base
    stp x0, x1, [x15] // hv store L194
    add x15, sp, #3104 // hv frame base
    ldp x0, x1, [x15] // hv load L194
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_eq // binop ==
    add x15, sp, #3120 // hv frame base
    stp x0, x1, [x15] // hv store L195
    add x15, sp, #3120 // hv frame base
    ldp x0, x1, [x15] // hv load L195
    cbz x1, _L22ed_rt_format_float_native_bb83 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb82 // branch -> then
_L22ed_rt_format_float_native_bb81:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    b _L22ed_rt_format_float_native_bb85 // branch
_L22ed_rt_format_float_native_bb82:
    add x15, sp, #2784 // hv frame base
    ldp x0, x1, [x15] // hv load L174
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    b _L22ed_rt_format_float_native_bb84 // branch
_L22ed_rt_format_float_native_bb83:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #3024 // hv frame base
    stp x0, x1, [x15] // hv store L189
    b _L22ed_rt_format_float_native_bb84 // branch
_L22ed_rt_format_float_native_bb84:
    b _L22ed_rt_format_float_native_bb85 // branch
_L22ed_rt_format_float_native_bb85:
    b _L22ed_rt_format_float_native_bb86 // branch
_L22ed_rt_format_float_native_bb86:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3152 // hv frame base
    stp x0, x1, [x15] // hv store L197
    add x15, sp, #3152 // hv frame base
    ldp x0, x1, [x15] // hv load L197
    add x15, sp, #2640 // hv frame base
    ldp x2, x3, [x15] // hv load L165
    bl hexa_sub // binop -
    add x15, sp, #3168 // hv frame base
    stp x0, x1, [x15] // hv store L198
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    add x15, sp, #3168 // hv frame base
    ldp x4, x5, [x15] // hv load L198
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #3024 // hv frame base
    ldp x0, x1, [x15] // hv load L189
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #3184 // hv frame base
    stp x0, x1, [x15] // hv store L199
    add x15, sp, #3184 // hv frame base
    ldp x0, x1, [x15] // hv load L199
    cbz x1, _L22ed_rt_format_float_native_bb88 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb87 // branch -> then
_L22ed_rt_format_float_native_bb87:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3216 // hv frame base
    stp x0, x1, [x15] // hv store L201
    add x15, sp, #3216 // hv frame base
    ldp x0, x1, [x15] // hv load L201
    add x15, sp, #2528 // hv frame base
    ldp x2, x3, [x15] // hv load L158
    bl hexa_add_slow // binop +
    add x15, sp, #3232 // hv frame base
    stp x0, x1, [x15] // hv store L202
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    add x15, sp, #3232 // hv frame base
    ldp x4, x5, [x15] // hv load L202
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    b _L22ed_rt_format_float_native_bb89 // branch
_L22ed_rt_format_float_native_bb88:
    b _L22ed_rt_format_float_native_bb69 // branch
_L22ed_rt_format_float_native_bb89:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3248 // hv frame base
    stp x0, x1, [x15] // hv store L203
    add x15, sp, #3248 // hv frame base
    ldp x0, x1, [x15] // hv load L203
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #51711 // imm 0-15
    movk x3, #15258, lsl #16 // imm 16-31
    bl hexa_cmp_gt // binop >
    add x15, sp, #3264 // hv frame base
    stp x0, x1, [x15] // hv store L204
    add x15, sp, #3264 // hv frame base
    ldp x0, x1, [x15] // hv load L204
    cbz x1, _L22ed_rt_format_float_native_bb91 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb90 // branch -> then
_L22ed_rt_format_float_native_bb90:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3280 // hv frame base
    stp x0, x1, [x15] // hv store L205
    add x15, sp, #3280 // hv frame base
    ldp x0, x1, [x15] // hv load L205
    add x15, sp, #2448 // hv frame base
    stp x0, x1, [x15] // hv store L153
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_lt // binop <
    add x15, sp, #3296 // hv frame base
    stp x0, x1, [x15] // hv store L206
    add x15, sp, #3296 // hv frame base
    ldp x0, x1, [x15] // hv load L206
    cbz x1, _L22ed_rt_format_float_native_bb93 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb92 // branch -> then
_L22ed_rt_format_float_native_bb91:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add x15, sp, #3376 // hv frame base
    stp x0, x1, [x15] // hv store L211
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_sub // binop -
    add x15, sp, #3392 // hv frame base
    stp x0, x1, [x15] // hv store L212
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #3392 // hv frame base
    ldp x2, x3, [x15] // hv load L212
    bl hexa_mul // binop *
    add x15, sp, #3408 // hv frame base
    stp x0, x1, [x15] // hv store L213
    add x15, sp, #3408 // hv frame base
    ldp x0, x1, [x15] // hv load L213
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    b _L22ed_rt_format_float_native_bb94 // branch
_L22ed_rt_format_float_native_bb92:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3328 // hv frame base
    stp x0, x1, [x15] // hv store L208
    add x15, sp, #3328 // hv frame base
    ldp x0, x1, [x15] // hv load L208
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    movz x4, #0 // hv const_int: TAG_INT
    movz x5, #0 // hv const_int val
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    b _L22ed_rt_format_float_native_bb93 // branch
_L22ed_rt_format_float_native_bb93:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3344 // hv frame base
    stp x0, x1, [x15] // hv store L209
    add x15, sp, #3344 // hv frame base
    ldp x0, x1, [x15] // hv load L209
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3360 // hv frame base
    stp x0, x1, [x15] // hv store L210
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #2448 // hv frame base
    ldp x2, x3, [x15] // hv load L153
    add x15, sp, #3360 // hv frame base
    ldp x4, x5, [x15] // hv load L210
    bl hexa_index_set // index_set: hexa_index_set
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    b _L22ed_rt_format_float_native_bb89 // branch
_L22ed_rt_format_float_native_bb94:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3424 // hv frame base
    stp x0, x1, [x15] // hv store L214
    add x15, sp, #3424 // hv frame base
    ldp x0, x1, [x15] // hv load L214
    add x15, sp, #3376 // hv frame base
    ldp x2, x3, [x15] // hv load L211
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3440 // hv frame base
    stp x0, x1, [x15] // hv store L215
    add x15, sp, #3440 // hv frame base
    ldp x0, x1, [x15] // hv load L215
    cbz x1, _L22ed_rt_format_float_native_bb96 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb95 // branch -> then
_L22ed_rt_format_float_native_bb95:
    add x15, sp, #3376 // hv frame base
    ldp x0, x1, [x15] // hv load L211
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #3456 // hv frame base
    stp x0, x1, [x15] // hv store L216
    add x15, sp, #3456 // hv frame base
    ldp x0, x1, [x15] // hv load L216
    add x15, sp, #3376 // hv frame base
    stp x0, x1, [x15] // hv store L211
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3472 // hv frame base
    stp x0, x1, [x15] // hv store L217
    add x15, sp, #3472 // hv frame base
    ldp x0, x1, [x15] // hv load L217
    add x15, sp, #2000 // hv frame base
    stp x0, x1, [x15] // hv store L125
    b _L22ed_rt_format_float_native_bb94 // branch
_L22ed_rt_format_float_native_bb96:
    b _L22ed_rt_format_float_native_bb88 // branch
_L22ed_rt_format_float_native_bb97:
    add x15, sp, #2448 // hv frame base
    ldp x0, x1, [x15] // hv load L153
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3536 // hv frame base
    stp x0, x1, [x15] // hv store L221
    add x15, sp, #3536 // hv frame base
    ldp x0, x1, [x15] // hv load L221
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb98 // branch
_L22ed_rt_format_float_native_bb98:
    b _L22ed_rt_format_float_native_bb61 // branch
_L22ed_rt_format_float_native_bb99:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_gt // binop >
    add x15, sp, #3552 // hv frame base
    stp x0, x1, [x15] // hv store L222
    add x15, sp, #3552 // hv frame base
    ldp x0, x1, [x15] // hv load L222
    cbz x1, _L22ed_rt_format_float_native_bb101 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb100 // branch -> then
_L22ed_rt_format_float_native_bb100:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3568 // hv frame base
    stp x0, x1, [x15] // hv store L223
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #3568 // hv frame base
    ldp x2, x3, [x15] // hv load L223
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3584 // hv frame base
    stp x0, x1, [x15] // hv store L224
    add x15, sp, #3584 // hv frame base
    ldp x0, x1, [x15] // hv load L224
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3600 // hv frame base
    stp x0, x1, [x15] // hv store L225
    add x15, sp, #3600 // hv frame base
    ldp x0, x1, [x15] // hv load L225
    cbz x1, _L22ed_rt_format_float_native_bb103 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb102 // branch -> then
_L22ed_rt_format_float_native_bb101:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #3648 // hv frame base
    stp x0, x1, [x15] // hv store L228
    add x15, sp, #3648 // hv frame base
    ldp x0, x1, [x15] // hv load L228
    cbz x1, _L22ed_rt_format_float_native_bb106 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb105 // branch -> then
_L22ed_rt_format_float_native_bb102:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3632 // hv frame base
    stp x0, x1, [x15] // hv store L227
    add x15, sp, #3632 // hv frame base
    ldp x0, x1, [x15] // hv load L227
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb104 // branch
_L22ed_rt_format_float_native_bb103:
    b _L22ed_rt_format_float_native_bb101 // branch
_L22ed_rt_format_float_native_bb104:
    b _L22ed_rt_format_float_native_bb99 // branch
_L22ed_rt_format_float_native_bb105:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb106 // branch
_L22ed_rt_format_float_native_bb106:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #2000 // hv frame base
    ldp x2, x3, [x15] // hv load L125
    bl hexa_cmp_gt // binop >
    add x15, sp, #3680 // hv frame base
    stp x0, x1, [x15] // hv store L230
    add x15, sp, #3680 // hv frame base
    ldp x0, x1, [x15] // hv load L230
    cbz x1, _L22ed_rt_format_float_native_bb108 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb107 // branch -> then
_L22ed_rt_format_float_native_bb107:
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // imm 0-15
    mvn x3, x3 // hv const_int: negate
    bl hexa_cmp_ge // binop >=
    add x15, sp, #3712 // hv frame base
    stp x0, x1, [x15] // hv store L232
    add x15, sp, #3712 // hv frame base
    ldp x0, x1, [x15] // hv load L232
    add x15, sp, #3696 // hv frame base
    stp x0, x1, [x15] // hv store L231
    b _L22ed_rt_format_float_native_bb109 // branch
_L22ed_rt_format_float_native_bb108:
    add x15, sp, #3680 // hv frame base
    ldp x0, x1, [x15] // hv load L230
    add x15, sp, #3696 // hv frame base
    stp x0, x1, [x15] // hv store L231
    b _L22ed_rt_format_float_native_bb109 // branch
_L22ed_rt_format_float_native_bb109:
    add x15, sp, #3696 // hv frame base
    ldp x0, x1, [x15] // hv load L231
    cbz x1, _L22ed_rt_format_float_native_bb111 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb110 // branch -> then
_L22ed_rt_format_float_native_bb110:
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3744 // hv frame base
    stp x0, x1, [x15] // hv store L234
    add x15, sp, #3744 // hv frame base
    ldp x0, x1, [x15] // hv load L234
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #3760 // hv frame base
    stp x0, x1, [x15] // hv store L235
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #3760 // hv frame base
    ldp x2, x3, [x15] // hv load L235
    bl hexa_sub // binop -
    add x15, sp, #3776 // hv frame base
    stp x0, x1, [x15] // hv store L236
    add x15, sp, #3776 // hv frame base
    ldp x0, x1, [x15] // hv load L236
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb112 // branch
_L22ed_rt_format_float_native_bb111:
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3792 // hv frame base
    stp x0, x1, [x15] // hv store L237
    add x15, sp, #3792 // hv frame base
    ldp x0, x1, [x15] // hv load L237
    add x15, sp, #2160 // hv frame base
    stp x0, x1, [x15] // hv store L135
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3808 // hv frame base
    stp x0, x1, [x15] // hv store L238
    add x15, sp, #3808 // hv frame base
    ldp x0, x1, [x15] // hv load L238
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb112 // branch
_L22ed_rt_format_float_native_bb112:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #3824 // hv frame base
    stp x0, x1, [x15] // hv store L239
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_gt // binop >
    add x15, sp, #3840 // hv frame base
    stp x0, x1, [x15] // hv store L240
    add x15, sp, #3840 // hv frame base
    ldp x0, x1, [x15] // hv load L240
    cbz x1, _L22ed_rt_format_float_native_bb114 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb113 // branch -> then
_L22ed_rt_format_float_native_bb113:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3872 // hv frame base
    stp x0, x1, [x15] // hv store L242
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #3872 // hv frame base
    ldp x2, x3, [x15] // hv load L242
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3888 // hv frame base
    stp x0, x1, [x15] // hv store L243
    add x15, sp, #3888 // hv frame base
    ldp x0, x1, [x15] // hv load L243
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    add x15, sp, #3904 // hv frame base
    stp x0, x1, [x15] // hv store L244
    add x15, sp, #3904 // hv frame base
    ldp x0, x1, [x15] // hv load L244
    cbz x1, _L22ed_rt_format_float_native_bb116 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb115 // branch -> then
_L22ed_rt_format_float_native_bb114:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_sub // binop -
    add x15, sp, #4048 // hv frame base
    stp x0, x1, [x15] // hv store L253
    add x15, sp, #4048 // hv frame base
    ldp x0, x1, [x15] // hv load L253
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #4064 // hv frame base
    stp x0, x1, [x15] // hv store L254
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    add x15, sp, #4064 // hv frame base
    ldp x2, x3, [x15] // hv load L254
    bl hexa_mul // binop *
    add x15, sp, #4080 // hv frame base
    stp x0, x1, [x15] // hv store L255
    add x15, sp, #4080 // hv frame base
    ldp x0, x1, [x15] // hv load L255
    movz x15, #4096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L256
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L257
    movz x15, #4112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L257
    cbz x1, _L22ed_rt_format_float_native_bb121 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb120 // branch -> then
_L22ed_rt_format_float_native_bb115:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #10 // hv const_int val
    add x15, sp, #3936 // hv frame base
    stp x0, x1, [x15] // hv store L246
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    add x15, sp, #3824 // hv frame base
    stp x0, x1, [x15] // hv store L239
    b _L22ed_rt_format_float_native_bb117 // branch
_L22ed_rt_format_float_native_bb116:
    b _L22ed_rt_format_float_native_bb114 // branch
_L22ed_rt_format_float_native_bb117:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    add x15, sp, #3952 // hv frame base
    stp x0, x1, [x15] // hv store L247
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #3952 // hv frame base
    ldp x2, x3, [x15] // hv load L247
    bl hexa_index_get // index: hexa_index_get
    add x15, sp, #3968 // hv frame base
    stp x0, x1, [x15] // hv store L248
    add x15, sp, #3968 // hv frame base
    ldp x0, x1, [x15] // hv load L248
    add x15, sp, #3936 // hv frame base
    ldp x2, x3, [x15] // hv load L246
    bl hexa_mod // binop %
    add x15, sp, #3984 // hv frame base
    stp x0, x1, [x15] // hv store L249
    add x15, sp, #3984 // hv frame base
    ldp x0, x1, [x15] // hv load L249
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    add x15, sp, #4000 // hv frame base
    stp x0, x1, [x15] // hv store L250
    add x15, sp, #4000 // hv frame base
    ldp x0, x1, [x15] // hv load L250
    cbz x1, _L22ed_rt_format_float_native_bb119 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb118 // branch -> then
_L22ed_rt_format_float_native_bb118:
    add x15, sp, #3936 // hv frame base
    ldp x0, x1, [x15] // hv load L246
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    bl hexa_mul // binop *
    add x15, sp, #4016 // hv frame base
    stp x0, x1, [x15] // hv store L251
    add x15, sp, #4016 // hv frame base
    ldp x0, x1, [x15] // hv load L251
    add x15, sp, #3936 // hv frame base
    stp x0, x1, [x15] // hv store L246
    add x15, sp, #3824 // hv frame base
    ldp x0, x1, [x15] // hv load L239
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    add x15, sp, #4032 // hv frame base
    stp x0, x1, [x15] // hv store L252
    add x15, sp, #4032 // hv frame base
    ldp x0, x1, [x15] // hv load L252
    add x15, sp, #3824 // hv frame base
    stp x0, x1, [x15] // hv store L239
    b _L22ed_rt_format_float_native_bb117 // branch
_L22ed_rt_format_float_native_bb119:
    b _L22ed_rt_format_float_native_bb116 // branch
_L22ed_rt_format_float_native_bb120:
    movz x15, #4096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L256
    add x15, sp, #3824 // hv frame base
    ldp x2, x3, [x15] // hv load L239
    bl hexa_sub // binop -
    movz x15, #4144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L259
    movz x15, #4144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L259
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L260
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L260
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #4176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L261
    movz x15, #4176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L261
    cbz x1, _L22ed_rt_format_float_native_bb123 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb122 // branch -> then
_L22ed_rt_format_float_native_bb121:
    movz x15, #4096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L256
    add x15, sp, #2000 // hv frame base
    ldp x2, x3, [x15] // hv load L125
    bl hexa_add_slow // binop +
    movz x15, #4240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L265
    movz x15, #4240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L265
    add x15, sp, #3824 // hv frame base
    ldp x2, x3, [x15] // hv load L239
    bl hexa_sub // binop -
    movz x15, #4256 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L266
    movz x15, #4256 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L266
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L267
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L267
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #4288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L268
    movz x15, #4288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L268
    cbz x1, _L22ed_rt_format_float_native_bb127 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb126 // branch -> then
_L22ed_rt_format_float_native_bb122:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L260
    b _L22ed_rt_format_float_native_bb123 // branch
_L22ed_rt_format_float_native_bb123:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L260
    bl hexa_cmp_gt // binop >
    movz x15, #4208 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L263
    movz x15, #4208 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L263
    cbz x1, _L22ed_rt_format_float_native_bb125 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb124 // branch -> then
_L22ed_rt_format_float_native_bb124:
    movz x15, #4160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L260
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb125 // branch
_L22ed_rt_format_float_native_bb125:
    b _L22ed_rt_format_float_native_bb130 // branch
_L22ed_rt_format_float_native_bb126:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L267
    b _L22ed_rt_format_float_native_bb127 // branch
_L22ed_rt_format_float_native_bb127:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L267
    bl hexa_cmp_gt // binop >
    movz x15, #4320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L270
    movz x15, #4320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L270
    cbz x1, _L22ed_rt_format_float_native_bb129 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb128 // branch -> then
_L22ed_rt_format_float_native_bb128:
    movz x15, #4272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L267
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb129 // branch
_L22ed_rt_format_float_native_bb129:
    b _L22ed_rt_format_float_native_bb130 // branch
_L22ed_rt_format_float_native_bb130:
    ldp x0, x1, [sp, #112] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    movz x15, #4352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L272
    movz x15, #4352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L272
    cbz x1, _L22ed_rt_format_float_native_bb132 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb131 // branch -> then
_L22ed_rt_format_float_native_bb131:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #4384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L274
    movz x15, #4384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L274
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb132 // branch
_L22ed_rt_format_float_native_bb132:
    add x15, sp, #2160 // hv frame base
    ldp x0, x1, [x15] // hv load L135
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #102 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L275
    movz x15, #4400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L275
    cbz x1, _L22ed_rt_format_float_native_bb134 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb133 // branch -> then
_L22ed_rt_format_float_native_bb133:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_cmp_gt // binop >
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L277
    movz x15, #4432 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L277
    cbz x1, _L22ed_rt_format_float_native_bb136 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb135 // branch -> then
_L22ed_rt_format_float_native_bb134:
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x15, #5552 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L347
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #5568 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L348
    add x15, sp, #2000 // hv frame base
    ldp x0, x1, [x15] // hv load L125
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #5584 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L349
    movz x15, #5584 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L349
    cbz x1, _L22ed_rt_format_float_native_bb180 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb179 // branch -> then
_L22ed_rt_format_float_native_bb135:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    b _L22ed_rt_format_float_native_bb136 // branch
_L22ed_rt_format_float_native_bb136:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L279
    b _L22ed_rt_format_float_native_bb137 // branch
_L22ed_rt_format_float_native_bb137:
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L279
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    bl hexa_cmp_le // binop <=
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L280
    movz x15, #4480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L280
    cbz x1, _L22ed_rt_format_float_native_bb139 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb138 // branch -> then
_L22ed_rt_format_float_native_bb138:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L279
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L281
    movz x15, #4496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L281
    bl _g_digits // call _g_digits
    movz x15, #4512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L282
    movz x15, #4512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L282
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L283
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L279
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    movz x15, #4544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L284
    movz x15, #4544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L284
    cbz x1, _L22ed_rt_format_float_native_bb141 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb140 // branch -> then
_L22ed_rt_format_float_native_bb139:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    movz x15, #4928 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L308
    movz x15, #4928 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L308
    cbz x1, _L22ed_rt_format_float_native_bb156 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb155 // branch -> then
_L22ed_rt_format_float_native_bb140:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #4576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L286
    movz x15, #4576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L286
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L287
    b _L22ed_rt_format_float_native_bb142 // branch
_L22ed_rt_format_float_native_bb141:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #4752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L297
    movz x15, #4752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L297
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #4768 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L298
    movz x15, #4768 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L298
    cbz x1, _L22ed_rt_format_float_native_bb149 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb148 // branch -> then
_L22ed_rt_format_float_native_bb142:
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L287
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #4608 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L288
    movz x15, #4608 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L288
    cbz x1, _L22ed_rt_format_float_native_bb144 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb143 // branch -> then
_L22ed_rt_format_float_native_bb143:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #4624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L289
    movz x15, #4624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L289
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L287
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #4640 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L290
    movz x15, #4640 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L290
    movz x15, #4592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L287
    b _L22ed_rt_format_float_native_bb142 // branch
_L22ed_rt_format_float_native_bb144:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L291
    b _L22ed_rt_format_float_native_bb145 // branch
_L22ed_rt_format_float_native_bb145:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L292
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L291
    movz x15, #4672 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L292
    bl hexa_cmp_lt // binop <
    movz x15, #4688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L293
    movz x15, #4688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L293
    cbz x1, _L22ed_rt_format_float_native_bb147 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb146 // branch -> then
_L22ed_rt_format_float_native_bb146:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L291
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L294
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #4704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L294
    bl hexa_array_push // call hexa_array_push
    movz x15, #4720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L295
    movz x15, #4720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L295
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L291
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #4736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L296
    movz x15, #4736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L296
    movz x15, #4656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L291
    b _L22ed_rt_format_float_native_bb145 // branch
_L22ed_rt_format_float_native_bb147:
    b _L22ed_rt_format_float_native_bb154 // branch
_L22ed_rt_format_float_native_bb148:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #4800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L300
    movz x15, #4800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L300
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb153 // branch
_L22ed_rt_format_float_native_bb149:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L301
    b _L22ed_rt_format_float_native_bb150 // branch
_L22ed_rt_format_float_native_bb150:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #4832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L302
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L301
    movz x15, #4832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L302
    bl hexa_cmp_lt // binop <
    movz x15, #4848 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L303
    movz x15, #4848 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L303
    cbz x1, _L22ed_rt_format_float_native_bb152 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb151 // branch -> then
_L22ed_rt_format_float_native_bb151:
    movz x15, #4528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L283
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L301
    bl hexa_index_get // index: hexa_index_get
    movz x15, #4864 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L304
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #4864 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L304
    bl hexa_array_push // call hexa_array_push
    movz x15, #4880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L305
    movz x15, #4880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L305
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L301
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #4896 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L306
    movz x15, #4896 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L306
    movz x15, #4816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L301
    b _L22ed_rt_format_float_native_bb150 // branch
_L22ed_rt_format_float_native_bb152:
    b _L22ed_rt_format_float_native_bb153 // branch
_L22ed_rt_format_float_native_bb153:
    b _L22ed_rt_format_float_native_bb154 // branch
_L22ed_rt_format_float_native_bb154:
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L279
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #4912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L307
    movz x15, #4912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L307
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L279
    b _L22ed_rt_format_float_native_bb137 // branch
_L22ed_rt_format_float_native_bb155:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #4960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L310
    movz x15, #4960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L310
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb156 // branch
_L22ed_rt_format_float_native_bb156:
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #4976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L311
    movz x15, #4976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L311
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L279
    b _L22ed_rt_format_float_native_bb157 // branch
_L22ed_rt_format_float_native_bb157:
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L279
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_cmp_lt // binop <
    movz x15, #4992 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L312
    movz x15, #4992 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L312
    cbz x1, _L22ed_rt_format_float_native_bb161 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb160 // branch -> then
_L22ed_rt_format_float_native_bb158:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L279
    bl hexa_index_get // index: hexa_index_get
    movz x15, #5040 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L315
    movz x15, #5040 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L315
    bl _g_digits // call _g_digits
    movz x15, #5056 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L316
    movz x15, #5056 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L316
    movz x15, #5072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L317
    bl hexa_array_new // array_lit: new array
    movz x15, #5088 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L318
    movz x15, #5088 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L318
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L319
    movz x15, #5072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L317
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #5120 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L320
    movz x15, #5120 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L320
    movz x15, #5136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L321
    b _L22ed_rt_format_float_native_bb163 // branch
_L22ed_rt_format_float_native_bb159:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    movz x15, #5456 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L341
    movz x15, #5456 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L341
    cbz x1, _L22ed_rt_format_float_native_bb175 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb174 // branch -> then
_L22ed_rt_format_float_native_bb160:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    movz x15, #5024 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L314
    movz x15, #5024 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L314
    movz x15, #5008 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L313
    b _L22ed_rt_format_float_native_bb162 // branch
_L22ed_rt_format_float_native_bb161:
    movz x15, #4992 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L312
    movz x15, #5008 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L313
    b _L22ed_rt_format_float_native_bb162 // branch
_L22ed_rt_format_float_native_bb162:
    movz x15, #5008 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L313
    cbz x1, _L22ed_rt_format_float_native_bb159 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb158 // branch -> then
_L22ed_rt_format_float_native_bb163:
    movz x15, #5136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L321
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #5152 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L322
    movz x15, #5152 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L322
    cbz x1, _L22ed_rt_format_float_native_bb165 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb164 // branch -> then
_L22ed_rt_format_float_native_bb164:
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L319
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #5168 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L323
    movz x15, #5168 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L323
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L319
    movz x15, #5136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L321
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5184 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L324
    movz x15, #5184 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L324
    movz x15, #5136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L321
    b _L22ed_rt_format_float_native_bb163 // branch
_L22ed_rt_format_float_native_bb165:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #5200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L325
    b _L22ed_rt_format_float_native_bb166 // branch
_L22ed_rt_format_float_native_bb166:
    movz x15, #5072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L317
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #5216 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L326
    movz x15, #5200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L325
    movz x15, #5216 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L326
    bl hexa_cmp_lt // binop <
    movz x15, #5232 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L327
    movz x15, #5232 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L327
    cbz x1, _L22ed_rt_format_float_native_bb168 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb167 // branch -> then
_L22ed_rt_format_float_native_bb167:
    movz x15, #5072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L317
    movz x15, #5200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L325
    bl hexa_index_get // index: hexa_index_get
    movz x15, #5248 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L328
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L319
    movz x15, #5248 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L328
    bl hexa_array_push // call hexa_array_push
    movz x15, #5264 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L329
    movz x15, #5264 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L329
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L319
    movz x15, #5200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L325
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5280 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L330
    movz x15, #5280 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L330
    movz x15, #5200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L325
    b _L22ed_rt_format_float_native_bb166 // branch
_L22ed_rt_format_float_native_bb168:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #9 // hv const_int val
    movz x15, #5296 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L331
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #5312 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L332
    movz x15, #5312 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L332
    cbz x1, _L22ed_rt_format_float_native_bb170 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb169 // branch -> then
_L22ed_rt_format_float_native_bb169:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #5296 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L331
    b _L22ed_rt_format_float_native_bb170 // branch
_L22ed_rt_format_float_native_bb170:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #5344 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L334
    b _L22ed_rt_format_float_native_bb171 // branch
_L22ed_rt_format_float_native_bb171:
    movz x15, #5344 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L334
    movz x15, #5296 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L331
    bl hexa_cmp_lt // binop <
    movz x15, #5360 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L335
    movz x15, #5360 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L335
    cbz x1, _L22ed_rt_format_float_native_bb173 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb172 // branch -> then
_L22ed_rt_format_float_native_bb172:
    movz x15, #5104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L319
    movz x15, #5344 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L334
    bl hexa_index_get // index: hexa_index_get
    movz x15, #5376 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L336
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #5376 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L336
    bl hexa_array_push // call hexa_array_push
    movz x15, #5392 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L337
    movz x15, #5392 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L337
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #5344 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L334
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5408 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L338
    movz x15, #5408 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L338
    movz x15, #5344 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L334
    b _L22ed_rt_format_float_native_bb171 // branch
_L22ed_rt_format_float_native_bb173:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_sub // binop -
    movz x15, #5424 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L339
    movz x15, #5424 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L339
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L279
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5440 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L340
    movz x15, #5440 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L340
    movz x15, #4464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L279
    b _L22ed_rt_format_float_native_bb157 // branch
_L22ed_rt_format_float_native_bb174:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #5488 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L343
    b _L22ed_rt_format_float_native_bb176 // branch
_L22ed_rt_format_float_native_bb175:
    b _L22ed_rt_format_float_native_bb238 // branch
_L22ed_rt_format_float_native_bb176:
    movz x15, #5488 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L343
    add x15, sp, #656 // hv frame base
    ldp x2, x3, [x15] // hv load L41
    bl hexa_cmp_lt // binop <
    movz x15, #5504 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L344
    movz x15, #5504 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L344
    cbz x1, _L22ed_rt_format_float_native_bb178 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb177 // branch -> then
_L22ed_rt_format_float_native_bb177:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #5520 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L345
    movz x15, #5520 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L345
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #5488 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L343
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5536 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L346
    movz x15, #5536 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L346
    movz x15, #5488 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L343
    b _L22ed_rt_format_float_native_bb176 // branch
_L22ed_rt_format_float_native_bb178:
    b _L22ed_rt_format_float_native_bb175 // branch
_L22ed_rt_format_float_native_bb179:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    movz x15, #5568 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L348
    movz x0, #0 // unop -: a.tag=TAG_INT
    movz x1, #0 // unop -: a.val=0
    add x15, sp, #2000 // hv frame base
    ldp x2, x3, [x15] // hv load L125
    bl hexa_sub // unop -: 0 - x
    movz x15, #5616 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L351
    movz x15, #5616 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L351
    movz x15, #5552 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L347
    b _L22ed_rt_format_float_native_bb180 // branch
_L22ed_rt_format_float_native_bb180:
    movz x15, #5552 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L347
    bl _g_digits // call _g_digits
    movz x15, #5632 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L352
    movz x15, #5632 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L352
    movz x15, #5648 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L353
    bl hexa_array_new // array_lit: new array
    movz x15, #5664 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L354
    movz x15, #5664 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L354
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    add x15, sp, #2160 // hv frame base
    ldp x2, x3, [x15] // hv load L135
    bl hexa_array_push // call hexa_array_push
    movz x15, #5696 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L356
    movz x15, #5696 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L356
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    movz x15, #5568 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L348
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    movz x15, #5712 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L357
    movz x15, #5712 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L357
    cbz x1, _L22ed_rt_format_float_native_bb182 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb181 // branch -> then
_L22ed_rt_format_float_native_bb181:
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #45 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #5744 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L359
    movz x15, #5744 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L359
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    b _L22ed_rt_format_float_native_bb183 // branch
_L22ed_rt_format_float_native_bb182:
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #43 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #5760 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L360
    movz x15, #5760 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L360
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    b _L22ed_rt_format_float_native_bb183 // branch
_L22ed_rt_format_float_native_bb183:
    movz x15, #5648 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L353
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #5776 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L361
    movz x15, #5776 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L361
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #5792 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L362
    movz x15, #5792 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L362
    cbz x1, _L22ed_rt_format_float_native_bb185 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb184 // branch -> then
_L22ed_rt_format_float_native_bb184:
    movz x15, #5648 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L353
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #5824 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L364
    movz x15, #5824 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L364
    movz x15, #5840 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L365
    b _L22ed_rt_format_float_native_bb186 // branch
_L22ed_rt_format_float_native_bb185:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #5904 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L369
    b _L22ed_rt_format_float_native_bb189 // branch
_L22ed_rt_format_float_native_bb186:
    movz x15, #5840 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L365
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #5856 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L366
    movz x15, #5856 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L366
    cbz x1, _L22ed_rt_format_float_native_bb188 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb187 // branch -> then
_L22ed_rt_format_float_native_bb187:
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #5872 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L367
    movz x15, #5872 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L367
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    movz x15, #5840 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L365
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5888 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L368
    movz x15, #5888 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L368
    movz x15, #5840 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L365
    b _L22ed_rt_format_float_native_bb186 // branch
_L22ed_rt_format_float_native_bb188:
    b _L22ed_rt_format_float_native_bb185 // branch
_L22ed_rt_format_float_native_bb189:
    movz x15, #5648 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L353
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #5920 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L370
    movz x15, #5904 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L369
    movz x15, #5920 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L370
    bl hexa_cmp_lt // binop <
    movz x15, #5936 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L371
    movz x15, #5936 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L371
    cbz x1, _L22ed_rt_format_float_native_bb191 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb190 // branch -> then
_L22ed_rt_format_float_native_bb190:
    movz x15, #5648 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L353
    movz x15, #5904 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L369
    bl hexa_index_get // index: hexa_index_get
    movz x15, #5952 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L372
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    movz x15, #5952 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L372
    bl hexa_array_push // call hexa_array_push
    movz x15, #5968 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L373
    movz x15, #5968 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L373
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L355
    movz x15, #5904 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L369
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #5984 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L374
    movz x15, #5984 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L374
    movz x15, #5904 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L369
    b _L22ed_rt_format_float_native_bb189 // branch
_L22ed_rt_format_float_native_bb191:
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_cmp_le // binop <=
    movz x15, #6000 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L375
    movz x15, #6000 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L375
    cbz x1, _L22ed_rt_format_float_native_bb193 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb192 // branch -> then
_L22ed_rt_format_float_native_bb192:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6032 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L377
    movz x15, #6032 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L377
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    b _L22ed_rt_format_float_native_bb193 // branch
_L22ed_rt_format_float_native_bb193:
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L378
    b _L22ed_rt_format_float_native_bb194 // branch
_L22ed_rt_format_float_native_bb194:
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L378
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    bl hexa_cmp_lt // binop <
    movz x15, #6064 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L379
    movz x15, #6064 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L379
    cbz x1, _L22ed_rt_format_float_native_bb198 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb197 // branch -> then
_L22ed_rt_format_float_native_bb195:
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L378
    bl hexa_index_get // index: hexa_index_get
    movz x15, #6112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L382
    movz x15, #6112 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L382
    bl _g_digits // call _g_digits
    movz x15, #6128 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L383
    movz x15, #6128 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L383
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L384
    bl hexa_array_new // array_lit: new array
    movz x15, #6160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L385
    movz x15, #6160 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L385
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L386
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L378
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_eq // ne: eq
    bl hexa_truthy // ne: truthy(eq) → w0
    eor x0, x0, #1 // ne: !truthy
    bl hexa_bool // ne: box bool
    movz x15, #6192 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L387
    movz x15, #6192 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L387
    cbz x1, _L22ed_rt_format_float_native_bb201 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb200 // branch -> then
_L22ed_rt_format_float_native_bb196:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    movz x15, #7104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L444
    movz x15, #7104 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L444
    cbz x1, _L22ed_rt_format_float_native_bb231 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb230 // branch -> then
_L22ed_rt_format_float_native_bb197:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_ge // binop >=
    movz x15, #6096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L381
    movz x15, #6096 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L381
    movz x15, #6080 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L380
    b _L22ed_rt_format_float_native_bb199 // branch
_L22ed_rt_format_float_native_bb198:
    movz x15, #6064 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L379
    movz x15, #6080 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L380
    b _L22ed_rt_format_float_native_bb199 // branch
_L22ed_rt_format_float_native_bb199:
    movz x15, #6080 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L380
    cbz x1, _L22ed_rt_format_float_native_bb196 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb195 // branch -> then
_L22ed_rt_format_float_native_bb200:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #6224 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L389
    movz x15, #6224 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L389
    movz x15, #6240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L390
    b _L22ed_rt_format_float_native_bb202 // branch
_L22ed_rt_format_float_native_bb201:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #6400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L400
    movz x15, #6400 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L400
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_eq // binop ==
    movz x15, #6416 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L401
    movz x15, #6416 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L401
    cbz x1, _L22ed_rt_format_float_native_bb209 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb208 // branch -> then
_L22ed_rt_format_float_native_bb202:
    movz x15, #6240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L390
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #9 // hv const_int val
    bl hexa_cmp_lt // binop <
    movz x15, #6256 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L391
    movz x15, #6256 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L391
    cbz x1, _L22ed_rt_format_float_native_bb204 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb203 // branch -> then
_L22ed_rt_format_float_native_bb203:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #6272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L392
    movz x15, #6272 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L392
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L386
    movz x15, #6240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L390
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L393
    movz x15, #6288 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L393
    movz x15, #6240 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L390
    b _L22ed_rt_format_float_native_bb202 // branch
_L22ed_rt_format_float_native_bb204:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #6304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L394
    b _L22ed_rt_format_float_native_bb205 // branch
_L22ed_rt_format_float_native_bb205:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #6320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L395
    movz x15, #6304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L394
    movz x15, #6320 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L395
    bl hexa_cmp_lt // binop <
    movz x15, #6336 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L396
    movz x15, #6336 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L396
    cbz x1, _L22ed_rt_format_float_native_bb207 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb206 // branch -> then
_L22ed_rt_format_float_native_bb206:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    movz x15, #6304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L394
    bl hexa_index_get // index: hexa_index_get
    movz x15, #6352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L397
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x15, #6352 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L397
    bl hexa_array_push // call hexa_array_push
    movz x15, #6368 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L398
    movz x15, #6368 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L398
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L386
    movz x15, #6304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L394
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L399
    movz x15, #6384 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L399
    movz x15, #6304 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L394
    b _L22ed_rt_format_float_native_bb205 // branch
_L22ed_rt_format_float_native_bb207:
    b _L22ed_rt_format_float_native_bb214 // branch
_L22ed_rt_format_float_native_bb208:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #6448 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L403
    movz x15, #6448 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L403
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L386
    b _L22ed_rt_format_float_native_bb213 // branch
_L22ed_rt_format_float_native_bb209:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #6464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L404
    b _L22ed_rt_format_float_native_bb210 // branch
_L22ed_rt_format_float_native_bb210:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #6480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L405
    movz x15, #6464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L404
    movz x15, #6480 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L405
    bl hexa_cmp_lt // binop <
    movz x15, #6496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L406
    movz x15, #6496 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L406
    cbz x1, _L22ed_rt_format_float_native_bb212 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb211 // branch -> then
_L22ed_rt_format_float_native_bb211:
    movz x15, #6144 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L384
    movz x15, #6464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L404
    bl hexa_index_get // index: hexa_index_get
    movz x15, #6512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L407
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x15, #6512 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L407
    bl hexa_array_push // call hexa_array_push
    movz x15, #6528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L408
    movz x15, #6528 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L408
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L386
    movz x15, #6464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L404
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L409
    movz x15, #6544 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L409
    movz x15, #6464 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L404
    b _L22ed_rt_format_float_native_bb210 // branch
_L22ed_rt_format_float_native_bb212:
    b _L22ed_rt_format_float_native_bb213 // branch
_L22ed_rt_format_float_native_bb213:
    b _L22ed_rt_format_float_native_bb214 // branch
_L22ed_rt_format_float_native_bb214:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #6560 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L410
    movz x15, #6560 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L410
    movz x15, #6576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L411
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L378
    add x15, sp, #848 // hv frame base
    ldp x2, x3, [x15] // hv load L53
    bl hexa_eq // binop ==
    movz x15, #6592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L412
    movz x15, #6592 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L412
    cbz x1, _L22ed_rt_format_float_native_bb216 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb215 // branch -> then
_L22ed_rt_format_float_native_bb215:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_index_get // index: hexa_index_get
    movz x15, #6624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L414
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #6624 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L414
    bl hexa_array_push // call hexa_array_push
    movz x15, #6640 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L415
    movz x15, #6640 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L415
    stp x0, x1, [sp, #0] // hv store L13
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    bl hexa_cmp_gt // binop >
    movz x15, #6656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L416
    movz x15, #6656 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L416
    cbz x1, _L22ed_rt_format_float_native_bb218 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb217 // branch -> then
_L22ed_rt_format_float_native_bb216:
    movz x15, #6576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L411
    movz x15, #6912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L432
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L432
    bl hexa_cmp_lt // binop <
    movz x15, #6928 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L433
    movz x15, #6928 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L433
    cbz x1, _L22ed_rt_format_float_native_bb225 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb224 // branch -> then
_L22ed_rt_format_float_native_bb217:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #46 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #6688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L418
    movz x15, #6688 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L418
    stp x0, x1, [sp, #0] // hv store L13
    b _L22ed_rt_format_float_native_bb218 // branch
_L22ed_rt_format_float_native_bb218:
    movz x15, #6576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L411
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_sub // binop -
    movz x15, #6704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L419
    movz x15, #6704 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L419
    movz x15, #6720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L420
    movz x15, #6720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L420
    movz x15, #6736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L421
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L421
    bl hexa_cmp_lt // binop <
    movz x15, #6752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L422
    movz x15, #6752 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L422
    cbz x1, _L22ed_rt_format_float_native_bb220 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb219 // branch -> then
_L22ed_rt_format_float_native_bb219:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L421
    b _L22ed_rt_format_float_native_bb220 // branch
_L22ed_rt_format_float_native_bb220:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    movz x15, #6784 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L424
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #6800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L425
    b _L22ed_rt_format_float_native_bb221 // branch
_L22ed_rt_format_float_native_bb221:
    movz x15, #6800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L425
    movz x15, #6736 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L421
    bl hexa_cmp_lt // binop <
    movz x15, #6816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L426
    movz x15, #6816 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L426
    cbz x1, _L22ed_rt_format_float_native_bb223 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb222 // branch -> then
_L22ed_rt_format_float_native_bb222:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x15, #6784 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L424
    bl hexa_index_get // index: hexa_index_get
    movz x15, #6832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L427
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #6832 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L427
    bl hexa_array_push // call hexa_array_push
    movz x15, #6848 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L428
    movz x15, #6848 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L428
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #6784 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L424
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6864 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L429
    movz x15, #6864 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L429
    movz x15, #6784 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L424
    movz x15, #6800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L425
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #6880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L430
    movz x15, #6880 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L430
    movz x15, #6800 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L425
    b _L22ed_rt_format_float_native_bb221 // branch
_L22ed_rt_format_float_native_bb223:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6720 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L420
    bl hexa_sub // binop -
    movz x15, #6896 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L431
    movz x15, #6896 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L431
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb229 // branch
_L22ed_rt_format_float_native_bb224:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L432
    b _L22ed_rt_format_float_native_bb225 // branch
_L22ed_rt_format_float_native_bb225:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #6960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L435
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #6976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L436
    b _L22ed_rt_format_float_native_bb226 // branch
_L22ed_rt_format_float_native_bb226:
    movz x15, #6976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L436
    movz x15, #6912 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L432
    bl hexa_cmp_lt // binop <
    movz x15, #6992 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L437
    movz x15, #6992 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L437
    cbz x1, _L22ed_rt_format_float_native_bb228 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb227 // branch -> then
_L22ed_rt_format_float_native_bb227:
    movz x15, #6176 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L386
    movz x15, #6960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L435
    bl hexa_index_get // index: hexa_index_get
    movz x15, #7008 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L438
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #7008 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L438
    bl hexa_array_push // call hexa_array_push
    movz x15, #7024 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L439
    movz x15, #7024 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L439
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #6960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L435
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #7040 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L440
    movz x15, #7040 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L440
    movz x15, #6960 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L435
    movz x15, #6976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L436
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #7056 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L441
    movz x15, #7056 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L441
    movz x15, #6976 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L436
    b _L22ed_rt_format_float_native_bb226 // branch
_L22ed_rt_format_float_native_bb228:
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    movz x15, #6576 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L411
    bl hexa_sub // binop -
    movz x15, #7072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L442
    movz x15, #7072 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L442
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    b _L22ed_rt_format_float_native_bb229 // branch
_L22ed_rt_format_float_native_bb229:
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L378
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #7088 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L443
    movz x15, #7088 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L443
    movz x15, #6048 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L378
    b _L22ed_rt_format_float_native_bb194 // branch
_L22ed_rt_format_float_native_bb230:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #7136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L446
    b _L22ed_rt_format_float_native_bb232 // branch
_L22ed_rt_format_float_native_bb231:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x15, #7200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L450
    b _L22ed_rt_format_float_native_bb235 // branch
_L22ed_rt_format_float_native_bb232:
    movz x15, #7136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L446
    add x15, sp, #656 // hv frame base
    ldp x2, x3, [x15] // hv load L41
    bl hexa_cmp_lt // binop <
    movz x15, #7152 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L447
    movz x15, #7152 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L447
    cbz x1, _L22ed_rt_format_float_native_bb234 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb233 // branch -> then
_L22ed_rt_format_float_native_bb233:
    ldp x0, x1, [sp, #0] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #48 // hv const_int val
    bl hexa_array_push // call hexa_array_push
    movz x15, #7168 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L448
    movz x15, #7168 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L448
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #7136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L446
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #7184 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L449
    movz x15, #7184 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L449
    movz x15, #7136 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L446
    b _L22ed_rt_format_float_native_bb232 // branch
_L22ed_rt_format_float_native_bb234:
    b _L22ed_rt_format_float_native_bb231 // branch
_L22ed_rt_format_float_native_bb235:
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    bl hexa_len // call hexa_len
    sxtw x0, w0 // ret int: sign-ext
    bl hexa_int // ret int: box → HexaVal
    movz x15, #7216 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L451
    movz x15, #7200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L450
    movz x15, #7216 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L451
    bl hexa_cmp_lt // binop <
    movz x15, #7232 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L452
    movz x15, #7232 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L452
    cbz x1, _L22ed_rt_format_float_native_bb237 // br_cond: !payload -> else
    b _L22ed_rt_format_float_native_bb236 // branch -> then
_L22ed_rt_format_float_native_bb236:
    movz x15, #5680 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L355
    movz x15, #7200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L450
    bl hexa_index_get // index: hexa_index_get
    movz x15, #7248 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L453
    ldp x0, x1, [sp, #0] // hv load L13
    movz x15, #7248 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x2, x3, [x15] // hv load L453
    bl hexa_array_push // call hexa_array_push
    movz x15, #7264 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L454
    movz x15, #7264 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L454
    stp x0, x1, [sp, #0] // hv store L13
    movz x15, #7200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L450
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    bl hexa_add_slow // binop +
    movz x15, #7280 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L455
    movz x15, #7280 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L455
    movz x15, #7200 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L450
    b _L22ed_rt_format_float_native_bb235 // branch
_L22ed_rt_format_float_native_bb237:
    b _L22ed_rt_format_float_native_bb238 // branch
_L22ed_rt_format_float_native_bb238:
    ldp x0, x1, [sp, #0] // hv load L13
    bl hexa_bytes_to_str_raw // call hexa_bytes_to_str_raw
    movz x15, #7296 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    stp x0, x1, [x15] // hv store L456
    movz x15, #7296 // imm 0-15
    add x15, sp, x15 // hv frame base (big)
    ldp x0, x1, [x15] // hv load L456
    movz x15, #7312 // imm 0-15
    add sp, sp, x15 // sp adj (big frame)
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
