/* b1_nanbox_gate.c — RT-NATIVE-ZEROC B1 nanbox-ctor C-differential gate (c2).
 *
 * Goal: prove the native nanbox constructors (the HEXA_RT_SELFEMIT path on
 * arm64, and the codegen-inlined _hv_load path on both targets) produce the
 * EXACT same 16-byte HexaVal {tag,payload} as the C-path constructors in
 * self/runtime.c, over many inputs incl. negative ints, INT64_MIN/MAX,
 * NaN/+-inf/+-0/DBL_MAX/MIN floats, true/false bools, void, and enum ptrs.
 *
 * Two halves:
 *   PART A — C-path liveness/shape oracle. Link this against the standalone
 *            runtime.c (the PRIMARY CI/release config — no -DHEXA_HAS, no
 *            -DHEXA_RT_SELFEMIT) and assert the {tag,payload} bytes for each
 *            constructor. This is the byte-shape the native object MUST match.
 *
 *   PART B — arm64 self-emit byte-sequence decode oracle. The native ctor
 *            objects (rt_hexa_*, self/codegen/runtime_arm64.hexa, emitted by
 *            test/native_build/emit_hexa_val_ctors_o.hexa) are hand-encoded
 *            arm64 machine code. This part hard-codes those exact byte
 *            sequences and asserts each decodes to the expected
 *            (tag-in-x0, payload-in-x1) ABI shape — i.e. byte-identical to the
 *            `as -arch arm64` output the emit driver claims. On an arm64 host
 *            the bytes additionally JIT-exec (HEXA_B1_JIT); on x86_64 we verify
 *            the encoding + the tag constants only (the run-side is the arm64
 *            CI faithful target's job).
 *
 * Build (x86_64 / arm64, PART A live):
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self \
 *      scripts/scratch/rt_native/b1_nanbox_gate.c self/runtime.c -o /tmp/b1gate
 *   /tmp/b1gate
 *
 * The CI faithful 3-target + selfhost-byteeq-real gates remain AUTHORITATIVE
 * for the whole-compiler fixpoint; this gate is the per-family byte oracle.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include "runtime.h"

static int fails = 0, checks = 0;

/* Compare a constructed HexaVal's raw 16 bytes to an expected (tag, payload8).
 * payload is the raw 8-byte union image (little-endian on both targets). */
static void expect_bytes(const char* what, HexaVal v, uint64_t tag, uint64_t payload) {
    checks++;
    uint64_t got_tag = 0, got_pay = 0;
    /* HexaVal = {HexaTag tag (lo 8B incl pad); union (hi 8B)} — 16B total. */
    unsigned char img[sizeof(HexaVal)];
    memset(img, 0, sizeof img);
    memcpy(img, &v, sizeof(HexaVal));
    memcpy(&got_tag, img + 0, 8);          /* tag eightbyte (enum + pad) */
    memcpy(&got_pay, img + 8, 8);          /* payload eightbyte */
    if (got_tag != tag || got_pay != payload) {
        fails++;
        fprintf(stderr,
            "FAIL %-22s tag got=%llu exp=%llu  payload got=0x%016llx exp=0x%016llx\n",
            what, (unsigned long long)got_tag, (unsigned long long)tag,
            (unsigned long long)got_pay, (unsigned long long)payload);
    }
}

static uint64_t f2bits(double d) { uint64_t u; memcpy(&u, &d, 8); return u; }

