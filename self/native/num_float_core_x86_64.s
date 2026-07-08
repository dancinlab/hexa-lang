// num_float_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-num-float).
// GENERATED: tool/regen_num_float_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o num_float_core_x86_64.s stdlib/runtime/num_float_core.hexa.
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
//   ABI: ELF, rt_parse_float_native no underscore. External: the PARSE half is self-contained (float leaves lower
//   inline, no libm call); the FORMAT half references the hexa string/array
//   runtime (hexa_array_new/push, hexa_bytes_to_str_raw, hexa_arena_alloc,
//   scalar ops) — resolved WITHIN runtime.a (the same archive this .o joins),
//   so no NEW undefined symbol appears at the app link.
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_NATIVE (parse,
//   default-ON) + HEXA_RT_FORMAT_FLOAT_NATIVE (format, R6 opt-IN) + ar this .o
//   into runtime.a so __hx_to_double and the float-repr path delegate to native.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/r6wt/stdlib/runtime/num_float_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/num_float_core.hexa"
.text
.globl rt_parse_float_native
.hidden rt_parse_float_native
    .p2align 4
rt_parse_float_native:
    .loc 1 71 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 2848 # prologue: alloc spill frame
    mov [rbp - 1456], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L22ed_rt_parse_float_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1464], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 1464] # tag L1 from tag-slot
    mov [rbp - 1472], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1480], r11 # store tag L3
    mov r15, 1 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L4
    jmp .L22ed_rt_parse_float_native_bb1 # branch
.L22ed_rt_parse_float_native_bb1:
    mov r11, 0 # hv payload
    mov r10, r15 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1496], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb3 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb2 # jump -> then
.L22ed_rt_parse_float_native_bb2:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1504], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 1504] # tag L6 from tag-slot
    mov [rbp - 1512], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 32 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1520], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 1520] # tag L8 from tag-slot
    mov [rbp - 1528], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, 8 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1536], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 1536] # tag L10 from tag-slot
    mov [rbp - 1544], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 14 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1552], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 1552] # tag L12 from tag-slot
    mov [rbp - 1560], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1568], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 1568] # tag L14 from tag-slot
    mov [rbp - 1576], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1584], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 1584] # tag L16 from tag-slot
    mov [rbp - 1592], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1600], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb5 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb4 # jump -> then
.L22ed_rt_parse_float_native_bb3:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1624], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1624] # tag L21 from tag-slot
    mov [rbp - 1632], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, 0 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1640], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 43 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1648], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb8 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb7 # jump -> then
.L22ed_rt_parse_float_native_bb4:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1616], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1616] # tag L20 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb6 # branch
.L22ed_rt_parse_float_native_bb5:
    mov r15, 0 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L4
    jmp .L22ed_rt_parse_float_native_bb6 # branch
.L22ed_rt_parse_float_native_bb6:
    jmp .L22ed_rt_parse_float_native_bb1 # branch
.L22ed_rt_parse_float_native_bb7:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1664], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1664] # tag L26 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb11 # branch
.L22ed_rt_parse_float_native_bb8:
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 45 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1672], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb10 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb9 # jump -> then
.L22ed_rt_parse_float_native_bb9:
    mov r10, 1 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1640], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1688], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1688] # tag L29 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb10 # branch
.L22ed_rt_parse_float_native_bb10:
    jmp .L22ed_rt_parse_float_native_bb11 # branch
.L22ed_rt_parse_float_native_bb11:
    mov r10, 0 # assign L30
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1696], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, 0 # assign L31
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1704], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, 0 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, 0 # assign L33
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1720], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, 0 # assign L34
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1728], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, 1 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L22ed_rt_parse_float_native_bb12 # branch
.L22ed_rt_parse_float_native_bb12:
    mov r11, 0 # hv payload
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1744], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb14 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb13 # jump -> then
.L22ed_rt_parse_float_native_bb13:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1752], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L38
    mov r11, [rbp - 1752] # tag L37 from tag-slot
    mov [rbp - 1760], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r11, r11 # hv payload
    mov r10, 47 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1768], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L40
    mov r11, [rbp - 1768] # tag L39 from tag-slot
    mov [rbp - 1776], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, 58 # hv payload
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1784], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 1784] # tag L41 from tag-slot
    mov [rbp - 1792], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 336] # reload L40 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1800], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 1800] # tag L43 from tag-slot
    mov [rbp - 1808], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    mov r11, 46 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1816], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L46
    mov r11, [rbp - 1816] # tag L45 from tag-slot
    mov [rbp - 1824], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1832], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb16 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb15 # jump -> then
.L22ed_rt_parse_float_native_bb14:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2000], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r11, [rbp - 560] # reload L68 from spill slot
    mov r10, r11 # assign L69
    mov r11, [rbp - 2000] # tag L68 from tag-slot
    mov [rbp - 2008], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    mov r10, r10 # hv payload
    mov r11, 101 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2016], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r11, [rbp - 576] # reload L70 from spill slot
    mov r10, r11 # assign L71
    mov r11, [rbp - 2016] # tag L70 from tag-slot
    mov [rbp - 2024], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    mov r10, r10 # hv payload
    mov r11, 69 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2032], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L73
    mov r11, [rbp - 2032] # tag L72 from tag-slot
    mov [rbp - 2040], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r11, [rbp - 600] # reload L73 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 584] # reload L71 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2048], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r11, [rbp - 608] # reload L74 from spill slot
    mov r10, r11 # assign L75
    mov r11, [rbp - 2048] # tag L74 from tag-slot
    mov [rbp - 2056], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, 0 # assign L76
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2064], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r10, 0 # assign L77
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, 0 # assign L78
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2080], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2088], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r10, [rbp - 648] # reload L79 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb30 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb29 # jump -> then
.L22ed_rt_parse_float_native_bb15:
    mov r11, 48 # hv payload
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1848], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r10, r11 # assign L50
    mov r11, [rbp - 1848] # tag L49 from tag-slot
    mov [rbp - 1856], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r11, r11 # hv payload
    mov r10, 900719925474099 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1864], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r11 # assign L52
    mov r11, [rbp - 1864] # tag L51 from tag-slot
    mov [rbp - 1872], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1880], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb18 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb17 # jump -> then
.L22ed_rt_parse_float_native_bb16:
    mov r11, 0 # hv payload
    mov r10, [rbp - 384] # reload L46 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1960], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r10, [rbp - 520] # reload L63 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb23 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb22 # jump -> then
.L22ed_rt_parse_float_native_bb17:
    mov r10, 1 # assign L34
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1728], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    jmp .L22ed_rt_parse_float_native_bb19 # branch
.L22ed_rt_parse_float_native_bb18:
    mov r11, 10 # hv payload
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1896], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov r10, r11 # assign L56
    mov r11, [rbp - 1896] # tag L55 from tag-slot
    mov [rbp - 1904], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 464] # reload L56 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1912], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 1912] # tag L57 from tag-slot
    mov [rbp - 1696], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    jmp .L22ed_rt_parse_float_native_bb19 # branch
.L22ed_rt_parse_float_native_bb19:
    mov r11, 1 # hv payload
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1920], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r11, [rbp - 480] # reload L58 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 1920] # tag L58 from tag-slot
    mov [rbp - 1704], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1928], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 488] # reload L59 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb21 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb20 # jump -> then
.L22ed_rt_parse_float_native_bb20:
    mov r11, 1 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1944], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 1944] # tag L61 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L22ed_rt_parse_float_native_bb21 # branch
.L22ed_rt_parse_float_native_bb21:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1952], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1952] # tag L62 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb28 # branch
.L22ed_rt_parse_float_native_bb22:
    mov r11, 0 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1976], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r10, [rbp - 536] # reload L65 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb25 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb24 # jump -> then
.L22ed_rt_parse_float_native_bb23:
    mov r10, 0 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L22ed_rt_parse_float_native_bb27 # branch
.L22ed_rt_parse_float_native_bb24:
    mov r10, 0 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L22ed_rt_parse_float_native_bb26 # branch
.L22ed_rt_parse_float_native_bb25:
    mov r10, 1 # assign L33
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1720], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1992], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1992] # tag L67 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb26 # branch
.L22ed_rt_parse_float_native_bb26:
    jmp .L22ed_rt_parse_float_native_bb27 # branch
.L22ed_rt_parse_float_native_bb27:
    jmp .L22ed_rt_parse_float_native_bb28 # branch
.L22ed_rt_parse_float_native_bb28:
    jmp .L22ed_rt_parse_float_native_bb12 # branch
.L22ed_rt_parse_float_native_bb29:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2104], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r10, [rbp - 664] # reload L81 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2104] # tag L81 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2112], r11 # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r11, [rbp - 672] # reload L82 from spill slot
    mov r10, r11 # assign L83
    mov r11, [rbp - 2112] # tag L82 from tag-slot
    mov [rbp - 2120], r11 # store tag L83
    mov [rbp - 680], r10 # spill L83 to slot
    mov r10, [rbp - 680] # reload L83 from spill slot
    mov r10, r10 # hv payload
    mov r11, 43 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2128], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb32 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb31 # jump -> then
.L22ed_rt_parse_float_native_bb30:
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2352], r11 # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r10, [rbp - 912] # reload L112 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb45 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb44 # jump -> then
.L22ed_rt_parse_float_native_bb31:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2144], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    mov r10, [rbp - 704] # reload L86 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2144] # tag L86 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb35 # branch
.L22ed_rt_parse_float_native_bb32:
    mov r10, [rbp - 680] # reload L83 from spill slot
    mov r10, r10 # hv payload
    mov r11, 45 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2152], r11 # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r10, [rbp - 712] # reload L87 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb34 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb33 # jump -> then
.L22ed_rt_parse_float_native_bb33:
    mov r10, 1 # assign L76
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2064], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2168], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2168] # tag L89 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb34 # branch
.L22ed_rt_parse_float_native_bb34:
    jmp .L22ed_rt_parse_float_native_bb35 # branch
.L22ed_rt_parse_float_native_bb35:
    mov r10, 1 # assign L90
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2176], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    jmp .L22ed_rt_parse_float_native_bb36 # branch
.L22ed_rt_parse_float_native_bb36:
    mov r11, 0 # hv payload
    mov r10, [rbp - 736] # reload L90 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2184], r11 # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r10, [rbp - 744] # reload L91 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb38 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb37 # jump -> then
.L22ed_rt_parse_float_native_bb37:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2192], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r11, [rbp - 752] # reload L92 from spill slot
    mov r10, r11 # assign L93
    mov r11, [rbp - 2192] # tag L92 from tag-slot
    mov [rbp - 2200], r11 # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    mov r11, [rbp - 760] # reload L93 from spill slot
    mov r11, r11 # hv payload
    mov r10, 47 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2208], r11 # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r11, [rbp - 768] # reload L94 from spill slot
    mov r10, r11 # assign L95
    mov r11, [rbp - 2208] # tag L94 from tag-slot
    mov [rbp - 2216], r11 # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r11, 58 # hv payload
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2224], r11 # store tag L96
    mov [rbp - 784], r10 # spill L96 to slot
    mov r11, [rbp - 784] # reload L96 from spill slot
    mov r10, r11 # assign L97
    mov r11, [rbp - 2224] # tag L96 from tag-slot
    mov [rbp - 2232], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r11, [rbp - 792] # reload L97 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 776] # reload L95 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2240], r11 # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r11, [rbp - 800] # reload L98 from spill slot
    mov r10, r11 # assign L99
    mov r11, [rbp - 2240] # tag L98 from tag-slot
    mov [rbp - 2248], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 808] # reload L99 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2256], r11 # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r10, [rbp - 816] # reload L100 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb40 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb39 # jump -> then
.L22ed_rt_parse_float_native_bb38:
    jmp .L22ed_rt_parse_float_native_bb30 # branch
.L22ed_rt_parse_float_native_bb39:
    mov r11, 48 # hv payload
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2272], r11 # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r11, [rbp - 832] # reload L102 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 2272] # tag L102 from tag-slot
    mov [rbp - 2280], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    mov r11, 10 # hv payload
    mov r10, [rbp - 632] # reload L77 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2288], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r10, r11 # assign L105
    mov r11, [rbp - 2288] # tag L104 from tag-slot
    mov [rbp - 2296], r11 # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    mov r11, [rbp - 840] # reload L103 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 856] # reload L105 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2304], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    mov r11, [rbp - 864] # reload L106 from spill slot
    mov r10, r11 # assign L77
    mov r11, [rbp - 2304] # tag L106 from tag-slot
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, 1 # assign L78
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2080], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, 1000 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2312], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    mov r11, [rbp - 872] # reload L107 from spill slot
    mov r10, r11 # assign L108
    mov r11, [rbp - 2312] # tag L107 from tag-slot
    mov [rbp - 2320], r11 # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 880] # reload L108 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2328], r11 # store tag L109
    mov [rbp - 888], r10 # spill L109 to slot
    mov r10, [rbp - 888] # reload L109 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb42 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb41 # jump -> then
.L22ed_rt_parse_float_native_bb40:
    mov r10, 0 # assign L90
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2176], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    jmp .L22ed_rt_parse_float_native_bb43 # branch
.L22ed_rt_parse_float_native_bb41:
    mov r10, 1000 # assign L77
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    jmp .L22ed_rt_parse_float_native_bb42 # branch
.L22ed_rt_parse_float_native_bb42:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2344], r11 # store tag L111
    mov [rbp - 904], r10 # spill L111 to slot
    mov r10, [rbp - 904] # reload L111 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2344] # tag L111 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L22ed_rt_parse_float_native_bb43 # branch
.L22ed_rt_parse_float_native_bb43:
    jmp .L22ed_rt_parse_float_native_bb36 # branch
.L22ed_rt_parse_float_native_bb44:
    mov r11, 0 # hv payload
    mov r10, [rbp - 624] # reload L76 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2368], r11 # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov r10, [rbp - 928] # reload L114 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb47 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb46 # jump -> then
.L22ed_rt_parse_float_native_bb45:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2400], r11 # store tag L118
    mov [rbp - 960], r10 # spill L118 to slot
    mov r11, [rbp - 960] # reload L118 from spill slot
    mov r10, r11 # assign L119
    mov r11, [rbp - 2400] # tag L118 from tag-slot
    mov [rbp - 2408], r11 # store tag L119
    mov [rbp - 968], r10 # spill L119 to slot
    mov r10, 0 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2424], r11 # store tag L121
    mov [rbp - 984], r10 # spill L121 to slot
    mov r10, [rbp - 984] # reload L121 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb50 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb49 # jump -> then
.L22ed_rt_parse_float_native_bb46:
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2384], r11 # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    mov r11, [rbp - 944] # reload L116 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 2384] # tag L116 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L22ed_rt_parse_float_native_bb48 # branch
.L22ed_rt_parse_float_native_bb47:
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2392], r11 # store tag L117
    mov [rbp - 952], r10 # spill L117 to slot
    mov r11, [rbp - 952] # reload L117 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 2392] # tag L117 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L22ed_rt_parse_float_native_bb48 # branch
.L22ed_rt_parse_float_native_bb48:
    jmp .L22ed_rt_parse_float_native_bb45 # branch
.L22ed_rt_parse_float_native_bb49:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb50 # branch
.L22ed_rt_parse_float_native_bb50:
    mov r11, 0 # hv payload
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2440], r11 # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov r10, [rbp - 1000] # reload L123 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb52 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb51 # jump -> then
.L22ed_rt_parse_float_native_bb51:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb52 # branch
.L22ed_rt_parse_float_native_bb52:
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2456], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb54 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb53 # jump -> then
.L22ed_rt_parse_float_native_bb53:
    mov r10, [rbp - 640] # reload L78 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2472], r11 # store tag L127
    mov [rbp - 1032], r10 # spill L127 to slot
    mov r10, [rbp - 1032] # reload L127 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb56 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb55 # jump -> then
.L22ed_rt_parse_float_native_bb54:
    mov r11, 0 # hv payload
    mov r10, [rbp - 968] # reload L119 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2488], r11 # store tag L129
    mov [rbp - 1048], r10 # spill L129 to slot
    mov r10, [rbp - 1048] # reload L129 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb58 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb57 # jump -> then
.L22ed_rt_parse_float_native_bb55:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb56 # branch
.L22ed_rt_parse_float_native_bb56:
    jmp .L22ed_rt_parse_float_native_bb54 # branch
.L22ed_rt_parse_float_native_bb57:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb58 # branch
.L22ed_rt_parse_float_native_bb58:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 22 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2504], r11 # store tag L131
    mov [rbp - 1064], r10 # spill L131 to slot
    mov r11, [rbp - 1064] # reload L131 from spill slot
    mov r10, r11 # assign L132
    mov r11, [rbp - 2504] # tag L131 from tag-slot
    mov [rbp - 2512], r11 # store tag L132
    mov [rbp - 1072], r10 # spill L132 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2520], r11 # store tag L133
    mov [rbp - 1080], r10 # spill L133 to slot
    mov r11, [rbp - 1080] # reload L133 from spill slot
    mov r10, r11 # assign L134
    mov r11, [rbp - 2520] # tag L133 from tag-slot
    mov [rbp - 2528], r11 # store tag L134
    mov [rbp - 1088], r10 # spill L134 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1072] # reload L132 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2536], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 1096] # reload L135 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb60 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb59 # jump -> then
.L22ed_rt_parse_float_native_bb59:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb60 # branch
.L22ed_rt_parse_float_native_bb60:
    mov r11, 0 # hv payload
    mov r10, [rbp - 1088] # reload L134 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2552], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    mov r10, [rbp - 1112] # reload L137 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb62 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb61 # jump -> then
.L22ed_rt_parse_float_native_bb61:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2568], r11 # store tag L139
    mov [rbp - 1128], r10 # spill L139 to slot
    mov r11, [rbp - 1128] # reload L139 from spill slot
    mov r10, r11 # assign L140
    mov r11, [rbp - 2568] # tag L139 from tag-slot
    mov [rbp - 2576], r11 # store tag L140
    mov [rbp - 1136], r10 # spill L140 to slot
    mov r11, [rbp - 1136] # reload L140 from spill slot
    mov r11, r11 # hv payload
    mov r10, 22 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2584], r11 # store tag L141
    mov [rbp - 1144], r10 # spill L141 to slot
    mov r11, [rbp - 1144] # reload L141 from spill slot
    mov r10, r11 # assign L142
    mov r11, [rbp - 2584] # tag L141 from tag-slot
    mov [rbp - 2592], r11 # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1152] # reload L142 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2600], r11 # store tag L143
    mov [rbp - 1160], r10 # spill L143 to slot
    mov r10, [rbp - 1160] # reload L143 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb64 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb63 # jump -> then
