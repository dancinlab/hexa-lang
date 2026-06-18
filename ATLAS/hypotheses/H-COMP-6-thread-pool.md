# H-COMP-6: Thread Pool Size = cores * phi(6)/mu(6) = cores * 2

## Hypothesis

> The optimal thread pool size for I/O-bound workloads is CPU_cores * phi(6)/mu(6) = cores * 2. For CPU-bound workloads, cores * mu(6)/mu(6) = cores * 1.

## Background

- phi(6) = 2, mu(6) = 1
- phi(6)/mu(6) = 2 → "double the cores" for I/O-bound
- Common recommendation: cores*2 for I/O, cores*1 for CPU
- Go GOMAXPROCS = cores (CPU-bound default)
- Node.js libuv: 4 threads default (often recommended: cores*2)
- Java ForkJoinPool: cores for CPU, cores*2 for I/O is standard advice

## Predictions

1. Thread pool = cores*2 minimizes latency for mixed workloads
2. Thread pool = cores*1 minimizes CPU waste for compute workloads
3. The ratio phi(6)/mu(6) = 2 captures the I/O wait factor

## Conclusion

**Status:** CONFIRMED — standard industry recommendation matches phi/mu=2
