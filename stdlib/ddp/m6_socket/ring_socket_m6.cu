// ════════════════════════════════════════════════════════════════════════════
//  ring_socket_m6.cu — HEXA-DDP DDP-M6 (multi-node leg): ring all-reduce whose
//  per-step transport CROSSES A NODE BOUNDARY over a TCP socket.
//
//  DDP-M1/M3/M5 proved the canonical ring all-reduce byte-exact single-node:
//    M1 in-process N-rank sim, M3 real 2-GPU cudaMemcpyPeer, M5 real 4-GPU.
//  Those all live inside ONE node (P2P / host-staged DMA over PCIe). DDP-M6 is
//  the multi-NODE leg: the ring's transport now goes over the host network
//  (a reliable, ordered TCP byte stream) so the bytes literally cross the wire
//  between two separate machines and must arrive BIT-IDENTICAL.
//
//  The SCHEDULE is the EXACT canonical ring of M1/M3/M5 — split each rank's
//  length-S vector into N contiguous chunks and run 2(N-1) communication steps:
//    Phase 1 reduce-scatter (N-1 steps): rank r sends one chunk to (r+1)%N,
//      the receiver ADDS it. After N-1 steps each rank owns the full SUM of
//      exactly one distinct chunk.
//    Phase 2 all-gather (N-1 steps): circulate the fully-reduced chunks around
//      the ring (overwrite, no add) so every rank holds the complete sum.
//  The chunk boundaries (chunk_start) are byte-identical to M1/M3/M5.
//
//  The ONLY thing M6 changes vs M3/M5 is the TRANSPORT: instead of
//  cudaMemcpyPeer (device->device inside one node), a ring send is
//    D2H copy chunk -> host staging -> send() over TCP to the next rank's node
//    -> recv() into the receiver's host staging -> H2D copy -> (add on device).
//  TCP is reliable + ordered, so the chunk that arrives is the chunk that was
//  sent, bit-for-bit. If the wire ever corrupted/reordered a byte the gate
//  (max|delta| vs serial sum) would catch it.
//
//  TOPOLOGY: this is a SINGLE-PROCESS-PER-RANK program. Each rank runs on its
//  own node, talks to GPU 0 of that node, and connects in a ring:
//    rank r OPENS a listening socket (recv from (r-1)%N) and CONNECTS to
//    rank (r+1)%N. The rendezvous addresses come from env DDP_PEERS
//    (comma list host:port, index = rank) + DDP_RANK + DDP_WORLD.
//  A loopback run (both ranks on 127.0.0.1, two processes on ONE node) is an
//  INTERMEDIATE proof of the socket-ring; the real proof is two ranks on TWO
//  separate nodes (DDP_PEERS pointing at the other node's reachable host:port).
//
//  GATE (g5): the all-reduced result on EVERY rank == the serial elementwise
//  sum of the N input vectors, byte-eq max|delta|=0, FP64, for:
//    * S = 7      (S%N != 0 boundary chunking — NOT a multiple of N), and
//    * S = 1<<20  (large).
//  Each rank verifies its OWN buffer == the serial sum and prints max|delta|.
//
//  Build:  nvcc -O2 -arch=sm_75 -o ring_socket_m6 ring_socket_m6.cu
//  Run (2 nodes):  on node A:  DDP_WORLD=2 DDP_RANK=0 \
//                    DDP_PEERS=0.0.0.0:5000,NODEB_HOST:5001 ./ring_socket_m6
//                  on node B:  DDP_WORLD=2 DDP_RANK=1 \
//                    DDP_PEERS=NODEA_HOST:5000,0.0.0.0:5001 ./ring_socket_m6
//  Run (loopback): two processes, DDP_PEERS=127.0.0.1:5000,127.0.0.1:5001 .
// ════════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include <cstdint>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

#define SCK(x) do { if ((x) < 0) { perror("sock " #x); exit(2); } } while (0)

