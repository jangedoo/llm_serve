# llama.cpp
## Gemma-4-E4B-it

```
uvx llama-benchy --base-url http://localhost:8080/v1 --model unsloth/gemma-4-E4B-it-GGUF --served-model-name gemma-4-E4B-it --tokenizer google/gemma-4-12B-it --concurrency 1 2 5 10 --pp 2048 --tg 512 1024 --depth 0
```

| model                       |         test |      t/s (total) |        t/s (req) |       peak t/s |   peak t/s (req) |          ttfr (ms) |       est_ppt (ms) |      e2e_ttft (ms) |
|:----------------------------|-------------:|-----------------:|-----------------:|---------------:|-----------------:|-------------------:|-------------------:|-------------------:|
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c1) |  4837.53 ± 19.23 |  4837.53 ± 19.23 |                |                  |      424.99 ± 1.72 |      423.64 ± 1.72 |      438.36 ± 1.71 |
| unsloth/gemma-4-E4B-it-GGUF |   tg512 (c1) |    183.98 ± 5.94 |    183.98 ± 5.94 |  184.33 ± 5.91 |    184.33 ± 5.91 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c2) |  4204.60 ± 54.16 |  2150.80 ± 28.91 |                |                  |     954.27 ± 13.00 |     952.92 ± 13.00 |     974.27 ± 12.71 |
| unsloth/gemma-4-E4B-it-GGUF |   tg512 (c2) |   244.55 ± 10.08 |    124.76 ± 7.44 | 251.00 ± 13.44 |    125.50 ± 7.46 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c5) |  1526.62 ± 21.30 |  912.88 ± 303.35 |                |                  |  2879.14 ± 1906.17 |  2877.79 ± 1906.17 |  2899.19 ± 1906.95 |
| unsloth/gemma-4-E4B-it-GGUF |   tg512 (c5) |    322.82 ± 3.07 |   118.30 ± 24.10 |  431.33 ± 8.50 |   118.87 ± 24.07 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF | pp2048 (c10) |  1399.21 ± 30.46 |  540.09 ± 398.03 |                |                  |  6920.13 ± 4631.43 |  6918.78 ± 4631.43 |  6961.97 ± 4644.81 |
| unsloth/gemma-4-E4B-it-GGUF |  tg512 (c10) |    294.07 ± 5.85 |    94.23 ± 14.88 | 392.33 ± 10.08 |    94.83 ± 14.85 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c1) | 4739.44 ± 148.22 | 4739.44 ± 148.22 |                |                  |     434.11 ± 13.56 |     432.75 ± 13.56 |     448.49 ± 14.12 |
| unsloth/gemma-4-E4B-it-GGUF |  tg1024 (c1) |    169.85 ± 1.07 |    169.85 ± 1.07 |  170.33 ± 1.25 |    170.33 ± 1.25 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c2) |  4060.23 ± 64.28 |  2075.86 ± 34.04 |                |                  |     988.68 ± 16.20 |     987.33 ± 16.20 |    1008.95 ± 16.00 |
| unsloth/gemma-4-E4B-it-GGUF |  tg1024 (c2) |   218.29 ± 10.26 |    113.35 ± 7.86 |  227.67 ± 2.49 |    113.83 ± 7.73 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF |  pp2048 (c5) |   932.17 ± 33.64 |  845.69 ± 329.45 |                |                  |  3819.86 ± 3585.71 |  3818.50 ± 3585.71 |  3840.31 ± 3586.28 |
| unsloth/gemma-4-E4B-it-GGUF |  tg1024 (c5) |    322.49 ± 5.75 |   115.93 ± 19.17 |  435.67 ± 4.50 |   116.40 ± 19.22 |                    |                    |                    |
| unsloth/gemma-4-E4B-it-GGUF | pp2048 (c10) |   849.75 ± 33.51 |  468.36 ± 412.09 |                |                  | 10787.38 ± 8038.59 | 10786.03 ± 8038.59 | 10822.88 ± 8043.61 |
| unsloth/gemma-4-E4B-it-GGUF | tg1024 (c10) |    319.63 ± 2.59 |    98.59 ± 13.82 |  401.33 ± 3.77 |    99.03 ± 13.79 |                    |                    |                    |


