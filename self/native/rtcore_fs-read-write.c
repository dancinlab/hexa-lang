// self/native/rtcore_fs-read-write.c — zero-c leg-B FS-READ-WRITE SEED (link de-risk).
//
// Supplies 9 stdio-based binary file-I/O HexaVal wrappers that runtime_core.c
// externs away under HEXA_RT_CORE_FS_READ_WRITE_NATIVE (the narrow fs-read-write
// guard, NOT the broad whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE
// .o (build/rtcore_fs-read-write_native.o) and linked when
// HEXA_ZEROC_RT_CORE_FS_READ_WRITE=1, so the build LINKS these bodies from a
// standalone object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the leaf (rtcore_leaf.c, 10 HexaVal value-ctors) + arith
// (rtcore_arith.c, 6 __raw_* wrappers) de-risk to the SEED-PORTABLE file-I/O
// class — the runtime_core.c symbols whose every callee is external-linkage or a
// macro (the seed-portability rule), routing the actual byte work through raw
// libc stdio (fopen/fclose/fread/fwrite/fseek/ftell/malloc/free) and the
// EXTERNAL value ctors. It does NOT drop the .c file (runtime_core.c drop is
// all-or-nothing). Default build (flag unset) is byte-IDENTICAL: these bodies
// are not compiled and the inline #else bodies in runtime_core.c are used.
//
// SEED-PORTABILITY rule: a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro AND the fn body is emitted IDENTICALLY in every
// runtime_core.c config (so an unconditional seed .o cannot double-define a
// config-conditional body). The 9 below are clean:
//   rt_read_file          → hexa_str(ext)/hexa_str_own(ext) + stdio + malloc
//   rt_write_bytes        → hexa_bool(ext) + stdio + malloc/free (the no-seed
//                           #else fopen body — HEXA_RT_FS_NATIVE arm not built
//                           here; the seed TU compiles WITHOUT that macro)
//   rt_write_bytes_v      → + hexa_valstruct_int(ext)
//   rt_read_file_bytes    → hexa_array_new(ext)/hexa_int(ext) + stdio + malloc
//   rt_read_bytes_at      → hexa_array_new(ext)/hexa_int(ext) + stdio + malloc
//   rt_read_f32_at        → hexa_farr_zeros/hexa_farr_set(ext) + hexa_int/float(ext)
//   rt_read_f32_array_at  → hexa_farr32_zeros/hexa_farr32_set(ext) + ctors
//   rt_write_bytes_append → hexa_bool(ext) + stdio (fopen "ab")
//   rt_write_bytes_append_v → + hexa_valstruct_int(ext)
// EXPLICITLY EXCLUDED (NOT clean — config-conditional definer, not unconditional):
//   rt_fs_append_atomic / rt_fs_stat / rt_fs_rotate_if_over
//     — emitted ONLY under `#if defined(HEXA_HAS_HEXA_RT_STDLIB) &&
//       !defined(HEXA_RT_SELFEMIT)` (stage-4 failure-stubs). Under the
//       faithful/release standalone config runtime.c's own
//       `#elif !defined(HEXA_HAS_HEXA_RT_STDLIB)` arm defines them instead. An
//       unconditional seed .o defining them would double-define against that
//       arm at link → NOT seed-portable. They stay inline-C.
//
// The bodies are the EXACT same C as the runtime_core.c bodies (SSOT
// self/runtime_core_emit.hexa) — byte-faithful by construction. The callees
// (hexa_str/hexa_str_own/hexa_array_new/hexa_int/hexa_float/hexa_bool/
// hexa_valstruct_int/hexa_farr*_zeros/hexa_farr*_set) resolve from the rest of
// the link (runtime_core.c / runtime.h), exactly as the leaf/arith seeds resolve
// hexa_int/hexa_float across the .o boundary; the libc stdio symbols resolve
// from libc.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaArr / HX_STR / HX_INT / HX_FLOAT /
// HX_IS_INT / HX_IS_ARRAY / HX_TAG + TAG_* enums + the extern protos for the
// hexa_* ctors that runtime.h declares). The array macros runtime_core.c defines
// but runtime.h does NOT (HX_ARR_LEN / HX_ARR_ITEMS / HX_SET_ARR_ITEMS /
// HX_SET_ARR_LEN / HX_SET_ARR_CAP) are re-declared below with #ifndef guards,
// byte-identical to the SSOT (self/runtime_core_emit.hexa / runtime_core.c
// lines 1173/1174/1186/1187/1188), so the seed TU compiles from runtime.h alone
// — same value, no semantic change. The two ctors runtime.h omits a proto for
// (hexa_str_own / hexa_valstruct_int) are extern-declared below.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifndef HX_ARR_LEN
#define HX_ARR_LEN(v)   ((v).arr_ptr->len)
#endif
#ifndef HX_ARR_ITEMS
#define HX_ARR_ITEMS(v) ((v).arr_ptr->items)
#endif
#ifndef HX_SET_ARR_ITEMS
#define HX_SET_ARR_ITEMS(v, p) ((v).arr_ptr->items = (p))
#endif
#ifndef HX_SET_ARR_LEN
#define HX_SET_ARR_LEN(v, n)   ((v).arr_ptr->len = (n))
#endif
#ifndef HX_SET_ARR_CAP
#define HX_SET_ARR_CAP(v, n)   ((v).arr_ptr->cap = (n))
#endif

