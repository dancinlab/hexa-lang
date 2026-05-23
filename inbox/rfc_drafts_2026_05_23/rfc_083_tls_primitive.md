# RFC 083 — TLS primitive (wss:// · HTTPS · secure runpod control plane)

- **Status**: design-draft (decision input phase)
- **Date**: 2026-05-23
- **Severity**: HIGH (보안 · 외부의존성 결정)
- **Source**: HEXA-LANG.md "Deferred RFC 사이클" 후보 3 · `inbox/patches/websocket-streaming-client-websocat-dependency`
- **Range**: 런타임 / C primitive (multi-week)
- **Implements**: 본 RFC 는 design ONLY — 구현은 별도 (`rfc_083_impl_*`)
- **External-llm scope**: 없음 (compiler/runtime 코어 작업)

## 1. Motivation

현재 TLS 가 필요한 hexa-native 경로 3가지:

| 경로 | 현재 처리 | 문제 |
|---|---|---|
| `wss://` WebSocket | `websocat` 외부 binary subprocess (`stdlib/websocket.hexa:21,84`) | `brew install websocat` / `cargo install websocat` 필요 — non-default · supply chain |
| HTTPS GET/POST | `curl` subprocess + 파일 파싱 (`stdlib/http.hexa`, `stdlib/net/http_client.hexa`) | curl on PATH 가정 · streaming 어려움 · header injection 위험 표면 |
| runpod / cloud control plane | `hexa cloud` 가 ssh + scp wrap (`stdlib/cloud/*`) | ssh 는 TLS 아님 — 호스트 key 트러스트만 · API endpoint 직접 호출 안 됨 |

세 경로 모두 **TLS 1.3 client (handshake · cert validation · session resume)** 가 hexa-native primitive 로 있으면 해결.

## 2. Scope (in / out)

**In v1 (이 RFC):**

- TLS 1.3 client only (server 미포함) — handshake · cert chain validation · session resume (PSK)
- ALPN negotiation (h2 / http/1.1)
- builtin syscall surface — `tls_connect(host: string, port: int) -> Result<TlsConn, TlsError>`, `tls_write(c, bytes) -> Result<int, TlsError>`, `tls_read(c, buf) -> Result<int, TlsError>`, `tls_close(c) -> Result<(), TlsError>`
- CA bundle policy 결정 (D3 참조)
- `wss://` / `https://` 스킴이 자동으로 builtin TLS 경로로 routing
- `hexa_tls_*` 빌트인 codegen + runtime.c 측 함수

**Out (follow-up RFC):**

- TLS server (acceptor / cert management) — server 작업은 별도
- mTLS (client cert) — v1 시 1-way auth 만
- TLS 1.2 fallback — v1 은 1.3 only · 2026년 기준 충분
- 0-RTT early-data — perf optim 별도
- DTLS (UDP over TLS) — non-scope
- HSM / PKCS#11 hardware key 통합 — non-scope
- Post-quantum (ML-KEM / X25519+ML-KEM hybrid) — D6 참조

## 3. Surface options (decision matrix)

### D1. 외부 의존성 — TLS library 선택

| option | library | 형태 | pros | cons |
|---|---|---|---|---|
| A. vendored BoringSSL | C library, vendored sub-runtime | mature · 안정 · Google 유지 | ~3MB binary 증가 · build 복잡 (cmake) · C API |
| B. vendored OpenSSL 3.x / LibreSSL | C library | 모든 distro에 있음 (system 링크 시) · standard | API churn 심함 · CVE 빈도 · build slow |
| C. rustls FFI (Rust → C ABI shim) | Rust library, like `phi_rs` (rfc_036) | memory-safe · modern · 작음 (~2MB) · 활발 | Rust toolchain 의존 · FFI ceremony · Mac/Linux 두 host에 cargo 필요 |
| **D. system OpenSSL / SecureTransport 동적 링크 (no vendor)** | dlopen `libssl.dylib` / `libssl.so.3` · Mac은 SecureTransport.framework | 추가 의존성 0 (system 사용) · binary 작음 | ABI fragmentation (distro별) · macOS는 SecureTransport (별도 API) · runtime 검출 코드 필요 |
| E. libsodium-only (TLS 직접 구현) | hexa/C 로 직접 TLS 1.3 handshake · libsodium primitive | 의존성 최소 · 통제권 | 작업량 막대 · TLS 보안 직접 책임 — 비권고 |

