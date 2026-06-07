// ════════════════════════════════════════════════════════════════════════════
//  ring_tcp_m6.c — HEXA-DDP DDP-M6: ring all-reduce ACROSS A NODE BOUNDARY.
//
//  DDP-M1/M3/M5 proved the canonical ring all-reduce byte-eq on ONE node
//  (in-process sim -> real cudaMemcpyPeer P2P -> 4-GPU). DDP-M6 changes ONLY the
//  per-step TRANSPORT: instead of cudaMemcpyPeer between two GPUs in one box,
//  each rank is a SEPARATE PROCESS (typically on a SEPARATE HOST), and a ring
//  step is a host-to-host TCP send/recv of the FP64 chunk over a socket.
//
//  The SCHEDULE is byte-for-byte the same one proven in M1/M3/M5
//  (stdlib/ddp/m5_4gpu/ring_p2p_m5.cu): split each rank's length-S vector into
//  N contiguous chunks (chunk_start: first S%N chunks get one extra element),
//  then run 2(N-1) communication steps —
//    Phase 1 reduce-scatter (N-1 steps): rank r sends one chunk to (r+1)%N;
//      receiver ADDS it. After N-1 steps each rank owns the full SUM of one
//      distinct chunk.
//    Phase 2 all-gather (N-1 steps): circulate the reduced chunks (overwrite,
//      no add) so every rank ends holding the complete sum.
//
//  The ONLY change vs M5 is the transport primitive:
//    M5:  cudaMemcpyPeer(staging[dst], dst, d[r], r, bytes)   (intra-node GPU)
//    M6:  sendall(chunk) on the ring socket to (r+1)%N        (inter-node TCP)
//         recvall(chunk) on the ring socket from (r-1+N)%N
//  Each rank simultaneously sends to its successor and receives from its
//  predecessor. Send-then-recv would deadlock on a 2-cycle, so the order is
//  keyed on rank parity: even ranks send-then-recv, odd ranks recv-then-send —
//  guarantees progress on any ring (no threads).
//
//  TOPOLOGY (rendezvous): each rank r LISTENS for its predecessor (r-1+N)%N and
//  CONNECTS to its successor (r+1)%N at a command-line host:port. For N=2 the
//  two ranks form a 2-cycle and just exchange the single chunk each step.
//
//  GATE (g5): the all-reduced result on EVERY rank == the serial elementwise
//  sum of the N input vectors, byte-eq max|delta|=0, FP64, for:
//    * S = 7    (S%2 = 1 boundary — chunking NOT a multiple of N), AND
//    * S = 1<<20 (large; bytes that cross the wire stay bit-identical).
//
//  This is a HOST-MEMORY ring (no CUDA needed): M6 isolates the cross-node
//  TRANSPORT correctness. The GPU buffers are M3/M5's job; here the bytes are
//  FP64 host arrays and the wire is TCP. That keeps the falsifier honest:
//  if a byte flips crossing the node boundary, max|delta| != 0.
//
//  Build:  cc -O2 -o ring_tcp_m6 ring_tcp_m6.c
//  Run (2 hosts):
//    rank1$  ./ring_tcp_m6 --rank 1 --np 2 --listen 0.0.0.0:5701 \
//                          --succ <hostA_ip>:5700 --S 7
//    rank0$  ./ring_tcp_m6 --rank 0 --np 2 --listen 0.0.0.0:5700 \
//                          --succ <hostB_ip>:5701 --S 7
//  Loopback intermediate proof (one host, 2 procs):
//    ./ring_tcp_m6 --rank 1 --np 2 --listen 127.0.0.1:5701 --succ 127.0.0.1:5700 --S 7 &
//    ./ring_tcp_m6 --rank 0 --np 2 --listen 127.0.0.1:5700 --succ 127.0.0.1:5701 --S 7
// ════════════════════════════════════════════════════════════════════════════
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

static void die(const char* m){ perror(m); exit(2); }

// ── chunk boundaries: identical to M1/M3/M5 ring_chunk_start ────────────────
//    S split into N chunks; first (S%N) chunks get one extra element.
static long chunk_start(long S, int N, int c){
    long base = S / N, rem = S % N;
    if (c <= rem) return (long)c * (base + 1);
    return rem * (base + 1) + (long)(c - rem) * base;
}