.L22ed_rt_parse_float_native_bb62:
    mov r11, 0 # hv payload
    mov r10, [rbp - 976] # reload L120 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2616], r11 # store tag L145
    mov [rbp - 1176], r10 # spill L145 to slot
    mov r10, [rbp - 1176] # reload L145 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb66 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb65 # jump -> then
.L22ed_rt_parse_float_native_bb63:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L22ed_rt_parse_float_native_bb64 # branch
.L22ed_rt_parse_float_native_bb64:
    jmp .L22ed_rt_parse_float_native_bb62 # branch
.L22ed_rt_parse_float_native_bb65:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2632], r11 # store tag L147
    mov [rbp - 1192], r10 # spill L147 to slot
    mov rdx, [rbp - 1192] # reload L147 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2632] # tag L147 from tag-slot
    add rsp, 2848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L22ed_rt_parse_float_native_bb66:
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 1696] # tag L30 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2640], r11 # store tag L148
    mov [rbp - 1200], r10 # spill L148 to slot
    mov r11, [rbp - 1200] # reload L148 from spill slot
    mov r10, r11 # assign L149
    mov r11, [rbp - 2640] # tag L148 from tag-slot
    mov [rbp - 2648], r11 # store tag L149
    mov [rbp - 1208], r10 # spill L149 to slot
    mov r11, 1 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2656], r11 # store tag L150
    mov [rbp - 1216], r10 # spill L150 to slot
    mov r11, [rbp - 1216] # reload L150 from spill slot
    mov r10, r11 # assign L151
    mov r11, [rbp - 2656] # tag L150 from tag-slot
    mov [rbp - 2664], r11 # store tag L151
    mov [rbp - 1224], r10 # spill L151 to slot
    mov r10, [rbp - 1224] # reload L151 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2664] # tag L151 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2672], r11 # store tag L152
    mov [rbp - 1232], r10 # spill L152 to slot
    mov r11, [rbp - 1232] # reload L152 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 2672] # tag L152 from tag-slot
    mov [rbp - 2680], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, 10 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2688], r11 # store tag L154
    mov [rbp - 1248], r10 # spill L154 to slot
    mov r11, [rbp - 1248] # reload L154 from spill slot
    mov r10, r11 # assign L155
    mov r11, [rbp - 2688] # tag L154 from tag-slot
    mov [rbp - 2696], r11 # store tag L155
    mov [rbp - 1256], r10 # spill L155 to slot
    mov r10, [rbp - 1256] # reload L155 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2696] # tag L155 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2704], r11 # store tag L156
    mov [rbp - 1264], r10 # spill L156 to slot
    mov r11, [rbp - 1264] # reload L156 from spill slot
    mov r10, r11 # assign L157
    mov r11, [rbp - 2704] # tag L156 from tag-slot
    mov [rbp - 2712], r11 # store tag L157
    mov [rbp - 1272], r10 # spill L157 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L158
    mov r11, [rbp - 1712] # tag L32 from tag-slot
    mov [rbp - 2720], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2728], r11 # store tag L159
    mov [rbp - 1288], r10 # spill L159 to slot
    mov r11, [rbp - 1288] # reload L159 from spill slot
    mov r10, r11 # assign L160
    mov r11, [rbp - 2728] # tag L159 from tag-slot
    mov [rbp - 2736], r11 # store tag L160
    mov [rbp - 1296], r10 # spill L160 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1296] # reload L160 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2744], r11 # store tag L161
    mov [rbp - 1304], r10 # spill L161 to slot
    mov r10, [rbp - 1304] # reload L161 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb68 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb67 # jump -> then
.L22ed_rt_parse_float_native_bb67:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2760], r11 # store tag L163
    mov [rbp - 1320], r10 # spill L163 to slot
    mov r11, [rbp - 1320] # reload L163 from spill slot
    mov r10, r11 # assign L158
    mov r11, [rbp - 2760] # tag L163 from tag-slot
    mov [rbp - 2720], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    jmp .L22ed_rt_parse_float_native_bb68 # branch
.L22ed_rt_parse_float_native_bb68:
    mov r10, 0 # assign L164
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2768], r11 # store tag L164
    mov [rbp - 1328], r10 # spill L164 to slot
    jmp .L22ed_rt_parse_float_native_bb69 # branch
.L22ed_rt_parse_float_native_bb69:
    mov r11, [rbp - 1280] # reload L158 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 1328] # reload L164 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2776], r11 # store tag L165
    mov [rbp - 1336], r10 # spill L165 to slot
    mov r10, [rbp - 1336] # reload L165 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb71 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb70 # jump -> then
.L22ed_rt_parse_float_native_bb70:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1272] # reload L157 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2784], r11 # store tag L166
    mov [rbp - 1344], r10 # spill L166 to slot
    mov r11, [rbp - 1344] # reload L166 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 2784] # tag L166 from tag-slot
    mov [rbp - 2680], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 1328] # reload L164 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2792], r11 # store tag L167
    mov [rbp - 1352], r10 # spill L167 to slot
    mov r11, [rbp - 1352] # reload L167 from spill slot
    mov r10, r11 # assign L164
    mov r11, [rbp - 2792] # tag L167 from tag-slot
    mov [rbp - 2768], r11 # store tag L164
    mov [rbp - 1328], r10 # spill L164 to slot
    jmp .L22ed_rt_parse_float_native_bb69 # branch
.L22ed_rt_parse_float_native_bb71:
    mov r11, [rbp - 1208] # reload L149 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2648] # tag L149 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1296] # reload L160 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2808], r11 # store tag L169
    mov [rbp - 1368], r10 # spill L169 to slot
    mov r10, [rbp - 1368] # reload L169 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb73 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb72 # jump -> then
.L22ed_rt_parse_float_native_bb72:
    mov r10, [rbp - 1208] # reload L149 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1240] # reload L153 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fdiv: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fdiv: xmm1 = b.f bits
    divsd xmm0, xmm1 # __hx_payload_fdiv: xmm0 = a.f divsd b.f
    movq r10, xmm0 # __hx_payload_fdiv: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2824], r11 # store tag L171
    mov [rbp - 1384], r10 # spill L171 to slot
    mov r11, [rbp - 1384] # reload L171 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2824] # tag L171 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L22ed_rt_parse_float_native_bb74 # branch
.L22ed_rt_parse_float_native_bb73:
    mov r10, [rbp - 1208] # reload L149 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1240] # reload L153 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2832], r11 # store tag L172
    mov [rbp - 1392], r10 # spill L172 to slot
    mov r11, [rbp - 1392] # reload L172 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2832] # tag L172 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L22ed_rt_parse_float_native_bb74 # branch
.L22ed_rt_parse_float_native_bb74:
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2840], r11 # store tag L173
    mov [rbp - 1400], r10 # spill L173 to slot
    mov r10, [rbp - 1400] # reload L173 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_parse_float_native_bb76 # jump-if-zero -> else
    jmp .L22ed_rt_parse_float_native_bb75 # jump -> then
.L22ed_rt_parse_float_native_bb75:
    mov r11, 1 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2856], r11 # store tag L175
    mov [rbp - 1416], r10 # spill L175 to slot
    mov r11, [rbp - 1416] # reload L175 from spill slot
    mov r10, r11 # assign L176
    mov r11, [rbp - 2856] # tag L175 from tag-slot
    mov [rbp - 2864], r11 # store tag L176
    mov [rbp - 1424], r10 # spill L176 to slot
    mov r10, [rbp - 1424] # reload L176 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2864] # tag L176 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2872], r11 # store tag L177
    mov [rbp - 1432], r10 # spill L177 to slot
    mov r11, [rbp - 1432] # reload L177 from spill slot
    mov r10, r11 # assign L178
    mov r11, [rbp - 2872] # tag L177 from tag-slot
    mov [rbp - 2880], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1440] # reload L178 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2888], r11 # store tag L179
    mov [rbp - 1448], r10 # spill L179 to slot
    mov r11, [rbp - 1448] # reload L179 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2888] # tag L179 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L22ed_rt_parse_float_native_bb76 # branch
.L22ed_rt_parse_float_native_bb76:
    mov rdx, [rbp - 1360] # reload L168 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2800] # tag L168 from tag-slot
    add rsp, 2848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl _g_digits
.hidden _g_digits
    .p2align 4
_g_digits:
    .loc 1 297 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 304 # prologue: alloc spill frame
    mov [rbp - 184], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L22ed__g_digits_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 184] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r12, rdx # binop ==: capture bool payload
    mov [rbp - 192], rax # store tag L1
    test r12, r12 # br_cond test
    jz .L22ed__g_digits_bb2 # jump-if-zero -> else
    jmp .L22ed__g_digits_bb1 # jump -> then
.L22ed__g_digits_bb1:
    call hexa_array_new # array_lit: new array
    mov r14, rdx # array_lit: capture new array payload
    mov [rbp - 208], rax # store tag L3
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 208] # tag L3 from tag-slot
    add rsp, 304 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L22ed__g_digits_bb2:
    call hexa_array_new # array_lit: new array
    mov r15, rdx # array_lit: capture new array payload
    mov [rbp - 216], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 216] # tag L4 from tag-slot
    mov [rbp - 224], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, rbx # assign L6
    mov r11, [rbp - 184] # tag L0 from tag-slot
    mov [rbp - 232], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L22ed__g_digits_bb3 # branch
.L22ed__g_digits_bb3:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 232] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 240], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed__g_digits_bb5 # jump-if-zero -> else
    jmp .L22ed__g_digits_bb4 # jump -> then
.L22ed__g_digits_bb4:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 232] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 248], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov rsi, 48 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L8 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 256], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 224] # tag L5 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L9 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 264], rax # store tag L10
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L5
    mov r11, [rbp - 264] # tag L10 from tag-slot
    mov [rbp - 224], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 232] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 272], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 272] # tag L11 from tag-slot
    mov [rbp - 232], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L22ed__g_digits_bb3 # branch
.L22ed__g_digits_bb5:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 280], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 280] # tag L12 from tag-slot
    mov [rbp - 288], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 224] # tag L5 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 296], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L14 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 304], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 304] # tag L15 from tag-slot
    mov [rbp - 312], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L22ed__g_digits_bb6 # branch
.L22ed__g_digits_bb6:
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L16 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 320], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed__g_digits_bb8 # jump-if-zero -> else
    jmp .L22ed__g_digits_bb7 # jump -> then
.L22ed__g_digits_bb7:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 224] # tag L5 from tag-slot
    mov rcx, [rbp - 144] # reload L16 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 312] # tag L16 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 328], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L13 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L18 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 336], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 336] # tag L19 from tag-slot
    mov [rbp - 288], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L16 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 344], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 344] # tag L20 from tag-slot
    mov [rbp - 312], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L22ed__g_digits_bb6 # branch
.L22ed__g_digits_bb8:
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 288] # tag L13 from tag-slot
    add rsp, 304 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_format_float_native
.hidden rt_format_float_native
    .p2align 4
rt_format_float_native:
    .loc 1 314 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 7280 # prologue: alloc spill frame
    mov [rbp - 3672], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 3680], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L22ed_rt_format_float_native_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 3672] # tag L0 from tag-slot
    call hexa_float_to_bits # call hexa_float_to_bits
    mov [rbp - 3688], rax # store tag L2
    mov r13, rdx # hv: unbox call result (rdx)
    mov r14, r13 # assign L3
    mov r11, [rbp - 3688] # tag L2 from tag-slot
    mov [rbp - 3696], r11 # store tag L3
    mov rcx, 63 # shift count → rcx (cl)
    mov r10, r14 # shift lhs → r10
    sar r10, cl # binop >> (count in cl)
    mov r15, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3704], r11 # store tag L4
    mov r10, r15 # binop lhs into dst
    and r10, 1 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3712], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 3712] # tag L5 from tag-slot
    mov [rbp - 3720], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rcx, 52 # shift count → rcx (cl)
    mov r10, r14 # shift lhs → r10
    sar r10, cl # binop >> (count in cl)
    mov r10, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3728], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # binop lhs into dst
    and r10, 2047 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3736], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 3736] # tag L8 from tag-slot
    mov [rbp - 3744], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, r14 # binop lhs into dst
    mov r11, 4503599627370495 # materialize wide imm to reg (x86 ALU imm is imm32)
    and r10, r11 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3752], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 3752] # tag L10 from tag-slot
    mov [rbp - 3760], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 3768], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3768] # tag L12 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3744] # tag L9 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3784], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb2 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb1 # jump -> then
.L22ed_rt_format_float_native_bb1:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3720] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 3800], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb4 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb3 # jump -> then
.L22ed_rt_format_float_native_bb2:
    mov r10, 0 # assign L28
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3896], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, 0 # assign L29
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3904], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3744] # tag L9 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3912], rax # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb9 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb8 # jump -> then
.L22ed_rt_format_float_native_bb3:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3816], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3816] # tag L18 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb4 # branch
.L22ed_rt_format_float_native_bb4:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3760] # tag L11 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3824], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb6 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb5 # jump -> then
.L22ed_rt_format_float_native_bb5:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 105 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3840], rax # store tag L21
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3840] # tag L21 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 110 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3848], rax # store tag L22
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3848] # tag L22 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3856], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3856] # tag L23 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb7 # branch
.L22ed_rt_format_float_native_bb6:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 110 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3864], rax # store tag L24
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3864] # tag L24 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3872], rax # store tag L25
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3872] # tag L25 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 110 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3880], rax # store tag L26
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3880] # tag L26 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb7 # branch
.L22ed_rt_format_float_native_bb7:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    call hexa_bytes_to_str_raw # call hexa_bytes_to_str_raw
    mov [rbp - 3888], rax # store tag L27
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3888] # tag L27 from tag-slot
    add rsp, 7280 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L22ed_rt_format_float_native_bb8:
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 3760] # tag L11 from tag-slot
    mov [rbp - 3896], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, -1074 # assign L29
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3904], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3896] # tag L28 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3928], rax # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb11 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb10 # jump -> then
.L22ed_rt_format_float_native_bb9:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # binop lhs into dst
    mov r11, 4503599627370496 # materialize wide imm to reg (x86 ALU imm is imm32)
    or r10, r11 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 3984], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 3984] # tag L39 from tag-slot
    mov [rbp - 3896], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3744] # tag L9 from tag-slot
    mov rcx, 1075 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3992], rax # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, [rbp - 336] # reload L40 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 3992] # tag L40 from tag-slot
    mov [rbp - 3904], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .L22ed_rt_format_float_native_bb14 # branch
.L22ed_rt_format_float_native_bb10:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3720] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 3944], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb13 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb12 # jump -> then
.L22ed_rt_format_float_native_bb11:
    jmp .L22ed_rt_format_float_native_bb14 # branch
.L22ed_rt_format_float_native_bb12:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3960], rax # store tag L36
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3960] # tag L36 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb13 # branch
.L22ed_rt_format_float_native_bb13:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 3968], rax # store tag L37
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 3968] # tag L37 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    call hexa_bytes_to_str_raw # call hexa_bytes_to_str_raw
    mov [rbp - 3976], rax # store tag L38
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 320], r10 # spill L38 to slot
    mov rdx, [rbp - 320] # reload L38 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3976] # tag L38 from tag-slot
    add rsp, 7280 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L22ed_rt_format_float_native_bb14:
    mov r10, r12 # assign L41
    mov r11, [rbp - 3680] # tag L1 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4008], rax # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb16 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb15 # jump -> then
.L22ed_rt_format_float_native_bb15:
    mov r10, 6 # assign L41
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb16 # branch
.L22ed_rt_format_float_native_bb16:
    mov r10, 512 # assign L44
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4024], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, 400 # assign L45
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4032], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 4040], rax # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L47
    mov r11, [rbp - 4040] # tag L46 from tag-slot
    mov [rbp - 4048], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, 0 # assign L48
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4056], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    jmp .L22ed_rt_format_float_native_bb17 # branch
.L22ed_rt_format_float_native_bb17:
    mov r10, [rbp - 400] # reload L48 from spill slot
    mov r11, [rbp - 368] # reload L44 from spill slot
    mov rsi, [rbp - 400] # reload L48 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4056] # tag L48 from tag-slot
    mov rcx, [rbp - 368] # reload L44 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4024] # tag L44 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4064], rax # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, [rbp - 408] # reload L49 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb19 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb18 # jump -> then
.L22ed_rt_format_float_native_bb18:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 4072], rax # store tag L50
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r10, r11 # assign L47
    mov r11, [rbp - 4072] # tag L50 from tag-slot
    mov [rbp - 4048], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 400] # reload L48 from spill slot
    mov rsi, [rbp - 400] # reload L48 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4056] # tag L48 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4080], rax # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r11 # assign L48
    mov r11, [rbp - 4080] # tag L51 from tag-slot
    mov [rbp - 4056], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    jmp .L22ed_rt_format_float_native_bb17 # branch
.L22ed_rt_format_float_native_bb19:
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L52
    mov r11, [rbp - 4032] # tag L45 from tag-slot
    mov [rbp - 4088], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 4032] # tag L45 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 376] # reload L45 from spill slot
    mov rsi, [rbp - 376] # reload L45 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4032] # tag L45 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4104], rax # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov r11, [rbp - 448] # reload L54 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 4104] # tag L54 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3896] # tag L28 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 4120], rax # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r10, [rbp - 464] # reload L56 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb21 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb20 # jump -> then
.L22ed_rt_format_float_native_bb20:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3896] # tag L28 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 4136], rax # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    mov r9, [rbp - 480] # reload L58 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4136] # tag L58 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4144], rax # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3896] # tag L28 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 4152], rax # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 488] # reload L59 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4144] # tag L59 from tag-slot
    mov r9, [rbp - 496] # reload L60 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4152] # tag L60 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4160], rax # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 4160] # tag L61 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    jmp .L22ed_rt_format_float_native_bb22 # branch
.L22ed_rt_format_float_native_bb21:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    mov r9, [rbp - 240] # reload L28 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 3896] # tag L28 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    jmp .L22ed_rt_format_float_native_bb22 # branch
.L22ed_rt_format_float_native_bb22:
    jmp .L22ed_rt_format_float_native_bb23 # branch