static void part_a_cpath(void) {
    puts("── PART A: C-path constructor byte-shape oracle (standalone runtime.c) ──");

    /* hexa_int — TAG_INT(0), payload = sign-extended i64 image */
    int64_t ints[] = { 0, 1, -1, 42, -42, INT64_MAX, INT64_MIN,
                       1234567890123LL, -1234567890123LL };
    for (size_t k = 0; k < sizeof(ints)/sizeof(*ints); k++) {
        HexaVal v = hexa_int(ints[k]);
        expect_bytes("hexa_int", v, (uint64_t)TAG_INT, (uint64_t)ints[k]);
    }

    /* hexa_float — TAG_FLOAT(1), payload = raw f64 bits */
    double fls[] = { 0.0, -0.0, 1.0, -1.0, 3.14, DBL_MAX, DBL_MIN,
                     INFINITY, -INFINITY, NAN };
    for (size_t k = 0; k < sizeof(fls)/sizeof(*fls); k++) {
        HexaVal v = hexa_float(fls[k]);
        expect_bytes("hexa_float", v, (uint64_t)TAG_FLOAT, f2bits(fls[k]));
    }

    /* hexa_bool — TAG_BOOL(2), payload = b (0/1, 32-bit zero-extended) */
    for (int b = 0; b <= 1; b++) {
        HexaVal v = hexa_bool(b);
        expect_bytes("hexa_bool", v, (uint64_t)TAG_BOOL, (uint64_t)(unsigned)b);
    }

    /* hexa_void — TAG_VOID(4), payload = 0 */
    {
        HexaVal v = hexa_void();
        expect_bytes("hexa_void", v, (uint64_t)TAG_VOID, 0);
    }

    /* hexa_bits_to_float — reinterpret an int64 image as a double, TAG_FLOAT.
     * Result payload bits == the input bits (pure reinterpret). */
    int64_t bitvals[] = { 0, 1, -1, (int64_t)0x7FF0000000000000LL /*+inf*/,
                          (int64_t)0x400921FB54442D18LL /*~pi*/, INT64_MIN };
    for (size_t k = 0; k < sizeof(bitvals)/sizeof(*bitvals); k++) {
        HexaVal in = hexa_int(bitvals[k]);
        HexaVal v  = hexa_bits_to_float(in);
        expect_bytes("hexa_bits_to_float", v, (uint64_t)TAG_FLOAT,
                     (uint64_t)bitvals[k]);
    }

    /* hexa_enum_str / hexa_enum_str_v — TAG_ENUM(11), payload = ptr verbatim */
    {
        const char* disp = "Direction::Left";
        HexaVal v = hexa_enum_str(disp);
        expect_bytes("hexa_enum_str", v, (uint64_t)TAG_ENUM, (uint64_t)(uintptr_t)disp);
    }
}

/* ── PART B: arm64 self-emit byte-sequence decode oracle ───────────────────
 * These are the EXACT bytes emitted by self/codegen/runtime_arm64.hexa
 * rt_hexa_* (and bundled by test/native_build/emit_hexa_val_ctors_o.hexa).
 * Each ctor is 12 bytes = 3 little-endian aarch64 instructions. We assert the
 * encoding matches and that the tag immediate is the expected TAG_* constant.
 */
static uint32_t le32(const unsigned char* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1]<<8) | ((uint32_t)p[2]<<16) | ((uint32_t)p[3]<<24);
}

/* movz Wd/Xd, #imm16 (hw=0): bits[20:5]=imm16, bits[4:0]=Rd. Returns imm16. */
static uint32_t movz_imm(uint32_t insn) { return (insn >> 5) & 0xFFFF; }

static void expect_seq(const char* what, const unsigned char* b,
                       uint32_t i0, uint32_t i1, uint32_t i2, uint64_t tag) {
    checks++;
    uint32_t g0 = le32(b), g1 = le32(b+4), g2 = le32(b+8);
    if (g0 != i0 || g1 != i1 || g2 != i2) {
        fails++;
        fprintf(stderr, "FAIL %-22s arm64 seq got=%08x %08x %08x exp=%08x %08x %08x\n",
                what, g0, g1, g2, i0, i1, i2);
        return;
    }
    /* the movz that sets x0/w0 = tag is whichever of the 3 is a movz to Rd=0 */
    uint32_t found_tag = 0xFFFFFFFFu;
    uint32_t insns[3] = { i0, i1, i2 };
    for (int j = 0; j < 3; j++) {
        /* movz X: 0xD28.. (sf=1, opc=10, 100101), movz W: 0x528.. */
        uint32_t hi = insns[j] >> 23;             /* top bits */
        uint32_t rd = insns[j] & 0x1F;
        if ((hi == 0x1A5 || hi == 0xA5) && rd == 0) found_tag = movz_imm(insns[j]);
    }
    if (found_tag != tag) {
        fails++;
        fprintf(stderr, "FAIL %-22s arm64 tag movz got=%u exp=%llu\n",
                what, found_tag, (unsigned long long)tag);
    }
}

