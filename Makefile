SHELL := /bin/bash
.DEFAULT_GOAL := help

LLAMA_DIR   := engines/llama.cpp
LLAMA_REPO  := https://github.com/ggml-org/llama.cpp.git
LLAMA_BUILD := $(LLAMA_DIR)/build
NCORES      := $(shell nproc)

# ── Platform detection ────────────────────────────────────────────────────────

CUDA_FOUND := $(shell which nvcc >/dev/null 2>&1 && echo 1 || echo 0)

CPU_FLAGS := $(shell \
  flags=""; \
  grep -q avx2    /proc/cpuinfo 2>/dev/null && flags="$$flags -DLLAMA_AVX2=ON";  \
  grep -q fma     /proc/cpuinfo 2>/dev/null && flags="$$flags -DLLAMA_FMA=ON";   \
  grep -q f16c    /proc/cpuinfo 2>/dev/null && flags="$$flags -DLLAMA_F16C=ON";  \
  grep -q sse4_2  /proc/cpuinfo 2>/dev/null && flags="$$flags -DLLAMA_SSE42=ON"; \
  grep -q sha_ni  /proc/cpuinfo 2>/dev/null && flags="$$flags -DLLAMA_SHA=ON";   \
  [ -z "$$flags" ] && flags="-DLLAMA_NATIVE=ON"; \
  echo $$flags; \
)

CUDA_CC := $(shell \
  if command -v nvidia-smi &>/dev/null; then \
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.'; \
  fi \
)

CUDA_FLAGS := $(shell \
  if [ $(CUDA_FOUND) -eq 1 ]; then \
    echo "-DLLAMA_CUDA=ON"; \
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

llama.build: ## Build llama.cpp with optimal flags for this machine
	@$(MAKE) _llama_prep
	@echo "Building with flags: $(CPU_FLAGS) $(CUDA_FLAGS)"
	cmake -S "$(LLAMA_DIR)" -B "$(LLAMA_BUILD)" \
	  -DCMAKE_BUILD_TYPE=Release \
	  $(CPU_FLAGS) \
	  $(CUDA_FLAGS)
	cmake --build "$(LLAMA_BUILD)" --parallel "$(NCORES)"
	@echo ""
	@echo "Binaries in $(LLAMA_BUILD)/bin/"
	@ls "$(LLAMA_BUILD)/bin/"

llama.build.cpu: ## Build CPU-only (ignore CUDA even if available)
	@$(MAKE) _llama_prep
	@echo "Building CPU-only with flags: $(CPU_FLAGS)"
	cmake -S "$(LLAMA_DIR)" -B "$(LLAMA_BUILD)" \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DLLAMA_CUDA=OFF \
	  $(CPU_FLAGS)
	cmake --build "$(LLAMA_BUILD)" --parallel "$(NCORES)"
	@echo ""
	@echo "Binaries in $(LLAMA_BUILD)/bin/"
	@ls "$(LLAMA_BUILD)/bin/"

llama.clean: ## Remove llama.cpp build artifacts
	@rm -rf "$(LLAMA_BUILD)"
	@echo "Cleaned $(LLAMA_BUILD)"

# ── Run ───────────────────────────────────────────────────────────────────────

llama.server: ## Start llama-server (args: LLAMA_ARGS="...")
	@if [ ! -f "$(LLAMA_BUILD)/bin/llama-server" ]; then \
	  echo "llama-server not built yet. Run 'make llama.build' first."; \
	  exit 1; \
	fi
	@echo "Starting llama-server on port 8080..."
	@$(LLAMA_BUILD)/bin/llama-server $(LLAMA_ARGS)

# ── Internal helpers ──────────────────────────────────────────────────────────

_llama_prep:
	@if [ ! -d "$(LLAMA_DIR)" ]; then \
	  echo "llama.cpp not found. Run 'make llama.init' first."; \
	  exit 1; \
	fi
	@mkdir -p "$(LLAMA_BUILD)"
