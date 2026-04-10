# V8 MSVC Build -- Dev Branch

Tooling, scripts, and agent prompts for adding MSVC CMake build support
for new V8 versions. This branch is NOT for building V8 -- see the version
branches (e.g., `v8-14.3.127.18`) for that.

## What's Here

```
scripts/           Automation scripts
  orchestrate.py     Master "add new version" pipeline
  parse_gn.py        GN (BUILD.gn) file parser
  generate_sources.py    BUILD.gn -> cmake/sources.cmake
  generate_torque_list.py  Extract .tq file lists
  generate_fetch_deps.py   V8 DEPS -> fetch_deps.py (pinned checkout enforcement)
  detect_features.py       Source tree -> feature manifest

prompts/           Agent prompt files
  coordinator.md     Top-level coordinator prompt
  workflow.md        Full workflow with feedback loops
  sub/               Sub-agent prompt templates
    error_analysis.md
    source_generation.md
    patch_creation.md
    build_attempt.md
    test_verification.md
    plan_review.md
    implementation_review.md

docs/              Reference documentation
  AGENT_WORKFLOW.md  How to use this tooling
  MSVC_PATTERNS.md   Catalog of MSVC fix patterns
  VERSION_GUIDE.md   Per-version notes and lessons
```

## Quick Start

```bash
python scripts/orchestrate.py --version 13.6.233.17 --node-version v24.14.1
```

See `docs/AGENT_WORKFLOW.md` for full instructions.

## Target Versions

| Order | V8 Version | Node.js | Difficulty |
|-------|-----------|---------|------------|
| 1 | 14.1.146.11 | v25 | Very Low |
| 2 | 13.6.233.17 | v24 LTS | Low |
| 3 | 12.4.254.21 | v22 LTS | Medium |
| 4 | 11.3.244.8 | v20 LTS | Medium-High |
| 5 | 10.2.154.26 | v18 LTS | High |
| 6 | 9.4.146.26 | v16 LTS | Very High |
