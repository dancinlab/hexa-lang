// num_core_arm64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM — sh-num-native).
// GENERATED: tool/regen_num_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-apple-darwin -o num_core_arm64.s stdlib/runtime/num_core.hexa.
//   Provides the num-core parse half (rt_parse_int_native) as a native
//   raw-mem body (__hx_ptr_load8 byte scan + digit fold + strtoll-faithful
//   overflow clamp, byte-faithful to the C hxlcl_strtoll(cs,NULL,base)). These
//   intrinsics are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed —
//   the array/str_core mechanism (resolve_native_num_core_seed).
//   ABI: Mach-O, _rt_parse_int_native underscore-prefixed; no external. External: NONE (fully self-contained).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_INT_NATIVE + ar this
//   .o into runtime.a so hexa_as_num delegates its string→int path to native.
; hexa-lang emit pass — target=arm64-apple-darwin
; source: /home/summer/dancinlab/hexa-lang/stdlib/runtime/num_core.hexa
.file 1 "stdlib/runtime/num_core.hexa"
.section __TEXT,__text,regular,pure_instructions
.globl _rt_parse_int_native
.private_extern _rt_parse_int_native
    .p2align 2
_rt_parse_int_native:
    .loc 1 78 0
    stp x29, x30, [sp, #-16]! ; prologue: save fp/lr
    mov x29, sp ; prologue: set fp
    sub sp, sp, #2032 ; sp adj
    stp x0, x1, [sp, #0] ; ingress param 0
__Ldd24_rt_parse_int_native_bb0:
    ldp x0, x1, [sp, #0] ; hv load L0
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #16] ; hv store L1
    ldp x0, x1, [sp, #16] ; hv load L1
    stp x0, x1, [sp, #32] ; hv store L2
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #48] ; hv store L3
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    stp x0, x1, [sp, #64] ; hv store L4
    b __Ldd24_rt_parse_int_native_bb1 ; branch
__Ldd24_rt_parse_int_native_bb1:
    ldp x0, x1, [sp, #64] ; hv load L4
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    stp x0, x1, [sp, #80] ; hv store L5
    ldp x0, x1, [sp, #80] ; hv load L5
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb3 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb2 ; branch -> then
__Ldd24_rt_parse_int_native_bb2:
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #96] ; hv store L6
    ldp x0, x1, [sp, #96] ; hv load L6
    stp x0, x1, [sp, #112] ; hv store L7
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #32 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] ; hv store L8
    ldp x0, x1, [sp, #128] ; hv load L8
    stp x0, x1, [sp, #144] ; hv store L9
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    ldp x2, x3, [sp, #112] ; hv load L7
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #160] ; hv store L10
    ldp x0, x1, [sp, #160] ; hv load L10
    stp x0, x1, [sp, #176] ; hv store L11
    ldp x0, x1, [sp, #112] ; hv load L7
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #14 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    stp x0, x1, [sp, #192] ; hv store L12
    ldp x0, x1, [sp, #192] ; hv load L12
    stp x0, x1, [sp, #208] ; hv store L13
    ldp x0, x1, [sp, #176] ; hv load L11
    ldp x2, x3, [sp, #208] ; hv load L13
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #224] ; hv store L14
    ldp x0, x1, [sp, #224] ; hv load L14
    stp x0, x1, [sp, #240] ; hv store L15
    ldp x0, x1, [sp, #144] ; hv load L9
    ldp x2, x3, [sp, #240] ; hv load L15
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] ; hv store L16
    ldp x0, x1, [sp, #256] ; hv load L16
    stp x0, x1, [sp, #272] ; hv store L17
    ldp x0, x1, [sp, #272] ; hv load L17
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    stp x0, x1, [sp, #288] ; hv store L18
    ldp x0, x1, [sp, #288] ; hv load L18
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb5 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb4 ; branch -> then
__Ldd24_rt_parse_int_native_bb3:
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #336] ; hv store L21
    ldp x0, x1, [sp, #336] ; hv load L21
    stp x0, x1, [sp, #352] ; hv store L22
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #352] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #43 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #384] ; hv store L24
    ldp x0, x1, [sp, #384] ; hv load L24
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb8 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb7 ; branch -> then
__Ldd24_rt_parse_int_native_bb4:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #320] ; hv store L20
    ldp x0, x1, [sp, #320] ; hv load L20
    stp x0, x1, [sp, #48] ; hv store L3
    b __Ldd24_rt_parse_int_native_bb6 ; branch
__Ldd24_rt_parse_int_native_bb5:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    stp x0, x1, [sp, #64] ; hv store L4
    b __Ldd24_rt_parse_int_native_bb6 ; branch
__Ldd24_rt_parse_int_native_bb6:
    b __Ldd24_rt_parse_int_native_bb1 ; branch
__Ldd24_rt_parse_int_native_bb7:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #416] ; hv store L26
    ldp x0, x1, [sp, #416] ; hv load L26
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #432] ; hv store L27
    ldp x0, x1, [sp, #432] ; hv load L27
    stp x0, x1, [sp, #352] ; hv store L22
    b __Ldd24_rt_parse_int_native_bb11 ; branch
__Ldd24_rt_parse_int_native_bb8:
    ldp x0, x1, [sp, #352] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #45 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    stp x0, x1, [sp, #448] ; hv store L28
    ldp x0, x1, [sp, #448] ; hv load L28
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb10 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb9 ; branch -> then
__Ldd24_rt_parse_int_native_bb9:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    stp x0, x1, [sp, #368] ; hv store L23
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #480] ; hv store L30
    ldp x0, x1, [sp, #480] ; hv load L30
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    stp x0, x1, [sp, #496] ; hv store L31
    ldp x0, x1, [sp, #496] ; hv load L31
    stp x0, x1, [sp, #352] ; hv store L22
    b __Ldd24_rt_parse_int_native_bb10 ; branch
__Ldd24_rt_parse_int_native_bb10:
    b __Ldd24_rt_parse_int_native_bb11 ; branch
__Ldd24_rt_parse_int_native_bb11:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #10 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    ldp x0, x1, [sp, #352] ; hv load L22
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #48 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #528 ; hv frame base
    stp x0, x1, [x15] ; hv store L33
    add x15, sp, #528 ; hv frame base
    ldp x0, x1, [x15] ; hv load L33
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb13 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb12 ; branch -> then
__Ldd24_rt_parse_int_native_bb12:
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #560 ; hv frame base
    stp x0, x1, [x15] ; hv store L35
    add x15, sp, #560 ; hv frame base
    ldp x0, x1, [x15] ; hv load L35
    add x15, sp, #576 ; hv frame base
    stp x0, x1, [x15] ; hv store L36
    ldp x0, x1, [sp, #32] ; hv load L2
    add x15, sp, #576 ; hv frame base
    ldp x2, x3, [x15] ; hv load L36
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #592 ; hv frame base
    stp x0, x1, [x15] ; hv store L37
    add x15, sp, #592 ; hv frame base
    ldp x0, x1, [x15] ; hv load L37
    add x15, sp, #608 ; hv frame base
    stp x0, x1, [x15] ; hv store L38
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #120 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #624 ; hv frame base
    stp x0, x1, [x15] ; hv store L39
    add x15, sp, #624 ; hv frame base
    ldp x0, x1, [x15] ; hv load L39
    add x15, sp, #640 ; hv frame base
    stp x0, x1, [x15] ; hv store L40
    add x15, sp, #608 ; hv frame base
    ldp x0, x1, [x15] ; hv load L38
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #88 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
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
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #688 ; hv frame base
    stp x0, x1, [x15] ; hv store L43
    add x15, sp, #688 ; hv frame base
    ldp x0, x1, [x15] ; hv load L43
    add x15, sp, #704 ; hv frame base
    stp x0, x1, [x15] ; hv store L44
    add x15, sp, #704 ; hv frame base
    ldp x0, x1, [x15] ; hv load L44
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #720 ; hv frame base
    stp x0, x1, [x15] ; hv store L45
    add x15, sp, #720 ; hv frame base
    ldp x0, x1, [x15] ; hv load L45
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb15 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb14 ; branch -> then
__Ldd24_rt_parse_int_native_bb13:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #52428 ; imm 0-15
    movk x1, #52428, lsl #16 ; imm 16-31
    movk x1, #52428, lsl #32 ; imm 32-47
    movk x1, #3276, lsl #48 ; imm 48-63
    add x15, sp, #784 ; hv frame base
    stp x0, x1, [x15] ; hv store L49
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #7 ; hv const_int val
    add x15, sp, #800 ; hv frame base
    stp x0, x1, [x15] ; hv store L50
    ldp x0, x1, [sp, #368] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #816 ; hv frame base
    stp x0, x1, [x15] ; hv store L51
    add x15, sp, #816 ; hv frame base
    ldp x0, x1, [x15] ; hv load L51
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb17 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb16 ; branch -> then
__Ldd24_rt_parse_int_native_bb14:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #16 ; hv const_int val
    add x15, sp, #512 ; hv frame base
    stp x0, x1, [x15] ; hv store L32
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #2 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #752 ; hv frame base
    stp x0, x1, [x15] ; hv store L47
    add x15, sp, #752 ; hv frame base
    ldp x0, x1, [x15] ; hv load L47
    stp x0, x1, [sp, #48] ; hv store L3
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #768 ; hv frame base
    stp x0, x1, [x15] ; hv store L48
    add x15, sp, #768 ; hv frame base
    ldp x0, x1, [x15] ; hv load L48
    stp x0, x1, [sp, #352] ; hv store L22
    b __Ldd24_rt_parse_int_native_bb15 ; branch
__Ldd24_rt_parse_int_native_bb15:
    b __Ldd24_rt_parse_int_native_bb13 ; branch
__Ldd24_rt_parse_int_native_bb16:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #52428 ; imm 0-15
    movk x1, #52428, lsl #16 ; imm 16-31
    movk x1, #52428, lsl #32 ; imm 32-47
    movk x1, #3276, lsl #48 ; imm 48-63
    add x15, sp, #784 ; hv frame base
    stp x0, x1, [x15] ; hv store L49
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #8 ; hv const_int val
    add x15, sp, #800 ; hv frame base
    stp x0, x1, [x15] ; hv store L50
    b __Ldd24_rt_parse_int_native_bb17 ; branch
__Ldd24_rt_parse_int_native_bb17:
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #848 ; hv frame base
    stp x0, x1, [x15] ; hv store L53
    add x15, sp, #848 ; hv frame base
    ldp x0, x1, [x15] ; hv load L53
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb19 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb18 ; branch -> then
__Ldd24_rt_parse_int_native_bb18:
    ldp x0, x1, [sp, #368] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #880 ; hv frame base
    stp x0, x1, [x15] ; hv store L55
    add x15, sp, #880 ; hv frame base
    ldp x0, x1, [x15] ; hv load L55
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb21 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb20 ; branch -> then
__Ldd24_rt_parse_int_native_bb19:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #912 ; hv frame base
    stp x0, x1, [x15] ; hv store L57
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #928 ; hv frame base
    stp x0, x1, [x15] ; hv store L58
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #944 ; hv frame base
    stp x0, x1, [x15] ; hv store L59
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #960 ; hv frame base
    stp x0, x1, [x15] ; hv store L60
    b __Ldd24_rt_parse_int_native_bb23 ; branch
__Ldd24_rt_parse_int_native_bb20:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #65535 ; imm 0-15
    movk x1, #65535, lsl #16 ; imm 16-31
    movk x1, #65535, lsl #32 ; imm 32-47
    movk x1, #2047, lsl #48 ; imm 48-63
    add x15, sp, #784 ; hv frame base
    stp x0, x1, [x15] ; hv store L49
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #15 ; hv const_int val
    add x15, sp, #800 ; hv frame base
    stp x0, x1, [x15] ; hv store L50
    b __Ldd24_rt_parse_int_native_bb22 ; branch
__Ldd24_rt_parse_int_native_bb21:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; imm 0-15
    movk x1, #2048, lsl #48 ; imm 48-63
    add x15, sp, #784 ; hv frame base
    stp x0, x1, [x15] ; hv store L49
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #800 ; hv frame base
    stp x0, x1, [x15] ; hv store L50
    b __Ldd24_rt_parse_int_native_bb22 ; branch
__Ldd24_rt_parse_int_native_bb22:
    b __Ldd24_rt_parse_int_native_bb19 ; branch
__Ldd24_rt_parse_int_native_bb23:
    add x15, sp, #960 ; hv frame base
    ldp x0, x1, [x15] ; hv load L60
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #976 ; hv frame base
    stp x0, x1, [x15] ; hv store L61
    add x15, sp, #976 ; hv frame base
    ldp x0, x1, [x15] ; hv load L61
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb25 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb24 ; branch -> then
__Ldd24_rt_parse_int_native_bb24:
    ldp x0, x1, [sp, #32] ; hv load L2
    ldp x2, x3, [sp, #48] ; hv load L3
    add x1, x1, x3 ; __hx_ptr_load8: addr = ptr + off
    ldrb w1, [x1] ; __hx_ptr_load8: w1 = *(u8*)addr (zero-ext)
    movz x0, #0 ; __hx_ptr_load8: TAG_INT
    add x15, sp, #992 ; hv frame base
    stp x0, x1, [x15] ; hv store L62
    add x15, sp, #992 ; hv frame base
    ldp x0, x1, [x15] ; hv load L62
    add x15, sp, #1008 ; hv frame base
    stp x0, x1, [x15] ; hv store L63
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1024 ; hv frame base
    stp x0, x1, [x15] ; hv store L64
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #1040 ; hv frame base
    stp x0, x1, [x15] ; hv store L65
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #47 ; hv const_int val
    add x15, sp, #1008 ; hv frame base
    ldp x2, x3, [x15] ; hv load L63
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1056 ; hv frame base
    stp x0, x1, [x15] ; hv store L66
    add x15, sp, #1056 ; hv frame base
    ldp x0, x1, [x15] ; hv load L66
    add x15, sp, #1072 ; hv frame base
    stp x0, x1, [x15] ; hv store L67
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #58 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1088 ; hv frame base
    stp x0, x1, [x15] ; hv store L68
    add x15, sp, #1088 ; hv frame base
    ldp x0, x1, [x15] ; hv load L68
    add x15, sp, #1104 ; hv frame base
    stp x0, x1, [x15] ; hv store L69
    add x15, sp, #1072 ; hv frame base
    ldp x0, x1, [x15] ; hv load L67
    add x15, sp, #1104 ; hv frame base
    ldp x2, x3, [x15] ; hv load L69
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #1120 ; hv frame base
    stp x0, x1, [x15] ; hv store L70
    add x15, sp, #1120 ; hv frame base
    ldp x0, x1, [x15] ; hv load L70
    add x15, sp, #1136 ; hv frame base
    stp x0, x1, [x15] ; hv store L71
    add x15, sp, #1136 ; hv frame base
    ldp x0, x1, [x15] ; hv load L71
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1152 ; hv frame base
    stp x0, x1, [x15] ; hv store L72
    add x15, sp, #1152 ; hv frame base
    ldp x0, x1, [x15] ; hv load L72
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb27 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb26 ; branch -> then
__Ldd24_rt_parse_int_native_bb25:
    add x15, sp, #928 ; hv frame base
    ldp x0, x1, [x15] ; hv load L58
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1824 ; hv frame base
    stp x0, x1, [x15] ; hv store L114
    add x15, sp, #1824 ; hv frame base
    ldp x0, x1, [x15] ; hv load L114
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb43 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb42 ; branch -> then
__Ldd24_rt_parse_int_native_bb26:
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #48 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1184 ; hv frame base
    stp x0, x1, [x15] ; hv store L74
    add x15, sp, #1184 ; hv frame base
    ldp x0, x1, [x15] ; hv load L74
    add x15, sp, #1024 ; hv frame base
    stp x0, x1, [x15] ; hv store L64
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1040 ; hv frame base
    stp x0, x1, [x15] ; hv store L65
    b __Ldd24_rt_parse_int_native_bb35 ; branch
__Ldd24_rt_parse_int_native_bb27:
    add x15, sp, #512 ; hv frame base
    ldp x0, x1, [x15] ; hv load L32
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #16 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1200 ; hv frame base
    stp x0, x1, [x15] ; hv store L75
    add x15, sp, #1200 ; hv frame base
    ldp x0, x1, [x15] ; hv load L75
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb29 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb28 ; branch -> then
__Ldd24_rt_parse_int_native_bb28:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #96 ; hv const_int val
    add x15, sp, #1008 ; hv frame base
    ldp x2, x3, [x15] ; hv load L63
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1232 ; hv frame base
    stp x0, x1, [x15] ; hv store L77
    add x15, sp, #1232 ; hv frame base
    ldp x0, x1, [x15] ; hv load L77
    add x15, sp, #1248 ; hv frame base
    stp x0, x1, [x15] ; hv store L78
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #103 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1264 ; hv frame base
    stp x0, x1, [x15] ; hv store L79
    add x15, sp, #1264 ; hv frame base
    ldp x0, x1, [x15] ; hv load L79
    add x15, sp, #1280 ; hv frame base
    stp x0, x1, [x15] ; hv store L80
    add x15, sp, #1248 ; hv frame base
    ldp x0, x1, [x15] ; hv load L78
    add x15, sp, #1280 ; hv frame base
    ldp x2, x3, [x15] ; hv load L80
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #1296 ; hv frame base
    stp x0, x1, [x15] ; hv store L81
    add x15, sp, #1296 ; hv frame base
    ldp x0, x1, [x15] ; hv load L81
    add x15, sp, #1312 ; hv frame base
    stp x0, x1, [x15] ; hv store L82
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #64 ; hv const_int val
    add x15, sp, #1008 ; hv frame base
    ldp x2, x3, [x15] ; hv load L63
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1328 ; hv frame base
    stp x0, x1, [x15] ; hv store L83
    add x15, sp, #1328 ; hv frame base
    ldp x0, x1, [x15] ; hv load L83
    add x15, sp, #1344 ; hv frame base
    stp x0, x1, [x15] ; hv store L84
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #71 ; hv const_int val
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1360 ; hv frame base
    stp x0, x1, [x15] ; hv store L85
    add x15, sp, #1360 ; hv frame base
    ldp x0, x1, [x15] ; hv load L85
    add x15, sp, #1376 ; hv frame base
    stp x0, x1, [x15] ; hv store L86
    add x15, sp, #1344 ; hv frame base
    ldp x0, x1, [x15] ; hv load L84
    add x15, sp, #1376 ; hv frame base
    ldp x2, x3, [x15] ; hv load L86
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #1392 ; hv frame base
    stp x0, x1, [x15] ; hv store L87
    add x15, sp, #1392 ; hv frame base
    ldp x0, x1, [x15] ; hv load L87
    add x15, sp, #1408 ; hv frame base
    stp x0, x1, [x15] ; hv store L88
    add x15, sp, #1312 ; hv frame base
    ldp x0, x1, [x15] ; hv load L82
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1424 ; hv frame base
    stp x0, x1, [x15] ; hv store L89
    add x15, sp, #1424 ; hv frame base
    ldp x0, x1, [x15] ; hv load L89
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb31 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb30 ; branch -> then
__Ldd24_rt_parse_int_native_bb29:
    b __Ldd24_rt_parse_int_native_bb35 ; branch
__Ldd24_rt_parse_int_native_bb30:
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #87 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1456 ; hv frame base
    stp x0, x1, [x15] ; hv store L91
    add x15, sp, #1456 ; hv frame base
    ldp x0, x1, [x15] ; hv load L91
    add x15, sp, #1024 ; hv frame base
    stp x0, x1, [x15] ; hv store L64
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1040 ; hv frame base
    stp x0, x1, [x15] ; hv store L65
    b __Ldd24_rt_parse_int_native_bb34 ; branch
__Ldd24_rt_parse_int_native_bb31:
    add x15, sp, #1408 ; hv frame base
    ldp x0, x1, [x15] ; hv load L88
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1472 ; hv frame base
    stp x0, x1, [x15] ; hv store L92
    add x15, sp, #1472 ; hv frame base
    ldp x0, x1, [x15] ; hv load L92
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb33 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb32 ; branch -> then
__Ldd24_rt_parse_int_native_bb32:
    add x15, sp, #1008 ; hv frame base
    ldp x0, x1, [x15] ; hv load L63
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #55 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1504 ; hv frame base
    stp x0, x1, [x15] ; hv store L94
    add x15, sp, #1504 ; hv frame base
    ldp x0, x1, [x15] ; hv load L94
    add x15, sp, #1024 ; hv frame base
    stp x0, x1, [x15] ; hv store L64
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #1040 ; hv frame base
    stp x0, x1, [x15] ; hv store L65
    b __Ldd24_rt_parse_int_native_bb33 ; branch
__Ldd24_rt_parse_int_native_bb33:
    b __Ldd24_rt_parse_int_native_bb34 ; branch
__Ldd24_rt_parse_int_native_bb34:
    b __Ldd24_rt_parse_int_native_bb29 ; branch
__Ldd24_rt_parse_int_native_bb35:
    add x15, sp, #1040 ; hv frame base
    ldp x0, x1, [x15] ; hv load L65
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1520 ; hv frame base
    stp x0, x1, [x15] ; hv store L95
    add x15, sp, #1520 ; hv frame base
    ldp x0, x1, [x15] ; hv load L95
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb37 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb36 ; branch -> then
__Ldd24_rt_parse_int_native_bb36:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #960 ; hv frame base
    stp x0, x1, [x15] ; hv store L60
    b __Ldd24_rt_parse_int_native_bb41 ; branch
__Ldd24_rt_parse_int_native_bb37:
    add x15, sp, #784 ; hv frame base
    ldp x0, x1, [x15] ; hv load L49
    add x15, sp, #912 ; hv frame base
    ldp x2, x3, [x15] ; hv load L57
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1552 ; hv frame base
    stp x0, x1, [x15] ; hv store L97
    add x15, sp, #1552 ; hv frame base
    ldp x0, x1, [x15] ; hv load L97
    add x15, sp, #1568 ; hv frame base
    stp x0, x1, [x15] ; hv store L98
    add x15, sp, #912 ; hv frame base
    ldp x0, x1, [x15] ; hv load L57
    add x15, sp, #784 ; hv frame base
    ldp x2, x3, [x15] ; hv load L49
    cmp x1, x3 ; __hx_payload_eq: cmp payloads
    cset x0, eq ; __hx_payload_eq: x0 = (a.pl == b.pl)
    bl _hexa_bool ; __hx_payload_eq: box bool
    add x15, sp, #1584 ; hv frame base
    stp x0, x1, [x15] ; hv store L99
    add x15, sp, #1584 ; hv frame base
    ldp x0, x1, [x15] ; hv load L99
    add x15, sp, #1600 ; hv frame base
    stp x0, x1, [x15] ; hv store L100
    add x15, sp, #800 ; hv frame base
    ldp x0, x1, [x15] ; hv load L50
    add x15, sp, #1024 ; hv frame base
    ldp x2, x3, [x15] ; hv load L64
    cmp x1, x3 ; __hx_payload_lt: cmp payloads
    cset x0, lt ; __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl _hexa_bool ; __hx_payload_lt: box bool
    add x15, sp, #1616 ; hv frame base
    stp x0, x1, [x15] ; hv store L101
    add x15, sp, #1616 ; hv frame base
    ldp x0, x1, [x15] ; hv load L101
    add x15, sp, #1632 ; hv frame base
    stp x0, x1, [x15] ; hv store L102
    add x15, sp, #1600 ; hv frame base
    ldp x0, x1, [x15] ; hv load L100
    add x15, sp, #1632 ; hv frame base
    ldp x2, x3, [x15] ; hv load L102
    and x1, x1, x3 ; __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 ; __hx_payload_and: TAG_INT
    add x15, sp, #1648 ; hv frame base
    stp x0, x1, [x15] ; hv store L103
    add x15, sp, #1648 ; hv frame base
    ldp x0, x1, [x15] ; hv load L103
    add x15, sp, #1664 ; hv frame base
    stp x0, x1, [x15] ; hv store L104
    add x15, sp, #1568 ; hv frame base
    ldp x0, x1, [x15] ; hv load L98
    add x15, sp, #1664 ; hv frame base
    ldp x2, x3, [x15] ; hv load L104
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1680 ; hv frame base
    stp x0, x1, [x15] ; hv store L105
    add x15, sp, #1680 ; hv frame base
    ldp x0, x1, [x15] ; hv load L105
    add x15, sp, #1696 ; hv frame base
    stp x0, x1, [x15] ; hv store L106
    add x15, sp, #1696 ; hv frame base
    ldp x0, x1, [x15] ; hv load L106
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1712 ; hv frame base
    stp x0, x1, [x15] ; hv store L107
    add x15, sp, #1712 ; hv frame base
    ldp x0, x1, [x15] ; hv load L107
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb39 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb38 ; branch -> then
__Ldd24_rt_parse_int_native_bb38:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #1 ; hv const_int val
    add x15, sp, #944 ; hv frame base
    stp x0, x1, [x15] ; hv store L59
    b __Ldd24_rt_parse_int_native_bb40 ; branch
__Ldd24_rt_parse_int_native_bb39:
    add x15, sp, #912 ; hv frame base
    ldp x0, x1, [x15] ; hv load L57
    add x15, sp, #512 ; hv frame base
    ldp x2, x3, [x15] ; hv load L32
    mul x1, x1, x3 ; __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 ; __hx_payload_mul: TAG_INT
    add x15, sp, #1744 ; hv frame base
    stp x0, x1, [x15] ; hv store L109
    add x15, sp, #1744 ; hv frame base
    ldp x0, x1, [x15] ; hv load L109
    add x15, sp, #1760 ; hv frame base
    stp x0, x1, [x15] ; hv store L110
    add x15, sp, #1760 ; hv frame base
    ldp x0, x1, [x15] ; hv load L110
    add x15, sp, #1024 ; hv frame base
    ldp x2, x3, [x15] ; hv load L64
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1776 ; hv frame base
    stp x0, x1, [x15] ; hv store L111
    add x15, sp, #1776 ; hv frame base
    ldp x0, x1, [x15] ; hv load L111
    add x15, sp, #912 ; hv frame base
    stp x0, x1, [x15] ; hv store L57
    b __Ldd24_rt_parse_int_native_bb40 ; branch
__Ldd24_rt_parse_int_native_bb40:
    add x15, sp, #928 ; hv frame base
    ldp x0, x1, [x15] ; hv load L58
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1792 ; hv frame base
    stp x0, x1, [x15] ; hv store L112
    add x15, sp, #1792 ; hv frame base
    ldp x0, x1, [x15] ; hv load L112
    add x15, sp, #928 ; hv frame base
    stp x0, x1, [x15] ; hv store L58
    ldp x0, x1, [sp, #48] ; hv load L3
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    add x1, x1, x3 ; __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 ; __hx_payload_add: TAG_INT
    add x15, sp, #1808 ; hv frame base
    stp x0, x1, [x15] ; hv store L113
    add x15, sp, #1808 ; hv frame base
    ldp x0, x1, [x15] ; hv load L113
    stp x0, x1, [sp, #48] ; hv store L3
    b __Ldd24_rt_parse_int_native_bb41 ; branch
__Ldd24_rt_parse_int_native_bb41:
    b __Ldd24_rt_parse_int_native_bb23 ; branch
__Ldd24_rt_parse_int_native_bb42:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add sp, sp, #2032 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__Ldd24_rt_parse_int_native_bb43:
    add x15, sp, #944 ; hv frame base
    ldp x0, x1, [x15] ; hv load L59
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1856 ; hv frame base
    stp x0, x1, [x15] ; hv store L116
    add x15, sp, #1856 ; hv frame base
    ldp x0, x1, [x15] ; hv load L116
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb45 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb44 ; branch -> then
__Ldd24_rt_parse_int_native_bb44:
    ldp x0, x1, [sp, #368] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1888 ; hv frame base
    stp x0, x1, [x15] ; hv store L118
    add x15, sp, #1888 ; hv frame base
    ldp x0, x1, [x15] ; hv load L118
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb47 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb46 ; branch -> then
__Ldd24_rt_parse_int_native_bb45:
    ldp x0, x1, [sp, #368] ; hv load L23
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #0 ; hv const_int val
    cmp x1, x3 ; __hx_payload_ne: cmp payloads
    cset x0, ne ; __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl _hexa_bool ; __hx_payload_ne: box bool
    add x15, sp, #1984 ; hv frame base
    stp x0, x1, [x15] ; hv store L124
    add x15, sp, #1984 ; hv frame base
    ldp x0, x1, [x15] ; hv load L124
    bl _hexa_truthy ; br_cond: truthy → w0
    uxtw x0, w0 ; br_cond: zext w0
    cbz x0, __Ldd24_rt_parse_int_native_bb49 ; br_cond: !truthy -> else
    b __Ldd24_rt_parse_int_native_bb48 ; branch -> then
__Ldd24_rt_parse_int_native_bb46:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #65535 ; imm 0-15
    movk x3, #65535, lsl #16 ; imm 16-31
    movk x3, #65535, lsl #32 ; imm 32-47
    movk x3, #32767, lsl #48 ; imm 48-63
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1920 ; hv frame base
    stp x0, x1, [x15] ; hv store L120
    add x15, sp, #1920 ; hv frame base
    ldp x0, x1, [x15] ; hv load L120
    add x15, sp, #1936 ; hv frame base
    stp x0, x1, [x15] ; hv store L121
    add x15, sp, #1936 ; hv frame base
    ldp x0, x1, [x15] ; hv load L121
    movz x2, #0 ; hv const_int: TAG_INT
    movz x3, #1 ; hv const_int val
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #1952 ; hv frame base
    stp x0, x1, [x15] ; hv store L122
    add x15, sp, #1952 ; hv frame base
    ldp x0, x1, [x15] ; hv load L122
    add x15, sp, #1968 ; hv frame base
    stp x0, x1, [x15] ; hv store L123
    add x15, sp, #1968 ; hv frame base
    ldp x0, x1, [x15] ; hv load L123
    add sp, sp, #2032 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__Ldd24_rt_parse_int_native_bb47:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #65535 ; imm 0-15
    movk x1, #65535, lsl #16 ; imm 16-31
    movk x1, #65535, lsl #32 ; imm 32-47
    movk x1, #32767, lsl #48 ; imm 48-63
    add sp, sp, #2032 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__Ldd24_rt_parse_int_native_bb48:
    movz x0, #0 ; hv const_int: TAG_INT
    movz x1, #0 ; hv const_int val
    add x15, sp, #912 ; hv frame base
    ldp x2, x3, [x15] ; hv load L57
    sub x1, x1, x3 ; __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 ; __hx_payload_sub: TAG_INT
    add x15, sp, #2016 ; hv frame base
    stp x0, x1, [x15] ; hv store L126
    add x15, sp, #2016 ; hv frame base
    ldp x0, x1, [x15] ; hv load L126
    add sp, sp, #2032 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
__Ldd24_rt_parse_int_native_bb49:
    add x15, sp, #912 ; hv frame base
    ldp x0, x1, [x15] ; hv load L57
    add sp, sp, #2032 ; sp adj
    ldp x29, x30, [sp], #16 ; epilogue: restore fp/lr
    ret ; return
.section __HEXA,__cap
_hexa_cap_manifest:
.section __HEXA,__abi
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