// ── reliable full-buffer send/recv (TCP can short-count) ────────────────────
static int sendall(int fd, const void* buf, size_t n){
    const char* p = (const char*)buf;
    while (n){ ssize_t k = send(fd, p, n, 0);
        if (k < 0){ if (errno==EINTR) continue; return -1; }
        if (k == 0) return -1; p += k; n -= (size_t)k; }
    return 0;
}
static int recvall(int fd, void* buf, size_t n){
    char* p = (char*)buf;
    while (n){ ssize_t k = recv(fd, p, n, 0);
        if (k < 0){ if (errno==EINTR) continue; return -1; }
        if (k == 0) return -1; p += k; n -= (size_t)k; }
    return 0;
}

static void parse_hp(const char* hp, char* host, int* port){
    const char* colon = strrchr(hp, ':');
    if (!colon){ fprintf(stderr,"bad host:port %s\n",hp); exit(2);}
    size_t hl = (size_t)(colon-hp); memcpy(host,hp,hl); host[hl]=0;
    *port = atoi(colon+1);
}

// ── listen on host:port, accept ONE predecessor connection ──────────────────
static int listen_one(const char* hostport){
    char host[256]; int port; parse_hp(hostport, host, &port);
    int ls = socket(AF_INET, SOCK_STREAM, 0); if (ls<0) die("socket");
    int one=1; setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    struct sockaddr_in a; memset(&a,0,sizeof a);
    a.sin_family=AF_INET; a.sin_port=htons((uint16_t)port);
    a.sin_addr.s_addr = (!strcmp(host,"0.0.0.0")||!host[0]) ? INADDR_ANY
                                                            : inet_addr(host);
    if (bind(ls,(struct sockaddr*)&a,sizeof a)<0) die("bind");
    if (listen(ls,1)<0) die("listen");
    fprintf(stderr,"[rank] listening on %s\n", hostport);
    int cs = accept(ls,NULL,NULL); if (cs<0) die("accept");
    close(ls);
    int one2=1; setsockopt(cs, IPPROTO_TCP, TCP_NODELAY, &one2, sizeof one2);
    return cs;
}

// ── connect to successor host:port, retrying until it is up (≤120s) ─────────
static int connect_succ(const char* hostport){
    char host[256]; int port; parse_hp(hostport, host, &port);
    struct sockaddr_in a; memset(&a,0,sizeof a);
    a.sin_family=AF_INET; a.sin_port=htons((uint16_t)port);
    struct in_addr ina;
    if (inet_aton(host,&ina)) a.sin_addr=ina;
    else { struct hostent* he=gethostbyname(host);
           if(!he){fprintf(stderr,"resolve %s failed\n",host);exit(2);}
           memcpy(&a.sin_addr,he->h_addr,he->h_length); }
    for (int tries=0; tries<600; tries++){
        int cs = socket(AF_INET,SOCK_STREAM,0); if(cs<0) die("socket");
        if (connect(cs,(struct sockaddr*)&a,sizeof a)==0){
            int one=1; setsockopt(cs,IPPROTO_TCP,TCP_NODELAY,&one,sizeof one);
            fprintf(stderr,"[rank] connected succ %s\n",hostport);
            return cs;
        }
        close(cs); usleep(200000); // 200ms; up to 120s total
    }
    fprintf(stderr,"connect %s timed out\n",hostport); exit(2);
}