// runtime.h declares no proto for these two external ctors — declare them here
// (byte-identical signatures to their runtime_core.c definitions).
extern HexaVal hexa_str_own(char* s);
extern HexaVal hexa_valstruct_int(HexaVal v);

HexaVal rt_read_file(HexaVal path) {
    FILE* f = fopen(HX_STR(path), "rb");
    if (!f) return hexa_str("");
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char* buf = malloc(len + 1);
    fread(buf, 1, len, f);
    buf[len] = 0;
    fclose(f);
    return hexa_str_own(buf);
}

HexaVal rt_write_bytes(HexaVal path, HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_bool(0);
    int len = HX_ARR_LEN(arr);
    FILE* f = fopen(HX_STR(path), "wb");
    if (!f) return hexa_bool(0);
    if (len > 0) {
        unsigned char* buf = (unsigned char*)malloc(len);
        HexaVal* items = HX_ARR_ITEMS(arr);
        for (int i = 0; i < len; i++) {
            int64_t v = HX_IS_INT(items[i]) ? HX_INT(items[i]) : (int64_t)HX_FLOAT(items[i]);
            buf[i] = (unsigned char)(v & 0xFF);
        }
        fwrite(buf, 1, len, f);
        free(buf);
    }
    fclose(f);
    return hexa_bool(1);
}

HexaVal rt_write_bytes_v(HexaVal path, HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_bool(0);
    int len = HX_ARR_LEN(arr);
    FILE* f = fopen(HX_STR(path), "wb");
    if (!f) return hexa_bool(0);
    if (len > 0) {
        unsigned char* buf = (unsigned char*)malloc(len);
        HexaVal* items = HX_ARR_ITEMS(arr);
        for (int i = 0; i < len; i++) {
            HexaVal item = items[i];
            int64_t v = 0;
            if (HX_IS_INT(item)) {
                v = HX_INT(item);
            } else if (HX_TAG(item) == TAG_FLOAT) {
                v = (int64_t)HX_FLOAT(item);
            } else if (HX_TAG(item) == TAG_VALSTRUCT) {
                HexaVal iv = hexa_valstruct_int(item);
                if (HX_IS_INT(iv)) {
                    v = HX_INT(iv);
                } else if (HX_TAG(iv) == TAG_FLOAT) {
                    v = (int64_t)HX_FLOAT(iv);
                }
            }
            buf[i] = (unsigned char)(v & 0xFF);
        }
        fwrite(buf, 1, len, f);
        free(buf);
    }
    fclose(f);
    return hexa_bool(1);
}

