/* self/native/crypto_sodium.c -- libsodium bindings for SSH crypto.
 *
 * Included from self/runtime.c via `#include "native/crypto_sodium.c"`.
 * NOT a standalone TU.
 *
 * Symbols exported (codegen direct-emit):
 *   hexa_sha512(data:[int])                        -> [int] 64-byte digest
 *   hexa_ed25519_keypair()                          -> map { pub: [int], priv: [int] }
 *   hexa_ed25519_sign(priv:[int], msg:[int])        -> [int] 64-byte signature
 *   hexa_ed25519_verify(pub:[int], msg:[int], sig:[int]) -> bool
 *   hexa_x25519_keypair()                            -> map { pub: [int], priv: [int] }
 *   hexa_x25519_scalarmult(scalar:[int], point:[int]) -> [int] 32-byte shared
 *   hexa_chacha20_poly1305_encrypt(key, nonce, aad, plaintext) -> [int] ciphertext||tag
 *   hexa_chacha20_poly1305_decrypt(key, nonce, aad, ciphertext_tag) -> [int] | { error }
 *
 * Linking: -lsodium. cmd_build adds it automatically when libsodium
 * is detected via pkg-config; on hosts without libsodium, the
 * builtins return an empty array / error map (caller should not
 * have called them — guarded by has_libsodium()).
 *
 * RFC: incoming/patches/stdlib-ssh-client.md prereq (crypto suite).
 */

#ifdef HEXA_HAS_LIBSODIUM
#include <sodium.h>
#endif

static int _libsodium_inited = 0;
static int _libsodium_ok = 0;

static int _ensure_sodium(void) {
#ifdef HEXA_HAS_LIBSODIUM
    if (_libsodium_inited) return _libsodium_ok;
    _libsodium_inited = 1;
    _libsodium_ok = (sodium_init() >= 0) ? 1 : 0;
    return _libsodium_ok;
#else
    return 0;
#endif
}

HexaVal hexa_libsodium_available(void) {
    return hexa_bool(_ensure_sodium());
}

/* Helper: copy a hexa [int] array of byte values into a fresh
 * unsigned char* buffer. Caller frees. Returns NULL + sets *err on
 * non-array input. */
static unsigned char* _arr_to_bytes(HexaVal arr, size_t* out_len) {
    *out_len = 0;
    if (!HX_IS_ARRAY(arr)) return NULL;
    int n = HX_ARR_LEN(arr);
    if (n < 0) return NULL;
    unsigned char* buf = (unsigned char*)malloc((size_t)n + 1);
    if (!buf) return NULL;
    for (int i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(arr)[i];
        long b = HX_IS_INT(v) ? (long)HX_INT(v) : 0;
        buf[i] = (unsigned char)(b & 0xff);
    }
    *out_len = (size_t)n;
    return buf;
}

/* Convert C bytes -> hexa [int] of length n. */
static HexaVal _bytes_to_arr(const unsigned char* buf, size_t n) {
    HexaVal out = hexa_array_new();
    for (size_t i = 0; i < n; i++) {
        out = hexa_array_push(out, hexa_int((int64_t)buf[i]));
    }
    return out;
}

static HexaVal _crypto_error(const char* msg) {
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "error", hexa_str(msg));
    return m;
}

/* SHA-512 */
HexaVal hexa_sha512(HexaVal data_val) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t n = 0;
    unsigned char* in = _arr_to_bytes(data_val, &n);
    if (!in) return _crypto_error("sha512: bad input");
    unsigned char out[crypto_hash_sha512_BYTES];
    crypto_hash_sha512(out, in, n);
    free(in);
    return _bytes_to_arr(out, crypto_hash_sha512_BYTES);
#else
    (void)data_val;
    return _crypto_error("libsodium not linked into this build");
#endif
}