**🔵 Decision needed.** 권고: **D (system 동적 링크) v1**.

이유:
- hexa-lang은 self-host native compiler — vendored TLS는 build infra 복잡도 큼 (cmake/cargo on both host)
- Mac/Linux 모두 system TLS 잘 maintained — supply chain 책임 OS 측에 위임
- runtime 검출 (`dlopen("libssl.so.3", RTLD_LAZY)`, Mac은 SecureTransport) — runtime.c ~200 LOC 예상
- vendored 가 필요해지는 시점은: (a) 정적 reproducible build 요구, (b) ALPN/PSK 등 system OpenSSL 이 제공 안 하는 기능 필요 — 둘 다 follow-up

**B (vendored OpenSSL)** alternative: reproducible build 우선 시 채택. self-host fixpoint (gen1.s ≡ gen2.s) 가 OS-OpenSSL 버전 차이로 깨질 가능성 있으면 **B 로 전환** 필요.

### D2. API surface — sync vs async

| option | 형태 | tradeoff |
|---|---|---|
| **A. sync blocking (libcurl-style)** | `tls_read(c, buf)` 가 데이터 도착까지 block | 단순 · 기존 hexa 코드와 자연스러움 (대부분 sync) · WebSocket streaming은 thread / fiber 필요 |
| B. async (epoll/kqueue + future) | `tls_read(c, buf) -> Future<Result<...>>` | streaming 자연스러움 · futures stdlib 필요 (없음) |
| C. sync + non-blocking flag (`tls_set_nonblocking`) + `tls_poll_readable` | 둘 다 | hexa 사용자가 선택 · 구현 비용 중간 |

**🔵 Decision needed.** 권고: **C** (sync + non-blocking). 이유:
- hexa-lang stdlib 에 future/async runtime 없음 — B 는 별도 대형 RFC 필요
- WebSocket streaming 은 `tls_poll_readable` + thread-per-connection 으로 충분
- 비동기 future RFC 가 나오면 C 의 non-blocking layer 위에 wrap 가능

### D3. CA bundle source

| option | 출처 | tradeoff |
|---|---|---|
| **A. system trust store 자동 검출** | macOS Keychain (Security.framework) · Linux `/etc/ssl/certs/ca-certificates.crt` · `SSL_CERT_FILE`/`SSL_CERT_DIR` env | OS 가 갱신 · 추가 작업 0 · 두 OS 검출 로직 필요 |
| B. mozilla CA bundle vendored (Mozilla bundle, ~200KB) | hexa-runtime 에 포함 | 결정적 · supply chain 통제 · 만료된 cert 가 hexa 업데이트 없이 갱신 안 됨 |
| C. BYO — 사용자가 `HEXA_TLS_CA_BUNDLE=/path` 강제 | 통제 · ergonomics 0 |
| D. A + 환경변수 override + B fallback | 모든 케이스 | 구현 복잡 |

**🔵 Decision needed.** 권고: **A** v1 + `HEXA_TLS_CA_BUNDLE` env override (C). vendored bundle 은 reproducibility 요구 시 follow-up.

### D4. 빌트인 API 형태

| option | 형태 |
|---|---|
| **A. opaque handle + builtin functions** — `let c = tls_connect(host, port)?; tls_write(c, bytes)?; let n = tls_read(c, buf)?` | C-style · 명시적 · stdlib wrap 위에서 OOP-ish API 가능 |
| B. method-bearing builtin struct — `let c = TlsConn::connect(host, port)?; c.write(bytes)?; let n = c.read(buf)?` | RFC 082 trait/method 의존 — 본 RFC 이전 도착 필요 |
| C. `connect(scheme://host:port)` 통합 — `wss://` 자동 dispatch | URL parsing + scheme routing |

