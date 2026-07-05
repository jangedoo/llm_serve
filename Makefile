SHELL := /bin/bash
.DEFAULT_GOAL := help

LLAMA_DIR   := engines/llama.cpp
LLAMA_REPO  := https://github.com/ggml-org/llama.cpp.git
LLAMA_BUILD := $(LLAMA_DIR)/build
NCORES      := $(shell nproc)

TAG    ?= latest
BRANCH ?=

LLAMA_BUILD_BASE := $(LLAMA_DIR)/build
LATEST_LINK      := $(LLAMA_BUILD_BASE)/latest

# ── vLLM directories ────────────────────────────────────────────────────────────

VLLM_DIR   := engines/vllm
VLLM_VENVS := $(VLLM_DIR)/venvs
VLLM_LATEST := $(VLLM_VENVS)/latest

_CUDA_VER := $(shell nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[\d.]+' | head -1)

_CUDA_MAP_13  := $(if $(filter 13%,$(_CUDA_VER)),cu130)
_CUDA_MAP_129 := $(if $(filter 12.9%,$(_CUDA_VER)),cu129)
_CUDA_MAP_128 := $(if $(filter 12.8%,$(_CUDA_VER)),cu128)
_CUDA_MAP_124 := $(if $(filter 12.4%,$(_CUDA_VER)),cu124)
_CUDA_MAP_118 := $(if $(filter 11.8%,$(_CUDA_VER)),cu118)

_CUDA_VARIANT := $(or $(_CUDA_MAP_13),$(_CUDA_MAP_129),$(_CUDA_MAP_128),$(_CUDA_MAP_124),$(_CUDA_MAP_118),cu130)

# ── Platform detection ────────────────────────────────────────────────────────

CUDA_FOUND := $(shell which nvcc >/dev/null 2>&1 && echo 1 || echo 0)

CPU_FLAGS := $(shell \
  flags=""; \
  grep -q avx2    /proc/cpuinfo 2>/dev/null && flags="$$flags -DGGML_AVX2=ON";   \
  grep -q fma     /proc/cpuinfo 2>/dev/null && flags="$$flags -DGGML_FMA=ON";    \
  grep -q f16c    /proc/cpuinfo 2>/dev/null && flags="$$flags -DGGML_F16C=ON";   \
  grep -q sse4_2  /proc/cpuinfo 2>/dev/null && flags="$$flags -DGGML_SSE42=ON";  \
  grep -q bmi2    /proc/cpuinfo 2>/dev/null && flags="$$flags -DGGML_BMI2=ON";   \
  [ -z "$$flags" ] && flags="-DGGML_NATIVE=ON"; \
  echo $$flags; \
)

CUDA_ARCHS := $(shell \
  if command -v nvidia-smi &>/dev/null; then \
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | \
      awk -F. '/^[0-9]+\.[0-9]+$$/ { arch = $$1 $$2; if (arch == "120") arch = "120a"; \
        if (!seen[arch]++) { printf "%s%s", sep, arch; sep = ";" } }'; \
  fi \
)

GPU ?= $(shell \
  nvidia-smi --query-gpu=pci.bus_id,memory.total --format=csv,noheader,nounits 2>/dev/null | \
    sort -t, -k1,1 | \
    awk -F, '{ gsub(/ /, "", $$2); if ($$2 + 0 > memory) { memory = $$2 + 0; gpu = NR - 1 } } \
      END { if (NR) print gpu }' \
)

CUDA_FLAGS := $(shell \
  if [ $(CUDA_FOUND) -eq 1 ]; then \
    echo "-DGGML_CUDA=ON"; \
    [ -n "$(CUDA_ARCHS)" ] && echo "-DCMAKE_CUDA_ARCHITECTURES=$(CUDA_ARCHS)"; \
  fi \
)

# ── Help ──────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z0-9._-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

info: ## Show detected platform info
	@echo "CPU cores        : $(NCORES)"
	@echo "CPU flags        : $(CPU_FLAGS)"
	@echo "CUDA toolkit     : $$([ $(CUDA_FOUND) -eq 1 ] && echo 'found' || echo 'not found')"
	@echo "CUDA architectures: $$([ -n '$(CUDA_ARCHS)' ] && echo '$(CUDA_ARCHS)' || echo 'N/A')"
	@echo ""

# ── llama.cpp init / update ───────────────────────────────────────────────────

llama.init: ## Clone llama.cpp as a git submodule (run once)
	@if [ -d "$(LLAMA_DIR)" ]; then \
	  echo "llama.cpp already exists at $(LLAMA_DIR)"; \
	else \
	  echo "Adding llama.cpp submodule..."; \
	  git submodule add "$(LLAMA_REPO)" "$(LLAMA_DIR)"; \
	  git submodule update --init --recursive; \
	  echo "Done. Run 'make llama.build' to compile."; \
	fi

llama.update: ## Pull latest llama.cpp (including its submodules)
	@git submodule update --remote --recursive

# ── Build ─────────────────────────────────────────────────────────────────────

llama.build: _llama_fetch ## Build llama.cpp (default: latest release; args: TAG=b9860, BRANCH=main)
	@ref=$$(if [ -n "$(BRANCH)" ]; then echo "$(BRANCH)"; \
	  elif [ "$(TAG)" != "latest" ]; then echo "$(TAG)"; \
	  else set -o pipefail; curl -sL --max-time 10 \
	    https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
	    | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4; fi); \
	if [ -z "$$ref" ]; then \
	  echo "GitHub API failed, falling back to latest git tag..." >&2; \
	  ref=$$(git -C "$(LLAMA_DIR)" tag --list 'b*' --sort=-version:refname | head -1); \
	fi; \
	if [ -z "$$ref" ]; then echo "Error: could not resolve ref to build" >&2; exit 1; fi; \
	echo "=== Building ref: $$ref ==="; \
	build_dir="$(LLAMA_BUILD_BASE)/$$ref"; \
	mkdir -p "$$build_dir"; \
	if [ -n "$(BRANCH)" ]; then \
	  git -C "$(LLAMA_DIR)" checkout -B "$(BRANCH)" "origin/$(BRANCH)"; \
	else \
	  git -C "$(LLAMA_DIR)" checkout "tags/$$ref"; \
	fi; \
	echo "Building with flags: $(CPU_FLAGS) $(CUDA_FLAGS)"; \
	cmake -S "$(LLAMA_DIR)" -B "$$build_dir" \
	  -DCMAKE_BUILD_TYPE=Release \
	  $(CPU_FLAGS) $(CUDA_FLAGS); \
	cmake --build "$$build_dir" --parallel "$(NCORES)"; \
	if [ -z "$(BRANCH)" ] && [ "$(TAG)" = "latest" ]; then \
	  rm -f "$(LATEST_LINK)"; \
	  ln -sf "$$ref" "$(LATEST_LINK)"; \
	  echo "Symlinked $(LATEST_LINK) -> $$ref"; \
	fi; \
	echo ""; \
	echo "Binaries in $$build_dir/bin/"; \
	ls "$$build_dir/bin/"

llama.build.cpu: _llama_fetch ## Build llama.cpp CPU-only (args: TAG=b9860, BRANCH=main)
	@ref=$$(if [ -n "$(BRANCH)" ]; then echo "$(BRANCH)"; \
	  elif [ "$(TAG)" != "latest" ]; then echo "$(TAG)"; \
	  else set -o pipefail; curl -sL --max-time 10 \
	    https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
	    | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4; fi); \
	if [ -z "$$ref" ]; then \
	  echo "GitHub API failed, falling back to latest git tag..." >&2; \
	  ref=$$(git -C "$(LLAMA_DIR)" tag --list 'b*' --sort=-version:refname | head -1); \
	fi; \
	if [ -z "$$ref" ]; then echo "Error: could not resolve ref to build" >&2; exit 1; fi; \
	echo "=== Building ref: $$ref (CPU-only) ==="; \
	build_dir="$(LLAMA_BUILD_BASE)/$$ref"; \
	mkdir -p "$$build_dir"; \
	if [ -n "$(BRANCH)" ]; then \
	  git -C "$(LLAMA_DIR)" checkout -B "$(BRANCH)" "origin/$(BRANCH)"; \
	else \
	  git -C "$(LLAMA_DIR)" checkout "tags/$$ref"; \
	fi; \
	echo "Building CPU-only with flags: $(CPU_FLAGS)"; \
	cmake -S "$(LLAMA_DIR)" -B "$$build_dir" \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DGGML_CUDA=OFF \
	  $(CPU_FLAGS); \
	cmake --build "$$build_dir" --parallel "$(NCORES)"; \
	if [ -z "$(BRANCH)" ] && [ "$(TAG)" = "latest" ]; then \
	  rm -f "$(LATEST_LINK)"; \
	  ln -sf "$$ref" "$(LATEST_LINK)"; \
	  echo "Symlinked $(LATEST_LINK) -> $$ref"; \
	fi; \
	echo ""; \
	echo "Binaries in $$build_dir/bin/"; \
	ls "$$build_dir/bin/"

llama.clean: ## Remove all llama.cpp build artifacts
	@rm -rf "$(LLAMA_BUILD_BASE)"
	@echo "Cleaned $(LLAMA_BUILD_BASE)"

llama.build.clean: ## Remove build for a specific ref (args: TAG=b9860 / BRANCH=main)
	@ref=$$(if [ -n "$(BRANCH)" ]; then echo "$(BRANCH)"; \
	  elif [ "$(TAG)" != "latest" ]; then echo "$(TAG)"; \
	  else echo ""; fi); \
	if [ -z "$$ref" ]; then \
	  echo "Usage: make llama.build.clean TAG=b9860"; exit 1; \
	fi; \
	target="$(LLAMA_BUILD_BASE)/$$ref"; \
	if [ -d "$$target" ]; then \
	  rm -rf "$$target"; \
	  echo "Cleaned $$target"; \
	else \
	  echo "No build at $$target"; \
	fi; \
	if [ "$$ref" = "latest" ] && [ -L "$(LATEST_LINK)" ]; then \
	  rm -f "$(LATEST_LINK)"; \
	  echo "Removed symlink $(LATEST_LINK)"; \
	fi

llama.build.ref: _llama_fetch ## Show which ref would be built
	@ref=$$(if [ -n "$(BRANCH)" ]; then echo "$(BRANCH)"; \
	  elif [ "$(TAG)" != "latest" ]; then echo "$(TAG)"; \
	  else set -o pipefail; curl -sL --max-time 10 \
	    https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
	    | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4; fi); \
	if [ -z "$$ref" ]; then \
	  echo "GitHub API failed, falling back to latest git tag..." >&2; \
	  ref=$$(git -C "$(LLAMA_DIR)" tag --list 'b*' --sort=-version:refname | head -1); \
	fi; \
	if [ -z "$$ref" ]; then echo "Error: could not resolve ref" >&2; exit 1; fi; \
	echo "$$ref"

# ── Run ───────────────────────────────────────────────────────────────────────

PRESET      ?= preset.ini
MODEL_ALIAS ?=

# Aliases for convenience — MODEL=Qwen3.6-35B-A3B expands to full HF ref
MODEL_QWEN35A3B := unsloth/Qwen3.6-35B-A3B-GGUF:Qwen3.6-35B-A3B-UD-Q4_K_M
MODEL_GEMMA4   := unsloth/gemma-4-E4B-it-GGUF:gemma-4-E4B-it-UD-Q4_K_XL
MODEL_QWEN27B  := unsloth/Qwen3.6-27B-GGUF:Qwen3.6-27B-Q4_K_M
MODEL_QWEN27B_MTP := unsloth/Qwen3.6-27B-MTP-GGUF:Qwen3.6-27B-UD-Q4_K_XL

llama.server: ## Start llama-server (args: LLAMA_ARGS="...", MODEL=<alias|hf-ref>, PRESET=...)
	@if [ -n "$(LLAMA_BUILD_DIR)" ]; then \
	  dir="$(LLAMA_BUILD_DIR)"; \
	elif [ -L "$(LATEST_LINK)" ]; then \
	  dir="$(LATEST_LINK)"; \
	else \
	  echo "No build found. Run 'make llama.build' first."; \
	  exit 1; \
	fi; \
	if [ ! -f "$$dir/bin/llama-server" ]; then \
	  echo "llama-server not found in $$dir"; exit 1; \
	fi; \
	if [ -n "$(MODEL)" ]; then \
	  ref="$(MODEL)"; \
	  case "$$ref" in \
	    Qwen3.6-35B-A3B) ref="$(MODEL_QWEN35A3B)" ;; \
	    gemma-4-E4B-it)  ref="$(MODEL_GEMMA4)" ;; \
	    Qwen3.6-27B)     ref="$(MODEL_QWEN27B)" ;; \
	    Qwen3.6-27B-MTP) ref="$(MODEL_QWEN27B_MTP)" ;; \
	  esac; \
	  echo "Starting llama-server with model '$$ref' on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all --hf-repo "$$ref" $(LLAMA_ARGS); \
	elif [ -f "$(PRESET)" ]; then \
	  echo "Starting llama-server with preset $(PRESET) on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all --models-preset "$(PRESET)" --models-max 1 $(LLAMA_ARGS); \
	else \
	  echo "Starting llama-server on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all $(LLAMA_ARGS); \
	fi