/* SHA-256 over byte array (needed for SSH curve25519-sha256 KEX
 * exchange-hash). The existing `hexa_sha256` in exec_argv_sha256.c
 * takes a string and returns a hex-string — kept for that surface;
 * this one is the raw bytes→bytes flavour. */
HexaVal hexa_sha256_bytes(HexaVal data_val) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t n = 0;
    unsigned char* in = _arr_to_bytes(data_val, &n);
    if (!in) return _crypto_error("sha256_bytes: bad input");
    unsigned char out[crypto_hash_sha256_BYTES];
    crypto_hash_sha256(out, in, n);
    free(in);
    return _bytes_to_arr(out, crypto_hash_sha256_BYTES);
#else
    (void)data_val;
    return _crypto_error("libsodium not linked into this build");
#endif
}

/* ed25519 key-pair generation */
HexaVal hexa_ed25519_keypair(void) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    unsigned char pk[crypto_sign_ed25519_PUBLICKEYBYTES];
    unsigned char sk[crypto_sign_ed25519_SECRETKEYBYTES];
    crypto_sign_ed25519_keypair(pk, sk);
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "pub",  _bytes_to_arr(pk, sizeof(pk)));
    hexa_map_set(m, "priv", _bytes_to_arr(sk, sizeof(sk)));
    return m;
#else
    return _crypto_error("libsodium not linked");
#endif
}

/* ed25519 sign: priv is the 64-byte secret key (sodium layout), msg is
 * the message bytes. Returns 64-byte signature. */
HexaVal hexa_ed25519_sign(HexaVal priv_val, HexaVal msg_val) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t priv_n = 0;
    size_t msg_n = 0;
    unsigned char* priv = _arr_to_bytes(priv_val, &priv_n);
    unsigned char* msg  = _arr_to_bytes(msg_val, &msg_n);
    if (!priv || priv_n != crypto_sign_ed25519_SECRETKEYBYTES) {
        if (priv) free(priv); if (msg) free(msg);
        return _crypto_error("ed25519_sign: privkey must be 64 bytes (sodium layout)");
    }
    if (!msg) { free(priv); return _crypto_error("ed25519_sign: bad msg"); }
    unsigned char sig[crypto_sign_ed25519_BYTES];
    unsigned long long sig_len = 0;
    int rc = crypto_sign_ed25519_detached(sig, &sig_len, msg, msg_n, priv);
    free(priv); free(msg);
    if (rc != 0) return _crypto_error("ed25519_sign failed");
    return _bytes_to_arr(sig, (size_t)sig_len);
#else
    (void)priv_val; (void)msg_val;
    return _crypto_error("libsodium not linked");
#endif
}

/* ed25519 verify: pub is 32-byte public key, returns bool. */
HexaVal hexa_ed25519_verify(HexaVal pub_val, HexaVal msg_val, HexaVal sig_val) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return hexa_bool(0);
    size_t pn = 0, mn = 0, sn = 0;
    unsigned char* pub = _arr_to_bytes(pub_val, &pn);
    unsigned char* msg = _arr_to_bytes(msg_val, &mn);
    unsigned char* sig = _arr_to_bytes(sig_val, &sn);
    int ok = 0;
    if (pub && pn == crypto_sign_ed25519_PUBLICKEYBYTES &&
        sig && sn == crypto_sign_ed25519_BYTES && msg) {
        ok = (crypto_sign_ed25519_verify_detached(sig, msg, mn, pub) == 0);
    }
    if (pub) free(pub); if (msg) free(msg); if (sig) free(sig);
    return hexa_bool(ok);
#else
    (void)pub_val; (void)msg_val; (void)sig_val;
    return hexa_bool(0);
#endif
}

/* X25519 keypair (Curve25519 in DH-form). */
HexaVal hexa_x25519_keypair(void) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    unsigned char pk[crypto_scalarmult_curve25519_BYTES];
    unsigned char sk[crypto_scalarmult_curve25519_SCALARBYTES];
    randombytes_buf(sk, sizeof(sk));
    crypto_scalarmult_curve25519_base(pk, sk);
    HexaVal m = hexa_map_new();
    hexa_map_set(m, "pub",  _bytes_to_arr(pk, sizeof(pk)));
    hexa_map_set(m, "priv", _bytes_to_arr(sk, sizeof(sk)));
    return m;
