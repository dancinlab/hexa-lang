// valop_core_arm64-linux.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 VALOP — sh-val-core).
// GENERATED: tool/regen_valop_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=arm64-linux-gnu -o valop_core_arm64-linux.s stdlib/runtime/valop_core.hexa.
//   Provides the SCALAR value-op core (rt_truthy_native, rt_sub_native,
//   rt_mul_native, rt_add_native, rt_cmp_*_native, rt_div_native, rt_mod_native) as native raw-mem bodies: __hx_tag
//   tag-read + raw int/float payload arithmetic + __hx_make_val re-box,
//   byte-faithful to the C hexa_truthy/sub/mul/add/cmp/div/mod scalar arms. The
//   intrinsics are
//   gen2-native-only (the hexat C-transpile bootstrap cannot lower them), so
//   the bodies enter the shipped runtime.a ONLY via this seed — the array/
//   num_core mechanism (resolve_native_valop_core_seed).
//   ABI: ELF aarch64, no underscore. External: NONE (fully self-contained).
//   Lets stage_resolve_runtime_a define HEXA_RT_VALOP_NATIVE + ar this .o
//   into runtime.a so hexa_truthy/sub/mul/add/cmp/div/mod scalar paths go native.
// hexa-lang emit pass — target=arm64-linux-gnu
// source: stdlib/runtime/valop_core.hexa
.file 1 "stdlib/runtime/valop_core.hexa"
.text
.globl rt_truthy_native
.hidden rt_truthy_native
    .p2align 2
rt_truthy_native:
    .loc 1 57 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1248 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L0436_rt_truthy_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L0436_rt_truthy_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb1 // branch -> then