.L22ed_rt_format_float_native_bb23:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3904] # tag L29 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 4168], rax # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb25 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb24 # jump -> then
.L22ed_rt_format_float_native_bb24:
    mov r10, 0 # assign L63
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4176], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 3904] # tag L29 from tag-slot
    mov [rbp - 4184], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, [rbp - 528] # reload L64 from spill slot
    mov rsi, [rbp - 528] # reload L64 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4184] # tag L64 from tag-slot
    mov rcx, 29 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 4192], rax # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r10, [rbp - 536] # reload L65 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb27 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb26 # jump -> then
.L22ed_rt_format_float_native_bb25:
    jmp .L22ed_rt_format_float_native_bb39 # branch
.L22ed_rt_format_float_native_bb26:
    mov r10, 29 # assign L64
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4184], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    jmp .L22ed_rt_format_float_native_bb27 # branch
.L22ed_rt_format_float_native_bb27:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4208], rax # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r11, [rbp - 552] # reload L67 from spill slot
    mov r10, r11 # assign L68
    mov r11, [rbp - 4208] # tag L67 from tag-slot
    mov [rbp - 4216], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    jmp .L22ed_rt_format_float_native_bb28 # branch
.L22ed_rt_format_float_native_bb28:
    mov r10, [rbp - 560] # reload L68 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 560] # reload L68 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4216] # tag L68 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 4224], rax # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb30 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb29 # jump -> then
.L22ed_rt_format_float_native_bb29:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 560] # reload L68 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4216] # tag L68 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4232], rax # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r10, [rbp - 576] # reload L70 from spill slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov rcx, r11 # shift count → rcx (cl)
    mov r10, r10 # shift lhs → r10
    shl r10, cl # binop << (count in cl)
    mov r10, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 4240], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r10, [rbp - 584] # reload L71 from spill slot
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov rsi, [rbp - 584] # reload L71 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4240] # tag L71 from tag-slot
    mov rcx, [rbp - 520] # reload L63 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4176] # tag L63 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4248], rax # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L73
    mov r11, [rbp - 4248] # tag L72 from tag-slot
    mov [rbp - 4256], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    mov rsi, [rbp - 600] # reload L73 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4256] # tag L73 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 4264], rax # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 560] # reload L68 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4216] # tag L68 from tag-slot
    mov r9, [rbp - 608] # reload L74 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4264] # tag L74 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    mov rsi, [rbp - 600] # reload L73 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4256] # tag L73 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 4272], rax # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r11, [rbp - 616] # reload L75 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 4272] # tag L75 from tag-slot
    mov [rbp - 4176], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r10, [rbp - 560] # reload L68 from spill slot
    mov rsi, [rbp - 560] # reload L68 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4216] # tag L68 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4280], rax # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r11, [rbp - 624] # reload L76 from spill slot
    mov r10, r11 # assign L68
    mov r11, [rbp - 4280] # tag L76 from tag-slot
    mov [rbp - 4216], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    jmp .L22ed_rt_format_float_native_bb28 # branch
.L22ed_rt_format_float_native_bb30:
    mov r10, [rbp - 520] # reload L63 from spill slot
    mov rsi, [rbp - 520] # reload L63 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4176] # tag L63 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 4288], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, [rbp - 632] # reload L77 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb32 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb31 # jump -> then
.L22ed_rt_format_float_native_bb31:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4304], rax # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r11, [rbp - 648] # reload L79 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 4304] # tag L79 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    mov r9, [rbp - 520] # reload L63 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4176] # tag L63 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    jmp .L22ed_rt_format_float_native_bb32 # branch
.L22ed_rt_format_float_native_bb32:
    jmp .L22ed_rt_format_float_native_bb33 # branch
.L22ed_rt_format_float_native_bb33:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 4312], rax # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r10, [rbp - 656] # reload L80 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb35 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb34 # jump -> then
.L22ed_rt_format_float_native_bb34:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4320], rax # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 664] # reload L81 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4320] # tag L81 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4328], rax # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r10, [rbp - 672] # reload L82 from spill slot
    mov rsi, [rbp - 672] # reload L82 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4328] # tag L82 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 4336], rax # store tag L83
    mov [rbp - 680], r10 # spill L83 to slot
    mov r10, [rbp - 680] # reload L83 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb37 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb36 # jump -> then
.L22ed_rt_format_float_native_bb35:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3904] # tag L29 from tag-slot
    mov rcx, [rbp - 528] # reload L64 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4184] # tag L64 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4360], rax # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    mov r11, [rbp - 704] # reload L86 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 4360] # tag L86 from tag-slot
    mov [rbp - 3904], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .L22ed_rt_format_float_native_bb23 # branch
.L22ed_rt_format_float_native_bb36:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4352], rax # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov r11, [rbp - 696] # reload L85 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 4352] # tag L85 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb38 # branch
.L22ed_rt_format_float_native_bb37:
    jmp .L22ed_rt_format_float_native_bb35 # branch
.L22ed_rt_format_float_native_bb38:
    jmp .L22ed_rt_format_float_native_bb33 # branch
.L22ed_rt_format_float_native_bb39:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3904] # tag L29 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4368], rax # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r10, [rbp - 712] # reload L87 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb41 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb40 # jump -> then
.L22ed_rt_format_float_native_bb40:
    mov r10, 0 # assign L88
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4376], r11 # store tag L88
    mov [rbp - 720], r10 # spill L88 to slot
    mov rdi, 0 # unop -: a.tag=TAG_INT
    mov rsi, 0 # unop -: a.payload=0
    mov rcx, [rbp - 248] # reload L29 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3904] # tag L29 from tag-slot
    call hexa_sub # unop -: 0 - x
    mov r10, rdx # unop -: capture result payload
    mov [rbp - 4384], rax # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r11, [rbp - 728] # reload L89 from spill slot
    mov r10, r11 # assign L90
    mov r11, [rbp - 4384] # tag L89 from tag-slot
    mov [rbp - 4392], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    mov r10, [rbp - 736] # reload L90 from spill slot
    mov rsi, [rbp - 736] # reload L90 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4392] # tag L90 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 4400], rax # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r10, [rbp - 744] # reload L91 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb43 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb42 # jump -> then
.L22ed_rt_format_float_native_bb41:
    mov r10, 0 # assign L125
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4672], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4680], rax # store tag L126
    mov [rbp - 1024], r10 # spill L126 to slot
    mov r10, [rbp - 1024] # reload L126 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb54 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb53 # jump -> then
.L22ed_rt_format_float_native_bb42:
    mov r10, 9 # assign L90
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4392], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    jmp .L22ed_rt_format_float_native_bb43 # branch
.L22ed_rt_format_float_native_bb43:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 17 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4416], rax # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov rsi, [rbp - 760] # reload L93 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4416] # tag L93 from tag-slot
    mov rcx, 8 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4424], rax # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r10, [rbp - 768] # reload L94 from spill slot
    mov rsi, [rbp - 768] # reload L94 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4424] # tag L94 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 4432], rax # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r11, [rbp - 776] # reload L95 from spill slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 776] # reload L95 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4432] # tag L95 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4440], rax # store tag L96
    mov [rbp - 784], r10 # spill L96 to slot
    mov r11, [rbp - 784] # reload L96 from spill slot
    mov r10, r11 # assign L97
    mov r11, [rbp - 4440] # tag L96 from tag-slot
    mov [rbp - 4448], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov rcx, r11 # shift count → rcx (cl)
    mov r10, 1 # shift lhs → r10
    shl r10, cl # binop << (count in cl)
    mov r10, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 4456], r11 # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r10, [rbp - 800] # reload L98 from spill slot
    mov rsi, [rbp - 800] # reload L98 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4456] # tag L98 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4464], rax # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r11, [rbp - 808] # reload L99 from spill slot
    mov r10, r11 # assign L100
    mov r11, [rbp - 4464] # tag L99 from tag-slot
    mov [rbp - 4472], r11 # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov rcx, r11 # shift count → rcx (cl)
    mov r10, 1000000000 # shift lhs → r10
    sar r10, cl # binop >> (count in cl)
    mov r10, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 4480], r11 # store tag L101
    mov [rbp - 824], r10 # spill L101 to slot
    mov r11, [rbp - 824] # reload L101 from spill slot
    mov r10, r11 # assign L102
    mov r11, [rbp - 4480] # tag L101 from tag-slot
    mov [rbp - 4488], r11 # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 4096] # tag L53 from tag-slot
    mov [rbp - 4496], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    jmp .L22ed_rt_format_float_native_bb44 # branch
.L22ed_rt_format_float_native_bb44:
    mov r10, [rbp - 840] # reload L103 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 840] # reload L103 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4496] # tag L103 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4504], rax # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r10, [rbp - 848] # reload L104 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb46 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb45 # jump -> then
.L22ed_rt_format_float_native_bb45:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 840] # reload L103 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4496] # tag L103 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4512], rax # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    mov r10, [rbp - 856] # reload L105 from spill slot
    mov r11, [rbp - 816] # reload L100 from spill slot
    mov r10, r10 # binop lhs into dst
    and r10, r11 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 4520], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    mov r11, [rbp - 864] # reload L106 from spill slot
    mov r10, r11 # assign L107
    mov r11, [rbp - 4520] # tag L106 from tag-slot
    mov [rbp - 4528], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 840] # reload L103 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4496] # tag L103 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4536], rax # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    mov r10, [rbp - 880] # reload L108 from spill slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov rcx, r11 # shift count → rcx (cl)
    mov r10, r10 # shift lhs → r10
    sar r10, cl # binop >> (count in cl)
    mov r10, r10 # shift result → dst
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 4544], r11 # store tag L109
    mov [rbp - 888], r10 # spill L109 to slot
    mov r10, [rbp - 888] # reload L109 from spill slot
    mov r11, [rbp - 720] # reload L88 from spill slot
    mov rsi, [rbp - 888] # reload L109 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4544] # tag L109 from tag-slot
    mov rcx, [rbp - 720] # reload L88 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4376] # tag L88 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4552], rax # store tag L110
    mov [rbp - 896], r10 # spill L110 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 840] # reload L103 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4496] # tag L103 from tag-slot
    mov r9, [rbp - 896] # reload L110 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4552] # tag L110 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 832] # reload L102 from spill slot
    mov r11, [rbp - 872] # reload L107 from spill slot
    mov rsi, [rbp - 832] # reload L102 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4488] # tag L102 from tag-slot
    mov rcx, [rbp - 872] # reload L107 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4528] # tag L107 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4560], rax # store tag L111
    mov [rbp - 904], r10 # spill L111 to slot
    mov r11, [rbp - 904] # reload L111 from spill slot
    mov r10, r11 # assign L88
    mov r11, [rbp - 4560] # tag L111 from tag-slot
    mov [rbp - 4376], r11 # store tag L88
    mov [rbp - 720], r10 # spill L88 to slot
    mov r10, [rbp - 840] # reload L103 from spill slot
    mov rsi, [rbp - 840] # reload L103 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4496] # tag L103 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4568], rax # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r11, [rbp - 912] # reload L112 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 4568] # tag L112 from tag-slot
    mov [rbp - 4496], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    jmp .L22ed_rt_format_float_native_bb44 # branch
.L22ed_rt_format_float_native_bb46:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4576], rax # store tag L113
    mov [rbp - 920], r10 # spill L113 to slot
    mov r10, [rbp - 920] # reload L113 from spill slot
    mov rsi, [rbp - 920] # reload L113 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4576] # tag L113 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 4584], rax # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov r10, [rbp - 928] # reload L114 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb48 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb47 # jump -> then
.L22ed_rt_format_float_native_bb47:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4600], rax # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    mov r11, [rbp - 944] # reload L116 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 4600] # tag L116 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    jmp .L22ed_rt_format_float_native_bb48 # branch
.L22ed_rt_format_float_native_bb48:
    mov r10, [rbp - 720] # reload L88 from spill slot
    mov rsi, [rbp - 720] # reload L88 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4376] # tag L88 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 4608], r11 # store tag L117
    mov [rbp - 952], r10 # spill L117 to slot
    mov r10, [rbp - 952] # reload L117 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb50 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb49 # jump -> then
.L22ed_rt_format_float_native_bb49:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    mov r9, [rbp - 720] # reload L88 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 4376] # tag L88 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4624], rax # store tag L119
    mov [rbp - 968], r10 # spill L119 to slot
    mov r11, [rbp - 968] # reload L119 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 4624] # tag L119 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb50 # branch
.L22ed_rt_format_float_native_bb50:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4632], rax # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r10, [rbp - 976] # reload L120 from spill slot
    mov r11, [rbp - 792] # reload L97 from spill slot
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4632] # tag L120 from tag-slot
    mov rcx, [rbp - 792] # reload L97 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4448] # tag L97 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 4640], rax # store tag L121
    mov [rbp - 984], r10 # spill L121 to slot
    mov r10, [rbp - 984] # reload L121 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb52 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb51 # jump -> then
.L22ed_rt_format_float_native_bb51:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov r11, [rbp - 792] # reload L97 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, [rbp - 792] # reload L97 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4448] # tag L97 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4656], rax # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov r11, [rbp - 1000] # reload L123 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 4656] # tag L123 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb52 # branch
.L22ed_rt_format_float_native_bb52:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3904] # tag L29 from tag-slot
    mov rcx, [rbp - 736] # reload L90 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4392] # tag L90 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4664], rax # store tag L124
    mov [rbp - 1008], r10 # spill L124 to slot
    mov r11, [rbp - 1008] # reload L124 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 4664] # tag L124 from tag-slot
    mov [rbp - 3904], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .L22ed_rt_format_float_native_bb39 # branch
.L22ed_rt_format_float_native_bb53:
    mov r10, 10 # assign L128
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4696], r11 # store tag L128
    mov [rbp - 1040], r10 # spill L128 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4704], rax # store tag L129
    mov [rbp - 1048], r10 # spill L129 to slot
    mov r11, [rbp - 1048] # reload L129 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1048] # reload L129 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4704] # tag L129 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4712], rax # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    mov r11, [rbp - 1056] # reload L130 from spill slot
    mov r10, r11 # assign L125
    mov r11, [rbp - 4712] # tag L130 from tag-slot
    mov [rbp - 4672], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    jmp .L22ed_rt_format_float_native_bb55 # branch
.L22ed_rt_format_float_native_bb54:
    mov r10, 103 # assign L135
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4752], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 1016] # reload L125 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4672] # tag L125 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4760], rax # store tag L136
    mov [rbp - 1104], r10 # spill L136 to slot
    mov r11, [rbp - 1104] # reload L136 from spill slot
    mov r10, r11 # assign L137
    mov r11, [rbp - 4760] # tag L136 from tag-slot
    mov [rbp - 4768], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 4776], r11 # store tag L138
    mov [rbp - 1120], r10 # spill L138 to slot
    mov r10, [rbp - 1120] # reload L138 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb59 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb58 # jump -> then
.L22ed_rt_format_float_native_bb55:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4720], rax # store tag L131
    mov [rbp - 1064], r10 # spill L131 to slot
    mov r10, [rbp - 1064] # reload L131 from spill slot
    mov r11, [rbp - 1040] # reload L128 from spill slot
    mov rsi, [rbp - 1064] # reload L131 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4720] # tag L131 from tag-slot
    mov rcx, [rbp - 1040] # reload L128 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4696] # tag L128 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 4728], rax # store tag L132
    mov [rbp - 1072], r10 # spill L132 to slot
    mov r10, [rbp - 1072] # reload L132 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb57 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb56 # jump -> then
.L22ed_rt_format_float_native_bb56:
    mov r10, [rbp - 1040] # reload L128 from spill slot
    mov rsi, [rbp - 1040] # reload L128 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4696] # tag L128 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4736], rax # store tag L133
    mov [rbp - 1080], r10 # spill L133 to slot
    mov r11, [rbp - 1080] # reload L133 from spill slot
    mov r10, r11 # assign L128
    mov r11, [rbp - 4736] # tag L133 from tag-slot
    mov [rbp - 4696], r11 # store tag L128
    mov [rbp - 1040], r10 # spill L128 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 1016] # reload L125 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4672] # tag L125 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4744], rax # store tag L134
    mov [rbp - 1088], r10 # spill L134 to slot
    mov r11, [rbp - 1088] # reload L134 from spill slot
    mov r10, r11 # assign L125
    mov r11, [rbp - 4744] # tag L134 from tag-slot
    mov [rbp - 4672], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    jmp .L22ed_rt_format_float_native_bb55 # branch
.L22ed_rt_format_float_native_bb57:
    jmp .L22ed_rt_format_float_native_bb54 # branch
.L22ed_rt_format_float_native_bb58:
    mov r10, [rbp - 1112] # reload L137 from spill slot
    mov rsi, [rbp - 1112] # reload L137 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4768] # tag L137 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4792], rax # store tag L140
    mov [rbp - 1136], r10 # spill L140 to slot
    mov r11, [rbp - 1136] # reload L140 from spill slot
    mov r10, r11 # assign L137
    mov r11, [rbp - 4792] # tag L140 from tag-slot
    mov [rbp - 4768], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    jmp .L22ed_rt_format_float_native_bb59 # branch
.L22ed_rt_format_float_native_bb59:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4800], rax # store tag L141
    mov [rbp - 1144], r10 # spill L141 to slot
    mov r10, [rbp - 1144] # reload L141 from spill slot
    mov rsi, [rbp - 1144] # reload L141 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4800] # tag L141 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4808], rax # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    mov r11, [rbp - 1152] # reload L142 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1152] # reload L142 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4808] # tag L142 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4816], rax # store tag L143
    mov [rbp - 1160], r10 # spill L143 to slot
    mov r10, [rbp - 1112] # reload L137 from spill slot
    mov r11, [rbp - 1160] # reload L143 from spill slot
    mov rsi, [rbp - 1112] # reload L137 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4768] # tag L137 from tag-slot
    mov rcx, [rbp - 1160] # reload L143 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4816] # tag L143 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4824], rax # store tag L144
    mov [rbp - 1168], r10 # spill L144 to slot
    mov r10, [rbp - 1168] # reload L144 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb61 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb60 # jump -> then