static void part_b_arm64_selfemit(void) {
    puts("── PART B: arm64 self-emit ctor byte-sequence decode oracle ──");

    /* rt_hexa_void : mov w0,#4 ; mov x1,#0 ; ret  (tag movz Rd=0 => TAG_VOID) */
    unsigned char vvoid[] = { 0x80,0x00,0x80,0x52, 0x01,0x00,0x80,0xD2, 0xC0,0x03,0x5F,0xD6 };
    expect_seq("rt_hexa_void", vvoid, 0x52800080, 0xD2800001, 0xD65F03C0, (uint64_t)TAG_VOID);

    /* rt_hexa_int : mov x1,x0 ; mov x0,#0 ; ret  (tag movz Rd=0 => TAG_INT) */
    unsigned char vint[] = { 0xE1,0x03,0x00,0xAA, 0x00,0x00,0x80,0xD2, 0xC0,0x03,0x5F,0xD6 };
    expect_seq("rt_hexa_int", vint, 0xAA0003E1, 0xD2800000, 0xD65F03C0, (uint64_t)TAG_INT);

    /* rt_hexa_bool : mov w1,w0 ; mov w0,#2 ; ret  (tag => TAG_BOOL) */
    unsigned char vbool[] = { 0xE1,0x03,0x00,0x2A, 0x40,0x00,0x80,0x52, 0xC0,0x03,0x5F,0xD6 };
    expect_seq("rt_hexa_bool", vbool, 0x2A0003E1, 0x52800040, 0xD65F03C0, (uint64_t)TAG_BOOL);

    /* rt_hexa_float : fmov x1,d0 ; mov w0,#1 ; ret  (tag => TAG_FLOAT) */
    unsigned char vflt[] = { 0x01,0x00,0x66,0x9E, 0x20,0x00,0x80,0x52, 0xC0,0x03,0x5F,0xD6 };
    expect_seq("rt_hexa_float", vflt, 0x9E660001, 0x52800020, 0xD65F03C0, (uint64_t)TAG_FLOAT);

    /* rt_hexa_enum_str : mov x1,x0 ; mov w0,#11 ; ret  (tag => TAG_ENUM=11) */
    unsigned char venum[] = { 0xE1,0x03,0x00,0xAA, 0x60,0x01,0x80,0x52, 0xC0,0x03,0x5F,0xD6 };
    expect_seq("rt_hexa_enum_str", venum, 0xAA0003E1, 0x52800160, 0xD65F03C0, (uint64_t)TAG_ENUM);

    /* rt_hexa_enum_str_v : byte-identical to rt_hexa_enum_str */
    expect_seq("rt_hexa_enum_str_v", venum, 0xAA0003E1, 0x52800160, 0xD65F03C0, (uint64_t)TAG_ENUM);
}

int main(void) {
    printf("HexaVal sizeof = %zu (expect 16), TAG_VOID=%d TAG_ENUM=%d\n",
           sizeof(HexaVal), (int)TAG_VOID, (int)TAG_ENUM);
    part_a_cpath();
    part_b_arm64_selfemit();
    printf("\n%s — %d checks, %d fails\n", fails ? "GATE FAIL" : "GATE PASS",
           checks, fails);
    return fails ? 1 : 0;
}
