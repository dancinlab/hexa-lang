// num_float_core_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-num-float).
// GENERATED: tool/regen_num_float_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o num_float_core_arm64.s stdlib/runtime/num_float_core.hexa.
//   Provides the num-float parse half (rt_parse_float_native) as a native
//   raw-mem + float body (__hx_ptr_load8 byte scan + integer mantissa fold +
//   __hx_to_double cast + __hx_payload_{fmul,fdiv} Clinger fast-path scale,
//   bit-exact to strtod on the mantissa<=2^53 AND |exp10|<=22 domain; out of
//   domain returns a TAG_VOID sentinel so the C wrapper falls back to strtod).
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: Mach-O, _rt_parse_float_native underscore-prefixed; no external. External: NONE (fully self-contained; float leaves lower inline).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_NATIVE + ar this
//   .o into runtime.a so __hx_to_double delegates its string→f64 path to native.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /home/summer/dancinlab/hexa-lang/stdlib/runtime/num_float_core.hexa
.file 1 "stdlib/runtime/num_float_core.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _rt_parse_float_native
.private_extern _rt_parse_float_native
    .p2align 2
_rt_parse_float_native:
    .loc 1 71 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #2880 ; sp adj
    stp x0, x1, [sp, #16] ; ingress param 0
__L40fd_rt_parse_float_native_bb0:
    ldp x0, x1, [sp, #16] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #32] ; hv store L1
    ldp x0, x1, [sp, #32] ; hv load L1
    stp x0, x1, [sp, #48] ; hv store L2
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #64] ; hv store L3
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    stp x0, x1, [sp, #80] ; hv store L4
    b __L40fd_rt_parse_float_native_bb1 ; branch
__L40fd_rt_parse_float_native_bb1:
    ldp x0, x1, [sp, #80] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    stp x0, x1, [sp, #96] ; hv store L5
    ldp x0, x1, [sp, #96] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb3 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb2 ; branch -> then
__L40fd_rt_parse_float_native_bb2:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #112] ; hv store L6
    ldp x0, x1, [sp, #112] ; hv load L6
    stp x0, x1, [sp, #128] ; hv store L7
    ldp x0, x1, [sp, #128] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #144] ; hv store L8
    ldp x0, x1, [sp, #144] ; hv load L8
    stp x0, x1, [sp, #160] ; hv store L9
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    ldp x2, x3, [sp, #128] ; hv load L7
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #176] ; hv store L10
    ldp x0, x1, [sp, #176] ; hv load L10
    stp x0, x1, [sp, #192] ; hv store L11
    ldp x0, x1, [sp, #128] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #14 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #208] ; hv store L12
    ldp x0, x1, [sp, #208] ; hv load L12
    stp x0, x1, [sp, #224] ; hv store L13
    ldp x0, x1, [sp, #192] ; hv load L11
    ldp x2, x3, [sp, #224] ; hv load L13
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #240] ; hv store L14
    ldp x0, x1, [sp, #240] ; hv load L14
    stp x0, x1, [sp, #256] ; hv store L15
    ldp x0, x1, [sp, #160] ; hv load L9
    ldp x2, x3, [sp, #256] ; hv load L15
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #272] ; hv store L16
    ldp x0, x1, [sp, #272] ; hv load L16
    stp x0, x1, [sp, #288] ; hv store L17
    ldp x0, x1, [sp, #288] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    stp x0, x1, [sp, #304] ; hv store L18
    ldp x0, x1, [sp, #304] ; hv load L18
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb5 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb4 ; branch -> then
__L40fd_rt_parse_float_native_bb3:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #352] ; hv store L21
    ldp x0, x1, [sp, #352] ; hv load L21
    stp x0, x1, [sp, #368] ; hv store L22
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #0] ; hv store L23
    ldp x0, x1, [sp, #368] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #43 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #384] ; hv load L24
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb8 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb7 ; branch -> then
__L40fd_rt_parse_float_native_bb4:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #336] ; hv store L20
    ldp x0, x1, [sp, #336] ; hv load L20
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb6 ; branch
__L40fd_rt_parse_float_native_bb5:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #80] ; hv store L4
    b __L40fd_rt_parse_float_native_bb6 ; branch
__L40fd_rt_parse_float_native_bb6:
    b __L40fd_rt_parse_float_native_bb1 ; branch
__L40fd_rt_parse_float_native_bb7:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb11 ; branch
__L40fd_rt_parse_float_native_bb8:
    ldp x0, x1, [sp, #368] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #45 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #432] ; hv load L27
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb10 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb9 ; branch -> then
__L40fd_rt_parse_float_native_bb9:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    stp x0, x1, [sp, #0] ; hv store L23
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #464] ; hv store L29
    ldp x0, x1, [sp, #464] ; hv load L29
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb10 ; branch
__L40fd_rt_parse_float_native_bb10:
    b __L40fd_rt_parse_float_native_bb11 ; branch
__L40fd_rt_parse_float_native_bb11:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #480] ; hv store L30
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #496] ; hv store L31
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #544 ; hv frame base
    stp x0, x1, [x15] ; hv store L34
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    b __L40fd_rt_parse_float_native_bb12 ; branch
__L40fd_rt_parse_float_native_bb12:
    add x15, sp, #560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L35
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    add x15, sp, #576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L36
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb14 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb13 ; branch -> then
__L40fd_rt_parse_float_native_bb13:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #592 ; hv frame base
    stp x0, x1, [x15] ; hv store L37
    add x15, sp, #592 ; hv frame base
    ldp x0, x1, [x15] ; hv load L37
    add x15, sp, #608 ; hv frame base
    stp x0, x1, [x15] ; hv store L38
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #47 ; hv const_int val
    add x15, sp, #608 ; hv frame base
    ldp x2, x3, [x15] ; hv load L38
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #624 ; hv frame base
    stp x0, x1, [x15] ; hv store L39
    add x15, sp, #624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L39
    add x15, sp, #640 ; hv frame base
    stp x0, x1, [x15] ; hv store L40
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #58 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #656 ; hv frame base
    stp x0, x1, [x15] ; hv store L41
    add x15, sp, #656 ; hv frame base
    ldp x0, x1, [x15] ; hv load L41
    add x15, sp, #672 ; hv frame base
    stp x0, x1, [x15] ; hv store L42
    add x15, sp, #640 ; hv frame base
    ldp x0, x1, [x15] ; hv load L40
    add x15, sp, #672 ; hv frame base
    ldp x2, x3, [x15] ; hv load L42
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #688 ; hv frame base
    stp x0, x1, [x15] ; hv store L43
    add x15, sp, #688 ; hv frame base
    ldp x0, x1, [x15] ; hv load L43
    add x15, sp, #704 ; hv frame base
    stp x0, x1, [x15] ; hv store L44
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #46 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #720 ; hv frame base
    stp x0, x1, [x15] ; hv store L45
    add x15, sp, #720 ; hv frame base
    ldp x0, x1, [x15] ; hv load L45
    add x15, sp, #736 ; hv frame base
    stp x0, x1, [x15] ; hv store L46
    add x15, sp, #704 ; hv frame base
    ldp x0, x1, [x15] ; hv load L44
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #752 ; hv frame base
    stp x0, x1, [x15] ; hv store L47
    add x15, sp, #752 ; hv frame base
    ldp x0, x1, [x15] ; hv load L47
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb16 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb15 ; branch -> then
__L40fd_rt_parse_float_native_bb14:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #1088 ; hv frame base
    stp x0, x1, [x15] ; hv store L68
    add x15, sp, #1088 ; hv frame base
    ldp x0, x1, [x15] ; hv load L68
    add x15, sp, #1104 ; hv frame base
    stp x0, x1, [x15] ; hv store L69
    add x15, sp, #1104 ; hv frame base
    ldp x0, x1, [x15] ; hv load L69
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #101 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1120 ; hv frame base
    stp x0, x1, [x15] ; hv store L70
    add x15, sp, #1120 ; hv frame base
    ldp x0, x1, [x15] ; hv load L70
    add x15, sp, #1136 ; hv frame base
    stp x0, x1, [x15] ; hv store L71
    add x15, sp, #1104 ; hv frame base
    ldp x0, x1, [x15] ; hv load L69
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #69 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1152 ; hv frame base
    stp x0, x1, [x15] ; hv store L72
    add x15, sp, #1152 ; hv frame base
    ldp x0, x1, [x15] ; hv load L72
    add x15, sp, #1168 ; hv frame base
    stp x0, x1, [x15] ; hv store L73
    add x15, sp, #1136 ; hv frame base
    ldp x0, x1, [x15] ; hv load L71
    add x15, sp, #1168 ; hv frame base
    ldp x2, x3, [x15] ; hv load L73
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1184 ; hv frame base
    stp x0, x1, [x15] ; hv store L74
    add x15, sp, #1184 ; hv frame base
    ldp x0, x1, [x15] ; hv load L74
    add x15, sp, #1200 ; hv frame base
    stp x0, x1, [x15] ; hv store L75
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1216 ; hv frame base
    stp x0, x1, [x15] ; hv store L76
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1232 ; hv frame base
    stp x0, x1, [x15] ; hv store L77
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1248 ; hv frame base
    stp x0, x1, [x15] ; hv store L78
    add x15, sp, #1200 ; hv frame base
    ldp x0, x1, [x15] ; hv load L75
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1264 ; hv frame base
    stp x0, x1, [x15] ; hv store L79
    add x15, sp, #1264 ; hv frame base
    ldp x0, x1, [x15] ; hv load L79
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb30 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb29 ; branch -> then
__L40fd_rt_parse_float_native_bb15:
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #48 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #784 ; hv frame base
    stp x0, x1, [x15] ; hv store L49
    add x15, sp, #784 ; hv frame base
    ldp x0, x1, [x15] ; hv load L49
    add x15, sp, #800 ; hv frame base
    stp x0, x1, [x15] ; hv store L50
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #13107 ; imm 0-15
    movk x1, #13107, lsl #16 ; imm 16-31
    movk x1, #13107, lsl #32 ; imm 32-47
    movk x1, #3, lsl #48 ; imm 48-63
    ldp x2, x3, [sp, #480] ; hv load L30
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #816 ; hv frame base
    stp x0, x1, [x15] ; hv store L51
    add x15, sp, #816 ; hv frame base
    ldp x0, x1, [x15] ; hv load L51
    add x15, sp, #832 ; hv frame base
    stp x0, x1, [x15] ; hv store L52
    add x15, sp, #832 ; hv frame base
    ldp x0, x1, [x15] ; hv load L52
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #848 ; hv frame base
    stp x0, x1, [x15] ; hv store L53
    add x15, sp, #848 ; hv frame base
    ldp x0, x1, [x15] ; hv load L53
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb18 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb17 ; branch -> then
__L40fd_rt_parse_float_native_bb16:
    add x15, sp, #736 ; hv frame base
    ldp x0, x1, [x15] ; hv load L46
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1008 ; hv frame base
    stp x0, x1, [x15] ; hv store L63
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb23 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb22 ; branch -> then
__L40fd_rt_parse_float_native_bb17:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #544 ; hv frame base
    stp x0, x1, [x15] ; hv store L34
    b __L40fd_rt_parse_float_native_bb19 ; branch
__L40fd_rt_parse_float_native_bb18:
    ldp x0, x1, [sp, #480] ; hv load L30
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    add x15, sp, #880 ; hv frame base
    stp x0, x1, [x15] ; hv store L55
    add x15, sp, #880 ; hv frame base
    ldp x0, x1, [x15] ; hv load L55
    add x15, sp, #896 ; hv frame base
    stp x0, x1, [x15] ; hv store L56
    add x15, sp, #896 ; hv frame base
    ldp x0, x1, [x15] ; hv load L56
    add x15, sp, #800 ; hv frame base
    ldp x2, x3, [x15] ; hv load L50
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #912 ; hv frame base
    stp x0, x1, [x15] ; hv store L57
    add x15, sp, #912 ; hv frame base
    ldp x0, x1, [x15] ; hv load L57
    stp x0, x1, [sp, #480] ; hv store L30
    b __L40fd_rt_parse_float_native_bb19 ; branch
__L40fd_rt_parse_float_native_bb19:
    ldp x0, x1, [sp, #496] ; hv load L31
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #928 ; hv frame base
    stp x0, x1, [x15] ; hv store L58
    add x15, sp, #928 ; hv frame base
    ldp x0, x1, [x15] ; hv load L58
    stp x0, x1, [sp, #496] ; hv store L31
    add x15, sp, #528 ; hv frame base
    ldp x0, x1, [x15] ; hv load L33
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #944 ; hv frame base
    stp x0, x1, [x15] ; hv store L59
    add x15, sp, #944 ; hv frame base
    ldp x0, x1, [x15] ; hv load L59
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb21 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb20 ; branch -> then
__L40fd_rt_parse_float_native_bb20:
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #976 ; hv frame base
    stp x0, x1, [x15] ; hv store L61
    add x15, sp, #976 ; hv frame base
    ldp x0, x1, [x15] ; hv load L61
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    b __L40fd_rt_parse_float_native_bb21 ; branch
__L40fd_rt_parse_float_native_bb21:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #992 ; hv frame base
    stp x0, x1, [x15] ; hv store L62
    add x15, sp, #992 ; hv frame base
    ldp x0, x1, [x15] ; hv load L62
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb28 ; branch
__L40fd_rt_parse_float_native_bb22:
    add x15, sp, #528 ; hv frame base
    ldp x0, x1, [x15] ; hv load L33
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1040 ; hv frame base
    stp x0, x1, [x15] ; hv store L65
    add x15, sp, #1040 ; hv frame base
    ldp x0, x1, [x15] ; hv load L65
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb25 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb24 ; branch -> then
__L40fd_rt_parse_float_native_bb23:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    b __L40fd_rt_parse_float_native_bb27 ; branch
__L40fd_rt_parse_float_native_bb24:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    b __L40fd_rt_parse_float_native_bb26 ; branch
__L40fd_rt_parse_float_native_bb25:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1072 ; hv frame base
    stp x0, x1, [x15] ; hv store L67
    add x15, sp, #1072 ; hv frame base
    ldp x0, x1, [x15] ; hv load L67
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb26 ; branch
__L40fd_rt_parse_float_native_bb26:
    b __L40fd_rt_parse_float_native_bb27 ; branch
__L40fd_rt_parse_float_native_bb27:
    b __L40fd_rt_parse_float_native_bb28 ; branch
__L40fd_rt_parse_float_native_bb28:
    b __L40fd_rt_parse_float_native_bb12 ; branch
__L40fd_rt_parse_float_native_bb29:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1296 ; hv frame base
    stp x0, x1, [x15] ; hv store L81
    add x15, sp, #1296 ; hv frame base
    ldp x0, x1, [x15] ; hv load L81
    stp x0, x1, [sp, #64] ; hv store L3
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #1312 ; hv frame base
    stp x0, x1, [x15] ; hv store L82
    add x15, sp, #1312 ; hv frame base
    ldp x0, x1, [x15] ; hv load L82
    add x15, sp, #1328 ; hv frame base
    stp x0, x1, [x15] ; hv store L83
    add x15, sp, #1328 ; hv frame base
    ldp x0, x1, [x15] ; hv load L83
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #43 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1344 ; hv frame base
    stp x0, x1, [x15] ; hv store L84
    add x15, sp, #1344 ; hv frame base
    ldp x0, x1, [x15] ; hv load L84
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb32 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb31 ; branch -> then
__L40fd_rt_parse_float_native_bb30:
    add x15, sp, #1200 ; hv frame base
    ldp x0, x1, [x15] ; hv load L75
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1792 ; hv frame base
    stp x0, x1, [x15] ; hv store L112
    add x15, sp, #1792 ; hv frame base
    ldp x0, x1, [x15] ; hv load L112
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb45 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb44 ; branch -> then
__L40fd_rt_parse_float_native_bb31:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1376 ; hv frame base
    stp x0, x1, [x15] ; hv store L86
    add x15, sp, #1376 ; hv frame base
    ldp x0, x1, [x15] ; hv load L86
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb35 ; branch
__L40fd_rt_parse_float_native_bb32:
    add x15, sp, #1328 ; hv frame base
    ldp x0, x1, [x15] ; hv load L83
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #45 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1392 ; hv frame base
    stp x0, x1, [x15] ; hv store L87
    add x15, sp, #1392 ; hv frame base
    ldp x0, x1, [x15] ; hv load L87
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb34 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb33 ; branch -> then
__L40fd_rt_parse_float_native_bb33:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1216 ; hv frame base
    stp x0, x1, [x15] ; hv store L76
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1424 ; hv frame base
    stp x0, x1, [x15] ; hv store L89
    add x15, sp, #1424 ; hv frame base
    ldp x0, x1, [x15] ; hv load L89
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb34 ; branch
__L40fd_rt_parse_float_native_bb34:
    b __L40fd_rt_parse_float_native_bb35 ; branch
__L40fd_rt_parse_float_native_bb35:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1440 ; hv frame base
    stp x0, x1, [x15] ; hv store L90
    b __L40fd_rt_parse_float_native_bb36 ; branch
__L40fd_rt_parse_float_native_bb36:
    add x15, sp, #1440 ; hv frame base
    ldp x0, x1, [x15] ; hv load L90
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1456 ; hv frame base
    stp x0, x1, [x15] ; hv store L91
    add x15, sp, #1456 ; hv frame base
    ldp x0, x1, [x15] ; hv load L91
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb38 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb37 ; branch -> then
__L40fd_rt_parse_float_native_bb37:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #1472 ; hv frame base
    stp x0, x1, [x15] ; hv store L92
    add x15, sp, #1472 ; hv frame base
    ldp x0, x1, [x15] ; hv load L92
    add x15, sp, #1488 ; hv frame base
    stp x0, x1, [x15] ; hv store L93
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #47 ; hv const_int val
    add x15, sp, #1488 ; hv frame base
    ldp x2, x3, [x15] ; hv load L93
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1504 ; hv frame base
    stp x0, x1, [x15] ; hv store L94
    add x15, sp, #1504 ; hv frame base
    ldp x0, x1, [x15] ; hv load L94
    add x15, sp, #1520 ; hv frame base
    stp x0, x1, [x15] ; hv store L95
    add x15, sp, #1488 ; hv frame base
    ldp x0, x1, [x15] ; hv load L93
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #58 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1536 ; hv frame base
    stp x0, x1, [x15] ; hv store L96
    add x15, sp, #1536 ; hv frame base
    ldp x0, x1, [x15] ; hv load L96
    add x15, sp, #1552 ; hv frame base
    stp x0, x1, [x15] ; hv store L97
    add x15, sp, #1520 ; hv frame base
    ldp x0, x1, [x15] ; hv load L95
    add x15, sp, #1552 ; hv frame base
    ldp x2, x3, [x15] ; hv load L97
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #1568 ; hv frame base
    stp x0, x1, [x15] ; hv store L98
    add x15, sp, #1568 ; hv frame base
    ldp x0, x1, [x15] ; hv load L98
    add x15, sp, #1584 ; hv frame base
    stp x0, x1, [x15] ; hv store L99
    add x15, sp, #1584 ; hv frame base
    ldp x0, x1, [x15] ; hv load L99
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1600 ; hv frame base
    stp x0, x1, [x15] ; hv store L100
    add x15, sp, #1600 ; hv frame base
    ldp x0, x1, [x15] ; hv load L100
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb40 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb39 ; branch -> then
__L40fd_rt_parse_float_native_bb38:
    b __L40fd_rt_parse_float_native_bb30 ; branch
__L40fd_rt_parse_float_native_bb39:
    add x15, sp, #1488 ; hv frame base
    ldp x0, x1, [x15] ; hv load L93
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #48 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1632 ; hv frame base
    stp x0, x1, [x15] ; hv store L102
    add x15, sp, #1632 ; hv frame base
    ldp x0, x1, [x15] ; hv load L102
    add x15, sp, #1648 ; hv frame base
    stp x0, x1, [x15] ; hv store L103
    add x15, sp, #1232 ; hv frame base
    ldp x0, x1, [x15] ; hv load L77
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    add x15, sp, #1664 ; hv frame base
    stp x0, x1, [x15] ; hv store L104
    add x15, sp, #1664 ; hv frame base
    ldp x0, x1, [x15] ; hv load L104
    add x15, sp, #1680 ; hv frame base
    stp x0, x1, [x15] ; hv store L105
    add x15, sp, #1680 ; hv frame base
    ldp x0, x1, [x15] ; hv load L105
    add x15, sp, #1648 ; hv frame base
    ldp x2, x3, [x15] ; hv load L103
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1696 ; hv frame base
    stp x0, x1, [x15] ; hv store L106
    add x15, sp, #1696 ; hv frame base
    ldp x0, x1, [x15] ; hv load L106
    add x15, sp, #1232 ; hv frame base
    stp x0, x1, [x15] ; hv store L77
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1248 ; hv frame base
    stp x0, x1, [x15] ; hv store L78
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1000 ; hv const_int val
    add x15, sp, #1232 ; hv frame base
    ldp x2, x3, [x15] ; hv load L77
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1712 ; hv frame base
    stp x0, x1, [x15] ; hv store L107
    add x15, sp, #1712 ; hv frame base
    ldp x0, x1, [x15] ; hv load L107
    add x15, sp, #1728 ; hv frame base
    stp x0, x1, [x15] ; hv store L108
    add x15, sp, #1728 ; hv frame base
    ldp x0, x1, [x15] ; hv load L108
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1744 ; hv frame base
    stp x0, x1, [x15] ; hv store L109
    add x15, sp, #1744 ; hv frame base
    ldp x0, x1, [x15] ; hv load L109
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb42 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb41 ; branch -> then
__L40fd_rt_parse_float_native_bb40:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1440 ; hv frame base
    stp x0, x1, [x15] ; hv store L90
    b __L40fd_rt_parse_float_native_bb43 ; branch
__L40fd_rt_parse_float_native_bb41:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1000 ; hv const_int val
    add x15, sp, #1232 ; hv frame base
    stp x0, x1, [x15] ; hv store L77
    b __L40fd_rt_parse_float_native_bb42 ; branch
__L40fd_rt_parse_float_native_bb42:
    ldp x0, x1, [sp, #64] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1776 ; hv frame base
    stp x0, x1, [x15] ; hv store L111
    add x15, sp, #1776 ; hv frame base
    ldp x0, x1, [x15] ; hv load L111
    stp x0, x1, [sp, #64] ; hv store L3
    b __L40fd_rt_parse_float_native_bb43 ; branch
__L40fd_rt_parse_float_native_bb43:
    b __L40fd_rt_parse_float_native_bb36 ; branch
__L40fd_rt_parse_float_native_bb44:
    add x15, sp, #1216 ; hv frame base
    ldp x0, x1, [x15] ; hv load L76
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1824 ; hv frame base
    stp x0, x1, [x15] ; hv store L114
    add x15, sp, #1824 ; hv frame base
    ldp x0, x1, [x15] ; hv load L114
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb47 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb46 ; branch -> then
__L40fd_rt_parse_float_native_bb45:
    ldp x0, x1, [sp, #48] ; hv load L2
    ldp x2, x3, [sp, #64] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #1888 ; hv frame base
    stp x0, x1, [x15] ; hv store L118
    add x15, sp, #1888 ; hv frame base
    ldp x0, x1, [x15] ; hv load L118
    add x15, sp, #1904 ; hv frame base
    stp x0, x1, [x15] ; hv store L119
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    ldp x0, x1, [sp, #496] ; hv load L31
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1936 ; hv frame base
    stp x0, x1, [x15] ; hv store L121
    add x15, sp, #1936 ; hv frame base
    ldp x0, x1, [x15] ; hv load L121
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb50 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb49 ; branch -> then
__L40fd_rt_parse_float_native_bb46:
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    add x15, sp, #1232 ; hv frame base
    ldp x2, x3, [x15] ; hv load L77
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1856 ; hv frame base
    stp x0, x1, [x15] ; hv store L116
    add x15, sp, #1856 ; hv frame base
    ldp x0, x1, [x15] ; hv load L116
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    b __L40fd_rt_parse_float_native_bb48 ; branch
__L40fd_rt_parse_float_native_bb47:
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    add x15, sp, #1232 ; hv frame base
    ldp x2, x3, [x15] ; hv load L77
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1872 ; hv frame base
    stp x0, x1, [x15] ; hv store L117
    add x15, sp, #1872 ; hv frame base
    ldp x0, x1, [x15] ; hv load L117
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    b __L40fd_rt_parse_float_native_bb48 ; branch
__L40fd_rt_parse_float_native_bb48:
    b __L40fd_rt_parse_float_native_bb45 ; branch
__L40fd_rt_parse_float_native_bb49:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb50 ; branch
__L40fd_rt_parse_float_native_bb50:
    add x15, sp, #544 ; hv frame base
    ldp x0, x1, [x15] ; hv load L34
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1968 ; hv frame base
    stp x0, x1, [x15] ; hv store L123
    add x15, sp, #1968 ; hv frame base
    ldp x0, x1, [x15] ; hv load L123
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb52 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb51 ; branch -> then
__L40fd_rt_parse_float_native_bb51:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb52 ; branch
__L40fd_rt_parse_float_native_bb52:
    add x15, sp, #1200 ; hv frame base
    ldp x0, x1, [x15] ; hv load L75
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2000 ; hv frame base
    stp x0, x1, [x15] ; hv store L125
    add x15, sp, #2000 ; hv frame base
    ldp x0, x1, [x15] ; hv load L125
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb54 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb53 ; branch -> then
__L40fd_rt_parse_float_native_bb53:
    add x15, sp, #1248 ; hv frame base
    ldp x0, x1, [x15] ; hv load L78
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #2032 ; hv frame base
    stp x0, x1, [x15] ; hv store L127
    add x15, sp, #2032 ; hv frame base
    ldp x0, x1, [x15] ; hv load L127
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb56 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb55 ; branch -> then
__L40fd_rt_parse_float_native_bb54:
    add x15, sp, #1904 ; hv frame base
    ldp x0, x1, [x15] ; hv load L119
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2064 ; hv frame base
    stp x0, x1, [x15] ; hv store L129
    add x15, sp, #2064 ; hv frame base
    ldp x0, x1, [x15] ; hv load L129
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb58 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb57 ; branch -> then
__L40fd_rt_parse_float_native_bb55:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb56 ; branch
__L40fd_rt_parse_float_native_bb56:
    b __L40fd_rt_parse_float_native_bb54 ; branch
__L40fd_rt_parse_float_native_bb57:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb58 ; branch
__L40fd_rt_parse_float_native_bb58:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #22 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    ldp x2, x3, [x15] ; hv load L32
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #2096 ; hv frame base
    stp x0, x1, [x15] ; hv store L131
    add x15, sp, #2096 ; hv frame base
    ldp x0, x1, [x15] ; hv load L131
    add x15, sp, #2112 ; hv frame base
    stp x0, x1, [x15] ; hv store L132
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #2128 ; hv frame base
    stp x0, x1, [x15] ; hv store L133
    add x15, sp, #2128 ; hv frame base
    ldp x0, x1, [x15] ; hv load L133
    add x15, sp, #2144 ; hv frame base
    stp x0, x1, [x15] ; hv store L134
    add x15, sp, #2112 ; hv frame base
    ldp x0, x1, [x15] ; hv load L132
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2160 ; hv frame base
    stp x0, x1, [x15] ; hv store L135
    add x15, sp, #2160 ; hv frame base
    ldp x0, x1, [x15] ; hv load L135
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb60 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb59 ; branch -> then
__L40fd_rt_parse_float_native_bb59:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb60 ; branch
__L40fd_rt_parse_float_native_bb60:
    add x15, sp, #2144 ; hv frame base
    ldp x0, x1, [x15] ; hv load L134
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2192 ; hv frame base
    stp x0, x1, [x15] ; hv store L137
    add x15, sp, #2192 ; hv frame base
    ldp x0, x1, [x15] ; hv load L137
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb62 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb61 ; branch -> then
__L40fd_rt_parse_float_native_bb61:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    ldp x2, x3, [x15] ; hv load L32
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #2224 ; hv frame base
    stp x0, x1, [x15] ; hv store L139
    add x15, sp, #2224 ; hv frame base
    ldp x0, x1, [x15] ; hv load L139
    add x15, sp, #2240 ; hv frame base
    stp x0, x1, [x15] ; hv store L140
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #22 ; hv const_int val
    add x15, sp, #2240 ; hv frame base
    ldp x2, x3, [x15] ; hv load L140
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #2256 ; hv frame base
    stp x0, x1, [x15] ; hv store L141
    add x15, sp, #2256 ; hv frame base
    ldp x0, x1, [x15] ; hv load L141
    add x15, sp, #2272 ; hv frame base
    stp x0, x1, [x15] ; hv store L142
    add x15, sp, #2272 ; hv frame base
    ldp x0, x1, [x15] ; hv load L142
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2288 ; hv frame base
    stp x0, x1, [x15] ; hv store L143
    add x15, sp, #2288 ; hv frame base
    ldp x0, x1, [x15] ; hv load L143
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb64 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb63 ; branch -> then
__L40fd_rt_parse_float_native_bb62:
    add x15, sp, #1920 ; hv frame base
    ldp x0, x1, [x15] ; hv load L120
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2320 ; hv frame base
    stp x0, x1, [x15] ; hv store L145
    add x15, sp, #2320 ; hv frame base
    ldp x0, x1, [x15] ; hv load L145
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb66 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb65 ; branch -> then
__L40fd_rt_parse_float_native_bb63:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    b __L40fd_rt_parse_float_native_bb64 ; branch
__L40fd_rt_parse_float_native_bb64:
    b __L40fd_rt_parse_float_native_bb62 ; branch
__L40fd_rt_parse_float_native_bb65:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #4 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    mov x0, x1 ; __hx_make_val: lo = tag word
    mov x1, x3 ; __hx_make_val: hi = payload word
    add x15, sp, #2352 ; hv frame base
    stp x0, x1, [x15] ; hv store L147
    add x15, sp, #2352 ; hv frame base
    ldp x0, x1, [x15] ; hv load L147
    add sp, sp, #2880 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__L40fd_rt_parse_float_native_bb66:
    ldp x0, x1, [sp, #480] ; hv load L30
    scvtf d0, x1 ; __hx_to_double: d0 = (double)int
    fmov x2, d0 ; __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 ; __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq ; __hx_to_double: float→keep bits, int→converted
    movz x0, #1 ; __hx_to_double: TAG_FLOAT
    add x15, sp, #2368 ; hv frame base
    stp x0, x1, [x15] ; hv store L148
    add x15, sp, #2368 ; hv frame base
    ldp x0, x1, [x15] ; hv load L148
    add x15, sp, #2384 ; hv frame base
    stp x0, x1, [x15] ; hv store L149
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #2400 ; hv frame base
    stp x0, x1, [x15] ; hv store L150
    add x15, sp, #2400 ; hv frame base
    ldp x0, x1, [x15] ; hv load L150
    add x15, sp, #2416 ; hv frame base
    stp x0, x1, [x15] ; hv store L151
    add x15, sp, #2416 ; hv frame base
    ldp x0, x1, [x15] ; hv load L151
    scvtf d0, x1 ; __hx_to_double: d0 = (double)int
    fmov x2, d0 ; __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 ; __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq ; __hx_to_double: float→keep bits, int→converted
    movz x0, #1 ; __hx_to_double: TAG_FLOAT
    add x15, sp, #2432 ; hv frame base
    stp x0, x1, [x15] ; hv store L152
    add x15, sp, #2432 ; hv frame base
    ldp x0, x1, [x15] ; hv load L152
    add x15, sp, #2448 ; hv frame base
    stp x0, x1, [x15] ; hv store L153
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #10 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #2464 ; hv frame base
    stp x0, x1, [x15] ; hv store L154
    add x15, sp, #2464 ; hv frame base
    ldp x0, x1, [x15] ; hv load L154
    add x15, sp, #2480 ; hv frame base
    stp x0, x1, [x15] ; hv store L155
    add x15, sp, #2480 ; hv frame base
    ldp x0, x1, [x15] ; hv load L155
    scvtf d0, x1 ; __hx_to_double: d0 = (double)int
    fmov x2, d0 ; __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 ; __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq ; __hx_to_double: float→keep bits, int→converted
    movz x0, #1 ; __hx_to_double: TAG_FLOAT
    add x15, sp, #2496 ; hv frame base
    stp x0, x1, [x15] ; hv store L156
    add x15, sp, #2496 ; hv frame base
    ldp x0, x1, [x15] ; hv load L156
    add x15, sp, #2512 ; hv frame base
    stp x0, x1, [x15] ; hv store L157
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    add x15, sp, #2528 ; hv frame base
    stp x0, x1, [x15] ; hv store L158
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #2544 ; hv frame base
    stp x0, x1, [x15] ; hv store L159
    add x15, sp, #2544 ; hv frame base
    ldp x0, x1, [x15] ; hv load L159
    add x15, sp, #2560 ; hv frame base
    stp x0, x1, [x15] ; hv store L160
    add x15, sp, #2560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L160
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2576 ; hv frame base
    stp x0, x1, [x15] ; hv store L161
    add x15, sp, #2576 ; hv frame base
    ldp x0, x1, [x15] ; hv load L161
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb68 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb67 ; branch -> then
__L40fd_rt_parse_float_native_bb67:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    ldp x2, x3, [x15] ; hv load L32
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #2608 ; hv frame base
    stp x0, x1, [x15] ; hv store L163
    add x15, sp, #2608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L163
    add x15, sp, #2528 ; hv frame base
    stp x0, x1, [x15] ; hv store L158
    b __L40fd_rt_parse_float_native_bb68 ; branch
__L40fd_rt_parse_float_native_bb68:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #2624 ; hv frame base
    stp x0, x1, [x15] ; hv store L164
    b __L40fd_rt_parse_float_native_bb69 ; branch
__L40fd_rt_parse_float_native_bb69:
    add x15, sp, #2624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L164
    add x15, sp, #2528 ; hv frame base
    ldp x2, x3, [x15] ; hv load L158
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #2640 ; hv frame base
    stp x0, x1, [x15] ; hv store L165
    add x15, sp, #2640 ; hv frame base
    ldp x0, x1, [x15] ; hv load L165
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb71 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb70 ; branch -> then
__L40fd_rt_parse_float_native_bb70:
    add x15, sp, #2448 ; hv frame base
    ldp x0, x1, [x15] ; hv load L153
    add x15, sp, #2512 ; hv frame base
    ldp x2, x3, [x15] ; hv load L157
    fmov d0, x1 ; __hx_payload_fmul: d0 = a.f
    fmov d1, x3 ; __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 ; __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 ; __hx_payload_fmul: x1 = result bits
    movz x0, #1 ; __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2656 ; hv frame base
    stp x0, x1, [x15] ; hv store L166
    add x15, sp, #2656 ; hv frame base
    ldp x0, x1, [x15] ; hv load L166
    add x15, sp, #2448 ; hv frame base
    stp x0, x1, [x15] ; hv store L153
    add x15, sp, #2624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L164
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #2672 ; hv frame base
    stp x0, x1, [x15] ; hv store L167
    add x15, sp, #2672 ; hv frame base
    ldp x0, x1, [x15] ; hv load L167
    add x15, sp, #2624 ; hv frame base
    stp x0, x1, [x15] ; hv store L164
    b __L40fd_rt_parse_float_native_bb69 ; branch
__L40fd_rt_parse_float_native_bb71:
    add x15, sp, #2384 ; hv frame base
    ldp x0, x1, [x15] ; hv load L149
    add x15, sp, #2688 ; hv frame base
    stp x0, x1, [x15] ; hv store L168
    add x15, sp, #2560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L160
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2704 ; hv frame base
    stp x0, x1, [x15] ; hv store L169
    add x15, sp, #2704 ; hv frame base
    ldp x0, x1, [x15] ; hv load L169
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb73 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb72 ; branch -> then
__L40fd_rt_parse_float_native_bb72:
    add x15, sp, #2384 ; hv frame base
    ldp x0, x1, [x15] ; hv load L149
    add x15, sp, #2448 ; hv frame base
    ldp x2, x3, [x15] ; hv load L153
    fmov d0, x1 ; __hx_payload_fdiv: d0 = a.f
    fmov d1, x3 ; __hx_payload_fdiv: d1 = b.f
    fdiv d0, d0, d1 ; __hx_payload_fdiv: d0 = a.f fdiv b.f
    fmov x1, d0 ; __hx_payload_fdiv: x1 = result bits
    movz x0, #1 ; __hx_payload_fdiv: TAG_FLOAT
    add x15, sp, #2736 ; hv frame base
    stp x0, x1, [x15] ; hv store L171
    add x15, sp, #2736 ; hv frame base
    ldp x0, x1, [x15] ; hv load L171
    add x15, sp, #2688 ; hv frame base
    stp x0, x1, [x15] ; hv store L168
    b __L40fd_rt_parse_float_native_bb74 ; branch
__L40fd_rt_parse_float_native_bb73:
    add x15, sp, #2384 ; hv frame base
    ldp x0, x1, [x15] ; hv load L149
    add x15, sp, #2448 ; hv frame base
    ldp x2, x3, [x15] ; hv load L153
    fmov d0, x1 ; __hx_payload_fmul: d0 = a.f
    fmov d1, x3 ; __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 ; __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 ; __hx_payload_fmul: x1 = result bits
    movz x0, #1 ; __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2752 ; hv frame base
    stp x0, x1, [x15] ; hv store L172
    add x15, sp, #2752 ; hv frame base
    ldp x0, x1, [x15] ; hv load L172
    add x15, sp, #2688 ; hv frame base
    stp x0, x1, [x15] ; hv store L168
    b __L40fd_rt_parse_float_native_bb74 ; branch
__L40fd_rt_parse_float_native_bb74:
    ldp x0, x1, [sp, #0] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #2768 ; hv frame base
    stp x0, x1, [x15] ; hv store L173
    add x15, sp, #2768 ; hv frame base
    ldp x0, x1, [x15] ; hv load L173
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __L40fd_rt_parse_float_native_bb76 ; br_cond: !truthy -> else
    b __L40fd_rt_parse_float_native_bb75 ; branch -> then
__L40fd_rt_parse_float_native_bb75:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #2800 ; hv frame base
    stp x0, x1, [x15] ; hv store L175
    add x15, sp, #2800 ; hv frame base
    ldp x0, x1, [x15] ; hv load L175
    add x15, sp, #2816 ; hv frame base
    stp x0, x1, [x15] ; hv store L176
    add x15, sp, #2816 ; hv frame base
    ldp x0, x1, [x15] ; hv load L176
    scvtf d0, x1 ; __hx_to_double: d0 = (double)int
    fmov x2, d0 ; __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 ; __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq ; __hx_to_double: float→keep bits, int→converted
    movz x0, #1 ; __hx_to_double: TAG_FLOAT
    add x15, sp, #2832 ; hv frame base
    stp x0, x1, [x15] ; hv store L177
    add x15, sp, #2832 ; hv frame base
    ldp x0, x1, [x15] ; hv load L177
    add x15, sp, #2848 ; hv frame base
    stp x0, x1, [x15] ; hv store L178
    add x15, sp, #2688 ; hv frame base
    ldp x0, x1, [x15] ; hv load L168
    add x15, sp, #2848 ; hv frame base
    ldp x2, x3, [x15] ; hv load L178
    fmov d0, x1 ; __hx_payload_fmul: d0 = a.f
    fmov d1, x3 ; __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 ; __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 ; __hx_payload_fmul: x1 = result bits
    movz x0, #1 ; __hx_payload_fmul: TAG_FLOAT
    add x15, sp, #2864 ; hv frame base
    stp x0, x1, [x15] ; hv store L179
    add x15, sp, #2864 ; hv frame base
    ldp x0, x1, [x15] ; hv load L179
    add x15, sp, #2688 ; hv frame base
    stp x0, x1, [x15] ; hv store L168
    b __L40fd_rt_parse_float_native_bb76 ; branch
__L40fd_rt_parse_float_native_bb76:
    add x15, sp, #2688 ; hv frame base
    ldp x0, x1, [x15] ; hv load L168
    add sp, sp, #2880 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
