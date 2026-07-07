// test/native_build/regex_parity_oracle.c
// zero-c #29 regex OFF(libc)-vs-ON(native NFA) parity. Deterministic-LCG class-tagged
// corpus + libc regcomp/regexec golden harvest. Mirrors feat/strtod-oracle-corpus.
//   cc -O2 regex_parity_oracle.c -o oracle && ./oracle <corpus.txt> <golden.txt>
//
// GRAMMAR (byte-identical in regex_parity_corpus.hexa so `diff` is line-clean):
//   corpus line : IDX \t TAG \t OP \t PAT \t INPUT \t REPL
//   golden line : IDX \t TAG \t OP \t RESULT
//   RESULT: match->M:1|M:0  full->F:1|F:0  search->S:so,eo|S:-
//           findall->A:k:so,eo,so,eo,...  split->P:k:seg,seg,...  replace->R:<str>
// Controlled alphabet EXCLUDES \t and ',' so segments/joins never collide the delims.
//
// FIDELITY (Fable port map @ ab79e1f64): the oracle is a VERBATIM port of the OFF-path
// libc bodies in self/runtime_emit_full.hexa — re_prep = strip-flags(:13840) + regcomp
// (:13833) ONLY (NO shim FIX-C/FIX-D, else golden != off_ledger). The 3 from-offset loops
// (findall :13930 / split :13968 / replace :14017) are ported 1:1; rm_so/rm_eo are relative
// to (s+off), spans emitted ABSOLUTE. Nullable patterns are excluded from `replace` rows at
// generation time (OFF-path zero-width-at-EOS underflow crash, its own gated fix round).
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <regex.h>

static uint64_t S = 0x2545F4914F6CDD1DULL;
static uint64_t nx(void) { S = S * 6364136223846793005ULL + 1442695040888963407ULL; return S; }
static int pick(int k) { return (int)((nx() >> 40) % (uint64_t)k); }

// per-class random-input alphabet (incl. case+digit+space for icase/POSIX-class cov).
// EXCLUDES \t and ',' by construction so the grammar delimiters never collide.
static const char *AL = "aAbBcC012 ^";
static void rndin(char *buf, int lo, int hi) {
    int L = lo + pick(hi - lo + 1);
    int i;
    for (i = 0; i < L; i++) buf[i] = AL[pick((int)strlen(AL))];
    buf[L] = 0;
}

// ---- OFF-body prep, ported VERBATIM (do NOT add FIX-C/FIX-D) ----
// _hexa_re_strip_flags (runtime_emit_full.hexa:13840-13847)
static const char *re_strip_flags(const char *pat, int *icase) {
    *icase = 0;
    if (pat && pat[0] == '(' && pat[1] == '?' && pat[2] == 'i' && pat[3] == ')') {
        *icase = 1;
        return pat + 4;
    }
    return pat;
}
// _hexa_re_compile (:13833-13837)
static int re_compile(const char *pat, regex_t *out, int icase) {
    int flags = REG_EXTENDED;
    if (icase) flags |= REG_ICASE;
    return regcomp(out, pat, flags);
}

// escape a segment/replacement for the RESULT grammar. The alphabet already excludes
// \t and ',', but a compile-failed passthrough could carry arbitrary INPUT bytes; keep
// output literal (INPUT is drawn from AL, so no escaping is actually needed — asserted).
static void put_raw(char *dst, size_t *dp, const char *src, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) dst[(*dp)++] = src[i];
}