# vllm

## Gemma-4-26B-A4B-IT
I use this model mostly for synthetic data generation, so I will be comparing at different concurrency levels, prompt sizes and token generation but the depth will always be zero since my use case is not a multi-turn chat conversation but one off requests.

Hiccups:
- I saw lot of examples online passing this `--load-format fastsafetensors` but this caused OOM issue. According to Codex, vllm reserves the memory for model about 18 GB and fastsafetensors tries to copy the model checkpoint shard into an additional GPU staging buffer requesting 9.3 GB which is about 27 GB in total, whereas my GPU has 24 GB.
- Kernel compilation takes way too much time. For the very first run which was successful I probably waited more than 30 minutes.
- Running `vllm serve ...` after a fresh install or for a new model started kernel compilation process which used all 32 GB of my RAM as well as all Swap causing the entire system to be unresponsive. Ubuntu was able to kill this process a few times but in many cases I just had to hard restart my PC. After some debugging with Codex, it suggested that kernel compilation by flashinfer library was the culprit. Solution was to use the following `MAX_JOBS=2 TORCHINDUCTOR_COMPILE_THREADS=2 vllm serve ...`. 

```bash
vllm.serve \
	    MODEL="nvidia/Gemma-4-26B-A4B-NVFP4" \
	    VERSION="$(VERSION)" \
	    VLLM_ARGS="--served-model-name gemma-4-26B-A4B-it --kv-cache-dtype fp8 --gpu-memory-utilization 0.9 --enable-auto-tool-choice --tool-call-parser gemma4 --reasoning-parser gemma4 --trust-remote-code --limit-mm-per-prompt '{\"image\":1,\"audio\":0}' --host 0.0.0.0 --port 8012"
	    
uvx llama-benchy --base-url http://localhost:8012/v1 --model nvidia/Gemma-4-26B-A4B-NVFP4 --served-model-name gemma-4-26B-A4B-it --concurrency 1 2 5 10 --pp 2048 4096 --tg 512 1024 --depth 0
```

### Prompt processing
It saturates at around 11.5K tok/s.

**For prompts with 2048 tokens**

 Concurrency    Overall throughput    Per-request throughput          TTFR
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━
             1     10.9K–11.3K tok/s         10.9K–11.3K tok/s    182–189 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             2     11.2K–11.6K tok/s           8.2K–8.6K tok/s    267–279 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             5     11.3K–11.5K tok/s           4.7K–4.8K tok/s    580–593 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
            10     11.4K–11.5K tok/s              ~3.0K tok/s    1.05–1.07 s


**For prompts with 4096 tokens**

 Concurrency    Overall throughput    Per-request throughput          TTFR
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━
             1          ~10.4K tok/s              ~10.4K tok/s       ~394 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             2          ~10.6K tok/s               ~7.1K tok/s       ~619 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             5          ~10.8K tok/s               ~4.3K tok/s       ~1.21 s
  ─────────────  ────────────────────  ────────────────────────  ────────────
            10          ~10.9K tok/s               ~2.8K tok/s       ~2.16 s


### Token generation

**512 generated tokens**

 Concurrency    Overall, PP 2K    Per request    Overall, PP 4K    Per request
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━
             1          85 tok/s       85 tok/s          82 tok/s       82 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             2         137 tok/s       74 tok/s         137 tok/s       72 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             5         259 tok/s       56 tok/s         239 tok/s       53 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
            10         389 tok/s       46 tok/s         345 tok/s       41 tok/s


**1024 generated tokens**

 Concurrency    Overall, PP 2K    Per request    Overall, PP 4K    Per request
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━
             1          84 tok/s       84 tok/s          82 tok/s       82 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             2         125 tok/s       75 tok/s         128 tok/s       72 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             5         222 tok/s       57 tok/s         221 tok/s       55 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
            10         337 tok/s       47 tok/s         307 tok/s       43 tok/s