.L22ed_rt_format_float_native_bb60:
    mov r10, 1024 # assign L146
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4840], r11 # store tag L146
    mov [rbp - 1184], r10 # spill L146 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4848], rax # store tag L147
    mov [rbp - 1192], r10 # spill L147 to slot
    mov r11, [rbp - 1184] # reload L146 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1184] # reload L146 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4840] # tag L146 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4856], rax # store tag L148
    mov [rbp - 1200], r10 # spill L148 to slot
    mov r10, [rbp - 1112] # reload L137 from spill slot
    mov r11, [rbp - 1200] # reload L148 from spill slot
    mov rsi, [rbp - 1112] # reload L137 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4768] # tag L137 from tag-slot
    mov rcx, [rbp - 1200] # reload L148 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4856] # tag L148 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4864], rax # store tag L149
    mov [rbp - 1208], r10 # spill L149 to slot
    mov r10, [rbp - 1208] # reload L149 from spill slot
    mov rsi, [rbp - 1208] # reload L149 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4864] # tag L149 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 4872], rax # store tag L150
    mov [rbp - 1216], r10 # spill L150 to slot
    mov r10, [rbp - 1216] # reload L150 from spill slot
    mov r11, [rbp - 1184] # reload L146 from spill slot
    mov rsi, [rbp - 1216] # reload L150 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4872] # tag L150 from tag-slot
    mov rcx, [rbp - 1184] # reload L146 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4840] # tag L146 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 4880], rax # store tag L151
    mov [rbp - 1224], r10 # spill L151 to slot
    mov r10, [rbp - 1192] # reload L147 from spill slot
    mov r11, [rbp - 1224] # reload L151 from spill slot
    mov rsi, [rbp - 1192] # reload L147 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4848] # tag L147 from tag-slot
    mov rcx, [rbp - 1224] # reload L151 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4880] # tag L151 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4888], rax # store tag L152
    mov [rbp - 1232], r10 # spill L152 to slot
    mov r11, [rbp - 1232] # reload L152 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 4888] # tag L152 from tag-slot
    mov [rbp - 4896], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, [rbp - 1184] # reload L146 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1184] # reload L146 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4840] # tag L146 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4904], rax # store tag L154
    mov [rbp - 1248], r10 # spill L154 to slot
    mov r10, [rbp - 1112] # reload L137 from spill slot
    mov r11, [rbp - 1248] # reload L154 from spill slot
    mov rsi, [rbp - 1112] # reload L137 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4768] # tag L137 from tag-slot
    mov rcx, [rbp - 1248] # reload L154 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4904] # tag L154 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4912], rax # store tag L155
    mov [rbp - 1256], r10 # spill L155 to slot
    mov r10, [rbp - 1256] # reload L155 from spill slot
    mov rsi, [rbp - 1256] # reload L155 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4912] # tag L155 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 4920], rax # store tag L156
    mov [rbp - 1264], r10 # spill L156 to slot
    mov r11, [rbp - 1264] # reload L156 from spill slot
    mov r10, r11 # assign L157
    mov r11, [rbp - 4920] # tag L156 from tag-slot
    mov [rbp - 4928], r11 # store tag L157
    mov [rbp - 1272], r10 # spill L157 to slot
    mov r10, 10 # assign L158
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4936], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    mov r10, [rbp - 1272] # reload L157 from spill slot
    mov rsi, [rbp - 1272] # reload L157 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4928] # tag L157 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4944], rax # store tag L159
    mov [rbp - 1288], r10 # spill L159 to slot
    mov r11, [rbp - 1288] # reload L159 from spill slot
    mov r10, r11 # assign L157
    mov r11, [rbp - 4944] # tag L159 from tag-slot
    mov [rbp - 4928], r11 # store tag L157
    mov [rbp - 1272], r10 # spill L157 to slot
    jmp .L22ed_rt_format_float_native_bb62 # branch
.L22ed_rt_format_float_native_bb61:
    jmp .L22ed_rt_format_float_native_bb99 # branch
.L22ed_rt_format_float_native_bb62:
    mov r10, [rbp - 1272] # reload L157 from spill slot
    mov rsi, [rbp - 1272] # reload L157 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4928] # tag L157 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 4952], rax # store tag L160
    mov [rbp - 1296], r10 # spill L160 to slot
    mov r10, [rbp - 1296] # reload L160 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb64 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb63 # jump -> then
.L22ed_rt_format_float_native_bb63:
    mov r10, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1280] # reload L158 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4936] # tag L158 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 4960], rax # store tag L161
    mov [rbp - 1304], r10 # spill L161 to slot
    mov r11, [rbp - 1304] # reload L161 from spill slot
    mov r10, r11 # assign L158
    mov r11, [rbp - 4960] # tag L161 from tag-slot
    mov [rbp - 4936], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    mov r10, [rbp - 1272] # reload L157 from spill slot
    mov rsi, [rbp - 1272] # reload L157 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4928] # tag L157 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 4968], rax # store tag L162
    mov [rbp - 1312], r10 # spill L162 to slot
    mov r11, [rbp - 1312] # reload L162 from spill slot
    mov r10, r11 # assign L157
    mov r11, [rbp - 4968] # tag L162 from tag-slot
    mov [rbp - 4928], r11 # store tag L157
    mov [rbp - 1272], r10 # spill L157 to slot
    jmp .L22ed_rt_format_float_native_bb62 # branch
.L22ed_rt_format_float_native_bb64:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 4976], rax # store tag L163
    mov [rbp - 1320], r10 # spill L163 to slot
    mov r10, [rbp - 1320] # reload L163 from spill slot
    mov r11, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1320] # reload L163 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4976] # tag L163 from tag-slot
    mov rcx, [rbp - 1280] # reload L158 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4936] # tag L158 from tag-slot
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 4984], rax # store tag L164
    mov [rbp - 1328], r10 # spill L164 to slot
    mov r11, [rbp - 1328] # reload L164 from spill slot
    mov r10, r11 # assign L165
    mov r11, [rbp - 4984] # tag L164 from tag-slot
    mov [rbp - 4992], r11 # store tag L165
    mov [rbp - 1336], r10 # spill L165 to slot
    mov r10, [rbp - 1336] # reload L165 from spill slot
    mov rsi, [rbp - 1336] # reload L165 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4992] # tag L165 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5000], r11 # store tag L166
    mov [rbp - 1344], r10 # spill L166 to slot
    mov r10, [rbp - 1344] # reload L166 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb66 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb65 # jump -> then
.L22ed_rt_format_float_native_bb65:
    mov r11, [rbp - 1344] # reload L166 from spill slot
    mov r10, r11 # assign L167
    mov r11, [rbp - 5000] # tag L166 from tag-slot
    mov [rbp - 5008], r11 # store tag L167
    mov [rbp - 1352], r10 # spill L167 to slot
    jmp .L22ed_rt_format_float_native_bb67 # branch
.L22ed_rt_format_float_native_bb66:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5016], rax # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 1360] # reload L168 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5016] # tag L168 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5024], r11 # store tag L169
    mov [rbp - 1368], r10 # spill L169 to slot
    mov r11, [rbp - 1368] # reload L169 from spill slot
    mov r10, r11 # assign L167
    mov r11, [rbp - 5024] # tag L169 from tag-slot
    mov [rbp - 5008], r11 # store tag L167
    mov [rbp - 1352], r10 # spill L167 to slot
    jmp .L22ed_rt_format_float_native_bb67 # branch
.L22ed_rt_format_float_native_bb67:
    mov r11, [rbp - 1352] # reload L167 from spill slot
    mov r10, r11 # assign L170
    mov r11, [rbp - 5008] # tag L167 from tag-slot
    mov [rbp - 5032], r11 # store tag L170
    mov [rbp - 1376], r10 # spill L170 to slot
    mov r10, [rbp - 1376] # reload L170 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb69 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb68 # jump -> then
.L22ed_rt_format_float_native_bb68:
    mov r10, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1280] # reload L158 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4936] # tag L158 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 5048], rax # store tag L172
    mov [rbp - 1392], r10 # spill L172 to slot
    mov r11, [rbp - 1392] # reload L172 from spill slot
    mov r10, r11 # assign L173
    mov r11, [rbp - 5048] # tag L172 from tag-slot
    mov [rbp - 5056], r11 # store tag L173
    mov [rbp - 1400], r10 # spill L173 to slot
    mov r10, 0 # assign L174
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5064], r11 # store tag L174
    mov [rbp - 1408], r10 # spill L174 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5072], rax # store tag L175
    mov [rbp - 1416], r10 # spill L175 to slot
    mov r10, [rbp - 1416] # reload L175 from spill slot
    mov r11, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1416] # reload L175 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5072] # tag L175 from tag-slot
    mov rcx, [rbp - 1280] # reload L158 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4936] # tag L158 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 5080], rax # store tag L176
    mov [rbp - 1424], r10 # spill L176 to slot
    mov r10, [rbp - 1424] # reload L176 from spill slot
    mov r10, r10 # binop lhs into dst
    and r10, 1 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 5088], r11 # store tag L177
    mov [rbp - 1432], r10 # spill L177 to slot
    mov r10, [rbp - 1432] # reload L177 from spill slot
    mov rsi, [rbp - 1432] # reload L177 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5088] # tag L177 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5096], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov r10, [rbp - 1440] # reload L178 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb71 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb70 # jump -> then
.L22ed_rt_format_float_native_bb69:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5416], rax # store tag L218
    mov [rbp - 1760], r10 # spill L218 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 1760] # reload L218 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 1760] # reload L218 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5416] # tag L218 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5424], rax # store tag L219
    mov [rbp - 1768], r10 # spill L219 to slot
    mov r10, [rbp - 1768] # reload L219 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb98 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb97 # jump -> then
.L22ed_rt_format_float_native_bb70:
    mov r10, 1 # assign L174
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5064], r11 # store tag L174
    mov [rbp - 1408], r10 # spill L174 to slot
    jmp .L22ed_rt_format_float_native_bb71 # branch
.L22ed_rt_format_float_native_bb71:
    mov r10, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1280] # reload L158 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4936] # tag L158 from tag-slot
    mov rcx, 1000000000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5112], rax # store tag L180
    mov [rbp - 1456], r10 # spill L180 to slot
    mov r10, [rbp - 1456] # reload L180 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb73 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb72 # jump -> then
.L22ed_rt_format_float_native_bb72:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5128], rax # store tag L182
    mov [rbp - 1472], r10 # spill L182 to slot
    mov r10, [rbp - 1472] # reload L182 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb75 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb74 # jump -> then
.L22ed_rt_format_float_native_bb73:
    mov r10, 0 # assign L189
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5184], r11 # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    mov r10, [rbp - 1336] # reload L165 from spill slot
    mov r11, [rbp - 1400] # reload L173 from spill slot
    mov rsi, [rbp - 1336] # reload L165 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4992] # tag L165 from tag-slot
    mov rcx, [rbp - 1400] # reload L173 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5056] # tag L173 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 5192], rax # store tag L190
    mov [rbp - 1536], r10 # spill L190 to slot
    mov r10, [rbp - 1536] # reload L190 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb79 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb78 # jump -> then
.L22ed_rt_format_float_native_bb74:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5144], rax # store tag L184
    mov [rbp - 1488], r10 # spill L184 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1488] # reload L184 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5144] # tag L184 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5152], rax # store tag L185
    mov [rbp - 1496], r10 # spill L185 to slot
    mov r10, [rbp - 1496] # reload L185 from spill slot
    mov r10, r10 # binop lhs into dst
    and r10, 1 # binop &
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 5160], r11 # store tag L186
    mov [rbp - 1504], r10 # spill L186 to slot
    mov r10, [rbp - 1504] # reload L186 from spill slot
    mov rsi, [rbp - 1504] # reload L186 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5160] # tag L186 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5168], r11 # store tag L187
    mov [rbp - 1512], r10 # spill L187 to slot
    mov r10, [rbp - 1512] # reload L187 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb77 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb76 # jump -> then
.L22ed_rt_format_float_native_bb75:
    jmp .L22ed_rt_format_float_native_bb73 # branch
.L22ed_rt_format_float_native_bb76:
    mov r10, 1 # assign L174
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5064], r11 # store tag L174
    mov [rbp - 1408], r10 # spill L174 to slot
    jmp .L22ed_rt_format_float_native_bb77 # branch
.L22ed_rt_format_float_native_bb77:
    jmp .L22ed_rt_format_float_native_bb75 # branch
.L22ed_rt_format_float_native_bb78:
    mov r10, 0 # assign L189
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5184], r11 # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    jmp .L22ed_rt_format_float_native_bb86 # branch
.L22ed_rt_format_float_native_bb79:
    mov r10, [rbp - 1336] # reload L165 from spill slot
    mov r11, [rbp - 1400] # reload L173 from spill slot
    mov rsi, [rbp - 1336] # reload L165 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4992] # tag L165 from tag-slot
    mov rcx, [rbp - 1400] # reload L173 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5056] # tag L173 from tag-slot
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5208], rax # store tag L192
    mov [rbp - 1552], r10 # spill L192 to slot
    mov r10, [rbp - 1552] # reload L192 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb81 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb80 # jump -> then
.L22ed_rt_format_float_native_bb80:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5224], rax # store tag L194
    mov [rbp - 1568], r10 # spill L194 to slot
    mov r10, [rbp - 1568] # reload L194 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 1568] # reload L194 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5224] # tag L194 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5232], rax # store tag L195
    mov [rbp - 1576], r10 # spill L195 to slot
    mov r10, [rbp - 1576] # reload L195 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb83 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb82 # jump -> then
.L22ed_rt_format_float_native_bb81:
    mov r10, 1 # assign L189
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5184], r11 # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    jmp .L22ed_rt_format_float_native_bb85 # branch
.L22ed_rt_format_float_native_bb82:
    mov r11, [rbp - 1408] # reload L174 from spill slot
    mov r10, r11 # assign L189
    mov r11, [rbp - 5064] # tag L174 from tag-slot
    mov [rbp - 5184], r11 # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    jmp .L22ed_rt_format_float_native_bb84 # branch
.L22ed_rt_format_float_native_bb83:
    mov r10, 1 # assign L189
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5184], r11 # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    jmp .L22ed_rt_format_float_native_bb84 # branch
.L22ed_rt_format_float_native_bb84:
    jmp .L22ed_rt_format_float_native_bb85 # branch
.L22ed_rt_format_float_native_bb85:
    jmp .L22ed_rt_format_float_native_bb86 # branch
.L22ed_rt_format_float_native_bb86:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5248], rax # store tag L197
    mov [rbp - 1592], r10 # spill L197 to slot
    mov r10, [rbp - 1592] # reload L197 from spill slot
    mov r11, [rbp - 1336] # reload L165 from spill slot
    mov rsi, [rbp - 1592] # reload L197 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5248] # tag L197 from tag-slot
    mov rcx, [rbp - 1336] # reload L165 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4992] # tag L165 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5256], rax # store tag L198
    mov [rbp - 1600], r10 # spill L198 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    mov r9, [rbp - 1600] # reload L198 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 5256] # tag L198 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 1528] # reload L189 from spill slot
    mov rsi, [rbp - 1528] # reload L189 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5184] # tag L189 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5264], r11 # store tag L199
    mov [rbp - 1608], r10 # spill L199 to slot
    mov r10, [rbp - 1608] # reload L199 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb88 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb87 # jump -> then
.L22ed_rt_format_float_native_bb87:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5280], rax # store tag L201
    mov [rbp - 1624], r10 # spill L201 to slot
    mov r10, [rbp - 1624] # reload L201 from spill slot
    mov r11, [rbp - 1280] # reload L158 from spill slot
    mov rsi, [rbp - 1624] # reload L201 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5280] # tag L201 from tag-slot
    mov rcx, [rbp - 1280] # reload L158 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4936] # tag L158 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5288], rax # store tag L202
    mov [rbp - 1632], r10 # spill L202 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    mov r9, [rbp - 1632] # reload L202 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 5288] # tag L202 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    jmp .L22ed_rt_format_float_native_bb89 # branch
.L22ed_rt_format_float_native_bb88:
    jmp .L22ed_rt_format_float_native_bb69 # branch
.L22ed_rt_format_float_native_bb89:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5296], rax # store tag L203
    mov [rbp - 1640], r10 # spill L203 to slot
    mov r10, [rbp - 1640] # reload L203 from spill slot
    mov rsi, [rbp - 1640] # reload L203 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5296] # tag L203 from tag-slot
    mov rcx, 999999999 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5304], rax # store tag L204
    mov [rbp - 1648], r10 # spill L204 to slot
    mov r10, [rbp - 1648] # reload L204 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb91 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb90 # jump -> then
.L22ed_rt_format_float_native_bb90:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5312], rax # store tag L205
    mov [rbp - 1656], r10 # spill L205 to slot
    mov r11, [rbp - 1656] # reload L205 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 5312] # tag L205 from tag-slot
    mov [rbp - 4896], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 5320], rax # store tag L206
    mov [rbp - 1664], r10 # spill L206 to slot
    mov r10, [rbp - 1664] # reload L206 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb93 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb92 # jump -> then
.L22ed_rt_format_float_native_bb91:
    mov r10, 10 # assign L211
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5360], r11 # store tag L211
    mov [rbp - 1704], r10 # spill L211 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5368], rax # store tag L212
    mov [rbp - 1712], r10 # spill L212 to slot
    mov r11, [rbp - 1712] # reload L212 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1712] # reload L212 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5368] # tag L212 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 5376], rax # store tag L213
    mov [rbp - 1720], r10 # spill L213 to slot
    mov r11, [rbp - 1720] # reload L213 from spill slot
    mov r10, r11 # assign L125
    mov r11, [rbp - 5376] # tag L213 from tag-slot
    mov [rbp - 4672], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    jmp .L22ed_rt_format_float_native_bb94 # branch
.L22ed_rt_format_float_native_bb92:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5336], rax # store tag L208
    mov [rbp - 1680], r10 # spill L208 to slot
    mov r11, [rbp - 1680] # reload L208 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 5336] # tag L208 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    jmp .L22ed_rt_format_float_native_bb93 # branch