# ── vLLM ────────────────────────────────────────────────────────────────────────

vllm.install: ## Install latest vLLM release (args: VERSION=x.y.z)
	@version="$(VERSION)"; \
	if [ -z "$$version" ]; then \
	  echo "Fetching latest vLLM version from PyPI..."; \
	  version=$$(curl -sL --max-time 10 'https://pypi.org/pypi/vllm/json' | \
	    python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])"); \
	  if [ -z "$$version" ]; then \
	    echo "Error: could not fetch latest version from PyPI" >&2; exit 1; \
	  fi; \
	fi; \
	venv_dir="$(VLLM_VENVS)/$$version"; \
	if [ -d "$$venv_dir" ]; then \
	  echo "vLLM $$version already installed at $$venv_dir"; \
	  rm -f "$(VLLM_LATEST)"; ln -sf "$$version" "$(VLLM_LATEST)"; \
	  echo "Symlinked $(VLLM_LATEST) -> $$version"; \
	  exit 0; \
	fi; \
	echo "=== Installing vLLM $$version ==="; \
	mkdir -p "$$venv_dir"; \
	uv venv "$$venv_dir" --python 3.12; \
	uv pip install --python "$$venv_dir/bin/python" "vllm==$$version"; \
	rm -f "$(VLLM_LATEST)"; ln -sf "$$version" "$(VLLM_LATEST)"; \
	echo "Symlinked $(VLLM_LATEST) -> $$version"; \
	echo "Done. Run 'make vllm.serve MODEL=...'"