Full output from llama-benchy

| model                        |         test |       t/s (total) |         t/s (req) |      peak t/s |   peak t/s (req) |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:-----------------------------|-------------:|------------------:|------------------:|--------------:|-----------------:|------------------:|------------------:|------------------:|
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c1) | 11315.92 ± 208.60 | 11315.92 ± 208.60 |               |                  |     182.01 ± 3.33 |     181.13 ± 3.33 |     182.01 ± 3.33 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c1) |      85.46 ± 0.22 |      85.46 ± 0.22 |  86.00 ± 0.00 |     86.00 ± 0.00 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c2) | 11649.04 ± 180.43 | 8584.41 ± 2751.93 |               |                  |    266.82 ± 85.13 |    265.94 ± 85.13 |    266.82 ± 85.13 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c2) |     136.94 ± 7.66 |      74.06 ± 1.74 | 151.33 ± 0.94 |     78.17 ± 3.89 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c5) |  11490.30 ± 30.54 | 4814.29 ± 3104.81 |               |                  |   580.01 ± 259.28 |   579.13 ± 259.28 |   580.01 ± 259.28 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c5) |    259.40 ± 13.30 |      56.49 ± 1.66 | 298.33 ± 2.36 |     61.60 ± 4.90 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 | pp2048 (c10) |   11519.27 ± 4.97 | 3020.16 ± 2689.53 |               |                  |  1052.55 ± 505.51 |  1051.67 ± 505.51 |  1052.55 ± 505.51 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg512 (c10) |    388.64 ± 15.16 |      45.73 ± 2.51 | 486.67 ± 4.71 |     52.97 ± 2.68 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c1) | 10887.63 ± 184.18 | 10887.63 ± 184.18 |               |                  |     189.10 ± 3.19 |     188.22 ± 3.19 |     189.10 ± 3.19 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c1) |      83.62 ± 0.05 |      83.62 ± 0.05 |  84.33 ± 0.47 |     84.33 ± 0.47 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c2) |  11168.91 ± 79.41 | 8198.83 ± 2603.35 |               |                  |    278.78 ± 88.16 |    277.90 ± 88.16 |    278.78 ± 88.16 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c2) |    124.86 ± 13.97 |      74.57 ± 2.28 | 150.00 ± 0.00 |     78.00 ± 4.24 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp2048 (c5) |  11251.44 ± 12.84 | 4691.22 ± 3005.05 |               |                  |   593.09 ± 264.08 |   592.21 ± 264.08 |   593.09 ± 264.08 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c5) |    222.19 ± 21.18 |      57.18 ± 3.30 | 295.00 ± 0.00 |     66.20 ± 8.40 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 | pp2048 (c10) |  11386.69 ± 18.33 | 2972.16 ± 2630.01 |               |                  |  1065.68 ± 510.80 |  1064.80 ± 510.80 |  1065.68 ± 510.80 |
| nvidia/Gemma-4-26B-A4B-NVFP4 | tg1024 (c10) |    337.23 ± 18.35 |      46.63 ± 4.42 | 496.67 ± 4.71 |     58.17 ± 9.79 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c1) |  10420.27 ± 14.52 |  10420.27 ± 14.52 |               |                  |     394.06 ± 0.55 |     393.18 ± 0.55 |     394.06 ± 0.55 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c1) |      82.18 ± 0.01 |      82.18 ± 0.01 |  83.00 ± 0.00 |     83.00 ± 0.00 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c2) |  10562.21 ± 23.28 | 7089.45 ± 1801.28 |               |                  |   618.66 ± 156.97 |   617.78 ± 156.97 |   618.66 ± 156.97 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c2) |     136.75 ± 4.03 |      71.63 ± 1.31 | 148.00 ± 0.00 |     75.33 ± 2.98 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c5) |   10781.33 ± 5.12 | 4313.82 ± 2388.56 |               |                  |  1206.23 ± 503.70 |  1205.35 ± 503.70 |  1206.23 ± 503.70 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |   tg512 (c5) |     239.44 ± 2.15 |      53.04 ± 2.59 | 286.67 ± 2.36 |     60.73 ± 3.28 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 | pp4096 (c10) |   10886.00 ± 5.53 | 2825.89 ± 2244.88 |               |                  | 2156.23 ± 1063.13 | 2155.35 ± 1063.13 | 2156.23 ± 1063.13 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg512 (c10) |     344.62 ± 7.14 |      41.45 ± 3.67 | 476.67 ± 4.71 |     51.57 ± 3.75 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c1) |   10417.77 ± 0.49 |   10417.77 ± 0.49 |               |                  |     394.18 ± 0.05 |     393.30 ± 0.05 |     394.18 ± 0.05 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c1) |      82.39 ± 0.01 |      82.39 ± 0.01 |  83.00 ± 0.00 |     83.00 ± 0.00 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c2) |  10578.87 ± 12.74 | 7085.57 ± 1789.66 |               |                  |   618.48 ± 156.01 |   617.60 ± 156.01 |   618.48 ± 156.01 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c2) |    127.87 ± 11.04 |      72.06 ± 2.93 | 147.33 ± 0.94 |     76.83 ± 4.06 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  pp4096 (c5) |  10793.90 ± 10.69 | 4306.54 ± 2376.22 |               |                  |  1206.37 ± 502.33 |  1205.49 ± 502.33 |  1206.37 ± 502.33 |
| nvidia/Gemma-4-26B-A4B-NVFP4 |  tg1024 (c5) |     221.48 ± 5.64 |      54.97 ± 2.16 | 286.67 ± 2.36 |     67.00 ± 8.04 |                   |                   |                   |
| nvidia/Gemma-4-26B-A4B-NVFP4 | pp4096 (c10) |   10878.39 ± 2.35 | 2815.84 ± 2228.47 |               |                  | 2159.43 ± 1063.11 | 2158.55 ± 1063.11 | 2159.43 ± 1063.11 |
| nvidia/Gemma-4-26B-A4B-NVFP4 | tg1024 (c10) |    307.28 ± 35.99 |      43.37 ± 5.07 | 473.33 ± 4.71 |     57.53 ± 9.50 |                   |                   |                   |