HexaVal rt_read_file_bytes(HexaVal path) {
    FILE* f = fopen(HX_STR(path), "rb");
    if (!f) return hexa_array_new();
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len < 0) { fclose(f); return hexa_array_new(); }
    int64_t n = (int64_t)len;
    unsigned char* buf = (unsigned char*)malloc((size_t)n);
    if (n > 0 && !buf) { fclose(f); return hexa_array_new(); }
    int64_t got = (int64_t)fread(buf, 1, (size_t)n, f);  // hxlcl_fread loops internally
    fclose(f);
    n = got;
    HexaVal arr = hexa_array_new();
    if (n > 0) {
        HexaVal* items = (HexaVal*)malloc(sizeof(HexaVal) * (size_t)n);
        if (!items) { free(buf); return arr; }
        HX_SET_ARR_ITEMS(arr, items);
        HX_SET_ARR_CAP(arr, n);
        HX_SET_ARR_LEN(arr, n);
        for (int64_t i = 0; i < n; i++) {
            items[i] = hexa_int((int64_t)buf[i]);
        }
    }
    free(buf);
    return arr;
}

HexaVal rt_read_bytes_at(HexaVal path, HexaVal offset, HexaVal nbytes) {
    int64_t off = HX_IS_INT(offset) ? HX_INT(offset)
                : (HX_TAG(offset) == TAG_FLOAT ? (int64_t)HX_FLOAT(offset) : 0);
    int64_t req = HX_IS_INT(nbytes) ? HX_INT(nbytes)
                : (HX_TAG(nbytes) == TAG_FLOAT ? (int64_t)HX_FLOAT(nbytes) : 0);
    if (off < 0 || req <= 0) return hexa_array_new();
    FILE* f = fopen(HX_STR(path), "rb");
    if (!f) return hexa_array_new();
    if (fseek(f, (long)off, SEEK_SET) != 0) { fclose(f); return hexa_array_new(); }
    unsigned char* buf = (unsigned char*)malloc((size_t)req);
    if (!buf) { fclose(f); return hexa_array_new(); }
    int64_t got = (int64_t)fread(buf, 1, (size_t)req, f);
    fclose(f);
    HexaVal arr = hexa_array_new();
    if (got > 0) {
        HX_SET_ARR_ITEMS(arr, (HexaVal*)malloc(sizeof(HexaVal) * (size_t)got));
        HX_SET_ARR_CAP(arr, got);
        HX_SET_ARR_LEN(arr, got);
        HexaVal* items = HX_ARR_ITEMS(arr);
        for (int64_t i = 0; i < got; i++) {
            items[i] = hexa_int((int64_t)buf[i]);
        }
    }
    free(buf);
    return arr;
}

HexaVal rt_read_f32_at(HexaVal path, HexaVal byte_off, HexaVal n_floats) {
    int64_t off = HX_IS_INT(byte_off) ? HX_INT(byte_off)
                : (HX_TAG(byte_off) == TAG_FLOAT ? (int64_t)HX_FLOAT(byte_off) : -1);
    int64_t nf  = HX_IS_INT(n_floats) ? HX_INT(n_floats)
                : (HX_TAG(n_floats) == TAG_FLOAT ? (int64_t)HX_FLOAT(n_floats) : 0);
    if (off < 0 || nf <= 0) return hexa_farr_zeros(hexa_int(0));
    FILE* f = fopen(HX_STR(path), "rb");
    if (!f) return hexa_farr_zeros(hexa_int(0));
    if (fseek(f, (long)off, SEEK_SET) != 0) { fclose(f); return hexa_farr_zeros(hexa_int(0)); }
    HexaVal fh = hexa_farr_zeros(hexa_int(nf));
    int64_t hid = HX_INT(fh);
    const int64_t CHUNK_FLOATS = 2097152;  // 2M floats = 8 MB per chunk
    unsigned char* cbuf = (unsigned char*)malloc((size_t)CHUNK_FLOATS * 4);
    if (!cbuf) { fclose(f); return fh; }
    int64_t done = 0;
    while (done < nf) {
        int64_t want = nf - done;
        if (want > CHUNK_FLOATS) want = CHUNK_FLOATS;
        int64_t got_bytes = (int64_t)fread(cbuf, 1, (size_t)(want * 4), f);
        int64_t got_floats = got_bytes / 4;  // ignore a trailing partial f32
        for (int64_t i = 0; i < got_floats; i++) {
            float fv;
            memcpy(&fv, cbuf + i * 4, 4);
            hexa_farr_set(fh, hexa_int(done + i), hexa_float((double)fv));
        }
        done += got_floats;
        if (got_floats < want) break;  // EOF / short read
    }
    (void)hid;
    free(cbuf);
    fclose(f);
    return fh;
}