.L22ed_rt_format_float_native_bb93:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5344], rax # store tag L209
    mov [rbp - 1688], r10 # spill L209 to slot
    mov r10, [rbp - 1688] # reload L209 from spill slot
    mov rsi, [rbp - 1688] # reload L209 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5344] # tag L209 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5352], rax # store tag L210
    mov [rbp - 1696], r10 # spill L210 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1240] # reload L153 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4896] # tag L153 from tag-slot
    mov r9, [rbp - 1696] # reload L210 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 5352] # tag L210 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 4048], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    jmp .L22ed_rt_format_float_native_bb89 # branch
.L22ed_rt_format_float_native_bb94:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5384], rax # store tag L214
    mov [rbp - 1728], r10 # spill L214 to slot
    mov r10, [rbp - 1728] # reload L214 from spill slot
    mov r11, [rbp - 1704] # reload L211 from spill slot
    mov rsi, [rbp - 1728] # reload L214 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5384] # tag L214 from tag-slot
    mov rcx, [rbp - 1704] # reload L211 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5360] # tag L211 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 5392], rax # store tag L215
    mov [rbp - 1736], r10 # spill L215 to slot
    mov r10, [rbp - 1736] # reload L215 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb96 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb95 # jump -> then
.L22ed_rt_format_float_native_bb95:
    mov r10, [rbp - 1704] # reload L211 from spill slot
    mov rsi, [rbp - 1704] # reload L211 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5360] # tag L211 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 5400], rax # store tag L216
    mov [rbp - 1744], r10 # spill L216 to slot
    mov r11, [rbp - 1744] # reload L216 from spill slot
    mov r10, r11 # assign L211
    mov r11, [rbp - 5400] # tag L216 from tag-slot
    mov [rbp - 5360], r11 # store tag L211
    mov [rbp - 1704], r10 # spill L211 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 1016] # reload L125 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4672] # tag L125 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5408], rax # store tag L217
    mov [rbp - 1752], r10 # spill L217 to slot
    mov r11, [rbp - 1752] # reload L217 from spill slot
    mov r10, r11 # assign L125
    mov r11, [rbp - 5408] # tag L217 from tag-slot
    mov [rbp - 4672], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    jmp .L22ed_rt_format_float_native_bb94 # branch
.L22ed_rt_format_float_native_bb96:
    jmp .L22ed_rt_format_float_native_bb88 # branch
.L22ed_rt_format_float_native_bb97:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov rsi, [rbp - 1240] # reload L153 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4896] # tag L153 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5440], rax # store tag L221
    mov [rbp - 1784], r10 # spill L221 to slot
    mov r11, [rbp - 1784] # reload L221 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 5440] # tag L221 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb98 # branch
.L22ed_rt_format_float_native_bb98:
    jmp .L22ed_rt_format_float_native_bb61 # branch
.L22ed_rt_format_float_native_bb99:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5448], rax # store tag L222
    mov [rbp - 1792], r10 # spill L222 to slot
    mov r10, [rbp - 1792] # reload L222 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb101 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb100 # jump -> then
.L22ed_rt_format_float_native_bb100:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5456], rax # store tag L223
    mov [rbp - 1800], r10 # spill L223 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1800] # reload L223 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5456] # tag L223 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5464], rax # store tag L224
    mov [rbp - 1808], r10 # spill L224 to slot
    mov r10, [rbp - 1808] # reload L224 from spill slot
    mov rsi, [rbp - 1808] # reload L224 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5464] # tag L224 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5472], rax # store tag L225
    mov [rbp - 1816], r10 # spill L225 to slot
    mov r10, [rbp - 1816] # reload L225 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb103 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb102 # jump -> then
.L22ed_rt_format_float_native_bb101:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5496], rax # store tag L228
    mov [rbp - 1840], r10 # spill L228 to slot
    mov r10, [rbp - 1840] # reload L228 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb106 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb105 # jump -> then
.L22ed_rt_format_float_native_bb102:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5488], rax # store tag L227
    mov [rbp - 1832], r10 # spill L227 to slot
    mov r11, [rbp - 1832] # reload L227 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 5488] # tag L227 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb104 # branch
.L22ed_rt_format_float_native_bb103:
    jmp .L22ed_rt_format_float_native_bb101 # branch
.L22ed_rt_format_float_native_bb104:
    jmp .L22ed_rt_format_float_native_bb99 # branch
.L22ed_rt_format_float_native_bb105:
    mov r10, 1 # assign L41
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb106 # branch
.L22ed_rt_format_float_native_bb106:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 1016] # reload L125 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4672] # tag L125 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5512], rax # store tag L230
    mov [rbp - 1856], r10 # spill L230 to slot
    mov r10, [rbp - 1856] # reload L230 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb108 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb107 # jump -> then
.L22ed_rt_format_float_native_bb107:
    mov r10, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 1016] # reload L125 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4672] # tag L125 from tag-slot
    mov rcx, -4 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 5528], rax # store tag L232
    mov [rbp - 1872], r10 # spill L232 to slot
    mov r11, [rbp - 1872] # reload L232 from spill slot
    mov r10, r11 # assign L231
    mov r11, [rbp - 5528] # tag L232 from tag-slot
    mov [rbp - 5520], r11 # store tag L231
    mov [rbp - 1864], r10 # spill L231 to slot
    jmp .L22ed_rt_format_float_native_bb109 # branch
.L22ed_rt_format_float_native_bb108:
    mov r11, [rbp - 1856] # reload L230 from spill slot
    mov r10, r11 # assign L231
    mov r11, [rbp - 5512] # tag L230 from tag-slot
    mov [rbp - 5520], r11 # store tag L231
    mov [rbp - 1864], r10 # spill L231 to slot
    jmp .L22ed_rt_format_float_native_bb109 # branch
.L22ed_rt_format_float_native_bb109:
    mov r10, [rbp - 1864] # reload L231 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb111 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb110 # jump -> then
.L22ed_rt_format_float_native_bb110:
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4752] # tag L135 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5544], rax # store tag L234
    mov [rbp - 1888], r10 # spill L234 to slot
    mov r11, [rbp - 1888] # reload L234 from spill slot
    mov r10, r11 # assign L135
    mov r11, [rbp - 5544] # tag L234 from tag-slot
    mov [rbp - 4752], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 1016] # reload L125 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4672] # tag L125 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5552], rax # store tag L235
    mov [rbp - 1896], r10 # spill L235 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 1896] # reload L235 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 1896] # reload L235 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5552] # tag L235 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5560], rax # store tag L236
    mov [rbp - 1904], r10 # spill L236 to slot
    mov r11, [rbp - 1904] # reload L236 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 5560] # tag L236 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb112 # branch
.L22ed_rt_format_float_native_bb111:
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4752] # tag L135 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5568], rax # store tag L237
    mov [rbp - 1912], r10 # spill L237 to slot
    mov r11, [rbp - 1912] # reload L237 from spill slot
    mov r10, r11 # assign L135
    mov r11, [rbp - 5568] # tag L237 from tag-slot
    mov [rbp - 4752], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5576], rax # store tag L238
    mov [rbp - 1920], r10 # spill L238 to slot
    mov r11, [rbp - 1920] # reload L238 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 5576] # tag L238 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb112 # branch
.L22ed_rt_format_float_native_bb112:
    mov r10, 9 # assign L239
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5584], r11 # store tag L239
    mov [rbp - 1928], r10 # spill L239 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5592], rax # store tag L240
    mov [rbp - 1936], r10 # spill L240 to slot
    mov r10, [rbp - 1936] # reload L240 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb114 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb113 # jump -> then
.L22ed_rt_format_float_native_bb113:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5608], rax # store tag L242
    mov [rbp - 1952], r10 # spill L242 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1952] # reload L242 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5608] # tag L242 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5616], rax # store tag L243
    mov [rbp - 1960], r10 # spill L243 to slot
    mov r10, [rbp - 1960] # reload L243 from spill slot
    mov rsi, [rbp - 1960] # reload L243 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5616] # tag L243 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5624], r11 # store tag L244
    mov [rbp - 1968], r10 # spill L244 to slot
    mov r10, [rbp - 1968] # reload L244 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb116 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb115 # jump -> then
.L22ed_rt_format_float_native_bb114:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5696], rax # store tag L253
    mov [rbp - 2040], r10 # spill L253 to slot
    mov r10, [rbp - 2040] # reload L253 from spill slot
    mov rsi, [rbp - 2040] # reload L253 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5696] # tag L253 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5704], rax # store tag L254
    mov [rbp - 2048], r10 # spill L254 to slot
    mov r11, [rbp - 2048] # reload L254 from spill slot
    mov rsi, 9 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 2048] # reload L254 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5704] # tag L254 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 5712], rax # store tag L255
    mov [rbp - 2056], r10 # spill L255 to slot
    mov r11, [rbp - 2056] # reload L255 from spill slot
    mov r10, r11 # assign L256
    mov r11, [rbp - 5712] # tag L255 from tag-slot
    mov [rbp - 5720], r11 # store tag L256
    mov [rbp - 2064], r10 # spill L256 to slot
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4752] # tag L135 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5728], rax # store tag L257
    mov [rbp - 2072], r10 # spill L257 to slot
    mov r10, [rbp - 2072] # reload L257 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb121 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb120 # jump -> then
.L22ed_rt_format_float_native_bb115:
    mov r10, 10 # assign L246
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5640], r11 # store tag L246
    mov [rbp - 1984], r10 # spill L246 to slot
    mov r10, 0 # assign L239
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5584], r11 # store tag L239
    mov [rbp - 1928], r10 # spill L239 to slot
    jmp .L22ed_rt_format_float_native_bb117 # branch
.L22ed_rt_format_float_native_bb116:
    jmp .L22ed_rt_format_float_native_bb114 # branch
.L22ed_rt_format_float_native_bb117:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5648], rax # store tag L247
    mov [rbp - 1992], r10 # spill L247 to slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 1992] # reload L247 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5648] # tag L247 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5656], rax # store tag L248
    mov [rbp - 2000], r10 # spill L248 to slot
    mov r10, [rbp - 2000] # reload L248 from spill slot
    mov r11, [rbp - 1984] # reload L246 from spill slot
    mov rsi, [rbp - 2000] # reload L248 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5656] # tag L248 from tag-slot
    mov rcx, [rbp - 1984] # reload L246 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5640] # tag L246 from tag-slot
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 5664], rax # store tag L249
    mov [rbp - 2008], r10 # spill L249 to slot
    mov r10, [rbp - 2008] # reload L249 from spill slot
    mov rsi, [rbp - 2008] # reload L249 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5664] # tag L249 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5672], rax # store tag L250
    mov [rbp - 2016], r10 # spill L250 to slot
    mov r10, [rbp - 2016] # reload L250 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb119 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb118 # jump -> then
.L22ed_rt_format_float_native_bb118:
    mov r10, [rbp - 1984] # reload L246 from spill slot
    mov rsi, [rbp - 1984] # reload L246 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5640] # tag L246 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 5680], rax # store tag L251
    mov [rbp - 2024], r10 # spill L251 to slot
    mov r11, [rbp - 2024] # reload L251 from spill slot
    mov r10, r11 # assign L246
    mov r11, [rbp - 5680] # tag L251 from tag-slot
    mov [rbp - 5640], r11 # store tag L246
    mov [rbp - 1984], r10 # spill L246 to slot
    mov r10, [rbp - 1928] # reload L239 from spill slot
    mov rsi, [rbp - 1928] # reload L239 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5584] # tag L239 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5688], rax # store tag L252
    mov [rbp - 2032], r10 # spill L252 to slot
    mov r11, [rbp - 2032] # reload L252 from spill slot
    mov r10, r11 # assign L239
    mov r11, [rbp - 5688] # tag L252 from tag-slot
    mov [rbp - 5584], r11 # store tag L239
    mov [rbp - 1928], r10 # spill L239 to slot
    jmp .L22ed_rt_format_float_native_bb117 # branch
.L22ed_rt_format_float_native_bb119:
    jmp .L22ed_rt_format_float_native_bb116 # branch
.L22ed_rt_format_float_native_bb120:
    mov r10, [rbp - 2064] # reload L256 from spill slot
    mov r11, [rbp - 1928] # reload L239 from spill slot
    mov rsi, [rbp - 2064] # reload L256 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5720] # tag L256 from tag-slot
    mov rcx, [rbp - 1928] # reload L239 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5584] # tag L239 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5744], rax # store tag L259
    mov [rbp - 2088], r10 # spill L259 to slot
    mov r11, [rbp - 2088] # reload L259 from spill slot
    mov r10, r11 # assign L260
    mov r11, [rbp - 5744] # tag L259 from tag-slot
    mov [rbp - 5752], r11 # store tag L260
    mov [rbp - 2096], r10 # spill L260 to slot
    mov r10, [rbp - 2096] # reload L260 from spill slot
    mov rsi, [rbp - 2096] # reload L260 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5752] # tag L260 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 5760], rax # store tag L261
    mov [rbp - 2104], r10 # spill L261 to slot
    mov r10, [rbp - 2104] # reload L261 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb123 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb122 # jump -> then
.L22ed_rt_format_float_native_bb121:
    mov r10, [rbp - 2064] # reload L256 from spill slot
    mov r11, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 2064] # reload L256 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5720] # tag L256 from tag-slot
    mov rcx, [rbp - 1016] # reload L125 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4672] # tag L125 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5792], rax # store tag L265
    mov [rbp - 2136], r10 # spill L265 to slot
    mov r10, [rbp - 2136] # reload L265 from spill slot
    mov r11, [rbp - 1928] # reload L239 from spill slot
    mov rsi, [rbp - 2136] # reload L265 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5792] # tag L265 from tag-slot
    mov rcx, [rbp - 1928] # reload L239 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5584] # tag L239 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 5800], rax # store tag L266
    mov [rbp - 2144], r10 # spill L266 to slot
    mov r11, [rbp - 2144] # reload L266 from spill slot
    mov r10, r11 # assign L267
    mov r11, [rbp - 5800] # tag L266 from tag-slot
    mov [rbp - 5808], r11 # store tag L267
    mov [rbp - 2152], r10 # spill L267 to slot
    mov r10, [rbp - 2152] # reload L267 from spill slot
    mov rsi, [rbp - 2152] # reload L267 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5808] # tag L267 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 5816], rax # store tag L268
    mov [rbp - 2160], r10 # spill L268 to slot
    mov r10, [rbp - 2160] # reload L268 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb127 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb126 # jump -> then
.L22ed_rt_format_float_native_bb122:
    mov r10, 0 # assign L260
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5752], r11 # store tag L260
    mov [rbp - 2096], r10 # spill L260 to slot
    jmp .L22ed_rt_format_float_native_bb123 # branch
.L22ed_rt_format_float_native_bb123:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 2096] # reload L260 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 2096] # reload L260 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5752] # tag L260 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5776], rax # store tag L263
    mov [rbp - 2120], r10 # spill L263 to slot
    mov r10, [rbp - 2120] # reload L263 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb125 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb124 # jump -> then
.L22ed_rt_format_float_native_bb124:
    mov r11, [rbp - 2096] # reload L260 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 5752] # tag L260 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb125 # branch
.L22ed_rt_format_float_native_bb125:
    jmp .L22ed_rt_format_float_native_bb130 # branch
.L22ed_rt_format_float_native_bb126:
    mov r10, 0 # assign L267
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 5808], r11 # store tag L267
    mov [rbp - 2152], r10 # spill L267 to slot
    jmp .L22ed_rt_format_float_native_bb127 # branch
.L22ed_rt_format_float_native_bb127:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 2152] # reload L267 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 2152] # reload L267 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5808] # tag L267 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5832], rax # store tag L270
    mov [rbp - 2176], r10 # spill L270 to slot
    mov r10, [rbp - 2176] # reload L270 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb129 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb128 # jump -> then
.L22ed_rt_format_float_native_bb128:
    mov r11, [rbp - 2152] # reload L267 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 5808] # tag L267 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb129 # branch
.L22ed_rt_format_float_native_bb129:
    jmp .L22ed_rt_format_float_native_bb130 # branch
.L22ed_rt_format_float_native_bb130:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3720] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5848], r11 # store tag L272
    mov [rbp - 2192], r10 # spill L272 to slot
    mov r10, [rbp - 2192] # reload L272 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb132 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb131 # jump -> then
.L22ed_rt_format_float_native_bb131:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 5864], rax # store tag L274
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2208], r10 # spill L274 to slot
    mov r11, [rbp - 2208] # reload L274 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 5864] # tag L274 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb132 # branch
.L22ed_rt_format_float_native_bb132:
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4752] # tag L135 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 5872], rax # store tag L275
    mov [rbp - 2216], r10 # spill L275 to slot
    mov r10, [rbp - 2216] # reload L275 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb134 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb133 # jump -> then
.L22ed_rt_format_float_native_bb133:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 5888], rax # store tag L277
    mov [rbp - 2232], r10 # spill L277 to slot
    mov r10, [rbp - 2232] # reload L277 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb136 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb135 # jump -> then
.L22ed_rt_format_float_native_bb134:
    mov r11, [rbp - 1016] # reload L125 from spill slot
    mov r10, r11 # assign L347
    mov r11, [rbp - 4672] # tag L125 from tag-slot
    mov [rbp - 6448], r11 # store tag L347
    mov [rbp - 2792], r10 # spill L347 to slot
    mov r10, 0 # assign L348
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6456], r11 # store tag L348
    mov [rbp - 2800], r10 # spill L348 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    mov rsi, [rbp - 1016] # reload L125 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4672] # tag L125 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6464], rax # store tag L349
    mov [rbp - 2808], r10 # spill L349 to slot
    mov r10, [rbp - 2808] # reload L349 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb180 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb179 # jump -> then
.L22ed_rt_format_float_native_bb135:
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 4088] # tag L52 from tag-slot
    mov [rbp - 4096], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    jmp .L22ed_rt_format_float_native_bb136 # branch
.L22ed_rt_format_float_native_bb136:
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L279
    mov r11, [rbp - 4096] # tag L53 from tag-slot
    mov [rbp - 5904], r11 # store tag L279
    mov [rbp - 2248], r10 # spill L279 to slot
    jmp .L22ed_rt_format_float_native_bb137 # branch
.L22ed_rt_format_float_native_bb137:
    mov r10, [rbp - 2248] # reload L279 from spill slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 2248] # reload L279 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5904] # tag L279 from tag-slot
    mov rcx, [rbp - 432] # reload L52 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4088] # tag L52 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 5912], rax # store tag L280
    mov [rbp - 2256], r10 # spill L280 to slot
    mov r10, [rbp - 2256] # reload L280 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb139 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb138 # jump -> then