// ── chunk boundaries: identical to M1/M3/M5 ring_chunk_start (S split into N
//    chunks; first (S%N) chunks get one extra element). ──────────────────────
static long chunk_start(long S, int N, int c) {
    long base = S / N;
    long rem  = S % N;
    if (c <= rem) return (long)c * (base + 1);
    return rem * (base + 1) + (long)(c - rem) * base;
}

// add: dst[i] += src[i] over [start,stop)
__global__ void add_range(double* dst, const double* src, long start, long stop) {
    long i = start + (long)blockIdx.x * blockDim.x + threadIdx.x;
    if (i < stop) dst[i] += src[i];
}

// ── blocking full read/write of n bytes over a TCP stream ────────────────────
static void send_all(int fd, const void* buf, size_t n) {
    const char* p = (const char*)buf;
    while (n > 0) {
        ssize_t w = send(fd, p, n, 0);
        if (w < 0) { perror("send"); exit(2); }
        p += w; n -= (size_t)w;
    }
}
static void recv_all(int fd, void* buf, size_t n) {
    char* p = (char*)buf;
    while (n > 0) {
        ssize_t r = recv(fd, p, n, 0);
        if (r < 0) { perror("recv"); exit(2); }
        if (r == 0) { fprintf(stderr, "peer closed\n"); exit(2); }
        p += r; n -= (size_t)r;
    }
}

static void set_nodelay(int fd) { int one = 1; setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one)); }

// parse env DDP_PEERS = "host:port,host:port,..."  (index = rank).
static std::vector<std::pair<std::string,int>> parse_peers(const char* s, int world) {
    std::vector<std::pair<std::string,int>> v;
    std::string str(s);
    size_t pos = 0;
    while (pos < str.size()) {
        size_t comma = str.find(',', pos);
        std::string tok = str.substr(pos, comma == std::string::npos ? std::string::npos : comma - pos);
        size_t colon = tok.rfind(':');
        v.push_back({tok.substr(0, colon), atoi(tok.substr(colon + 1).c_str())});
        if (comma == std::string::npos) break;
        pos = comma + 1;
    }
    if ((int)v.size() != world) {
        fprintf(stderr, "DDP_PEERS has %zu entries, expected DDP_WORLD=%d\n", v.size(), world);
        exit(2);
    }
    return v;
}

// listen on my port, accept ONE connection (the predecessor rank).
static int open_listen(int port) {
    int ls; SCK(ls = socket(AF_INET, SOCK_STREAM, 0));
    int one = 1; setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = INADDR_ANY; a.sin_port = htons((uint16_t)port);
    SCK(bind(ls, (struct sockaddr*)&a, sizeof(a)));
    SCK(listen(ls, 4));
    return ls;
}

// connect to host:port, retrying until the peer's listener is up.
static int connect_retry(const std::string& host, int port) {
    for (int attempt = 0; attempt < 600; attempt++) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) { usleep(200000); continue; }
        struct sockaddr_in a; memset(&a, 0, sizeof(a));
        a.sin_family = AF_INET; a.sin_port = htons((uint16_t)port);
        if (inet_pton(AF_INET, host.c_str(), &a.sin_addr) != 1) {
            // try resolving as hostname via gethostbyname-free path is omitted;
            // runpod proxy/direct gives an IP, so require dotted-quad here.
            fprintf(stderr, "DDP_PEERS host '%s' must be a dotted-quad IP\n", host.c_str());
            exit(2);
        }
        if (connect(fd, (struct sockaddr*)&a, sizeof(a)) == 0) { set_nodelay(fd); return fd; }
        close(fd);
        usleep(200000);  // 0.2s backoff, up to 120s total
    }
    fprintf(stderr, "connect to %s:%d failed after retries\n", host.c_str(), port);
    exit(2);
}