_L0436_rt_truthy_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #96] // hv load L6
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb2:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    cbz x1, _L0436_rt_truthy_native_bb4 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb3 // branch -> then
_L0436_rt_truthy_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #240] // hv load L15
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb4:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    cbz x1, _L0436_rt_truthy_native_bb6 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb5 // branch -> then
_L0436_rt_truthy_native_bb5:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #320] // hv load L20
    fmov d0, x1 // __hx_payload_fle: d0 = a.f
    fmov d1, x3 // __hx_payload_fle: d1 = b.f
    fcmp d0, d1 // __hx_payload_fle: fcmp a.f, b.f
    cset x0, ls // __hx_payload_fle: x0 = (a ls b)
    bl hexa_bool // __hx_payload_fle: box bool
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #320] // hv load L20
    fmov d0, x1 // __hx_payload_fge: d0 = a.f
    fmov d1, x3 // __hx_payload_fge: d1 = b.f
    fcmp d0, d1 // __hx_payload_fge: fcmp a.f, b.f
    cset x0, ge // __hx_payload_fge: x0 = (a ge b)
    bl hexa_bool // __hx_payload_fge: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #352] // hv load L22
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #416] // hv load L26
    ldp x2, x3, [sp, #448] // hv load L28
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #464] // hv load L29
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #496] // hv load L31
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #544 // hv frame base
    ldp x2, x3, [x15] // hv load L34
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb6:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    cbz x1, _L0436_rt_truthy_native_bb8 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb7 // branch -> then
_L0436_rt_truthy_native_bb7:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb8:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    add x15, sp, #624 // hv frame base
    ldp x0, x1, [x15] // hv load L39
    cbz x1, _L0436_rt_truthy_native_bb10 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb9 // branch -> then
_L0436_rt_truthy_native_bb9:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x0, #0 // __hx_str_ptr: TAG_INT
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    cmp x1, #0 // __hx_payload_nz: cmp payload, 0
    cset x0, ne // __hx_payload_nz: x0 = (payload != 0)
    bl hexa_bool // __hx_payload_nz: box bool
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    add x15, sp, #704 // hv frame base
    stp x0, x1, [x15] // hv store L44
    add x15, sp, #704 // hv frame base
    ldp x0, x1, [x15] // hv load L44
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    cbz x1, _L0436_rt_truthy_native_bb12 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb11 // branch -> then
_L0436_rt_truthy_native_bb10:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #5 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    cbz x1, _L0436_rt_truthy_native_bb14 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb13 // branch -> then
_L0436_rt_truthy_native_bb11:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb12:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_str_byte: x1 = s + i
    ldrb w0, [x1] // __hx_str_byte: w0 = s[i]
    mov x1, x0 // __hx_str_byte: payload = byte
    movz x0, #0 // __hx_str_byte: TAG_INT
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
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #832 // hv frame base
    ldp x0, x1, [x15] // hv load L52
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    add x15, sp, #864 // hv frame base
    ldp x0, x1, [x15] // hv load L54
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #880 // hv frame base
    ldp x2, x3, [x15] // hv load L55
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb13:
    ldp x0, x1, [sp, #0] // hv load L0
    ldr w1, [x1, #8] // __hx_arr_len: w1 = arr->len (int32)
    movz x0, #0 // __hx_arr_len: TAG_INT
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #944 // hv frame base
    ldp x0, x1, [x15] // hv load L59
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #992 // hv frame base
    ldp x2, x3, [x15] // hv load L62
    cmp x1, x3 // __hx_payload_gt: cmp payloads
    cset x0, gt // __hx_payload_gt: x0 = (a.pl gt b.pl)
    bl hexa_bool // __hx_payload_gt: box bool
    add x15, sp, #1008 // hv frame base
    stp x0, x1, [x15] // hv store L63
    add x15, sp, #1008 // hv frame base
    ldp x0, x1, [x15] // hv load L63
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #1056 // hv frame base
    ldp x2, x3, [x15] // hv load L66
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb14:
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #10 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    cbz x1, _L0436_rt_truthy_native_bb16 // br_cond: !payload -> else
    b _L0436_rt_truthy_native_bb15 // branch -> then
_L0436_rt_truthy_native_bb15:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1136 // hv frame base
    ldp x0, x1, [x15] // hv load L71
    cmp x1, #0 // __hx_payload_nz: cmp payload, 0
    cset x0, ne // __hx_payload_nz: x0 = (payload != 0)
    bl hexa_bool // __hx_payload_nz: box bool
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    add x15, sp, #1168 // hv frame base
    ldp x0, x1, [x15] // hv load L73
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #1200 // hv frame base
    ldp x2, x3, [x15] // hv load L75
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1216 // hv frame base
    stp x0, x1, [x15] // hv store L76
    add x15, sp, #1216 // hv frame base
    ldp x0, x1, [x15] // hv load L76
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_truthy_native_bb16:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1232 // hv frame base
    stp x0, x1, [x15] // hv store L77
    add x15, sp, #1232 // hv frame base
    ldp x0, x1, [x15] // hv load L77
    add sp, sp, #1248 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_sub_native
.hidden rt_sub_native
    .p2align 2
rt_sub_native:
    .loc 1 139 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_sub_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_sub_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_sub_native_bb1 // branch -> then
_L0436_rt_sub_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_sub_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fsub: d0 = a.f
    fmov d1, x3 // __hx_payload_fsub: d1 = b.f
    fsub d0, d0, d1 // __hx_payload_fsub: d0 = a.f fsub b.f
    fmov x1, d0 // __hx_payload_fsub: x1 = result bits
    movz x0, #1 // __hx_payload_fsub: TAG_FLOAT
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_mul_native
.hidden rt_mul_native
    .p2align 2
rt_mul_native:
    .loc 1 161 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_mul_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_mul_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_mul_native_bb1 // branch -> then
_L0436_rt_mul_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    mul x1, x1, x3 // __hx_payload_mul: x1 = a.pl mul b.pl
    movz x0, #0 // __hx_payload_mul: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_mul_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fmul: d0 = a.f
    fmov d1, x3 // __hx_payload_fmul: d1 = b.f
    fmul d0, d0, d1 // __hx_payload_fmul: d0 = a.f fmul b.f
    fmov x1, d0 // __hx_payload_fmul: x1 = result bits
    movz x0, #1 // __hx_payload_fmul: TAG_FLOAT
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_add_native
.hidden rt_add_native
    .p2align 2
rt_add_native:
    .loc 1 189 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_add_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_add_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_add_native_bb1 // branch -> then
_L0436_rt_add_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_add_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fadd: d0 = a.f
    fmov d1, x3 // __hx_payload_fadd: d1 = b.f
    fadd d0, d0, d1 // __hx_payload_fadd: d0 = a.f fadd b.f
    fmov x1, d0 // __hx_payload_fadd: x1 = result bits
    movz x0, #1 // __hx_payload_fadd: TAG_FLOAT
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_cmp_lt_native
.hidden rt_cmp_lt_native
    .p2align 2
rt_cmp_lt_native:
    .loc 1 224 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_cmp_lt_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_cmp_lt_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_cmp_lt_native_bb1 // branch -> then
_L0436_rt_cmp_lt_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_cmp_lt_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_flt: d0 = a.f
    fmov d1, x3 // __hx_payload_flt: d1 = b.f
    fcmp d0, d1 // __hx_payload_flt: fcmp a.f, b.f
    cset x0, mi // __hx_payload_flt: x0 = (a mi b)
    bl hexa_bool // __hx_payload_flt: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_cmp_gt_native
.hidden rt_cmp_gt_native
    .p2align 2
rt_cmp_gt_native:
    .loc 1 243 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_cmp_gt_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_cmp_gt_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_cmp_gt_native_bb1 // branch -> then
_L0436_rt_cmp_gt_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_gt: cmp payloads
    cset x0, gt // __hx_payload_gt: x0 = (a.pl gt b.pl)
    bl hexa_bool // __hx_payload_gt: box bool
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_cmp_gt_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fgt: d0 = a.f
    fmov d1, x3 // __hx_payload_fgt: d1 = b.f
    fcmp d0, d1 // __hx_payload_fgt: fcmp a.f, b.f
    cset x0, gt // __hx_payload_fgt: x0 = (a gt b)
    bl hexa_bool // __hx_payload_fgt: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_cmp_le_native
.hidden rt_cmp_le_native
    .p2align 2
rt_cmp_le_native:
    .loc 1 262 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_cmp_le_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_cmp_le_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_cmp_le_native_bb1 // branch -> then
_L0436_rt_cmp_le_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_le: cmp payloads
    cset x0, le // __hx_payload_le: x0 = (a.pl le b.pl)
    bl hexa_bool // __hx_payload_le: box bool
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_cmp_le_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fle: d0 = a.f
    fmov d1, x3 // __hx_payload_fle: d1 = b.f
    fcmp d0, d1 // __hx_payload_fle: fcmp a.f, b.f
    cset x0, ls // __hx_payload_fle: x0 = (a ls b)
    bl hexa_bool // __hx_payload_fle: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_cmp_ge_native
.hidden rt_cmp_ge_native
    .p2align 2
rt_cmp_ge_native:
    .loc 1 281 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #448 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_cmp_ge_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #144] // hv load L9
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    cbz x1, _L0436_rt_cmp_ge_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_cmp_ge_native_bb1 // branch -> then
_L0436_rt_cmp_ge_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #272] // hv load L17
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_cmp_ge_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #320] // hv load L20
    ldp x2, x3, [sp, #352] // hv load L22
    fmov d0, x1 // __hx_payload_fge: d0 = a.f
    fmov d1, x3 // __hx_payload_fge: d1 = b.f
    fcmp d0, d1 // __hx_payload_fge: fcmp a.f, b.f
    cset x0, ge // __hx_payload_fge: x0 = (a ge b)
    bl hexa_bool // __hx_payload_fge: box bool
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #400] // hv store L25
    ldp x0, x1, [sp, #400] // hv load L25
    stp x0, x1, [sp, #416] // hv store L26
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    ldp x2, x3, [sp, #416] // hv load L26
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    add sp, sp, #448 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_div_native
.hidden rt_div_native
    .p2align 2
rt_div_native:
    .loc 1 311 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_div_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    sdiv x1, x1, x3 // __hx_payload_div: x1 = a.pl / b.pl (trunc)
    movz x0, #0 // __hx_payload_div: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #80] // hv load L5
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_mod_native
.hidden rt_mod_native
    .p2align 2
rt_mod_native:
    .loc 1 318 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #112 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_mod_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    sdiv x4, x1, x3 // __hx_payload_mod: x4 = a.pl / b.pl
    msub x1, x4, x3, x1 // __hx_payload_mod: x1 = a.pl - x4*b.pl (rem)
    movz x0, #0 // __hx_payload_mod: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #80] // hv load L5
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    add sp, sp, #112 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_eq_scalar_native
.hidden rt_eq_scalar_native
    .p2align 2
rt_eq_scalar_native:
    .loc 1 332 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #1216 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_eq_scalar_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #16] // hv load L1
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #208] // hv load L13
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #176] // hv load L11
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #240] // hv load L15
    ldp x2, x3, [sp, #272] // hv load L17
    orr x1, x1, x3 // __hx_payload_or: x1 = a.pl orr b.pl
    movz x0, #0 // __hx_payload_or: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #144] // hv load L9
    ldp x2, x3, [sp, #208] // hv load L13
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #336] // hv load L21
    orr x1, x1, x3 // __hx_payload_or: x1 = a.pl orr b.pl
    movz x0, #0 // __hx_payload_or: TAG_INT
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _L0436_rt_eq_scalar_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_eq_scalar_native_bb1 // branch -> then
_L0436_rt_eq_scalar_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #16] // hv load L1
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #464] // hv store L29
    ldp x0, x1, [sp, #432] // hv load L27
    ldp x2, x3, [sp, #464] // hv load L29
    fmov d0, x1 // __hx_payload_fle: d0 = a.f
    fmov d1, x3 // __hx_payload_fle: d1 = b.f
    fcmp d0, d1 // __hx_payload_fle: fcmp a.f, b.f
    cset x0, ls // __hx_payload_fle: x0 = (a ls b)
    bl hexa_bool // __hx_payload_fle: box bool
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    stp x0, x1, [sp, #496] // hv store L31
    ldp x0, x1, [sp, #432] // hv load L27
    ldp x2, x3, [sp, #464] // hv load L29
    fmov d0, x1 // __hx_payload_fge: d0 = a.f
    fmov d1, x3 // __hx_payload_fge: d1 = b.f
    fcmp d0, d1 // __hx_payload_fge: fcmp a.f, b.f
    cset x0, ge // __hx_payload_fge: x0 = (a ge b)
    bl hexa_bool // __hx_payload_fge: box bool
    add x15, sp, #512 // hv frame base
    stp x0, x1, [x15] // hv store L32
    add x15, sp, #512 // hv frame base
    ldp x0, x1, [x15] // hv load L32
    add x15, sp, #528 // hv frame base
    stp x0, x1, [x15] // hv store L33
    ldp x0, x1, [sp, #496] // hv load L31
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #544 // hv frame base
    stp x0, x1, [x15] // hv store L34
    add x15, sp, #544 // hv frame base
    ldp x0, x1, [x15] // hv load L34
    add x15, sp, #560 // hv frame base
    stp x0, x1, [x15] // hv store L35
    add x15, sp, #528 // hv frame base
    ldp x0, x1, [x15] // hv load L33
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #576 // hv frame base
    stp x0, x1, [x15] // hv store L36
    add x15, sp, #576 // hv frame base
    ldp x0, x1, [x15] // hv load L36
    add x15, sp, #592 // hv frame base
    stp x0, x1, [x15] // hv store L37
    add x15, sp, #560 // hv frame base
    ldp x0, x1, [x15] // hv load L35
    add x15, sp, #592 // hv frame base
    ldp x2, x3, [x15] // hv load L37
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #608 // hv frame base
    stp x0, x1, [x15] // hv store L38
    add x15, sp, #608 // hv frame base
    ldp x0, x1, [x15] // hv load L38
    add x15, sp, #624 // hv frame base
    stp x0, x1, [x15] // hv store L39
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #624 // hv frame base
    ldp x2, x3, [x15] // hv load L39
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #640 // hv frame base
    stp x0, x1, [x15] // hv store L40
    add x15, sp, #640 // hv frame base
    ldp x0, x1, [x15] // hv load L40
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_eq_scalar_native_bb2:
    ldp x0, x1, [sp, #112] // hv load L7
    ldp x2, x3, [sp, #176] // hv load L11
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #656 // hv frame base
    stp x0, x1, [x15] // hv store L41
    add x15, sp, #656 // hv frame base
    ldp x0, x1, [x15] // hv load L41
    add x15, sp, #672 // hv frame base
    stp x0, x1, [x15] // hv store L42
    add x15, sp, #672 // hv frame base
    ldp x0, x1, [x15] // hv load L42
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #688 // hv frame base
    stp x0, x1, [x15] // hv store L43
    add x15, sp, #688 // hv frame base
    ldp x0, x1, [x15] // hv load L43
    cbz x1, _L0436_rt_eq_scalar_native_bb4 // br_cond: !payload -> else
    b _L0436_rt_eq_scalar_native_bb3 // branch -> then
_L0436_rt_eq_scalar_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_le: cmp payloads
    cset x0, le // __hx_payload_le: x0 = (a.pl le b.pl)
    bl hexa_bool // __hx_payload_le: box bool
    add x15, sp, #720 // hv frame base
    stp x0, x1, [x15] // hv store L45
    add x15, sp, #720 // hv frame base
    ldp x0, x1, [x15] // hv load L45
    add x15, sp, #736 // hv frame base
    stp x0, x1, [x15] // hv store L46
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    add x15, sp, #752 // hv frame base
    stp x0, x1, [x15] // hv store L47
    add x15, sp, #752 // hv frame base
    ldp x0, x1, [x15] // hv load L47
    add x15, sp, #768 // hv frame base
    stp x0, x1, [x15] // hv store L48
    add x15, sp, #736 // hv frame base
    ldp x0, x1, [x15] // hv load L46
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #784 // hv frame base
    stp x0, x1, [x15] // hv store L49
    add x15, sp, #784 // hv frame base
    ldp x0, x1, [x15] // hv load L49
    add x15, sp, #800 // hv frame base
    stp x0, x1, [x15] // hv store L50
    add x15, sp, #768 // hv frame base
    ldp x0, x1, [x15] // hv load L48
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #816 // hv frame base
    stp x0, x1, [x15] // hv store L51
    add x15, sp, #816 // hv frame base
    ldp x0, x1, [x15] // hv load L51
    add x15, sp, #832 // hv frame base
    stp x0, x1, [x15] // hv store L52
    add x15, sp, #800 // hv frame base
    ldp x0, x1, [x15] // hv load L50
    add x15, sp, #832 // hv frame base
    ldp x2, x3, [x15] // hv load L52
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #848 // hv frame base
    stp x0, x1, [x15] // hv store L53
    add x15, sp, #848 // hv frame base
    ldp x0, x1, [x15] // hv load L53
    add x15, sp, #864 // hv frame base
    stp x0, x1, [x15] // hv store L54
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #864 // hv frame base
    ldp x2, x3, [x15] // hv load L54
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #880 // hv frame base
    stp x0, x1, [x15] // hv store L55
    add x15, sp, #880 // hv frame base
    ldp x0, x1, [x15] // hv load L55
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_eq_scalar_native_bb4:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #896 // hv frame base
    stp x0, x1, [x15] // hv store L56
    add x15, sp, #896 // hv frame base
    ldp x0, x1, [x15] // hv load L56
    add x15, sp, #912 // hv frame base
    stp x0, x1, [x15] // hv store L57
    ldp x0, x1, [sp, #80] // hv load L5
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #2 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    add x15, sp, #928 // hv frame base
    stp x0, x1, [x15] // hv store L58
    add x15, sp, #928 // hv frame base
    ldp x0, x1, [x15] // hv load L58
    add x15, sp, #944 // hv frame base
    stp x0, x1, [x15] // hv store L59
    add x15, sp, #912 // hv frame base
    ldp x0, x1, [x15] // hv load L57
    add x15, sp, #944 // hv frame base
    ldp x2, x3, [x15] // hv load L59
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #960 // hv frame base
    stp x0, x1, [x15] // hv store L60
    add x15, sp, #960 // hv frame base
    ldp x0, x1, [x15] // hv load L60
    add x15, sp, #976 // hv frame base
    stp x0, x1, [x15] // hv store L61
    add x15, sp, #976 // hv frame base
    ldp x0, x1, [x15] // hv load L61
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_ne: cmp payloads
    cset x0, ne // __hx_payload_ne: x0 = (a.pl ne b.pl)
    bl hexa_bool // __hx_payload_ne: box bool
    add x15, sp, #992 // hv frame base
    stp x0, x1, [x15] // hv store L62
    add x15, sp, #992 // hv frame base
    ldp x0, x1, [x15] // hv load L62
    cbz x1, _L0436_rt_eq_scalar_native_bb6 // br_cond: !payload -> else
    b _L0436_rt_eq_scalar_native_bb5 // branch -> then
_L0436_rt_eq_scalar_native_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_le: cmp payloads
    cset x0, le // __hx_payload_le: x0 = (a.pl le b.pl)
    bl hexa_bool // __hx_payload_le: box bool
    add x15, sp, #1024 // hv frame base
    stp x0, x1, [x15] // hv store L64
    add x15, sp, #1024 // hv frame base
    ldp x0, x1, [x15] // hv load L64
    add x15, sp, #1040 // hv frame base
    stp x0, x1, [x15] // hv store L65
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #16] // hv load L1
    cmp x1, x3 // __hx_payload_ge: cmp payloads
    cset x0, ge // __hx_payload_ge: x0 = (a.pl ge b.pl)
    bl hexa_bool // __hx_payload_ge: box bool
    add x15, sp, #1056 // hv frame base
    stp x0, x1, [x15] // hv store L66
    add x15, sp, #1056 // hv frame base
    ldp x0, x1, [x15] // hv load L66
    add x15, sp, #1072 // hv frame base
    stp x0, x1, [x15] // hv store L67
    add x15, sp, #1040 // hv frame base
    ldp x0, x1, [x15] // hv load L65
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1088 // hv frame base
    stp x0, x1, [x15] // hv store L68
    add x15, sp, #1088 // hv frame base
    ldp x0, x1, [x15] // hv load L68
    add x15, sp, #1104 // hv frame base
    stp x0, x1, [x15] // hv store L69
    add x15, sp, #1072 // hv frame base
    ldp x0, x1, [x15] // hv load L67
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    add x15, sp, #1120 // hv frame base
    stp x0, x1, [x15] // hv store L70
    add x15, sp, #1120 // hv frame base
    ldp x0, x1, [x15] // hv load L70
    add x15, sp, #1136 // hv frame base
    stp x0, x1, [x15] // hv store L71
    add x15, sp, #1104 // hv frame base
    ldp x0, x1, [x15] // hv load L69
    add x15, sp, #1136 // hv frame base
    ldp x2, x3, [x15] // hv load L71
    and x1, x1, x3 // __hx_payload_and: x1 = a.pl and b.pl
    movz x0, #0 // __hx_payload_and: TAG_INT
    add x15, sp, #1152 // hv frame base
    stp x0, x1, [x15] // hv store L72
    add x15, sp, #1152 // hv frame base
    ldp x0, x1, [x15] // hv load L72
    add x15, sp, #1168 // hv frame base
    stp x0, x1, [x15] // hv store L73
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    add x15, sp, #1168 // hv frame base
    ldp x2, x3, [x15] // hv load L73
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1184 // hv frame base
    stp x0, x1, [x15] // hv store L74
    add x15, sp, #1184 // hv frame base
    ldp x0, x1, [x15] // hv load L74
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_eq_scalar_native_bb6:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #2 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    add x15, sp, #1200 // hv frame base
    stp x0, x1, [x15] // hv store L75
    add x15, sp, #1200 // hv frame base
    ldp x0, x1, [x15] // hv load L75
    add sp, sp, #1216 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_to_int_native
.hidden rt_to_int_native
    .p2align 2
rt_to_int_native:
    .loc 1 378 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L0436_rt_to_int_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L0436_rt_to_int_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_to_int_native_bb1 // branch -> then
_L0436_rt_to_int_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_to_int_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    fmov d0, x1 // __hx_payload_f2i: d0 = v.f bits
    fcvtzs x1, d0 // __hx_payload_f2i: x1 = (i64)trunc(v.f)
    movz x0, #0 // __hx_payload_f2i: TAG_INT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #128] // hv load L8
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_to_float_native
.hidden rt_to_float_native
    .p2align 2
rt_to_float_native:
    .loc 1 387 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #160 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L0436_rt_to_float_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #1 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L0436_rt_to_float_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_to_float_native_bb1 // branch -> then
_L0436_rt_to_float_native_bb1:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_to_float_native_bb2:
    ldp x0, x1, [sp, #0] // hv load L0
    scvtf d0, x1 // __hx_payload_i2f: d0 = (double)v.i
    fmov x1, d0 // __hx_payload_i2f: x1 = converted bits
    movz x0, #1 // __hx_payload_i2f: TAG_FLOAT
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x2, x3, [sp, #128] // hv load L8
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    add sp, sp, #160 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_abs_native
.hidden rt_abs_native
    .p2align 2
rt_abs_native:
    .loc 1 397 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #496 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
_L0436_rt_abs_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #16] // hv store L1
    ldp x0, x1, [sp, #16] // hv load L1
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    cbz x1, _L0436_rt_abs_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_abs_native_bb1 // branch -> then
_L0436_rt_abs_native_bb1:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #80] // hv store L5
    ldp x0, x1, [sp, #80] // hv load L5
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #96] // hv load L6
    cmp x1, x3 // __hx_payload_lt: cmp payloads
    cset x0, lt // __hx_payload_lt: x0 = (a.pl lt b.pl)
    bl hexa_bool // __hx_payload_lt: box bool
    stp x0, x1, [sp, #112] // hv store L7
    ldp x0, x1, [sp, #112] // hv load L7
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    cbz x1, _L0436_rt_abs_native_bb4 // br_cond: !payload -> else
    b _L0436_rt_abs_native_bb3 // branch -> then
_L0436_rt_abs_native_bb2:
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    scvtf d0, x1 // __hx_to_double: d0 = (double)int
    fmov x2, d0 // __hx_to_double: x2 = int-as-double bits
    cmp x0, #1 // __hx_to_double: tag == TAG_FLOAT?
    csel x1, x1, x2, eq // __hx_to_double: float→keep bits, int→converted
    movz x0, #1 // __hx_to_double: TAG_FLOAT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #0] // hv load L0
    ldp x2, x3, [sp, #304] // hv load L19
    fmov d0, x1 // __hx_payload_flt: d0 = a.f
    fmov d1, x3 // __hx_payload_flt: d1 = b.f
    fcmp d0, d1 // __hx_payload_flt: fcmp a.f, b.f
    cset x0, mi // __hx_payload_flt: x0 = (a mi b)
    bl hexa_bool // __hx_payload_flt: box bool
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    stp x0, x1, [sp, #336] // hv store L21
    ldp x0, x1, [sp, #336] // hv load L21
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #352] // hv store L22
    ldp x0, x1, [sp, #352] // hv load L22
    stp x0, x1, [sp, #368] // hv store L23
    ldp x0, x1, [sp, #368] // hv load L23
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #384] // hv store L24
    ldp x0, x1, [sp, #384] // hv load L24
    cbz x1, _L0436_rt_abs_native_bb6 // br_cond: !payload -> else
    b _L0436_rt_abs_native_bb5 // branch -> then
_L0436_rt_abs_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_abs_native_bb4:
    ldp x0, x1, [sp, #96] // hv load L6
    ldp x2, x3, [sp, #0] // hv load L0
    sub x1, x1, x3 // __hx_payload_sub: x1 = a.pl sub b.pl
    movz x0, #0 // __hx_payload_sub: TAG_INT
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #240] // hv store L15
    ldp x0, x1, [sp, #240] // hv load L15
    stp x0, x1, [sp, #256] // hv store L16
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #0 // hv const_int val
    ldp x2, x3, [sp, #256] // hv load L16
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_abs_native_bb5:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_abs_native_bb6:
    ldp x0, x1, [sp, #304] // hv load L19
    ldp x2, x3, [sp, #0] // hv load L0
    fmov d0, x1 // __hx_payload_fsub: d0 = a.f
    fmov d1, x3 // __hx_payload_fsub: d1 = b.f
    fsub d0, d0, d1 // __hx_payload_fsub: d0 = a.f fsub b.f
    fmov x1, d0 // __hx_payload_fsub: x1 = result bits
    movz x0, #1 // __hx_payload_fsub: TAG_FLOAT
    stp x0, x1, [sp, #416] // hv store L26
    ldp x0, x1, [sp, #416] // hv load L26
    stp x0, x1, [sp, #432] // hv store L27
    ldp x0, x1, [sp, #432] // hv load L27
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #448] // hv store L28
    ldp x0, x1, [sp, #448] // hv load L28
    stp x0, x1, [sp, #464] // hv store L29
    movz x0, #0 // hv const_int: TAG_INT
    movz x1, #1 // hv const_int val
    ldp x2, x3, [sp, #464] // hv load L29
    mov x0, x1 // __hx_make_val: lo = tag word
    mov x1, x3 // __hx_make_val: hi = payload word
    stp x0, x1, [sp, #480] // hv store L30
    ldp x0, x1, [sp, #480] // hv load L30
    add sp, sp, #496 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.globl rt_null_coal_native
.hidden rt_null_coal_native
    .p2align 2
rt_null_coal_native:
    .loc 1 418 0
    stp x29, x30, [sp, #-16]! // prologue: save fp/lr
    mov x29, sp // prologue: set fp
    sub sp, sp, #352 // sp adj
    stp x0, x1, [sp, #0] // ingress param 0
    stp x2, x3, [sp, #16] // ingress param 1
_L0436_rt_null_coal_native_bb0:
    ldp x0, x1, [sp, #0] // hv load L0
    mov x1, x0 // __hx_tag: payload = v.tag
    movz x0, #0 // __hx_tag: TAG_INT
    stp x0, x1, [sp, #32] // hv store L2
    ldp x0, x1, [sp, #32] // hv load L2
    stp x0, x1, [sp, #48] // hv store L3
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #4 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #64] // hv store L4
    ldp x0, x1, [sp, #64] // hv load L4
    cbz x1, _L0436_rt_null_coal_native_bb2 // br_cond: !payload -> else
    b _L0436_rt_null_coal_native_bb1 // branch -> then
_L0436_rt_null_coal_native_bb1:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_null_coal_native_bb2:
    ldp x0, x1, [sp, #48] // hv load L3
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #3 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #96] // hv store L6
    ldp x0, x1, [sp, #96] // hv load L6
    cbz x1, _L0436_rt_null_coal_native_bb4 // br_cond: !payload -> else
    b _L0436_rt_null_coal_native_bb3 // branch -> then
_L0436_rt_null_coal_native_bb3:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x0, #0 // __hx_str_ptr: TAG_INT
    stp x0, x1, [sp, #128] // hv store L8
    ldp x0, x1, [sp, #128] // hv load L8
    stp x0, x1, [sp, #144] // hv store L9
    ldp x0, x1, [sp, #144] // hv load L9
    cmp x1, #0 // __hx_payload_nz: cmp payload, 0
    cset x0, ne // __hx_payload_nz: x0 = (payload != 0)
    bl hexa_bool // __hx_payload_nz: box bool
    stp x0, x1, [sp, #160] // hv store L10
    ldp x0, x1, [sp, #160] // hv load L10
    stp x0, x1, [sp, #176] // hv store L11
    ldp x0, x1, [sp, #176] // hv load L11
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #192] // hv store L12
    ldp x0, x1, [sp, #192] // hv load L12
    stp x0, x1, [sp, #208] // hv store L13
    ldp x0, x1, [sp, #208] // hv load L13
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #224] // hv store L14
    ldp x0, x1, [sp, #224] // hv load L14
    cbz x1, _L0436_rt_null_coal_native_bb6 // br_cond: !payload -> else
    b _L0436_rt_null_coal_native_bb5 // branch -> then
_L0436_rt_null_coal_native_bb4:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_null_coal_native_bb5:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_null_coal_native_bb6:
    ldp x0, x1, [sp, #0] // hv load L0
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_str_byte: x1 = s + i
    ldrb w0, [x1] // __hx_str_byte: w0 = s[i]
    mov x1, x0 // __hx_str_byte: payload = byte
    movz x0, #0 // __hx_str_byte: TAG_INT
    stp x0, x1, [sp, #256] // hv store L16
    ldp x0, x1, [sp, #256] // hv load L16
    stp x0, x1, [sp, #272] // hv store L17
    ldp x0, x1, [sp, #272] // hv load L17
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    add x1, x1, x3 // __hx_payload_add: x1 = a.pl add b.pl
    movz x0, #0 // __hx_payload_add: TAG_INT
    stp x0, x1, [sp, #288] // hv store L18
    ldp x0, x1, [sp, #288] // hv load L18
    stp x0, x1, [sp, #304] // hv store L19
    ldp x0, x1, [sp, #304] // hv load L19
    movz x2, #0 // hv const_int: TAG_INT
    movz x3, #0 // hv const_int val
    cmp x1, x3 // __hx_payload_eq: cmp payloads
    cset x0, eq // __hx_payload_eq: x0 = (a.pl == b.pl)
    bl hexa_bool // __hx_payload_eq: box bool
    stp x0, x1, [sp, #320] // hv store L20
    ldp x0, x1, [sp, #320] // hv load L20
    cbz x1, _L0436_rt_null_coal_native_bb8 // br_cond: !payload -> else
    b _L0436_rt_null_coal_native_bb7 // branch -> then
_L0436_rt_null_coal_native_bb7:
    ldp x0, x1, [sp, #16] // hv load L1
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
_L0436_rt_null_coal_native_bb8:
    ldp x0, x1, [sp, #0] // hv load L0
    add sp, sp, #352 // sp adj
    ldp x29, x30, [sp], #16 // epilogue: restore fp/lr
    ret // return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",%progbits