#else
    return _crypto_error("libsodium not linked");
#endif
}

/* X25519 scalar multiplication (DH shared secret). */
HexaVal hexa_x25519_scalarmult(HexaVal scalar_val, HexaVal point_val) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t sn = 0, pn = 0;
    unsigned char* sc = _arr_to_bytes(scalar_val, &sn);
    unsigned char* pt = _arr_to_bytes(point_val,  &pn);
    if (!sc || sn != crypto_scalarmult_curve25519_SCALARBYTES ||
        !pt || pn != crypto_scalarmult_curve25519_BYTES) {
        if (sc) free(sc); if (pt) free(pt);
        return _crypto_error("x25519: scalar+point must be 32 bytes each");
    }
    unsigned char out[crypto_scalarmult_curve25519_BYTES];
    int rc = crypto_scalarmult_curve25519(out, sc, pt);
    free(sc); free(pt);
    if (rc != 0) return _crypto_error("x25519_scalarmult: weak point");
    return _bytes_to_arr(out, sizeof(out));
#else
    (void)scalar_val; (void)point_val;
    return _crypto_error("libsodium not linked");
#endif
}

/* ChaCha20 keystream XOR (no Poly1305). Used by SSH's
 * chacha20-poly1305@openssh.com to encrypt the 4-byte packet_length
 * header with a separate key from the payload. Nonce is 8 bytes
 * (SSH sequence number, big-endian), key is 32 bytes. */
HexaVal hexa_chacha20_xor(HexaVal key_v, HexaVal nonce_v, HexaVal data_v) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t kn = 0, nn = 0, dn = 0;
    unsigned char* k = _arr_to_bytes(key_v,   &kn);
    unsigned char* n = _arr_to_bytes(nonce_v, &nn);
    unsigned char* d = _arr_to_bytes(data_v,  &dn);
    if (!k || kn != crypto_stream_chacha20_KEYBYTES ||
        !n || nn != crypto_stream_chacha20_NONCEBYTES ||
        !d) {
        if (k) free(k); if (n) free(n); if (d) free(d);
        return _crypto_error("chacha20_xor: key=32 nonce=8 required");
    }
    unsigned char* out = (unsigned char*)malloc(dn);
    int rc = crypto_stream_chacha20_xor(out, d, dn, n, k);
    HexaVal res;
    if (rc == 0) { res = _bytes_to_arr(out, dn); }
    else { res = _crypto_error("chacha20_xor failed"); }
    free(k); free(n); free(d); free(out);
    return res;
#else
    (void)key_v; (void)nonce_v; (void)data_v;
    return _crypto_error("libsodium not linked");
#endif
}

/* Poly1305 one-shot MAC. Used for SSH chacha20-poly1305@openssh.com
 * separately from the AEAD wrapper. key = 32 bytes, msg = any. */
HexaVal hexa_poly1305_onetimeauth(HexaVal key_v, HexaVal msg_v) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t kn = 0, mn = 0;
    unsigned char* k = _arr_to_bytes(key_v, &kn);
    unsigned char* m = _arr_to_bytes(msg_v, &mn);
    if (!k || kn != crypto_onetimeauth_poly1305_KEYBYTES) {
        if (k) free(k); if (m) free(m);
        return _crypto_error("poly1305: key must be 32 bytes");
    }
    unsigned char tag[crypto_onetimeauth_poly1305_BYTES];
    crypto_onetimeauth_poly1305(tag, m, mn, k);
    free(k); if (m) free(m);
    return _bytes_to_arr(tag, sizeof(tag));
#else
    (void)key_v; (void)msg_v;
    return _crypto_error("libsodium not linked");
