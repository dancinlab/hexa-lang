/* float_dtoa_shortest_exact_gate.c — R1b EXACT-parser differential oracle.
 * @state-ok: sibling of float_dtoa_shortest_gate.c; regenerable C differential
 * gate kept beside its peers in rt_native. This is the PRE-FLIP gate for
 * HEXA_RT_NUM_PARSE_FLOAT_EXACT (the flip stays a separate held PR).
 *
 * float_dtoa_shortest_gate.c checks the round-trip with rt_parse_float_native
 * (Clinger, sentinel->strtod) — it does NOT exercise rt_str_parse_float_exact,
 * the parser the EXACT-substituted shipping path uses (site A
 * self/runtime_emit_full.hexa:14574, design edits B/C runtime_core_emit.hexa
 * :8030/:8043). This gate mirrors site A's native round-trip EXACTLY, using
 * rt_str_parse_float_exact as the value checker over the full finite corpus,
 * and asserts 0-diff vs the C snprintf %.*g + strtod default on all 3 targets.
 *
 * Build (opt-in; pool only — mini is git/gh/read):
 *   aprime_cc _drv.hexa --emit=obj --target=<T> -o num_float_core.o \
 *       stdlib/runtime/num_float_core.hexa
 *   aprime_cc _drv.hexa --emit=obj --target=<T> -o float_parse_exact.o \
 *       stdlib/runtime/float_parse_exact.hexa
 *   clang -O2 -std=gnu11 float_dtoa_shortest_exact_gate.c num_float_core.o \
 *       float_parse_exact.o ~/.hx/bin/build/runtime.a -lm -o g && ./g
 *   (<T> in x86_64-linux-gnu | aarch64-linux-gnu | arm64-apple-darwin)
 * Exit 26 = full pass. 1 = a byte / decline / value divergence.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; char* s; void* p; }; } HexaVal;
#define HX_TAG(v)   ((v).tag)
#define HX_STR(v)   ((v).s)
#define HX_FLOAT(v) ((v).f)

/* the two seeds the EXACT shipping path composes (site A) */
extern HexaVal rt_format_float_native(HexaVal v, HexaVal sig);
extern HexaVal rt_str_parse_float_exact(HexaVal s);   /* NOT rt_parse_float_native */

static long fails=0, declines=0, parse_diff=0, total=0;

static HexaVal hxf(double d){ HexaVal v; v.tag=TAG_FLOAT; v.f=d; return v; }
static HexaVal hxi(int64_t n){ HexaVal v; v.tag=TAG_INT; v.i=n; return v; }
static HexaVal hxs(char* p){ HexaVal v; v.tag=TAG_STR; v.s=p; return v; }
static double frombits(uint64_t u){ double d; memcpy(&d,&u,8); return d; }
static uint64_t bits(double d){ uint64_t u; memcpy(&u,&d,8); return u; }

/* C reference = site A #else (runtime_emit_full.hexa:14590-14594): the canonical
 * default byte target. Loop 1..16 then explicit 17, matching the shipping shape. */
static void cshortest(double f, char* out, size_t cap){
    for(int p=1;p<17;p++){
        snprintf(out,cap,"%.*g",p,f);
        if(strtod(out,NULL)==f) return;
    }
    snprintf(out,cap,"%.17g",f);
}

/* EXACT native arm = faithful mirror of site A (runtime_emit_full.hexa:14571-14588).
 * Selection uses the EXACT parser's returned value; the per-candidate cross-check
 * IS the differential oracle the review requires. finite==1 gates the decline
 * assertion (inf/nan never reach _shortest_double; the exact parser declines on
 * them by design, float_parse_exact.hexa:373/:395/:403). */