**🔵 Decision needed.** 권고: **A** v1, **C** 는 `stdlib/websocket.hexa` · `stdlib/http.hexa` 측에서 wrap. RFC 082 trait 도착 후 **B** 형태로 ergonomics 향상.

### D5. 인증서 검증 정책

| option | 정책 |
|---|---|
| **A. strict (Mozilla CA bundle 기준, hostname match, OCSP/CRL 옵션)** | 안전 · 기본값 · OCSP 는 v1 미포함 (latency · 복잡도) |
| B. allow-self-signed (env `HEXA_TLS_INSECURE=1`) | 개발/테스트 편의 · default OFF |
| C. cert pinning (host → cert fingerprint 매핑) | high-security · API 노출 비용 |

**🔵 Decision needed.** 권고: **A + B opt-in** (C 는 follow-up). `HEXA_TLS_INSECURE=1` 시 진단 메시지 출력.

### D6. post-quantum readiness

NIST PQC 표준 ML-KEM (CRYSTALS-Kyber) — Chrome/Cloudflare 2025 이미 X25519+ML-KEM hybrid 활성화.

| option | 정책 |
|---|---|
| **A. v1 미포함 — system library 가 PQ 지원 시 자동 활용** | system OpenSSL 3.5+ 가 ML-KEM 지원 시 hexa 코드 변경 없이 적용 |
| B. v1 에 ML-KEM 명시 요구 — 구현 시 system lib 가 지원하는지 검증 | 미래대비 · system OpenSSL 버전 매트릭스 검증 비용 |

**🔵 Decision needed.** 권고: **A** — system library 책임 위임, hexa 측 PQ 작업 follow-up.

### D7. 모듈 위치

| option | 경로 |
|---|---|
| **A. `stdlib/tls.hexa` + `runtime.c::hexa_tls_*`** | 표준 stdlib 위치 |
| B. `stdlib/net/tls.hexa` (`net/` 하위) | http/websocket 과 동일 그룹 — `stdlib/net/http_client.hexa` 존재 |
| C. `compiler/runtime/tls/` 하위 디렉토리 | 큰 모듈 (여러 파일) 가정 |

**🔵 Decision needed.** 권고: **B** — net 그룹 통일. 동시에 기존 `stdlib/websocket.hexa` · `stdlib/http.hexa` 를 `stdlib/net/` 로 이동하는 mini-refactor 동반.

## 4. Falsifier

- **F-083-1**: `tls_connect("github.com", 443)` 성공, `Ok(handle)` 반환
- **F-083-2**: `tls_connect("expired.badssl.com", 443)` 실패, `Err(CertExpired)` 반환 (D5=A strict)
- **F-083-3**: `tls_connect("self-signed.badssl.com", 443)` 실패 (default) · `HEXA_TLS_INSECURE=1` 시 성공
- **F-083-4**: GET `https://api.runpod.io/...` request response 200 (실제 운영 endpoint 검증)
- **F-083-5**: `wss://echo.websocket.events` connect + send + receive 동작 — `websocat` PATH 제거 후
- **F-083-6**: ALPN 협상으로 `h2` advertise 시 server 가 HTTP/2 로 응답 (stdlib/http2 와 연동)
- **F-083-7**: existing self-host corpus byte-eq — `hexa build self/main.hexa` gen1.s ≡ gen2.s 유지 (TLS primitive 도입이 기존 builtin 영향 없음)

## 5. Decision input — 정리표

| ID | 결정 항목 | 권고 |
|---|---|---|
| D1 | TLS 라이브러리 | **D** (system 동적 링크) v1 · OpenSSL vendored 는 reproducibility 요구 시 |
| D2 | API surface | **C** (sync + non-blocking flag) |
| D3 | CA bundle | **A** (system trust) + `HEXA_TLS_CA_BUNDLE` env override |
| D4 | builtin API 형태 | **A** (opaque handle + functions) · trait 도착 후 B |
| D5 | 인증서 검증 | **A** strict + **B** opt-in insecure flag |
| D6 | PQC | **A** (system lib 위임) |
| D7 | 모듈 위치 | **B** (`stdlib/net/tls.hexa`) — `stdlib/net/` 이동 mini-refactor 동반 |