int main(int argc, char** argv){
    int rank=-1, N=-1; long S=7;
    const char *listen_hp=NULL, *succ_hp=NULL;
    for (int i=1;i<argc;i++){
        if(!strcmp(argv[i],"--rank")) rank=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--np")) N=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--S")) S=atol(argv[++i]);
        else if(!strcmp(argv[i],"--listen")) listen_hp=argv[++i];
        else if(!strcmp(argv[i],"--succ")) succ_hp=argv[++i];
        else { fprintf(stderr,"unknown arg %s\n",argv[i]); return 2; }
    }
    if(rank<0||N<2||!listen_hp||!succ_hp){
        fprintf(stderr,"usage: --rank R --np N --listen H:P --succ H:P [--S n]\n");
        return 2;
    }
    fprintf(stderr,"[rank %d/%d] S=%ld listen=%s succ=%s steps=2(N-1)=%d\n",
            rank,N,S,listen_hp,succ_hp,2*(N-1));

    // ── ring sockets: connect to successor, accept from predecessor.
    //    Parity ordering avoids a connect/accept deadlock on a 2-cycle.
    int sock_succ=-1, sock_pred=-1;
    if (rank % 2 == 0){ sock_succ=connect_succ(succ_hp); sock_pred=listen_one(listen_hp); }
    else              { sock_pred=listen_one(listen_hp); sock_succ=connect_succ(succ_hp); }

    // ── input: rank r holds vector r (deterministic, distinct per rank) — the
    //    SAME generator as M5, so the serial reference matches across milestones.
    double* x      = (double*)malloc((size_t)S*sizeof(double));
    double* serial = (double*)malloc((size_t)S*sizeof(double));
    double* stage  = (double*)malloc((size_t)S*sizeof(double));
    for (long i=0;i<S;i++){
        double acc=0.0;
        for (int r=0;r<N;r++){
            double v = (double)(((long)r*1000003L + i*7L + 1) % 9973) - 4096.0;
            if (r==rank) x[i]=v;
            acc += v;
        }
        serial[i]=acc;
    }

    // ── one ring step: send chunk `sc` to succ, recv chunk `rc` from pred.
    //    Parity ordering guarantees progress without threads.
    //    add=1 -> received chunk ADDED into x (reduce-scatter); else overwrite.
    #define DO_STEP(sc, rc, add) do {                                          \
        long s_st=chunk_start(S,N,(sc)), s_sp=chunk_start(S,N,(sc)+1);          \
        long r_st=chunk_start(S,N,(rc)), r_sp=chunk_start(S,N,(rc)+1);          \
        size_t s_n=(size_t)(s_sp-s_st)*sizeof(double);                         \
        size_t r_n=(size_t)(r_sp-r_st)*sizeof(double);                         \
        if (rank % 2 == 0){                                                    \
            if (s_n && sendall(sock_succ, x+s_st, s_n)) die("send");           \
            if (r_n && recvall(sock_pred, stage+r_st, r_n)) die("recv");       \
        } else {                                                              \
            if (r_n && recvall(sock_pred, stage+r_st, r_n)) die("recv");       \
            if (s_n && sendall(sock_succ, x+s_st, s_n)) die("send");           \
        }                                                                     \
        if (r_n){                                                             \
            if (add) for(long i=r_st;i<r_sp;i++) x[i]+=stage[i];                \
            else     for(long i=r_st;i<r_sp;i++) x[i] =stage[i];                \
        }                                                                     \
    } while(0)

    // ── Phase 1: reduce-scatter (N-1 steps) — schedule identical to M5 ──────
    for (int step=0; step<N-1; step++){
        int send_chunk = ((rank - step) % N + N) % N;
        int recv_chunk = ((((rank-1)%N+N)%N - step) % N + N) % N;
        DO_STEP(send_chunk, recv_chunk, 1);
    }
    // ── Phase 2: all-gather (N-1 steps) — overwrite, no add ─────────────────
    for (int step=0; step<N-1; step++){
        int send_chunk = ((rank - step + 1) % N + N) % N;
        int recv_chunk = ((((rank-1)%N+N)%N - step + 1) % N + N) % N;
        DO_STEP(send_chunk, recv_chunk, 0);
    }

    // ── gate: this rank's full vector == serial elementwise sum, max|delta| ──
    double md=0.0;
    for (long i=0;i<S;i++){ double d=fabs(x[i]-serial[i]); if(d>md) md=d; }
    printf("rank %d/%d S=%ld (S%%N=%ld) : max|delta| vs serial-sum = %.17g  %s\n",
           rank,N,S,S%N,md,(md==0.0)?"BYTE-EQ PASS":"FAIL");

    close(sock_succ); close(sock_pred);
    free(x); free(serial); free(stage);
    return md==0.0 ? 0 : 1;
}
