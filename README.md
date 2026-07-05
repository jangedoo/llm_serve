# llm-serve

Multi-engine LLM serving workspace. Build and run various LLM inference engines
from source with optimal platform-specific flags.

## Structure

```
.
├── Makefile       # orchestrator — all targets via `make help`
├── README.md
├── AGENTS.md
└── engines/
    ├── llama.cpp/ # git submodule
    ├── vllm/      # future
    └── sglang/    # future
```

## Quick start (llama.cpp)

```bash
make llama.init   # clone + recursive submodules
make llama.build  # cmake with auto-detected CPU/CUDA flags
make llama.server # start OpenAI-compatible API on :8080
```

Model files are loaded from Hugging Face's default cache
(`~/.cache/huggingface/`). Use `-hf user/model` flags or pass `LLAMA_ARGS`
to override.

## Gemma 4 E4B with vLLM

```bash
make vllm.install
make vllm.gemma4
```

This serves `cosmicproc/gemma-4-E4B-it-NVFP4` as `gemma-4-E4B-it` through an
OpenAI-compatible API on port 8000.

## All targets

```
make help          # list everything
make info          # show detected CPU / CUDA capabilities
make llama.init    # git submodule add + recursive init
make llama.update  # git submodule update --remote --recursive
make llama.build   # build with optimal flags
make llama.build.cpu  # force CPU-only build
make llama.clean   # remove build artifacts
make llama.server  # run llama-server (LLAMA_ARGS="..." for extra flags)
```

## Cloning on another machine

```bash
git clone --recurse-submodules <repo-url>
make llama.build
```

The Makefile auto-detects CPU features (AVX2, FMA, F16C, SSE4.2, SHA) and
CUDA toolkit availability at build time — no per-machine configuration needed.

## Adding a new engine

Add a new section to the Makefile following the `engine.action` naming
convention (e.g. `vllm.build`, `sglang.init`). The `help` target picks up
any target annotated with `##`.
