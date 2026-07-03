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

CUDA_CC := $(shell \
  if command -v nvidia-smi &>/dev/null; then \
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.'; \
  fi \
)

CUDA_FLAGS := $(shell \
  if [ $(CUDA_FOUND) -eq 1 ]; then \
    echo "-DGGML_CUDA=ON"; \
    [ -n "$(CUDA_CC)" ] && echo "-DCMAKE_CUDA_ARCHITECTURES=$(CUDA_CC)"; \
  fi \
)

# ── Help ──────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z._-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

info: ## Show detected platform info
	@echo "CPU cores        : $(NCORES)"
	@echo "CPU flags        : $(CPU_FLAGS)"
	@echo "CUDA toolkit     : $$([ $(CUDA_FOUND) -eq 1 ] && echo 'found' || echo 'not found')"
	@echo "CUDA compute cap : $$([ -n '$(CUDA_CC)' ] && echo '$(CUDA_CC)' || echo 'N/A')"
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
MODEL_QWEN27B  := unsloth/Qwen3.6-27B-MTP-GGUF:Qwen3.6-27B-UD-Q4_K_XL

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
	  esac; \
	  echo "Starting llama-server with model '$$ref' on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all --hf-repo "$$ref" $(LLAMA_ARGS); \
	elif [ -f "$(PRESET)" ]; then \
	  echo "Starting llama-server with preset $(PRESET) on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all --models-preset "$(PRESET)" $(LLAMA_ARGS); \
	else \
	  echo "Starting llama-server on port 8080..."; \
	  "$$dir/bin/llama-server" --tools all $(LLAMA_ARGS); \
	fi

# ── Internal helpers ──────────────────────────────────────────────────────────

_llama_fetch: ## Fetch latest tags/refs from upstream
	@if [ ! -d "$(LLAMA_DIR)" ]; then \
	  echo "llama.cpp not found at $(LLAMA_DIR). Run 'make llama.init' first."; \
	  exit 1; \
	fi
	@git -C "$(LLAMA_DIR)" fetch --tags --force origin

_llama_prep: ## Ensure build dir exists (legacy)
	@mkdir -p "$(LLAMA_BUILD)"