.L22ed_rt_format_float_native_bb138:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 2248] # reload L279 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5904] # tag L279 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 5920], rax # store tag L281
    mov [rbp - 2264], r10 # spill L281 to slot
    mov rsi, [rbp - 2264] # reload L281 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5920] # tag L281 from tag-slot
    call _g_digits # call _g_digits
    mov [rbp - 5928], rax # store tag L282
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 2272], r10 # spill L282 to slot
    mov r11, [rbp - 2272] # reload L282 from spill slot
    mov r10, r11 # assign L283
    mov r11, [rbp - 5928] # tag L282 from tag-slot
    mov [rbp - 5936], r11 # store tag L283
    mov [rbp - 2280], r10 # spill L283 to slot
    mov r10, [rbp - 2248] # reload L279 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 2248] # reload L279 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5904] # tag L279 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 5944], r11 # store tag L284
    mov [rbp - 2288], r10 # spill L284 to slot
    mov r10, [rbp - 2288] # reload L284 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb141 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb140 # jump -> then
.L22ed_rt_format_float_native_bb139:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 6136], r11 # store tag L308
    mov [rbp - 2480], r10 # spill L308 to slot
    mov r10, [rbp - 2480] # reload L308 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb156 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb155 # jump -> then
.L22ed_rt_format_float_native_bb140:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 5960], r11 # store tag L286
    mov [rbp - 2304], r10 # spill L286 to slot
    mov r11, [rbp - 2304] # reload L286 from spill slot
    mov r10, r11 # assign L287
    mov r11, [rbp - 5960] # tag L286 from tag-slot
    mov [rbp - 5968], r11 # store tag L287
    mov [rbp - 2312], r10 # spill L287 to slot
    jmp .L22ed_rt_format_float_native_bb142 # branch
.L22ed_rt_format_float_native_bb141:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6048], r11 # store tag L297
    mov [rbp - 2392], r10 # spill L297 to slot
    mov r10, [rbp - 2392] # reload L297 from spill slot
    mov rsi, [rbp - 2392] # reload L297 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6048] # tag L297 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 6056], rax # store tag L298
    mov [rbp - 2400], r10 # spill L298 to slot
    mov r10, [rbp - 2400] # reload L298 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb149 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb148 # jump -> then
.L22ed_rt_format_float_native_bb142:
    mov r10, [rbp - 2312] # reload L287 from spill slot
    mov rsi, [rbp - 2312] # reload L287 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5968] # tag L287 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 5976], rax # store tag L288
    mov [rbp - 2320], r10 # spill L288 to slot
    mov r10, [rbp - 2320] # reload L288 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb144 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb143 # jump -> then
.L22ed_rt_format_float_native_bb143:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 5984], rax # store tag L289
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2328], r10 # spill L289 to slot
    mov r11, [rbp - 2328] # reload L289 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 5984] # tag L289 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 2312] # reload L287 from spill slot
    mov rsi, [rbp - 2312] # reload L287 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5968] # tag L287 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 5992], rax # store tag L290
    mov [rbp - 2336], r10 # spill L290 to slot
    mov r11, [rbp - 2336] # reload L290 from spill slot
    mov r10, r11 # assign L287
    mov r11, [rbp - 5992] # tag L290 from tag-slot
    mov [rbp - 5968], r11 # store tag L287
    mov [rbp - 2312], r10 # spill L287 to slot
    jmp .L22ed_rt_format_float_native_bb142 # branch
.L22ed_rt_format_float_native_bb144:
    mov r10, 0 # assign L291
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6000], r11 # store tag L291
    mov [rbp - 2344], r10 # spill L291 to slot
    jmp .L22ed_rt_format_float_native_bb145 # branch
.L22ed_rt_format_float_native_bb145:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6008], r11 # store tag L292
    mov [rbp - 2352], r10 # spill L292 to slot
    mov r10, [rbp - 2344] # reload L291 from spill slot
    mov r11, [rbp - 2352] # reload L292 from spill slot
    mov rsi, [rbp - 2344] # reload L291 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6000] # tag L291 from tag-slot
    mov rcx, [rbp - 2352] # reload L292 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6008] # tag L292 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6016], rax # store tag L293
    mov [rbp - 2360], r10 # spill L293 to slot
    mov r10, [rbp - 2360] # reload L293 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb147 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb146 # jump -> then
.L22ed_rt_format_float_native_bb146:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    mov rcx, [rbp - 2344] # reload L291 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6000] # tag L291 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6024], rax # store tag L294
    mov [rbp - 2368], r10 # spill L294 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 2368] # reload L294 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6024] # tag L294 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6032], rax # store tag L295
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2376], r10 # spill L295 to slot
    mov r11, [rbp - 2376] # reload L295 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6032] # tag L295 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 2344] # reload L291 from spill slot
    mov rsi, [rbp - 2344] # reload L291 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6000] # tag L291 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6040], rax # store tag L296
    mov [rbp - 2384], r10 # spill L296 to slot
    mov r11, [rbp - 2384] # reload L296 from spill slot
    mov r10, r11 # assign L291
    mov r11, [rbp - 6040] # tag L296 from tag-slot
    mov [rbp - 6000], r11 # store tag L291
    mov [rbp - 2344], r10 # spill L291 to slot
    jmp .L22ed_rt_format_float_native_bb145 # branch
.L22ed_rt_format_float_native_bb147:
    jmp .L22ed_rt_format_float_native_bb154 # branch
.L22ed_rt_format_float_native_bb148:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6072], rax # store tag L300
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2416], r10 # spill L300 to slot
    mov r11, [rbp - 2416] # reload L300 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6072] # tag L300 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb153 # branch
.L22ed_rt_format_float_native_bb149:
    mov r10, 0 # assign L301
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6080], r11 # store tag L301
    mov [rbp - 2424], r10 # spill L301 to slot
    jmp .L22ed_rt_format_float_native_bb150 # branch
.L22ed_rt_format_float_native_bb150:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6088], r11 # store tag L302
    mov [rbp - 2432], r10 # spill L302 to slot
    mov r10, [rbp - 2424] # reload L301 from spill slot
    mov r11, [rbp - 2432] # reload L302 from spill slot
    mov rsi, [rbp - 2424] # reload L301 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6080] # tag L301 from tag-slot
    mov rcx, [rbp - 2432] # reload L302 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6088] # tag L302 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6096], rax # store tag L303
    mov [rbp - 2440], r10 # spill L303 to slot
    mov r10, [rbp - 2440] # reload L303 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb152 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb151 # jump -> then
.L22ed_rt_format_float_native_bb151:
    mov rsi, [rbp - 2280] # reload L283 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5936] # tag L283 from tag-slot
    mov rcx, [rbp - 2424] # reload L301 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6080] # tag L301 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6104], rax # store tag L304
    mov [rbp - 2448], r10 # spill L304 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 2448] # reload L304 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6104] # tag L304 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6112], rax # store tag L305
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2456], r10 # spill L305 to slot
    mov r11, [rbp - 2456] # reload L305 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6112] # tag L305 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 2424] # reload L301 from spill slot
    mov rsi, [rbp - 2424] # reload L301 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6080] # tag L301 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6120], rax # store tag L306
    mov [rbp - 2464], r10 # spill L306 to slot
    mov r11, [rbp - 2464] # reload L306 from spill slot
    mov r10, r11 # assign L301
    mov r11, [rbp - 6120] # tag L306 from tag-slot
    mov [rbp - 6080], r11 # store tag L301
    mov [rbp - 2424], r10 # spill L301 to slot
    jmp .L22ed_rt_format_float_native_bb150 # branch
.L22ed_rt_format_float_native_bb152:
    jmp .L22ed_rt_format_float_native_bb153 # branch
.L22ed_rt_format_float_native_bb153:
    jmp .L22ed_rt_format_float_native_bb154 # branch
.L22ed_rt_format_float_native_bb154:
    mov r10, [rbp - 2248] # reload L279 from spill slot
    mov rsi, [rbp - 2248] # reload L279 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5904] # tag L279 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6128], rax # store tag L307
    mov [rbp - 2472], r10 # spill L307 to slot
    mov r11, [rbp - 2472] # reload L307 from spill slot
    mov r10, r11 # assign L279
    mov r11, [rbp - 6128] # tag L307 from tag-slot
    mov [rbp - 5904], r11 # store tag L279
    mov [rbp - 2248], r10 # spill L279 to slot
    jmp .L22ed_rt_format_float_native_bb137 # branch
.L22ed_rt_format_float_native_bb155:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 46 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6152], rax # store tag L310
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2496], r10 # spill L310 to slot
    mov r11, [rbp - 2496] # reload L310 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6152] # tag L310 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb156 # branch
.L22ed_rt_format_float_native_bb156:
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov rsi, [rbp - 432] # reload L52 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4088] # tag L52 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6160], rax # store tag L311
    mov [rbp - 2504], r10 # spill L311 to slot
    mov r11, [rbp - 2504] # reload L311 from spill slot
    mov r10, r11 # assign L279
    mov r11, [rbp - 6160] # tag L311 from tag-slot
    mov [rbp - 5904], r11 # store tag L279
    mov [rbp - 2248], r10 # spill L279 to slot
    jmp .L22ed_rt_format_float_native_bb157 # branch
.L22ed_rt_format_float_native_bb157:
    mov r10, [rbp - 2248] # reload L279 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 2248] # reload L279 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5904] # tag L279 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6168], rax # store tag L312
    mov [rbp - 2512], r10 # spill L312 to slot
    mov r10, [rbp - 2512] # reload L312 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb161 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb160 # jump -> then
.L22ed_rt_format_float_native_bb158:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 2248] # reload L279 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 5904] # tag L279 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6192], rax # store tag L315
    mov [rbp - 2536], r10 # spill L315 to slot
    mov rsi, [rbp - 2536] # reload L315 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6192] # tag L315 from tag-slot
    call _g_digits # call _g_digits
    mov [rbp - 6200], rax # store tag L316
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 2544], r10 # spill L316 to slot
    mov r11, [rbp - 2544] # reload L316 from spill slot
    mov r10, r11 # assign L317
    mov r11, [rbp - 6200] # tag L316 from tag-slot
    mov [rbp - 6208], r11 # store tag L317
    mov [rbp - 2552], r10 # spill L317 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 6216], rax # store tag L318
    mov [rbp - 2560], r10 # spill L318 to slot
    mov r11, [rbp - 2560] # reload L318 from spill slot
    mov r10, r11 # assign L319
    mov r11, [rbp - 6216] # tag L318 from tag-slot
    mov [rbp - 6224], r11 # store tag L319
    mov [rbp - 2568], r10 # spill L319 to slot
    mov rsi, [rbp - 2552] # reload L317 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6208] # tag L317 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6232], r11 # store tag L320
    mov [rbp - 2576], r10 # spill L320 to slot
    mov r11, [rbp - 2576] # reload L320 from spill slot
    mov r10, r11 # assign L321
    mov r11, [rbp - 6232] # tag L320 from tag-slot
    mov [rbp - 6240], r11 # store tag L321
    mov [rbp - 2584], r10 # spill L321 to slot
    jmp .L22ed_rt_format_float_native_bb163 # branch
.L22ed_rt_format_float_native_bb159:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 6400], rax # store tag L341
    mov [rbp - 2744], r10 # spill L341 to slot
    mov r10, [rbp - 2744] # reload L341 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb175 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb174 # jump -> then
.L22ed_rt_format_float_native_bb160:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 6184], rax # store tag L314
    mov [rbp - 2528], r10 # spill L314 to slot
    mov r11, [rbp - 2528] # reload L314 from spill slot
    mov r10, r11 # assign L313
    mov r11, [rbp - 6184] # tag L314 from tag-slot
    mov [rbp - 6176], r11 # store tag L313
    mov [rbp - 2520], r10 # spill L313 to slot
    jmp .L22ed_rt_format_float_native_bb162 # branch
.L22ed_rt_format_float_native_bb161:
    mov r11, [rbp - 2512] # reload L312 from spill slot
    mov r10, r11 # assign L313
    mov r11, [rbp - 6168] # tag L312 from tag-slot
    mov [rbp - 6176], r11 # store tag L313
    mov [rbp - 2520], r10 # spill L313 to slot
    jmp .L22ed_rt_format_float_native_bb162 # branch
.L22ed_rt_format_float_native_bb162:
    mov r10, [rbp - 2520] # reload L313 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb159 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb158 # jump -> then
.L22ed_rt_format_float_native_bb163:
    mov r10, [rbp - 2584] # reload L321 from spill slot
    mov rsi, [rbp - 2584] # reload L321 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6240] # tag L321 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6248], rax # store tag L322
    mov [rbp - 2592], r10 # spill L322 to slot
    mov r10, [rbp - 2592] # reload L322 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb165 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb164 # jump -> then
.L22ed_rt_format_float_native_bb164:
    mov rsi, [rbp - 2568] # reload L319 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6224] # tag L319 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6256], rax # store tag L323
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2600], r10 # spill L323 to slot
    mov r11, [rbp - 2600] # reload L323 from spill slot
    mov r10, r11 # assign L319
    mov r11, [rbp - 6256] # tag L323 from tag-slot
    mov [rbp - 6224], r11 # store tag L319
    mov [rbp - 2568], r10 # spill L319 to slot
    mov r10, [rbp - 2584] # reload L321 from spill slot
    mov rsi, [rbp - 2584] # reload L321 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6240] # tag L321 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6264], rax # store tag L324
    mov [rbp - 2608], r10 # spill L324 to slot
    mov r11, [rbp - 2608] # reload L324 from spill slot
    mov r10, r11 # assign L321
    mov r11, [rbp - 6264] # tag L324 from tag-slot
    mov [rbp - 6240], r11 # store tag L321
    mov [rbp - 2584], r10 # spill L321 to slot
    jmp .L22ed_rt_format_float_native_bb163 # branch
.L22ed_rt_format_float_native_bb165:
    mov r10, 0 # assign L325
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6272], r11 # store tag L325
    mov [rbp - 2616], r10 # spill L325 to slot
    jmp .L22ed_rt_format_float_native_bb166 # branch
.L22ed_rt_format_float_native_bb166:
    mov rsi, [rbp - 2552] # reload L317 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6208] # tag L317 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6280], r11 # store tag L326
    mov [rbp - 2624], r10 # spill L326 to slot
    mov r10, [rbp - 2616] # reload L325 from spill slot
    mov r11, [rbp - 2624] # reload L326 from spill slot
    mov rsi, [rbp - 2616] # reload L325 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6272] # tag L325 from tag-slot
    mov rcx, [rbp - 2624] # reload L326 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6280] # tag L326 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6288], rax # store tag L327
    mov [rbp - 2632], r10 # spill L327 to slot
    mov r10, [rbp - 2632] # reload L327 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb168 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb167 # jump -> then
.L22ed_rt_format_float_native_bb167:
    mov rsi, [rbp - 2552] # reload L317 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6208] # tag L317 from tag-slot
    mov rcx, [rbp - 2616] # reload L325 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6272] # tag L325 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6296], rax # store tag L328
    mov [rbp - 2640], r10 # spill L328 to slot
    mov rsi, [rbp - 2568] # reload L319 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6224] # tag L319 from tag-slot
    mov rcx, [rbp - 2640] # reload L328 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6296] # tag L328 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6304], rax # store tag L329
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2648], r10 # spill L329 to slot
    mov r11, [rbp - 2648] # reload L329 from spill slot
    mov r10, r11 # assign L319
    mov r11, [rbp - 6304] # tag L329 from tag-slot
    mov [rbp - 6224], r11 # store tag L319
    mov [rbp - 2568], r10 # spill L319 to slot
    mov r10, [rbp - 2616] # reload L325 from spill slot
    mov rsi, [rbp - 2616] # reload L325 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6272] # tag L325 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6312], rax # store tag L330
    mov [rbp - 2656], r10 # spill L330 to slot
    mov r11, [rbp - 2656] # reload L330 from spill slot
    mov r10, r11 # assign L325
    mov r11, [rbp - 6312] # tag L330 from tag-slot
    mov [rbp - 6272], r11 # store tag L325
    mov [rbp - 2616], r10 # spill L325 to slot
    jmp .L22ed_rt_format_float_native_bb166 # branch
.L22ed_rt_format_float_native_bb168:
    mov r10, 9 # assign L331
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6320], r11 # store tag L331
    mov [rbp - 2664], r10 # spill L331 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6328], rax # store tag L332
    mov [rbp - 2672], r10 # spill L332 to slot
    mov r10, [rbp - 2672] # reload L332 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb170 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb169 # jump -> then
.L22ed_rt_format_float_native_bb169:
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L331
    mov r11, [rbp - 4000] # tag L41 from tag-slot
    mov [rbp - 6320], r11 # store tag L331
    mov [rbp - 2664], r10 # spill L331 to slot
    jmp .L22ed_rt_format_float_native_bb170 # branch
.L22ed_rt_format_float_native_bb170:
    mov r10, 0 # assign L334
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6344], r11 # store tag L334
    mov [rbp - 2688], r10 # spill L334 to slot
    jmp .L22ed_rt_format_float_native_bb171 # branch
.L22ed_rt_format_float_native_bb171:
    mov r10, [rbp - 2688] # reload L334 from spill slot
    mov r11, [rbp - 2664] # reload L331 from spill slot
    mov rsi, [rbp - 2688] # reload L334 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6344] # tag L334 from tag-slot
    mov rcx, [rbp - 2664] # reload L331 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6320] # tag L331 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6352], rax # store tag L335
    mov [rbp - 2696], r10 # spill L335 to slot
    mov r10, [rbp - 2696] # reload L335 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb173 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb172 # jump -> then
.L22ed_rt_format_float_native_bb172:
    mov rsi, [rbp - 2568] # reload L319 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6224] # tag L319 from tag-slot
    mov rcx, [rbp - 2688] # reload L334 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6344] # tag L334 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6360], rax # store tag L336
    mov [rbp - 2704], r10 # spill L336 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 2704] # reload L336 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6360] # tag L336 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6368], rax # store tag L337
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2712], r10 # spill L337 to slot
    mov r11, [rbp - 2712] # reload L337 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6368] # tag L337 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 2688] # reload L334 from spill slot
    mov rsi, [rbp - 2688] # reload L334 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6344] # tag L334 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6376], rax # store tag L338
    mov [rbp - 2720], r10 # spill L338 to slot
    mov r11, [rbp - 2720] # reload L338 from spill slot
    mov r10, r11 # assign L334
    mov r11, [rbp - 6376] # tag L338 from tag-slot
    mov [rbp - 6344], r11 # store tag L334
    mov [rbp - 2688], r10 # spill L334 to slot
    jmp .L22ed_rt_format_float_native_bb171 # branch
