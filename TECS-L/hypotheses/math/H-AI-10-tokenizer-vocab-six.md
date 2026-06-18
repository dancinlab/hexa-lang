# H-AI-10: BPE Tokenizer Optimal Vocab Size and Powers of 6

> **Hypothesis**: BPE tokenizer's optimal vocab size maximizes efficiency near 6^k.

## Status: REFUTED

Grade: ⚪ (Coincidence / Failure)

## Background
- GPT-2: 50257, GPT-4: 100K, LLaMA: 32K etc - are major LLM vocab sizes close to 6^k?
- 6^5=7776, 6^6=46656, 6^7=279936
- Marked as "weak" even at time of hypothesis proposal

## Verification Results (2026-03-24)

Comparing 16 major LLMs' vocab sizes by relative error to 6^k and 2^k:

| Model | Vocab | Near 6^k | %err 6^k | Near 2^k | %err 2^k | Winner |
|---|---|---|---|---|---|---|
| GPT-2 | 50257 | 6^6=46656 | 7.2% | 2^16=65536 | 30.4% | 6^k |
| GPT-3/3.5 | 50257 | 6^6=46656 | 7.2% | 2^16=65536 | 30.4% | 6^k |
| GPT-4 | 100256 | 6^6=46656 | 53.5% | 2^17=131072 | 30.7% | 2^k |
| BERT | 30522 | 6^6=46656 | 52.9% | 2^15=32768 | 7.4% | 2^k |
| T5 | 32000 | 6^6=46656 | 45.8% | 2^15=32768 | 2.4% | 2^k |
| LLaMA | 32000 | 6^6=46656 | 45.8% | 2^15=32768 | 2.4% | 2^k |
| LLaMA-2 | 32000 | 6^6=46656 | 45.8% | 2^15=32768 | 2.4% | 2^k |
| LLaMA-3 | 128256 | 6^6=46656 | 63.6% | 2^17=131072 | 2.2% | 2^k |
| Mistral | 32000 | 6^6=46656 | 45.8% | 2^15=32768 | 2.4% | 2^k |
| Claude | 100000 | 6^6=46656 | 53.3% | 2^17=131072 | 31.1% | 2^k |
| Gemini | 256000 | 6^7=279936 | 9.3% | 2^18=262144 | 2.4% | 2^k |
| PaLM | 256000 | 6^7=279936 | 9.3% | 2^18=262144 | 2.4% | 2^k |
| Falcon | 65024 | 6^6=46656 | 28.2% | 2^16=65536 | 0.8% | 2^k |
| Phi-2 | 51200 | 6^6=46656 | 8.9% | 2^16=65536 | 28.0% | 6^k |
| Qwen | 151936 | 6^6=46656 | 69.3% | 2^17=131072 | 13.7% | 2^k |
| DeepSeek | 102400 | 6^6=46656 | 54.4% | 2^17=131072 | 28.0% | 2^k |

### Summary Statistics

```
  Wins:  2^k = 13,  6^k = 3
  Average relative error to nearest 6^k: 37.5%
  Average relative error to nearest 2^k: 13.6%
  Ratio: 6^k is 2.8x worse than 2^k

  6^k wins:
    |===                          | 3/16 (19%)
  2^k wins:
    |=========================    | 13/16 (81%)
```

## Interpretation

Vocab sizes are much closer to powers of 2. The reasons are obvious:

1. **Hardware optimization**: GPUs/TPUs perform optimally with 2^k sized matrices
2. **Embedding tables**: 2^k alignment benefits memory access patterns
3. **Design conventions**: ML engineers use 32K, 64K, 128K, 256K as defaults

The 3 cases where 6^k wins (GPT-2, GPT-3, Phi-2) are all near 50K, which happens to be close to 6^6=46656 by coincidence, not by design targeting 6. GPT-2's 50257 was determined by byte-level BPE with 256 byte tokens + 50000 merges + 1 special token.

## Limitations

- Only compared vocab sizes, not downstream task performance
- Whether performance maximizes near 6^k would require separate experiments, but the hypothesis premise itself is wrong

## Conclusion

**⚪ REFUTED**. Tokenizer vocab size is unrelated to powers of 6. Powers of 2 bias is overwhelming, stemming from hardware optimization and ML design conventions. Values near 6^k are coincidental.

## Difficulty: Medium | Impact: ★ (None)