static void natshortest_exact(double f, char* out, size_t cap, int finite){
    uint64_t fb = bits(f);
    for(int p=1;p<17;p++){
        HexaVal r = rt_format_float_native(hxf(f), hxi(p));
        if(HX_TAG(r)!=TAG_STR || !HX_STR(r)) break;
        HexaVal pv = rt_str_parse_float_exact(r);
        /* ORACLE 1 — never-decline on a native %g candidate (finite only) */
        if(finite && HX_TAG(pv)!=TAG_FLOAT){
            declines++;
            if(declines<=40) fprintf(stderr,"[exact] DECLINE on %%g cand \"%s\" (f bits=0x%016llx)\n",
                                     HX_STR(r),(unsigned long long)fb);
        }
        /* ORACLE 2 — exact value == strtod value on that same candidate string */
        if(HX_TAG(pv)==TAG_FLOAT){
            double sd = strtod(HX_STR(r),NULL);
            if(bits(HX_FLOAT(pv))!=bits(sd)){
                parse_diff++;
                if(parse_diff<=40) fprintf(stderr,"[exact] VALUE cand=\"%s\" exact=0x%016llx strtod=0x%016llx\n",
                    HX_STR(r),(unsigned long long)bits(HX_FLOAT(pv)),(unsigned long long)bits(sd));
            }
            if(bits(HX_FLOAT(pv))==fb){ snprintf(out,cap,"%s",HX_STR(r)); return; }
        }
    }
    { HexaVal r = rt_format_float_native(hxf(f), hxi(17));
      if(HX_TAG(r)==TAG_STR && HX_STR(r)){ snprintf(out,cap,"%s",HX_STR(r)); return; } }
    snprintf(out,cap,"%.17g",f);
}

static void chk(double d){
    char cref[64], cnat[64];
    int finite = isfinite(d);
    cshortest(d,cref,sizeof cref);
    natshortest_exact(d,cnat,sizeof cnat,finite);
    total++;
    /* ORACLE 3 — final selected string byte-identical to the C default path */
    if(strcmp(cref,cnat)){
        fails++;
        if(fails<=40) fprintf(stderr,"[exact] STRING bits=0x%016llx exact=\"%s\" cref=\"%s\"\n",
                              (unsigned long long)bits(d),cnat,cref);
    }
}

int main(void){
    if(sizeof(HexaVal)!=16){ fprintf(stderr,"sizeof(HexaVal)!=16\n"); return 2; }
    /* corpus IDENTICAL to float_dtoa_shortest_gate.c (apples-to-apples full finite corpus) */
    double reps[] = {
        0.0,-0.0,0.5,-0.5,0.25,0.125,2.5,3.5,
        0.1,0.2,0.3,0.30000000000000004,1.0/3.0,
        1.0,-1.0,42.0,100.0,3.0,9999.0,
        1e21,1e-7,1e308,1e-308,1e22,1e-22,1e23,1e-23,
        1.7976931348623157e308,2.2250738585072014e-308,
        9007199254740992.0,9007199254740994.0,
        123.456,-123.456,12345.6789,6.022e23,6.626e-34,
    };
    for(size_t k=0;k<sizeof reps/sizeof reps[0];k++) chk(reps[k]);
    /* specials — format-only (finite=0 => decline assertion skipped) */
    chk(frombits(0x7FF0000000000000ULL)); chk(frombits(0xFFF0000000000000ULL));
    chk(frombits(0x7FF8000000000000ULL)); chk(frombits(0xFFF8000000000000ULL));
    /* finite boundaries — subnormal path (float_parse_exact.hexa:465-478) + tie path (:451/:470) */
    chk(frombits(0x0000000000000001ULL)); chk(frombits(0x000FFFFFFFFFFFFFULL));
    chk(frombits(0x0010000000000000ULL)); chk(frombits(0x7FEFFFFFFFFFFFFFULL));
    /* deterministic full-bit-space sweep (xorshift64, 2,000,000) — exercises round-half-even ties */
    uint64_t st=0x243F6A8885A308D3ULL;
    for(long n=0;n<2000000;n++){ st^=st<<13; st^=st>>7; st^=st<<17; chk(frombits(st)); }
    /* dense small ints + simple decimals (low-p shortest selection) */
    for(int n=-100000;n<=100000;n++) chk((double)n);
    for(int n=1;n<5000;n++){ chk(n/7.0); chk(n/3.0); chk(n*1.0/1000.0); }

    long bad = fails+declines+parse_diff;
    printf("[float_dtoa_shortest_exact] %s — total=%ld string_fails=%ld declines=%ld value_diff=%ld "
           "(EXACT-parser round-trip vs C snprintf%%.*g+strtod byte-id)\n",
           bad?"FAIL":"PASS", total, fails, declines, parse_diff);
    return bad?1:26;
}