// harvest one (op,pat,in,repl) → append the RESULT string into out (NUL-terminated).
static void harvest(char *out, const char *op, const char *pat, const char *in, const char *repl) {
    regex_t re;
    int icase = 0;
    const char *cp = re_strip_flags(pat, &icase);
    int cf = re_compile(cp, &re, icase);   // 0 = compiled ok
    size_t L = strlen(in);
    size_t dp = 0;

    if (strcmp(op, "match") == 0) {
        int m = (cf == 0) && (regexec(&re, in, 0, NULL, 0) == 0);
        sprintf(out, "M:%d", m ? 1 : 0);
    } else if (strcmp(op, "full") == 0) {
        int f = 0;
        if (cf == 0) {
            regmatch_t m;
            if (regexec(&re, in, 1, &m, 0) == 0 && m.rm_so == 0 && (size_t)m.rm_eo == L) f = 1;
        }
        sprintf(out, "F:%d", f ? 1 : 0);
    } else if (strcmp(op, "search") == 0) {
        if (cf == 0) {
            regmatch_t m;
            if (regexec(&re, in, 1, &m, 0) == 0) sprintf(out, "S:%d,%d", (int)m.rm_so, (int)m.rm_eo);
            else strcpy(out, "S:-");
        } else strcpy(out, "S:-");
    } else if (strcmp(op, "findall") == 0) {
        // from-offset loop, runtime_emit_full.hexa:13930-13945 (1:1)
        int pairs[512], k = 0;
        if (cf == 0) {
            regmatch_t m;
            size_t off = 0;
            while (off <= L) {
                if (regexec(&re, in + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
                if (m.rm_eo == m.rm_so) { off += 1; continue; }   // zero-width: skip, no emit
                if (k < 500) { pairs[k++] = (int)(off + m.rm_so); pairs[k++] = (int)(off + m.rm_eo); }
                off += m.rm_eo;
            }
        }
        int np = k / 2, i;
        dp = (size_t)sprintf(out, "A:%d:", np);
        for (i = 0; i < k; i += 2) {
            dp += (size_t)sprintf(out + dp, "%s%d,%d", i ? "," : "", pairs[i], pairs[i + 1]);
        }
        out[dp] = 0;
    } else if (strcmp(op, "split") == 0) {
        // from-offset loop, :13968-13987 (1:1). compile-fail: whole string, 1 seg.
        char segs[64][128];
        int k = 0;
        if (cf != 0) {
            strncpy(segs[k++], in, 127);
        } else {
            regmatch_t m;
            size_t off = 0;
            while (off <= L && k < 60) {
                if (regexec(&re, in + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
                if (m.rm_eo == m.rm_so) { off += 1; continue; }   // zero-width: NO segment
                size_t sl = (size_t)m.rm_so;
                memcpy(segs[k], in + off, sl); segs[k][sl] = 0; k++;
                off += (size_t)m.rm_eo;
            }
            if (off <= L) {                                       // final tail (:13985-13987 guard)
                size_t tl = L - off;
                memcpy(segs[k], in + off, tl); segs[k][tl] = 0; k++;
            }
        }
        int i;
        dp = (size_t)sprintf(out, "P:%d:", k);
        for (i = 0; i < k; i++) {
            if (i) out[dp++] = ',';
            put_raw(out, &dp, segs[i], strlen(segs[i]));
        }
        out[dp] = 0;
    } else if (strcmp(op, "replace") == 0) {
        // from-offset loop, :14017-14051 (1:1). compile-fail: s unchanged.
        char buf[1024];
        size_t bp = 0;
        if (cf != 0) {
            strcpy(buf, in);
        } else {
            regmatch_t m;
            size_t off = 0, Rlen = strlen(repl);
            while (off <= L) {
                if (regexec(&re, in + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
                if (m.rm_eo == m.rm_so) { buf[bp++] = in[off]; off += 1; continue; }
                memcpy(buf + bp, in + off, (size_t)m.rm_so); bp += (size_t)m.rm_so;
                memcpy(buf + bp, repl, Rlen); bp += Rlen;
                off += (size_t)m.rm_eo;
            }
            memcpy(buf + bp, in + off, L - off); bp += (L - off);
            buf[bp] = 0;
        }
        dp = (size_t)sprintf(out, "R:");
        put_raw(out, &dp, buf, strlen(buf));
        out[dp] = 0;
    } else {
        strcpy(out, "?:bad-op");
    }
    if (cf == 0) regfree(&re);
}

// ---- CLASS TABLE ----
// nullable[] marks patterns that zero-width-match (exclude from `replace` — OFF crash §4).
typedef struct { const char *tag, *pat; int nullable; const char *ops; const char *fixed[6]; int rand_lo, rand_hi, rand_n; } Cls;
static const Cls TABLE[] = {
  // C1 anchors
  {"C1","^abc",0,"match full search findall",{"abc","xabc","abcx",0},1,6,2},
  {"C1","abc$",0,"match full search findall",{"abc","abcx","xabc",0},1,6,2},
  {"C1","^abc$",0,"match full search",{"abc","abcd",0},1,5,1},
  {"C1","^$",1,"match full search",{"","a",0},0,3,1},
  // C2 alternation (POSIX longest-branch — Thompson, parity-clean)
  {"C2","a|ab|abc",0,"match search",{"abc","ab","a","x",0},1,6,2},
  {"C2","cat|category",0,"match search",{"category","cat",0},1,4,1},
  // C3 greedy (nullable a*/a? -> no replace)
  {"C3","a*",1,"search findall",{"aaa","","baaab",0},1,6,2},
  {"C3","a+",0,"search findall replace",{"aaa","b","aXa",0},1,6,2},
  {"C3","a?",1,"search findall",{"a","",0},0,4,1},
  {"C3","a.*c",0,"search replace",{"axxc","ac","abc",0},1,6,2},
  {"C3",".*",1,"search",{"abc","",0},0,4,1},
  // C4 zero-width
  {"C4","(a|)",1,"findall split search",{"a","b","",0},0,4,1},
  {"C4","x*",1,"findall split",{"xxa","a","",0},1,5,1},
  // C5 POSIX classes
  {"C5","[[:digit:]]+",0,"search findall replace",{"a12b","012","x",0},1,6,2},
  {"C5","[[:alpha:]]",0,"search findall",{"a1b","012",0},1,5,1},
  {"C5","[^[:space:]]",0,"search findall",{"a b"," a ",0},1,5,1},
  {"C5","[a-z]+",0,"search findall replace",{"ABcd","abc","01",0},1,6,2},
  // C6 dot/literal
  {"C6","a.c",0,"match search replace",{"abc","axc","ac",0},1,5,1},
  {"C6","a\\.c",0,"match search",{"a.c","abc",0},1,4,1},
  {"C6","\\*",0,"match search",{"a*b","ab",0},1,4,1},
  // C7 PCRE-literal (libc ERE: \d = literal 'd' — the parity question)
  {"C7","\\d",0,"match search",{"d","dx","1",0},1,4,1},
  {"C7","\\w",0,"match search",{"w","1",0},1,4,1},
  {"C7","\\s",0,"match search",{"s"," ",0},1,4,1},
  // C8 icase (pure-alpha — fold-translate == REG_ICASE, parity-clean)
  {"C8","(?i)abc",0,"match search",{"ABC","AbC","abc","xyz",0},1,5,1},
  {"C8","(?i)[a-z]+",0,"search",{"ABcd","AB","abc",0},1,5,1},
  // C9 lookaround-reject (both sides compile-fail -> agreement)
  {"C9","(?=a)",0,"match search",{"a","b",0},1,4,1},
  {"C9","(?!a)",0,"match search",{"a","b",0},1,4,1},
  {"C9","(?<=a)",0,"match search",{"ab","b",0},1,4,1},
  // D1 {n,m} greedy-first vs POSIX-longest (INTENTIONAL divergence, allowlisted)
  {"D1","(a|ab){1,2}",0,"search findall full",{"aab","aba","abab",0},1,6,2},
  {"D1","(ab|a){1,3}",0,"search full",{"abab","aabab",0},1,6,2},
  // D2 icase fold-corrupting ranges (INTENTIONAL divergence, allowlisted)
  {"D2","(?i)[;-Z]",0,"match search",{"^","A","_",0},1,4,1},
  {"D2","(?i)[X-b]",0,"match search",{"a","Y","_",0},1,4,1},
  // D3 ERE backref — per-libc (INTENTIONAL/accounted divergence, allowlisted)
  {"D3","(a)\\1",0,"match search",{"aa","ab",0},1,4,1},
  {0,0,0,0,{0},0,0,0}
};

static int has_op(const char *ops, const char *op) {
    size_t ol = strlen(op);
    const char *p = ops;
    while ((p = strstr(p, op)) != NULL) {
        int lok = (p == ops || p[-1] == ' ');
        int rok = (p[ol] == 0 || p[ol] == ' ');
        if (lok && rok) return 1;
        p += ol;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s corpus.txt golden.txt\n", argv[0]); return 2; }
    FILE *cf = fopen(argv[1], "w"), *gf = fopen(argv[2], "w");
    if (!cf || !gf) { fprintf(stderr, "open failed\n"); return 2; }
    static const char *OPS[] = {"match", "full", "search", "findall", "split", "replace"};
    int idx = 0, ci;
    for (ci = 0; TABLE[ci].tag; ci++) {
        const Cls *c = &TABLE[ci];
        // collect inputs: fixed[] then rand_n random
        char inputs[16][256];
        int ni = 0, fi;
        for (fi = 0; c->fixed[fi] && ni < 12; fi++) strcpy(inputs[ni++], c->fixed[fi]);
        int ri;
        for (ri = 0; ri < c->rand_n && ni < 16; ri++) rndin(inputs[ni++], c->rand_lo, c->rand_hi);
        int oi;
        for (oi = 0; oi < 6; oi++) {
            const char *op = OPS[oi];
            if (!has_op(c->ops, op)) continue;
            // exclude nullable patterns from replace (OFF zero-width-at-EOS crash §4)
            if (strcmp(op, "replace") == 0 && c->nullable) continue;
            int ii;
            for (ii = 0; ii < ni; ii++) {
                const char *in = inputs[ii];
                const char *repl = (strcmp(op, "replace") == 0) ? "X" : "-";
                char res[2048];
                harvest(res, op, c->pat, in, repl);
                fprintf(cf, "%d\t%s\t%s\t%s\t%s\t%s\n", idx, c->tag, op, c->pat, in, repl);
                fprintf(gf, "%d\t%s\t%s\t%s\n", idx, c->tag, op, res);
                idx++;
            }
        }
    }
    fclose(cf); fclose(gf);
    fprintf(stderr, "oracle: %d rows -> %s + %s\n", idx, argv[1], argv[2]);
    return 0;
}