.L22ed_rt_format_float_native_bb173:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 6384], rax # store tag L339
    mov [rbp - 2728], r10 # spill L339 to slot
    mov r11, [rbp - 2728] # reload L339 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 6384] # tag L339 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r10, [rbp - 2248] # reload L279 from spill slot
    mov rsi, [rbp - 2248] # reload L279 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 5904] # tag L279 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6392], rax # store tag L340
    mov [rbp - 2736], r10 # spill L340 to slot
    mov r11, [rbp - 2736] # reload L340 from spill slot
    mov r10, r11 # assign L279
    mov r11, [rbp - 6392] # tag L340 from tag-slot
    mov [rbp - 5904], r11 # store tag L279
    mov [rbp - 2248], r10 # spill L279 to slot
    jmp .L22ed_rt_format_float_native_bb157 # branch
.L22ed_rt_format_float_native_bb174:
    mov r10, 0 # assign L343
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6416], r11 # store tag L343
    mov [rbp - 2760], r10 # spill L343 to slot
    jmp .L22ed_rt_format_float_native_bb176 # branch
.L22ed_rt_format_float_native_bb175:
    jmp .L22ed_rt_format_float_native_bb238 # branch
.L22ed_rt_format_float_native_bb176:
    mov r10, [rbp - 2760] # reload L343 from spill slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 2760] # reload L343 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6416] # tag L343 from tag-slot
    mov rcx, [rbp - 344] # reload L41 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4000] # tag L41 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6424], rax # store tag L344
    mov [rbp - 2768], r10 # spill L344 to slot
    mov r10, [rbp - 2768] # reload L344 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb178 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb177 # jump -> then
.L22ed_rt_format_float_native_bb177:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6432], rax # store tag L345
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2776], r10 # spill L345 to slot
    mov r11, [rbp - 2776] # reload L345 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6432] # tag L345 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 2760] # reload L343 from spill slot
    mov rsi, [rbp - 2760] # reload L343 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6416] # tag L343 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6440], rax # store tag L346
    mov [rbp - 2784], r10 # spill L346 to slot
    mov r11, [rbp - 2784] # reload L346 from spill slot
    mov r10, r11 # assign L343
    mov r11, [rbp - 6440] # tag L346 from tag-slot
    mov [rbp - 6416], r11 # store tag L343
    mov [rbp - 2760], r10 # spill L343 to slot
    jmp .L22ed_rt_format_float_native_bb176 # branch
.L22ed_rt_format_float_native_bb178:
    jmp .L22ed_rt_format_float_native_bb175 # branch
.L22ed_rt_format_float_native_bb179:
    mov r10, 1 # assign L348
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6456], r11 # store tag L348
    mov [rbp - 2800], r10 # spill L348 to slot
    mov rdi, 0 # unop -: a.tag=TAG_INT
    mov rsi, 0 # unop -: a.payload=0
    mov rcx, [rbp - 1016] # reload L125 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4672] # tag L125 from tag-slot
    call hexa_sub # unop -: 0 - x
    mov r10, rdx # unop -: capture result payload
    mov [rbp - 6480], rax # store tag L351
    mov [rbp - 2824], r10 # spill L351 to slot
    mov r11, [rbp - 2824] # reload L351 from spill slot
    mov r10, r11 # assign L347
    mov r11, [rbp - 6480] # tag L351 from tag-slot
    mov [rbp - 6448], r11 # store tag L347
    mov [rbp - 2792], r10 # spill L347 to slot
    jmp .L22ed_rt_format_float_native_bb180 # branch
.L22ed_rt_format_float_native_bb180:
    mov rsi, [rbp - 2792] # reload L347 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6448] # tag L347 from tag-slot
    call _g_digits # call _g_digits
    mov [rbp - 6488], rax # store tag L352
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 2832], r10 # spill L352 to slot
    mov r11, [rbp - 2832] # reload L352 from spill slot
    mov r10, r11 # assign L353
    mov r11, [rbp - 6488] # tag L352 from tag-slot
    mov [rbp - 6496], r11 # store tag L353
    mov [rbp - 2840], r10 # spill L353 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 6504], rax # store tag L354
    mov [rbp - 2848], r10 # spill L354 to slot
    mov r11, [rbp - 2848] # reload L354 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6504] # tag L354 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, [rbp - 1096] # reload L135 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4752] # tag L135 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6520], rax # store tag L356
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2864], r10 # spill L356 to slot
    mov r11, [rbp - 2864] # reload L356 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6520] # tag L356 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    mov r10, [rbp - 2800] # reload L348 from spill slot
    mov rsi, [rbp - 2800] # reload L348 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6456] # tag L348 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 6528], r11 # store tag L357
    mov [rbp - 2872], r10 # spill L357 to slot
    mov r10, [rbp - 2872] # reload L357 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb182 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb181 # jump -> then
.L22ed_rt_format_float_native_bb181:
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6544], rax # store tag L359
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2888], r10 # spill L359 to slot
    mov r11, [rbp - 2888] # reload L359 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6544] # tag L359 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    jmp .L22ed_rt_format_float_native_bb183 # branch
.L22ed_rt_format_float_native_bb182:
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, 43 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6552], rax # store tag L360
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2896], r10 # spill L360 to slot
    mov r11, [rbp - 2896] # reload L360 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6552] # tag L360 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    jmp .L22ed_rt_format_float_native_bb183 # branch
.L22ed_rt_format_float_native_bb183:
    mov rsi, [rbp - 2840] # reload L353 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6496] # tag L353 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6560], r11 # store tag L361
    mov [rbp - 2904], r10 # spill L361 to slot
    mov r10, [rbp - 2904] # reload L361 from spill slot
    mov rsi, [rbp - 2904] # reload L361 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6560] # tag L361 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6568], rax # store tag L362
    mov [rbp - 2912], r10 # spill L362 to slot
    mov r10, [rbp - 2912] # reload L362 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb185 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb184 # jump -> then
.L22ed_rt_format_float_native_bb184:
    mov rsi, [rbp - 2840] # reload L353 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6496] # tag L353 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6584], r11 # store tag L364
    mov [rbp - 2928], r10 # spill L364 to slot
    mov r11, [rbp - 2928] # reload L364 from spill slot
    mov r10, r11 # assign L365
    mov r11, [rbp - 6584] # tag L364 from tag-slot
    mov [rbp - 6592], r11 # store tag L365
    mov [rbp - 2936], r10 # spill L365 to slot
    jmp .L22ed_rt_format_float_native_bb186 # branch
.L22ed_rt_format_float_native_bb185:
    mov r10, 0 # assign L369
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6624], r11 # store tag L369
    mov [rbp - 2968], r10 # spill L369 to slot
    jmp .L22ed_rt_format_float_native_bb189 # branch
.L22ed_rt_format_float_native_bb186:
    mov r10, [rbp - 2936] # reload L365 from spill slot
    mov rsi, [rbp - 2936] # reload L365 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6592] # tag L365 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6600], rax # store tag L366
    mov [rbp - 2944], r10 # spill L366 to slot
    mov r10, [rbp - 2944] # reload L366 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb188 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb187 # jump -> then
.L22ed_rt_format_float_native_bb187:
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6608], rax # store tag L367
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 2952], r10 # spill L367 to slot
    mov r11, [rbp - 2952] # reload L367 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6608] # tag L367 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    mov r10, [rbp - 2936] # reload L365 from spill slot
    mov rsi, [rbp - 2936] # reload L365 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6592] # tag L365 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6616], rax # store tag L368
    mov [rbp - 2960], r10 # spill L368 to slot
    mov r11, [rbp - 2960] # reload L368 from spill slot
    mov r10, r11 # assign L365
    mov r11, [rbp - 6616] # tag L368 from tag-slot
    mov [rbp - 6592], r11 # store tag L365
    mov [rbp - 2936], r10 # spill L365 to slot
    jmp .L22ed_rt_format_float_native_bb186 # branch
.L22ed_rt_format_float_native_bb188:
    jmp .L22ed_rt_format_float_native_bb185 # branch
.L22ed_rt_format_float_native_bb189:
    mov rsi, [rbp - 2840] # reload L353 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6496] # tag L353 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6632], r11 # store tag L370
    mov [rbp - 2976], r10 # spill L370 to slot
    mov r10, [rbp - 2968] # reload L369 from spill slot
    mov r11, [rbp - 2976] # reload L370 from spill slot
    mov rsi, [rbp - 2968] # reload L369 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6624] # tag L369 from tag-slot
    mov rcx, [rbp - 2976] # reload L370 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6632] # tag L370 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6640], rax # store tag L371
    mov [rbp - 2984], r10 # spill L371 to slot
    mov r10, [rbp - 2984] # reload L371 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb191 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb190 # jump -> then
.L22ed_rt_format_float_native_bb190:
    mov rsi, [rbp - 2840] # reload L353 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6496] # tag L353 from tag-slot
    mov rcx, [rbp - 2968] # reload L369 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6624] # tag L369 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6648], rax # store tag L372
    mov [rbp - 2992], r10 # spill L372 to slot
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, [rbp - 2992] # reload L372 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6648] # tag L372 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6656], rax # store tag L373
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3000], r10 # spill L373 to slot
    mov r11, [rbp - 3000] # reload L373 from spill slot
    mov r10, r11 # assign L355
    mov r11, [rbp - 6656] # tag L373 from tag-slot
    mov [rbp - 6512], r11 # store tag L355
    mov [rbp - 2856], r10 # spill L355 to slot
    mov r10, [rbp - 2968] # reload L369 from spill slot
    mov rsi, [rbp - 2968] # reload L369 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6624] # tag L369 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6664], rax # store tag L374
    mov [rbp - 3008], r10 # spill L374 to slot
    mov r11, [rbp - 3008] # reload L374 from spill slot
    mov r10, r11 # assign L369
    mov r11, [rbp - 6664] # tag L374 from tag-slot
    mov [rbp - 6624], r11 # store tag L369
    mov [rbp - 2968], r10 # spill L369 to slot
    jmp .L22ed_rt_format_float_native_bb189 # branch
.L22ed_rt_format_float_native_bb191:
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4112] # tag L55 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 6672], rax # store tag L375
    mov [rbp - 3016], r10 # spill L375 to slot
    mov r10, [rbp - 3016] # reload L375 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb193 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb192 # jump -> then
.L22ed_rt_format_float_native_bb192:
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 440] # reload L53 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4096] # tag L53 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6688], rax # store tag L377
    mov [rbp - 3032], r10 # spill L377 to slot
    mov r11, [rbp - 3032] # reload L377 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 6688] # tag L377 from tag-slot
    mov [rbp - 4112], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    jmp .L22ed_rt_format_float_native_bb193 # branch
.L22ed_rt_format_float_native_bb193:
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L378
    mov r11, [rbp - 4096] # tag L53 from tag-slot
    mov [rbp - 6696], r11 # store tag L378
    mov [rbp - 3040], r10 # spill L378 to slot
    jmp .L22ed_rt_format_float_native_bb194 # branch
.L22ed_rt_format_float_native_bb194:
    mov r10, [rbp - 3040] # reload L378 from spill slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 3040] # reload L378 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6696] # tag L378 from tag-slot
    mov rcx, [rbp - 456] # reload L55 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4112] # tag L55 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6704], rax # store tag L379
    mov [rbp - 3048], r10 # spill L379 to slot
    mov r10, [rbp - 3048] # reload L379 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb198 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb197 # jump -> then
.L22ed_rt_format_float_native_bb195:
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4048] # tag L47 from tag-slot
    mov rcx, [rbp - 3040] # reload L378 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6696] # tag L378 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6728], rax # store tag L382
    mov [rbp - 3072], r10 # spill L382 to slot
    mov rsi, [rbp - 3072] # reload L382 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6728] # tag L382 from tag-slot
    call _g_digits # call _g_digits
    mov [rbp - 6736], rax # store tag L383
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 3080], r10 # spill L383 to slot
    mov r11, [rbp - 3080] # reload L383 from spill slot
    mov r10, r11 # assign L384
    mov r11, [rbp - 6736] # tag L383 from tag-slot
    mov [rbp - 6744], r11 # store tag L384
    mov [rbp - 3088], r10 # spill L384 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 6752], rax # store tag L385
    mov [rbp - 3096], r10 # spill L385 to slot
    mov r11, [rbp - 3096] # reload L385 from spill slot
    mov r10, r11 # assign L386
    mov r11, [rbp - 6752] # tag L385 from tag-slot
    mov [rbp - 6760], r11 # store tag L386
    mov [rbp - 3104], r10 # spill L386 to slot
    mov r10, [rbp - 3040] # reload L378 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 3040] # reload L378 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6696] # tag L378 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 6768], r11 # store tag L387
    mov [rbp - 3112], r10 # spill L387 to slot
    mov r10, [rbp - 3112] # reload L387 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb201 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb200 # jump -> then
.L22ed_rt_format_float_native_bb196:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 7224], rax # store tag L444
    mov [rbp - 3568], r10 # spill L444 to slot
    mov r10, [rbp - 3568] # reload L444 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb231 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb230 # jump -> then
.L22ed_rt_format_float_native_bb197:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 6720], rax # store tag L381
    mov [rbp - 3064], r10 # spill L381 to slot
    mov r11, [rbp - 3064] # reload L381 from spill slot
    mov r10, r11 # assign L380
    mov r11, [rbp - 6720] # tag L381 from tag-slot
    mov [rbp - 6712], r11 # store tag L380
    mov [rbp - 3056], r10 # spill L380 to slot
    jmp .L22ed_rt_format_float_native_bb199 # branch
.L22ed_rt_format_float_native_bb198:
    mov r11, [rbp - 3048] # reload L379 from spill slot
    mov r10, r11 # assign L380
    mov r11, [rbp - 6704] # tag L379 from tag-slot
    mov [rbp - 6712], r11 # store tag L380
    mov [rbp - 3056], r10 # spill L380 to slot
    jmp .L22ed_rt_format_float_native_bb199 # branch
.L22ed_rt_format_float_native_bb199:
    mov r10, [rbp - 3056] # reload L380 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb196 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb195 # jump -> then
.L22ed_rt_format_float_native_bb200:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6784], r11 # store tag L389
    mov [rbp - 3128], r10 # spill L389 to slot
    mov r11, [rbp - 3128] # reload L389 from spill slot
    mov r10, r11 # assign L390
    mov r11, [rbp - 6784] # tag L389 from tag-slot
    mov [rbp - 6792], r11 # store tag L390
    mov [rbp - 3136], r10 # spill L390 to slot
    jmp .L22ed_rt_format_float_native_bb202 # branch
.L22ed_rt_format_float_native_bb201:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6872], r11 # store tag L400
    mov [rbp - 3216], r10 # spill L400 to slot
    mov r10, [rbp - 3216] # reload L400 from spill slot
    mov rsi, [rbp - 3216] # reload L400 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6872] # tag L400 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 6880], rax # store tag L401
    mov [rbp - 3224], r10 # spill L401 to slot
    mov r10, [rbp - 3224] # reload L401 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb209 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb208 # jump -> then
.L22ed_rt_format_float_native_bb202:
    mov r10, [rbp - 3136] # reload L390 from spill slot
    mov rsi, [rbp - 3136] # reload L390 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6792] # tag L390 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6800], rax # store tag L391
    mov [rbp - 3144], r10 # spill L391 to slot
    mov r10, [rbp - 3144] # reload L391 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb204 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb203 # jump -> then
.L22ed_rt_format_float_native_bb203:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6808], rax # store tag L392
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3152], r10 # spill L392 to slot
    mov r11, [rbp - 3152] # reload L392 from spill slot
    mov r10, r11 # assign L386
    mov r11, [rbp - 6808] # tag L392 from tag-slot
    mov [rbp - 6760], r11 # store tag L386
    mov [rbp - 3104], r10 # spill L386 to slot
    mov r10, [rbp - 3136] # reload L390 from spill slot
    mov rsi, [rbp - 3136] # reload L390 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6792] # tag L390 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6816], rax # store tag L393
    mov [rbp - 3160], r10 # spill L393 to slot
    mov r11, [rbp - 3160] # reload L393 from spill slot
    mov r10, r11 # assign L390
    mov r11, [rbp - 6816] # tag L393 from tag-slot
    mov [rbp - 6792], r11 # store tag L390
    mov [rbp - 3136], r10 # spill L390 to slot
    jmp .L22ed_rt_format_float_native_bb202 # branch
.L22ed_rt_format_float_native_bb204:
    mov r10, 0 # assign L394
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6824], r11 # store tag L394
    mov [rbp - 3168], r10 # spill L394 to slot
    jmp .L22ed_rt_format_float_native_bb205 # branch
.L22ed_rt_format_float_native_bb205:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6832], r11 # store tag L395
    mov [rbp - 3176], r10 # spill L395 to slot
    mov r10, [rbp - 3168] # reload L394 from spill slot
    mov r11, [rbp - 3176] # reload L395 from spill slot
    mov rsi, [rbp - 3168] # reload L394 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6824] # tag L394 from tag-slot
    mov rcx, [rbp - 3176] # reload L395 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6832] # tag L395 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6840], rax # store tag L396
    mov [rbp - 3184], r10 # spill L396 to slot
    mov r10, [rbp - 3184] # reload L396 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb207 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb206 # jump -> then