HexaVal rt_read_f32_array_at(HexaVal path, HexaVal byte_off, HexaVal n_floats) {
    int64_t off = HX_IS_INT(byte_off) ? HX_INT(byte_off)
                : (HX_TAG(byte_off) == TAG_FLOAT ? (int64_t)HX_FLOAT(byte_off) : -1);
    int64_t nf  = HX_IS_INT(n_floats) ? HX_INT(n_floats)
                : (HX_TAG(n_floats) == TAG_FLOAT ? (int64_t)HX_FLOAT(n_floats) : 0);
    if (off < 0 || nf <= 0) return hexa_farr32_zeros(hexa_int(0));
    FILE* f = fopen(HX_STR(path), "rb");
    if (!f) return hexa_farr32_zeros(hexa_int(0));
    if (fseek(f, (long)off, SEEK_SET) != 0) { fclose(f); return hexa_farr32_zeros(hexa_int(0)); }
    HexaVal fh = hexa_farr32_zeros(hexa_int(nf));
    const int64_t CHUNK_FLOATS = 2097152;  // 2M floats = 8 MB per chunk
    unsigned char* cbuf = (unsigned char*)malloc((size_t)CHUNK_FLOATS * 4);
    if (!cbuf) { fclose(f); return fh; }
    int64_t done = 0;
    while (done < nf) {
        int64_t want = nf - done;
        if (want > CHUNK_FLOATS) want = CHUNK_FLOATS;
        int64_t got_bytes = (int64_t)fread(cbuf, 1, (size_t)(want * 4), f);
        int64_t got_floats = got_bytes / 4;  // ignore a trailing partial f32
        for (int64_t i = 0; i < got_floats; i++) {
            float fv;
            memcpy(&fv, cbuf + i * 4, 4);
            hexa_farr32_set(fh, hexa_int(done + i), hexa_float((double)fv));
        }
        done += got_floats;
        if (got_floats < want) break;  // EOF / short read
    }
    free(cbuf);
    fclose(f);
    return fh;
}

HexaVal rt_write_bytes_append(HexaVal path, HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_bool(0);
    int len = HX_ARR_LEN(arr);
    FILE* f = fopen(HX_STR(path), "ab");
    if (!f) return hexa_bool(0);
    if (len > 0) {
        unsigned char* buf = (unsigned char*)malloc(len);
        HexaVal* items = HX_ARR_ITEMS(arr);
        for (int i = 0; i < len; i++) {
            int64_t v = HX_IS_INT(items[i]) ? HX_INT(items[i]) : (int64_t)HX_FLOAT(items[i]);
            buf[i] = (unsigned char)(v & 0xFF);
        }
        fwrite(buf, 1, len, f);
        free(buf);
    }
    fclose(f);
    return hexa_bool(1);
}

HexaVal rt_write_bytes_append_v(HexaVal path, HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_bool(0);
    int len = HX_ARR_LEN(arr);
    FILE* f = fopen(HX_STR(path), "ab");
    if (!f) return hexa_bool(0);
    if (len > 0) {
        unsigned char* buf = (unsigned char*)malloc(len);
        HexaVal* items = HX_ARR_ITEMS(arr);
        for (int i = 0; i < len; i++) {
            HexaVal item = items[i];
            int64_t v = 0;
            if (HX_IS_INT(item)) {
                v = HX_INT(item);
            } else if (HX_TAG(item) == TAG_FLOAT) {
                v = (int64_t)HX_FLOAT(item);
            } else if (HX_TAG(item) == TAG_VALSTRUCT) {
                HexaVal iv = hexa_valstruct_int(item);
                if (HX_IS_INT(iv)) {
                    v = HX_INT(iv);
                } else if (HX_TAG(iv) == TAG_FLOAT) {
                    v = (int64_t)HX_FLOAT(iv);
                }
            }
            buf[i] = (unsigned char)(v & 0xFF);
        }
        fwrite(buf, 1, len, f);
        free(buf);
    }
    fclose(f);
    return hexa_bool(1);
}