## 6. Phase plan (implementation — 별도 RFC)

이 RFC 는 design ONLY. D1-D7 확정 후 별도:

- **rfc_083_impl_a** — runtime.c TLS dlopen + libssl symbol resolution + Mac SecureTransport 분기
- **rfc_083_impl_b** — `hexa_tls_connect` / `_write` / `_read` / `_close` 빌트인 codegen
- **rfc_083_impl_c** — CA bundle 검출 (D3) + 인증서 검증 (D5)
- **rfc_083_impl_d** — `stdlib/net/tls.hexa` + `stdlib/net/` 이동 refactor
- **rfc_083_impl_e** — `stdlib/websocket.hexa` 의 `websocat` 분기 제거 → 빌트인 TLS 경로 사용
- **rfc_083_impl_f** — `stdlib/http.hexa` · `stdlib/net/http_client.hexa` 의 curl 분기 제거
- **rfc_083_impl_g** — `inbox/patches/websocket-streaming-client-websocat-dependency` CLOSE

## 7. Non-scope (follow-up RFC)

- TLS server — 별도 RFC
- mTLS · 0-RTT · DTLS · HSM
- Post-quantum 명시 활성화
- 비동기 future stdlib (D2 의 B option 도착 시)
- TLS 1.2 backward compat (필요 시점에만)
- OCSP / CRL 검증

## 8. 보안 책임 분담

| 책임 | 주체 |
|---|---|
| TLS 핸드셰이크 / 암호화 / cert 검증 | system libssl (D1=D 권고) — 또는 vendored lib (D1=B 시) |
| CA 갱신 | OS package manager (D3=A 권고) |
| hexa 측 빌트인 API 안전성 (memory safety · API misuse 방지) | **hexa-lang 책임** — `tls_*` 빌트인이 raw pointer 노출 안 함 · close 자동/명시 결정 (D2 영향) |
| 사용자 정책 (insecure flag · cert pinning) | hexa-lang stdlib + env |

## 9. Cross-RFC interactions

- **RFC 081 (Option/Result)**: TLS API 가 `Result<T, TlsError>` 반환 — 본 RFC 는 RFC 081 의 `Result` 사용을 가정 · RFC 081 이전 도착 필수 (혹은 본 RFC 의 빌트인이 자체 `(value, error_code)` 튜플 surface 사용 후 마이그레이션)
- **RFC 082 (trait operator)**: 본 RFC v1 의 D4=A 는 trait 무관 · follow-up D4=B 시점에 trait 의존
- **`hexa cloud`** ([[project_stdlib_cloud_cycle_a]]): control plane 의 ssh+scp wrap 을 `https://` API 호출로 marker 표시 가능 — RunPod GraphQL API 호출 등
- **self-host fixpoint** ([[project_compiler_native_self_host_fixpoint]]): system OpenSSL 버전 다양성이 gen1.s ≡ gen2.s 영향 — TLS primitive 가 codegen 출력에 영향 주면 안 됨 (런타임 동적 dispatch 만)

## 10. References

- HEXA-LANG.md §"RFC 후보 3"
- `inbox/patches/websocket-streaming-client-websocat-dependency`
- BoringSSL · OpenSSL 3.x · rustls API
- mozilla CA bundle: https://hg.mozilla.org/mozilla-central/raw-file/tip/security/nss/lib/ckfw/builtins/certdata.txt
- RFC 8446 (TLS 1.3) · RFC 7301 (ALPN) · RFC 8773 (PSK)
- NIST FIPS 203 (ML-KEM) · IETF draft hybrid X25519+ML-KEM
- [[rfc_081_option_result_lane]] — Result 의존
- [[rfc_082_trait_operator_overload]] — D4 follow-up trait 의존
- [[project_stdlib_cloud_cycle_a]] — cloud control plane 활용 시점
