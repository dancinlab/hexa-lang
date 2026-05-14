/* self/native/crypto_openssl.c -- OpenSSL EVP binding (AES-256-CTR).
 *
 * Included from self/runtime.c (NOT a standalone TU).
 *
 * Only AES-256-CTR for now — needed by OpenSSH passphrase-encrypted
 * private-key decryption (cipher = "aes256-ctr"). libsodium ships
 * AES-128 only; AES-256 needs OpenSSL or a hand-rolled S-box impl.
 *
 * Exports:
 *   hexa_aes256_ctr_xor(key, iv, data) -> [int]
 *
 * Linking: -lcrypto (OpenSSL). Detected by self/main.hexa::os_clang_*
 * flags via pkg-config openssl when HEXA_HAS_OPENSSL is defined.
 */

#ifdef HEXA_HAS_OPENSSL
#include <openssl/evp.h>
#endif

HexaVal hexa_aes256_ctr_xor(HexaVal key_v, HexaVal iv_v, HexaVal data_v) {
#ifdef HEXA_HAS_OPENSSL
    size_t kn = 0, in = 0, dn = 0;
    unsigned char* k = _arr_to_bytes(key_v,  &kn);
    unsigned char* iv = _arr_to_bytes(iv_v,  &in);
    unsigned char* d = _arr_to_bytes(data_v, &dn);
    if (!k || kn != 32 || !iv || in != 16 || !d) {
        if (k) free(k); if (iv) free(iv); if (d) free(d);
        return _crypto_error("aes256_ctr: key=32 iv=16 required");
    }
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx) { free(k); free(iv); free(d); return _crypto_error("aes256_ctr: ctx_new"); }
    unsigned char* out = (unsigned char*)malloc(dn);
    int outlen = 0, finlen = 0;
    int ok = EVP_EncryptInit_ex(ctx, EVP_aes_256_ctr(), NULL, k, iv) == 1
          && EVP_EncryptUpdate(ctx, out, &outlen, d, (int)dn) == 1
          && EVP_EncryptFinal_ex(ctx, out + outlen, &finlen) == 1;
    EVP_CIPHER_CTX_free(ctx);
    HexaVal res;
    if (ok) { res = _bytes_to_arr(out, dn); }
    else { res = _crypto_error("aes256_ctr: EVP failed"); }
    free(k); free(iv); free(d); free(out);
    return res;
#else
    (void)key_v; (void)iv_v; (void)data_v;
    return _crypto_error("OpenSSL not linked — passphrase-encrypted keys unsupported");
#endif
}