vllm.serve: ## Start vLLM server (args: MODEL=<hf-model>, VLLM_ARGS="...", VERSION=x.y.z)
	@venv=$$(if [ -n "$(VERSION)" ]; then echo "$(VLLM_VENVS)/$(VERSION)"; \
	  elif [ -L "$(VLLM_LATEST)" ]; then echo "$(VLLM_LATEST)"; \
	  else echo ""; fi); \
	if [ -z "$$venv" ] || [ ! -f "$$venv/bin/vllm" ]; then \
	  echo "vLLM not found. Run 'make vllm.install' first."; exit 1; \
	fi; \
	if [ -z "$(MODEL)" ]; then \
	  echo "MODEL is required. Usage: make vllm.serve MODEL=Qwen/Qwen2.5-7B-Instruct"; exit 1; \
	fi; \
	echo "Starting vLLM $$(basename "$$venv") with model $(MODEL)..."; \
	"$$venv/bin/vllm" serve "$(MODEL)" $(VLLM_ARGS)

vllm.gemma4: ## Serve Gemma 4 E4B NVFP4 on the largest GPU (args: GPU=N, VERSION=x.y.z)
	@venv=$$(if [ -n "$(VERSION)" ]; then echo "$(VLLM_VENVS)/$(VERSION)"; \
	  elif [ -L "$(VLLM_LATEST)" ]; then echo "$(VLLM_LATEST)"; \
	  else echo ""; fi); \
	if [ -z "$$venv" ] || [ ! -f "$$venv/bin/vllm" ]; then \
	  echo "vLLM not found. Run 'make vllm.install' first."; exit 1; \
	fi; \
	if [ -z "$(GPU)" ]; then \
	  echo "No NVIDIA GPU found. Set GPU=N to select one explicitly."; exit 1; \
	fi; \
	echo "Starting Gemma 4 E4B with PCI-order GPU $(GPU) on port 8000..."; \
	CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES="$(GPU)" \
	  "$$venv/bin/vllm" serve "cosmicproc/gemma-4-E4B-it-NVFP4" \
	    --served-model-name "gemma-4-E4B-it" \
	    --quantization compressed-tensors \
	    --kv-cache-dtype fp8 \
	    --max-model-len 131072 \
	    --gpu-memory-utilization 0.90 \
	    --limit-mm-per-prompt '{"image":1,"audio":0}' \
	    --host 0.0.0.0 \
	    --port 8000