// ── one full ring all-reduce. This rank holds vector `rank` on its GPU 0.
//   `send_fd` -> successor (r+1)%N ; `recv_fd` <- predecessor (r-1)%N.
//   Returns max|delta| of THIS rank's buffer vs the serial elementwise sum.
static double ring_all_reduce(int N, int rank, long S, int send_fd, int recv_fd) {
    // host input: rank r holds vector r (deterministic, distinct per rank) —
    // SAME generator as M5 so the reference sum is identical across legs.
    std::vector<double> myvec(S);
    std::vector<double> serial(S, 0.0);
    for (int r = 0; r < N; r++)
        for (long i = 0; i < S; i++) {
            double v = (double)((r * 1000003L + i * 7L + 1) % 9973) - 4096.0;
            if (r == rank) myvec[i] = v;
            serial[i] += v;            // reference: serial elementwise sum
        }

    CK(cudaSetDevice(0));
    double *d = nullptr, *staging = nullptr;
    CK(cudaMalloc(&d, S * sizeof(double)));
    CK(cudaMalloc(&staging, S * sizeof(double)));
    CK(cudaMemcpy(d, myvec.data(), S * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaDeviceSynchronize());

    // host send/recv staging buffers (one chunk max == one whole vector worst case)
    std::vector<double> hsend(S), hrecv(S);

    // ── Phase 1: reduce-scatter (N-1 steps) — schedule identical to M1/M3/M5 ──
    for (int step = 0; step < N - 1; step++) {
        int send_chunk = ((rank - step) % N + N) % N;            // I send this
        int recv_chunk = ((rank - 1 - step) % N + N) % N;        // I receive this
        long sst = chunk_start(S, N, send_chunk), ssp = chunk_start(S, N, send_chunk + 1);
        long rst = chunk_start(S, N, recv_chunk), rsp = chunk_start(S, N, recv_chunk + 1);
        long scnt = ssp - sst, rcnt = rsp - rst;
        // D2H the chunk I send, ship it, recv the incoming chunk, H2D it, add.
        if (scnt > 0) CK(cudaMemcpy(hsend.data() + sst, d + sst, scnt * sizeof(double), cudaMemcpyDeviceToHost));
        // ordered exchange: even rank sends-then-recvs, odd recvs-then-sends —
        // avoids deadlock on a 2-rank ring where send_fd==recv_fd peer pair.
        if (rank % 2 == 0) {
            if (scnt > 0) send_all(send_fd, hsend.data() + sst, scnt * sizeof(double));
            if (rcnt > 0) recv_all(recv_fd, hrecv.data() + rst, rcnt * sizeof(double));
        } else {
            if (rcnt > 0) recv_all(recv_fd, hrecv.data() + rst, rcnt * sizeof(double));
            if (scnt > 0) send_all(send_fd, hsend.data() + sst, scnt * sizeof(double));
        }
        if (rcnt > 0) {
            CK(cudaMemcpy(staging + rst, hrecv.data() + rst, rcnt * sizeof(double), cudaMemcpyHostToDevice));
            int tpb = 256; long blk = (rcnt + tpb - 1) / tpb;
            add_range<<<(unsigned)blk, tpb>>>(d, staging, rst, rsp);
            CK(cudaDeviceSynchronize());
        }
    }

    // ── Phase 2: all-gather (N-1 steps) — overwrite, no add ───────────────────
    for (int step = 0; step < N - 1; step++) {
        int send_chunk = ((rank - step + 1) % N + N) % N;
        int recv_chunk = ((rank - step) % N + N) % N;
        long sst = chunk_start(S, N, send_chunk), ssp = chunk_start(S, N, send_chunk + 1);
        long rst = chunk_start(S, N, recv_chunk), rsp = chunk_start(S, N, recv_chunk + 1);
        long scnt = ssp - sst, rcnt = rsp - rst;
        if (scnt > 0) CK(cudaMemcpy(hsend.data() + sst, d + sst, scnt * sizeof(double), cudaMemcpyDeviceToHost));
        if (rank % 2 == 0) {
            if (scnt > 0) send_all(send_fd, hsend.data() + sst, scnt * sizeof(double));
            if (rcnt > 0) recv_all(recv_fd, hrecv.data() + rst, rcnt * sizeof(double));
        } else {
            if (rcnt > 0) recv_all(recv_fd, hrecv.data() + rst, rcnt * sizeof(double));
            if (scnt > 0) send_all(send_fd, hsend.data() + sst, scnt * sizeof(double));
        }
        if (rcnt > 0)
            CK(cudaMemcpy(d + rst, hrecv.data() + rst, rcnt * sizeof(double), cudaMemcpyHostToDevice));
    }

    // ── gate: THIS rank's buffer == serial elementwise sum, max|delta| ────────
    std::vector<double> hout(S);
    CK(cudaMemcpy(hout.data(), d, S * sizeof(double), cudaMemcpyDeviceToHost));
    double max_abs_diff = 0.0;
    for (long i = 0; i < S; i++) {
        double dlt = fabs(hout[i] - serial[i]);
        if (dlt > max_abs_diff) max_abs_diff = dlt;
    }
    CK(cudaFree(d)); CK(cudaFree(staging));
    return max_abs_diff;
}

int main(int argc, char** argv) {
    const char* eW = getenv("DDP_WORLD");
    const char* eR = getenv("DDP_RANK");
    const char* eP = getenv("DDP_PEERS");
    if (!eW || !eR || !eP) {
        fprintf(stderr, "need DDP_WORLD, DDP_RANK, DDP_PEERS (host:port,... index=rank)\n");
        return 2;
    }
    int N = atoi(eW), rank = atoi(eR);
    if (N < 2 || rank < 0 || rank >= N) { fprintf(stderr, "bad world/rank\n"); return 2; }
    auto peers = parse_peers(eP, N);

    int ndev = 0; CK(cudaGetDeviceCount(&ndev));
    printf("=== ring_socket_m6 :: rank %d/%d  visible CUDA devices = %d ===\n", rank, N, ndev);
    if (ndev < 1) { printf("FATAL: need >= 1 GPU on this node\n"); return 3; }
    printf("rank %d: ring schedule = 2(N-1) = %d communication steps\n", rank, 2 * (N - 1));

    // ── ring rendezvous: listen on MY port, connect to successor ──────────────
    //   My listen port = peers[rank].port ; successor = peers[(rank+1)%N].
    int my_port = peers[rank].second;
    int succ = (rank + 1) % N;
    int pred = (rank - 1 + N) % N;
    printf("rank %d: listen 0.0.0.0:%d (recv<-rank %d), connect %s:%d (send->rank %d)\n",
           rank, my_port, pred, peers[succ].first.c_str(), peers[succ].second, succ);
    fflush(stdout);

    int ls = open_listen(my_port);
    // connect to successor, then accept from predecessor. The retry loop on
    // connect handles the cross-node startup-order race.
    int send_fd = connect_retry(peers[succ].first, peers[succ].second);
    int recv_fd = -1;
    SCK(recv_fd = accept(ls, nullptr, nullptr));
    set_nodelay(recv_fd);
    printf("rank %d: ring wired (send_fd=%d recv_fd=%d)\n", rank, send_fd, recv_fd);
    fflush(stdout);

    // ── gate cases: S=7 (S%N boundary) and S=1<<20 (large) ────────────────────
    long cases[] = { 7, 1L << 20 };
    int all_pass = 1;
    for (int ci = 0; ci < 2; ci++) {
        long S = cases[ci];
        double mad = ring_all_reduce(N, rank, S, send_fd, recv_fd);
        int pass = (mad == 0.0);
        printf("rank %d: S=%ld  max|delta|=%.17g  %s\n", rank, S, mad, pass ? "BYTE-EQ PASS" : "FAIL");
        fflush(stdout);
        if (!pass) all_pass = 0;
    }

    close(send_fd); close(recv_fd); close(ls);
    printf("rank %d: %s\n", rank, all_pass ? "ALL BYTE-EQ PASS" : "SOME FAIL");
    return all_pass ? 0 : 1;
}