## Gemma-4-26B-A4B-IT with MTP
With vllm 0.25.1, there is a bug when using draft model for Gemma 4. There is already an issue regarding this [#47794](https://github.com/vllm-project/vllm/issues/47794).

When it is resolved, will add the following and run the benchmark.
```bash
--spec-method mtp \
--spec-model google/gemma-4-26B-A4B-it-assistant \
--spec-tokens 4 \
```

## Gemma-4-E4B-it
I use this model mostly for synthetic data generation, so I will be comparing at different concurrency levels, prompt sizes and token generation but the depth will always be zero since my use case is not a multi-turn chat conversation but one off requests.


```bash
vllm.serve \
	    MODEL="cosmicproc/gemma-4-E4B-it-NVFP4" \
	    VERSION="$(VERSION)" \
	    VLLM_ARGS="--served-model-name gemma-4-E4B-it --kv-cache-dtype fp8 --gpu-memory-utilization 0.9 --enable-auto-tool-choice --tool-call-parser gemma4  --limit-mm-per-prompt '{\"image\":1,\"audio\":0}' --host 0.0.0.0 --port 8012"

uvx llama-benchy --base-url http://localhost:8012/v1 --model cosmicproc/gemma-4-E4B-it-NVFP4 --served-model-name gemma-4-E4B-it --tokenizer google/gemma-4-12B-it --concurrency 1 2 5 10 --pp 2048 4096 --tg 512 1024 --depth 0
```

### Prompt processing
 It saturates at around 22k tok/s.

**For prompts with 2048 tokens**

Concurrency    Overall throughput    Per-request throughput          TTFR
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━
             1     19.0K–19.5K tok/s         19.0K–19.5K tok/s    106–108 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             2          ~20.6K tok/s         10.4K–10.5K tok/s    195–198 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             5     22.0K–22.3K tok/s           5.6K–5.7K tok/s    391–393 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
            10     22.5K–22.8K tok/s           3.6K–3.7K tok/s    646–654 ms


**For prompts with 4096 tokens**

 Concurrency    Overall throughput    Per-request throughput          TTFR
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━
             1          ~19.4K tok/s              ~19.4K tok/s       ~212 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             2          ~20.5K tok/s              ~10.8K tok/s       ~380 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
             5          ~21.5K tok/s           6.7K–6.8K tok/s    681–687 ms
  ─────────────  ────────────────────  ────────────────────────  ────────────
            10          ~21.7K tok/s               ~4.6K tok/s       ~1.15 s


### Token generation

**512 generated tokens**

 Concurrency    Overall, PP 2K    Per request    Overall, PP 4K    Per request
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━
             1         119 tok/s      119 tok/s         114 tok/s      114 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             2         228 tok/s      115 tok/s         179 tok/s      110 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             5         416 tok/s      110 tok/s         397 tok/s       97 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
            10         754 tok/s       99 tok/s         623 tok/s       82 tok/s


***1024 generated tokens**

 Concurrency    Overall, PP 2K    Per request    Overall, PP 4K    Per request
  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━
             1         118 tok/s      118 tok/s         114 tok/s      114 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             2         184 tok/s      114 tok/s         161 tok/s      110 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
             5         393 tok/s      109 tok/s         344 tok/s      101 tok/s
  ─────────────  ────────────────  ─────────────  ────────────────  ─────────────
            10         596 tok/s       99 tok/s         556 tok/s       87 tok/s


Full output from llama-benchy

| model                           |         test |       t/s (total) |         t/s (req) |       peak t/s |   peak t/s (req) |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:--------------------------------|-------------:|------------------:|------------------:|---------------:|-----------------:|-----------------:|-----------------:|-----------------:|
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c1) | 19538.67 ± 326.19 | 19538.67 ± 326.19 |                |                  |    105.77 ± 1.76 |    104.90 ± 1.76 |    105.77 ± 1.76 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c1) |     119.23 ± 0.75 |     119.23 ± 0.75 |  119.67 ± 0.94 |    119.67 ± 0.94 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c2) | 20593.28 ± 293.17 | 10539.91 ± 343.57 |                |                  |    195.47 ± 6.17 |    194.59 ± 6.17 |    195.47 ± 6.17 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c2) |     228.04 ± 2.90 |     115.19 ± 0.17 |  233.00 ± 0.00 |    116.50 ± 0.50 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c5) |  22312.87 ± 16.84 | 5625.38 ± 1778.82 |                |                  |   391.08 ± 85.02 |   390.20 ± 85.02 |   391.08 ± 85.02 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c5) |    416.36 ± 35.42 |     109.96 ± 5.48 | 538.00 ± 25.57 |    113.86 ± 5.33 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 | pp2048 (c10) | 22790.83 ± 101.27 | 3677.14 ± 1575.09 |                |                  |  645.61 ± 215.44 |  644.73 ± 215.44 |  645.61 ± 215.44 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg512 (c10) |    753.87 ± 33.30 |     99.45 ± 10.32 | 982.33 ± 22.17 |   107.01 ± 13.95 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c1) | 19043.74 ± 256.09 | 19043.74 ± 256.09 |                |                  |    108.49 ± 1.45 |    107.61 ± 1.45 |    108.49 ± 1.45 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c1) |     117.94 ± 0.05 |     117.94 ± 0.05 |  119.00 ± 0.00 |    119.00 ± 0.00 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c2) | 20607.54 ± 396.05 | 10415.50 ± 217.66 |                |                  |    197.69 ± 4.08 |    196.81 ± 4.08 |    197.69 ± 4.08 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c2) |     184.48 ± 6.87 |     114.15 ± 0.73 |  229.00 ± 0.00 |    115.83 ± 1.57 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp2048 (c5) |  21968.78 ± 65.33 | 5732.13 ± 2125.20 |                |                  |   392.80 ± 95.52 |   391.92 ± 95.52 |   392.80 ± 95.52 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c5) |    393.29 ± 55.61 |     109.23 ± 2.44 |  547.33 ± 3.09 |    113.55 ± 2.19 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 | pp2048 (c10) | 22490.29 ± 126.85 | 3631.94 ± 1552.39 |                |                  |  653.76 ± 218.73 |  652.88 ± 218.73 |  653.76 ± 218.73 |
| cosmicproc/gemma-4-E4B-it-NVFP4 | tg1024 (c10) |    596.48 ± 75.84 |      99.20 ± 6.14 | 1035.33 ± 3.86 |    108.37 ± 4.56 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c1) |  19396.43 ± 47.27 |  19396.43 ± 47.27 |                |                  |    212.12 ± 0.54 |    211.24 ± 0.54 |    212.12 ± 0.54 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c1) |     113.78 ± 0.01 |     113.78 ± 0.01 |  115.00 ± 0.00 |    115.00 ± 0.00 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c2) | 20535.85 ± 100.95 | 10836.64 ± 553.50 |                |                  |   379.91 ± 19.28 |   379.04 ± 19.28 |   379.91 ± 19.28 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c2) |    179.41 ± 27.82 |     110.16 ± 1.28 |  222.00 ± 0.00 |    112.00 ± 1.41 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c5) |  21442.21 ± 42.92 | 6735.73 ± 2530.07 |                |                  |  687.46 ± 216.25 |  686.58 ± 216.25 |  687.46 ± 216.25 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |   tg512 (c5) |    397.20 ± 23.04 |     97.11 ± 13.99 | 503.67 ± 23.10 |   104.35 ± 14.87 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 | pp4096 (c10) |  21679.41 ± 32.36 | 4565.65 ± 2604.22 |                |                  | 1151.59 ± 493.19 | 1150.72 ± 493.19 | 1151.59 ± 493.19 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg512 (c10) |    622.68 ± 55.36 |     82.43 ± 13.03 | 939.00 ± 29.70 |     97.40 ± 9.40 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c1) | 19394.95 ± 101.89 | 19394.95 ± 101.89 |                |                  |    212.14 ± 1.11 |    211.26 ± 1.11 |    212.14 ± 1.11 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c1) |     114.04 ± 0.09 |     114.04 ± 0.09 |  115.00 ± 0.00 |    115.00 ± 0.00 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c2) | 20499.64 ± 145.90 | 10848.79 ± 586.92 |                |                  |   379.66 ± 20.38 |   378.78 ± 20.38 |   379.66 ± 20.38 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c2) |    161.39 ± 22.12 |     110.31 ± 1.89 |  216.67 ± 7.54 |    112.37 ± 2.50 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  pp4096 (c5) |  21516.19 ± 44.70 | 6814.11 ± 2569.91 |                |                  |  680.55 ± 215.79 |  679.68 ± 215.79 |  680.55 ± 215.79 |
| cosmicproc/gemma-4-E4B-it-NVFP4 |  tg1024 (c5) |    343.59 ± 29.46 |     100.78 ± 6.28 |  520.00 ± 0.00 |    108.93 ± 3.02 |                  |                  |                  |
| cosmicproc/gemma-4-E4B-it-NVFP4 | pp4096 (c10) |  21680.71 ± 22.78 | 4569.83 ± 2604.62 |                |                  | 1150.87 ± 493.60 | 1149.99 ± 493.60 | 1150.87 ± 493.60 |
| cosmicproc/gemma-4-E4B-it-NVFP4 | tg1024 (c10) |     555.69 ± 7.51 |     86.95 ± 11.16 | 950.00 ± 14.14 |    101.07 ± 7.91 |                  |                  |                  |