#endif
}

/* ChaCha20-Poly1305 IETF AEAD encrypt.
 *   key: 32 bytes  nonce: 12 bytes  aad: any  plaintext: any
 *   Returns ciphertext || 16-byte tag.
 */
HexaVal hexa_chacha20_poly1305_encrypt(HexaVal key_v, HexaVal nonce_v,
                                       HexaVal aad_v, HexaVal pt_v) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t kn = 0, nn = 0, an = 0, pn = 0;
    unsigned char* k = _arr_to_bytes(key_v,   &kn);
    unsigned char* n = _arr_to_bytes(nonce_v, &nn);
    unsigned char* a = _arr_to_bytes(aad_v,   &an);
    unsigned char* p = _arr_to_bytes(pt_v,    &pn);
    if (!k || kn != crypto_aead_chacha20poly1305_ietf_KEYBYTES ||
        !n || nn != crypto_aead_chacha20poly1305_ietf_NPUBBYTES) {
        if (k) free(k); if (n) free(n); if (a) free(a); if (p) free(p);
        return _crypto_error("chacha20poly1305: key/nonce wrong length");
    }
    unsigned char* ct = (unsigned char*)malloc(pn + crypto_aead_chacha20poly1305_ietf_ABYTES);
    unsigned long long ct_len = 0;
    int rc = crypto_aead_chacha20poly1305_ietf_encrypt(
        ct, &ct_len, p, pn, a, an, NULL, n, k);
    HexaVal out;
    if (rc == 0) { out = _bytes_to_arr(ct, (size_t)ct_len); }
    else { out = _crypto_error("chacha20poly1305 encrypt failed"); }
    free(k); free(n); if (a) free(a); if (p) free(p); free(ct);
    return out;
#else
    (void)key_v; (void)nonce_v; (void)aad_v; (void)pt_v;
    return _crypto_error("libsodium not linked");
#endif
}

/* ChaCha20-Poly1305 IETF AEAD decrypt + tag verify.
 *   Returns plaintext bytes on success, or { error } on tag mismatch / bad input.
 */
HexaVal hexa_chacha20_poly1305_decrypt(HexaVal key_v, HexaVal nonce_v,
                                       HexaVal aad_v, HexaVal ct_v) {
#ifdef HEXA_HAS_LIBSODIUM
    if (!_ensure_sodium()) return _crypto_error("libsodium init failed");
    size_t kn = 0, nn = 0, an = 0, cn = 0;
    unsigned char* k = _arr_to_bytes(key_v,   &kn);
    unsigned char* n = _arr_to_bytes(nonce_v, &nn);
    unsigned char* a = _arr_to_bytes(aad_v,   &an);
    unsigned char* c = _arr_to_bytes(ct_v,    &cn);
    if (!k || kn != crypto_aead_chacha20poly1305_ietf_KEYBYTES ||
        !n || nn != crypto_aead_chacha20poly1305_ietf_NPUBBYTES ||
        !c || cn < crypto_aead_chacha20poly1305_ietf_ABYTES) {
        if (k) free(k); if (n) free(n); if (a) free(a); if (c) free(c);
        return _crypto_error("chacha20poly1305: bad inputs");
    }
    unsigned char* pt = (unsigned char*)malloc(cn);
    unsigned long long pt_len = 0;
    int rc = crypto_aead_chacha20poly1305_ietf_decrypt(
        pt, &pt_len, NULL, c, cn, a, an, n, k);
    HexaVal out;
    if (rc == 0) { out = _bytes_to_arr(pt, (size_t)pt_len); }
    else { out = _crypto_error("chacha20poly1305 decrypt failed (tag mismatch?)"); }
    free(k); free(n); if (a) free(a); free(c); free(pt);
    return out;
#else
    (void)key_v; (void)nonce_v; (void)aad_v; (void)ct_v;
    return _crypto_error("libsodium not linked");
#endif
}