vllm.list: ## List installed vLLM versions
	@if [ -d "$(VLLM_VENVS)" ]; then \
	  for d in "$(VLLM_VENVS)"/*/; do \
	    v=$$(basename "$$d"); \
	    if [ "$$v" != "latest" ]; then \
	      extra=""; \
	      [ -L "$(VLLM_LATEST)" ] && [ "$$(readlink "$(VLLM_LATEST)")" = "$$v" ] && extra=" <-- latest"; \
	      echo "  $$v$$extra"; \
	    fi; \
	  done; \
	else \
	  echo "  No versions installed"; \
	fi

vllm.clean: ## Remove all vLLM venvs
	@rm -rf "$(VLLM_VENVS)"
	@echo "Cleaned $(VLLM_VENVS)"

# ── Internal helpers ──────────────────────────────────────────────────────────

_llama_fetch: ## Fetch latest tags/refs from upstream
	@if [ ! -d "$(LLAMA_DIR)" ]; then \
	  echo "llama.cpp not found at $(LLAMA_DIR). Run 'make llama.init' first."; \
	  exit 1; \
	fi
	@git -C "$(LLAMA_DIR)" fetch --tags --force origin

_llama_prep: ## Ensure build dir exists (legacy)
	@mkdir -p "$(LLAMA_BUILD)"
