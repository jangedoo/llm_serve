# AGENTS.md — Instructions for AI coding assistants

## Project structure

```
./
├── Makefile          # single orchestrator — keep root minimal
├── README.md
├── AGENTS.md
├── .gitignore
└── engines/
    ├── llama.cpp/    # git submodule
    ├── vllm/         # future
    └── sglang/       # future
```

## Conventions

- **Root must stay lean.** Only `Makefile`, `README.md`, `AGENTS.md`, `.gitignore`
  live at the top level. Everything else goes under `engines/`.
- **Engine targets are namespaced.** `make <engine>.<action>` — e.g.
  `llama.build`, `vllm.serve`, `sglang.install`.
- **Self-documenting Makefile.** Every public target must have a `##` comment
  so `make help` picks it up.
- **Platform detection** lives in Makefile variables at the top (CPU_FLAGS,
  CUDA_FOUND, etc.). Build targets use these unconditionally.
- **Models come from ~/.cache/huggingface/** — never add a `models/` dir.

## Adding a new engine

1. Add the engine as a git submodule under `engines/` (or as a pip package
   if Python-based).
2. Add a `make <engine>.init` (if submodule) and `make <engine>.build` target.
3. Keep the cmake/ninja build inside `<engine>/build/`.
4. Annotate every target with `## <description>`.

## Reminders for the assistant

- Always run `make help` after modifying the Makefile to verify all targets
  are documented.
- Do not add comments to code files unless explicitly asked.
- Prefer editing existing files over creating new ones.