.L22ed_rt_format_float_native_bb206:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    mov rcx, [rbp - 3168] # reload L394 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6824] # tag L394 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6848], rax # store tag L397
    mov [rbp - 3192], r10 # spill L397 to slot
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, [rbp - 3192] # reload L397 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6848] # tag L397 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6856], rax # store tag L398
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3200], r10 # spill L398 to slot
    mov r11, [rbp - 3200] # reload L398 from spill slot
    mov r10, r11 # assign L386
    mov r11, [rbp - 6856] # tag L398 from tag-slot
    mov [rbp - 6760], r11 # store tag L386
    mov [rbp - 3104], r10 # spill L386 to slot
    mov r10, [rbp - 3168] # reload L394 from spill slot
    mov rsi, [rbp - 3168] # reload L394 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6824] # tag L394 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6864], rax # store tag L399
    mov [rbp - 3208], r10 # spill L399 to slot
    mov r11, [rbp - 3208] # reload L399 from spill slot
    mov r10, r11 # assign L394
    mov r11, [rbp - 6864] # tag L399 from tag-slot
    mov [rbp - 6824], r11 # store tag L394
    mov [rbp - 3168], r10 # spill L394 to slot
    jmp .L22ed_rt_format_float_native_bb205 # branch
.L22ed_rt_format_float_native_bb207:
    jmp .L22ed_rt_format_float_native_bb214 # branch
.L22ed_rt_format_float_native_bb208:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6896], rax # store tag L403
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3240], r10 # spill L403 to slot
    mov r11, [rbp - 3240] # reload L403 from spill slot
    mov r10, r11 # assign L386
    mov r11, [rbp - 6896] # tag L403 from tag-slot
    mov [rbp - 6760], r11 # store tag L386
    mov [rbp - 3104], r10 # spill L386 to slot
    jmp .L22ed_rt_format_float_native_bb213 # branch
.L22ed_rt_format_float_native_bb209:
    mov r10, 0 # assign L404
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 6904], r11 # store tag L404
    mov [rbp - 3248], r10 # spill L404 to slot
    jmp .L22ed_rt_format_float_native_bb210 # branch
.L22ed_rt_format_float_native_bb210:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6912], r11 # store tag L405
    mov [rbp - 3256], r10 # spill L405 to slot
    mov r10, [rbp - 3248] # reload L404 from spill slot
    mov r11, [rbp - 3256] # reload L405 from spill slot
    mov rsi, [rbp - 3248] # reload L404 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6904] # tag L404 from tag-slot
    mov rcx, [rbp - 3256] # reload L405 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6912] # tag L405 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 6920], rax # store tag L406
    mov [rbp - 3264], r10 # spill L406 to slot
    mov r10, [rbp - 3264] # reload L406 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb212 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb211 # jump -> then
.L22ed_rt_format_float_native_bb211:
    mov rsi, [rbp - 3088] # reload L384 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6744] # tag L384 from tag-slot
    mov rcx, [rbp - 3248] # reload L404 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6904] # tag L404 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6928], rax # store tag L407
    mov [rbp - 3272], r10 # spill L407 to slot
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, [rbp - 3272] # reload L407 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6928] # tag L407 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6936], rax # store tag L408
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3280], r10 # spill L408 to slot
    mov r11, [rbp - 3280] # reload L408 from spill slot
    mov r10, r11 # assign L386
    mov r11, [rbp - 6936] # tag L408 from tag-slot
    mov [rbp - 6760], r11 # store tag L386
    mov [rbp - 3104], r10 # spill L386 to slot
    mov r10, [rbp - 3248] # reload L404 from spill slot
    mov rsi, [rbp - 3248] # reload L404 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6904] # tag L404 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 6944], rax # store tag L409
    mov [rbp - 3288], r10 # spill L409 to slot
    mov r11, [rbp - 3288] # reload L409 from spill slot
    mov r10, r11 # assign L404
    mov r11, [rbp - 6944] # tag L409 from tag-slot
    mov [rbp - 6904], r11 # store tag L404
    mov [rbp - 3248], r10 # spill L404 to slot
    jmp .L22ed_rt_format_float_native_bb210 # branch
.L22ed_rt_format_float_native_bb212:
    jmp .L22ed_rt_format_float_native_bb213 # branch
.L22ed_rt_format_float_native_bb213:
    jmp .L22ed_rt_format_float_native_bb214 # branch
.L22ed_rt_format_float_native_bb214:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 6952], r11 # store tag L410
    mov [rbp - 3296], r10 # spill L410 to slot
    mov r11, [rbp - 3296] # reload L410 from spill slot
    mov r10, r11 # assign L411
    mov r11, [rbp - 6952] # tag L410 from tag-slot
    mov [rbp - 6960], r11 # store tag L411
    mov [rbp - 3304], r10 # spill L411 to slot
    mov r10, [rbp - 3040] # reload L378 from spill slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov rsi, [rbp - 3040] # reload L378 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6696] # tag L378 from tag-slot
    mov rcx, [rbp - 440] # reload L53 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4096] # tag L53 from tag-slot
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 6968], rax # store tag L412
    mov [rbp - 3312], r10 # spill L412 to slot
    mov r10, [rbp - 3312] # reload L412 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb216 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb215 # jump -> then
.L22ed_rt_format_float_native_bb215:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 6984], rax # store tag L414
    mov [rbp - 3328], r10 # spill L414 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 3328] # reload L414 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6984] # tag L414 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 6992], rax # store tag L415
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3336], r10 # spill L415 to slot
    mov r11, [rbp - 3336] # reload L415 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 6992] # tag L415 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 7000], rax # store tag L416
    mov [rbp - 3344], r10 # spill L416 to slot
    mov r10, [rbp - 3344] # reload L416 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb218 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb217 # jump -> then
.L22ed_rt_format_float_native_bb216:
    mov r11, [rbp - 3304] # reload L411 from spill slot
    mov r10, r11 # assign L432
    mov r11, [rbp - 6960] # tag L411 from tag-slot
    mov [rbp - 7128], r11 # store tag L432
    mov [rbp - 3472], r10 # spill L432 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 3472] # reload L432 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 3472] # reload L432 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7128] # tag L432 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7136], rax # store tag L433
    mov [rbp - 3480], r10 # spill L433 to slot
    mov r10, [rbp - 3480] # reload L433 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb225 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb224 # jump -> then
.L22ed_rt_format_float_native_bb217:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 46 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 7016], rax # store tag L418
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3360], r10 # spill L418 to slot
    mov r11, [rbp - 3360] # reload L418 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 7016] # tag L418 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L22ed_rt_format_float_native_bb218 # branch
.L22ed_rt_format_float_native_bb218:
    mov r10, [rbp - 3304] # reload L411 from spill slot
    mov rsi, [rbp - 3304] # reload L411 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6960] # tag L411 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 7024], rax # store tag L419
    mov [rbp - 3368], r10 # spill L419 to slot
    mov r11, [rbp - 3368] # reload L419 from spill slot
    mov r10, r11 # assign L420
    mov r11, [rbp - 7024] # tag L419 from tag-slot
    mov [rbp - 7032], r11 # store tag L420
    mov [rbp - 3376], r10 # spill L420 to slot
    mov r11, [rbp - 3376] # reload L420 from spill slot
    mov r10, r11 # assign L421
    mov r11, [rbp - 7032] # tag L420 from tag-slot
    mov [rbp - 7040], r11 # store tag L421
    mov [rbp - 3384], r10 # spill L421 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 3384] # reload L421 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 3384] # reload L421 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7040] # tag L421 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7048], rax # store tag L422
    mov [rbp - 3392], r10 # spill L422 to slot
    mov r10, [rbp - 3392] # reload L422 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb220 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb219 # jump -> then
.L22ed_rt_format_float_native_bb219:
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L421
    mov r11, [rbp - 4000] # tag L41 from tag-slot
    mov [rbp - 7040], r11 # store tag L421
    mov [rbp - 3384], r10 # spill L421 to slot
    jmp .L22ed_rt_format_float_native_bb220 # branch
.L22ed_rt_format_float_native_bb220:
    mov r10, 1 # assign L424
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7064], r11 # store tag L424
    mov [rbp - 3408], r10 # spill L424 to slot
    mov r10, 0 # assign L425
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7072], r11 # store tag L425
    mov [rbp - 3416], r10 # spill L425 to slot
    jmp .L22ed_rt_format_float_native_bb221 # branch
.L22ed_rt_format_float_native_bb221:
    mov r10, [rbp - 3416] # reload L425 from spill slot
    mov r11, [rbp - 3384] # reload L421 from spill slot
    mov rsi, [rbp - 3416] # reload L425 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7072] # tag L425 from tag-slot
    mov rcx, [rbp - 3384] # reload L421 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7040] # tag L421 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7080], rax # store tag L426
    mov [rbp - 3424], r10 # spill L426 to slot
    mov r10, [rbp - 3424] # reload L426 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb223 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb222 # jump -> then
.L22ed_rt_format_float_native_bb222:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, [rbp - 3408] # reload L424 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7064] # tag L424 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 7088], rax # store tag L427
    mov [rbp - 3432], r10 # spill L427 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 3432] # reload L427 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7088] # tag L427 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 7096], rax # store tag L428
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3440], r10 # spill L428 to slot
    mov r11, [rbp - 3440] # reload L428 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 7096] # tag L428 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 3408] # reload L424 from spill slot
    mov rsi, [rbp - 3408] # reload L424 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7064] # tag L424 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7104], rax # store tag L429
    mov [rbp - 3448], r10 # spill L429 to slot
    mov r11, [rbp - 3448] # reload L429 from spill slot
    mov r10, r11 # assign L424
    mov r11, [rbp - 7104] # tag L429 from tag-slot
    mov [rbp - 7064], r11 # store tag L424
    mov [rbp - 3408], r10 # spill L424 to slot
    mov r10, [rbp - 3416] # reload L425 from spill slot
    mov rsi, [rbp - 3416] # reload L425 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7072] # tag L425 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7112], rax # store tag L430
    mov [rbp - 3456], r10 # spill L430 to slot
    mov r11, [rbp - 3456] # reload L430 from spill slot
    mov r10, r11 # assign L425
    mov r11, [rbp - 7112] # tag L430 from tag-slot
    mov [rbp - 7072], r11 # store tag L425
    mov [rbp - 3416], r10 # spill L425 to slot
    jmp .L22ed_rt_format_float_native_bb221 # branch
.L22ed_rt_format_float_native_bb223:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 3376] # reload L420 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 3376] # reload L420 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7032] # tag L420 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 7120], rax # store tag L431
    mov [rbp - 3464], r10 # spill L431 to slot
    mov r11, [rbp - 3464] # reload L431 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 7120] # tag L431 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb229 # branch
.L22ed_rt_format_float_native_bb224:
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L432
    mov r11, [rbp - 4000] # tag L41 from tag-slot
    mov [rbp - 7128], r11 # store tag L432
    mov [rbp - 3472], r10 # spill L432 to slot
    jmp .L22ed_rt_format_float_native_bb225 # branch
.L22ed_rt_format_float_native_bb225:
    mov r10, 0 # assign L435
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7152], r11 # store tag L435
    mov [rbp - 3496], r10 # spill L435 to slot
    mov r10, 0 # assign L436
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7160], r11 # store tag L436
    mov [rbp - 3504], r10 # spill L436 to slot
    jmp .L22ed_rt_format_float_native_bb226 # branch
.L22ed_rt_format_float_native_bb226:
    mov r10, [rbp - 3504] # reload L436 from spill slot
    mov r11, [rbp - 3472] # reload L432 from spill slot
    mov rsi, [rbp - 3504] # reload L436 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7160] # tag L436 from tag-slot
    mov rcx, [rbp - 3472] # reload L432 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7128] # tag L432 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7168], rax # store tag L437
    mov [rbp - 3512], r10 # spill L437 to slot
    mov r10, [rbp - 3512] # reload L437 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb228 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb227 # jump -> then
.L22ed_rt_format_float_native_bb227:
    mov rsi, [rbp - 3104] # reload L386 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6760] # tag L386 from tag-slot
    mov rcx, [rbp - 3496] # reload L435 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7152] # tag L435 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 7176], rax # store tag L438
    mov [rbp - 3520], r10 # spill L438 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 3520] # reload L438 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7176] # tag L438 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 7184], rax # store tag L439
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3528], r10 # spill L439 to slot
    mov r11, [rbp - 3528] # reload L439 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 7184] # tag L439 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 3496] # reload L435 from spill slot
    mov rsi, [rbp - 3496] # reload L435 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7152] # tag L435 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7192], rax # store tag L440
    mov [rbp - 3536], r10 # spill L440 to slot
    mov r11, [rbp - 3536] # reload L440 from spill slot
    mov r10, r11 # assign L435
    mov r11, [rbp - 7192] # tag L440 from tag-slot
    mov [rbp - 7152], r11 # store tag L435
    mov [rbp - 3496], r10 # spill L435 to slot
    mov r10, [rbp - 3504] # reload L436 from spill slot
    mov rsi, [rbp - 3504] # reload L436 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7160] # tag L436 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7200], rax # store tag L441
    mov [rbp - 3544], r10 # spill L441 to slot
    mov r11, [rbp - 3544] # reload L441 from spill slot
    mov r10, r11 # assign L436
    mov r11, [rbp - 7200] # tag L441 from tag-slot
    mov [rbp - 7160], r11 # store tag L436
    mov [rbp - 3504], r10 # spill L436 to slot
    jmp .L22ed_rt_format_float_native_bb226 # branch
.L22ed_rt_format_float_native_bb228:
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 3304] # reload L411 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 4000] # tag L41 from tag-slot
    mov rcx, [rbp - 3304] # reload L411 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 6960] # tag L411 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 7208], rax # store tag L442
    mov [rbp - 3552], r10 # spill L442 to slot
    mov r11, [rbp - 3552] # reload L442 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 7208] # tag L442 from tag-slot
    mov [rbp - 4000], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L22ed_rt_format_float_native_bb229 # branch
.L22ed_rt_format_float_native_bb229:
    mov r10, [rbp - 3040] # reload L378 from spill slot
    mov rsi, [rbp - 3040] # reload L378 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6696] # tag L378 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7216], rax # store tag L443
    mov [rbp - 3560], r10 # spill L443 to slot
    mov r11, [rbp - 3560] # reload L443 from spill slot
    mov r10, r11 # assign L378
    mov r11, [rbp - 7216] # tag L443 from tag-slot
    mov [rbp - 6696], r11 # store tag L378
    mov [rbp - 3040], r10 # spill L378 to slot
    jmp .L22ed_rt_format_float_native_bb194 # branch
.L22ed_rt_format_float_native_bb230:
    mov r10, 0 # assign L446
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7240], r11 # store tag L446
    mov [rbp - 3584], r10 # spill L446 to slot
    jmp .L22ed_rt_format_float_native_bb232 # branch
.L22ed_rt_format_float_native_bb231:
    mov r10, 0 # assign L450
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 7272], r11 # store tag L450
    mov [rbp - 3616], r10 # spill L450 to slot
    jmp .L22ed_rt_format_float_native_bb235 # branch
.L22ed_rt_format_float_native_bb232:
    mov r10, [rbp - 3584] # reload L446 from spill slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov rsi, [rbp - 3584] # reload L446 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7240] # tag L446 from tag-slot
    mov rcx, [rbp - 344] # reload L41 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 4000] # tag L41 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7248], rax # store tag L447
    mov [rbp - 3592], r10 # spill L447 to slot
    mov r10, [rbp - 3592] # reload L447 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb234 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb233 # jump -> then
.L22ed_rt_format_float_native_bb233:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 7256], rax # store tag L448
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3600], r10 # spill L448 to slot
    mov r11, [rbp - 3600] # reload L448 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 7256] # tag L448 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 3584] # reload L446 from spill slot
    mov rsi, [rbp - 3584] # reload L446 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7240] # tag L446 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7264], rax # store tag L449
    mov [rbp - 3608], r10 # spill L449 to slot
    mov r11, [rbp - 3608] # reload L449 from spill slot
    mov r10, r11 # assign L446
    mov r11, [rbp - 7264] # tag L449 from tag-slot
    mov [rbp - 7240], r11 # store tag L446
    mov [rbp - 3584], r10 # spill L446 to slot
    jmp .L22ed_rt_format_float_native_bb232 # branch
.L22ed_rt_format_float_native_bb234:
    jmp .L22ed_rt_format_float_native_bb231 # branch
.L22ed_rt_format_float_native_bb235:
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 7280], r11 # store tag L451
    mov [rbp - 3624], r10 # spill L451 to slot
    mov r10, [rbp - 3616] # reload L450 from spill slot
    mov r11, [rbp - 3624] # reload L451 from spill slot
    mov rsi, [rbp - 3616] # reload L450 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7272] # tag L450 from tag-slot
    mov rcx, [rbp - 3624] # reload L451 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7280] # tag L451 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 7288], rax # store tag L452
    mov [rbp - 3632], r10 # spill L452 to slot
    mov r10, [rbp - 3632] # reload L452 from spill slot
    test r10, r10 # br_cond test
    jz .L22ed_rt_format_float_native_bb237 # jump-if-zero -> else
    jmp .L22ed_rt_format_float_native_bb236 # jump -> then
.L22ed_rt_format_float_native_bb236:
    mov rsi, [rbp - 2856] # reload L355 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 6512] # tag L355 from tag-slot
    mov rcx, [rbp - 3616] # reload L450 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7272] # tag L450 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 7296], rax # store tag L453
    mov [rbp - 3640], r10 # spill L453 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    mov rcx, [rbp - 3640] # reload L453 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 7296] # tag L453 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 7304], rax # store tag L454
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3648], r10 # spill L454 to slot
    mov r11, [rbp - 3648] # reload L454 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 7304] # tag L454 from tag-slot
    mov [rbp - 3776], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 3616] # reload L450 from spill slot
    mov rsi, [rbp - 3616] # reload L450 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 7272] # tag L450 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 7312], rax # store tag L455
    mov [rbp - 3656], r10 # spill L455 to slot
    mov r11, [rbp - 3656] # reload L455 from spill slot
    mov r10, r11 # assign L450
    mov r11, [rbp - 7312] # tag L455 from tag-slot
    mov [rbp - 7272], r11 # store tag L450
    mov [rbp - 3616], r10 # spill L450 to slot
    jmp .L22ed_rt_format_float_native_bb235 # branch
.L22ed_rt_format_float_native_bb237:
    jmp .L22ed_rt_format_float_native_bb238 # branch
.L22ed_rt_format_float_native_bb238:
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3776] # tag L13 from tag-slot
    call hexa_bytes_to_str_raw # call hexa_bytes_to_str_raw
    mov [rbp - 7320], rax # store tag L456
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 3664], r10 # spill L456 to slot
    mov rdx, [rbp - 3664] # reload L456 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 7320] # tag L456 from tag-slot
    add rsp, 7280 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",@progbits
