# Agent Workflow Guide

This document explains how to use the tooling on the `dev` branch to add
MSVC CMake build support for a new V8 version.

## Quick Start

```bash
# 1. Start from the dev branch
git checkout dev

# 2. Run the orchestration script
python scripts/orchestrate.py --version 13.6.233.17 --node-version v24.14.1

# 3. The script will:
#    - Create branch v8-13.6.233.17
#    - Generate fetch_deps.py and fetch V8 source
#    - Detect version features
#    - Generate cmake/sources.cmake
#    - Generate CMakeLists.txt from template
#    - Copy stable cmake modules
#    - Attempt the first build
#    - Report what needs manual attention
```

## Repository Structure

```
dev branch:
├── scripts/           # Automation scripts
│   ├── orchestrate.py         # Master orchestration
│   ├── parse_gn.py            # GN file parser
│   ├── generate_sources.py    # BUILD.gn → sources.cmake
│   ├── generate_torque_list.py
│   ├── generate_fetch_deps.py # DEPS → fetch_deps.py
│   └── detect_features.py     # Feature detection → JSON
├── templates/         # Version-parameterized templates
│   ├── CMakeLists.txt.in
│   └── fetch_deps.py.in
├── cmake/             # Stable cmake modules (copied to version branches)
│   ├── icu.cmake
│   ├── abseil.cmake
│   ├── zlib.cmake
│   ├── snapshot.cmake
│   ├── targets.cmake
│   ├── install.cmake
│   ├── unittests.cmake
│   ├── msvc-toolchain.cmake
│   ├── generate_icu_data.py
│   └── v8Config.cmake.in
├── prompts/           # Agent prompts
│   ├── coordinator.md         # Top-level coordinator prompt
│   ├── workflow.md            # Full workflow definition
│   └── sub/                   # Sub-agent prompt templates
│       ├── error_analysis.md
│       ├── source_generation.md
│       ├── patch_creation.md
│       ├── build_attempt.md
│       ├── test_verification.md
│       ├── plan_review.md
│       └── implementation_review.md
├── docs/              # Reference documentation
│   ├── AGENT_WORKFLOW.md      # This file
│   ├── MSVC_PATTERNS.md       # Known MSVC fix patterns
│   └── VERSION_GUIDE.md       # Per-version notes and lessons
└── test/              # Test infrastructure
    ├── run_mjsunit.py
    └── hello_v8.cc
```

## Version Branch Structure (output)

Each generated version branch will contain:

```
v8-X.Y.Z.W branch:
├── CMakeLists.txt
├── README.md
├── fetch_deps.py
├── cmake/
│   ├── sources.cmake
│   ├── targets.cmake
│   ├── torque.cmake
│   ├── snapshot.cmake
│   ├── icu.cmake
│   ├── abseil.cmake (if applicable)
│   ├── zlib.cmake
│   ├── install.cmake
│   ├── unittests.cmake
│   ├── msvc-toolchain.cmake
│   ├── generate_icu_data.py
│   └── v8Config.cmake.in
├── patches/
│   └── 001-msvc-compatibility.patch
├── test/
│   ├── run_mjsunit.py
│   └── hello_v8.cc
└── docs/
    ├── test-results.md
    └── ...
```

## Scripts Reference

### `scripts/orchestrate.py`

Master script that runs the full pipeline.

```bash
python scripts/orchestrate.py \
  --version 13.6.233.17 \
  --node-version v24.14.1 \
  --reference-branch v8-14.3.127.18 \
  --skip-fetch          # Skip fetching if v8-src already has the right version
  --stop-after discover # Stop after discovery phase (don't attempt build)
```

### `scripts/detect_features.py`

Scans a V8 source tree and produces a feature manifest.

```bash
python scripts/detect_features.py --source-dir v8-src --output version_features.json
```

Output example:
```json
{
  "version": "13.6.233.17",
  "major": 13, "minor": 6,
  "cxx_standard": 20,
  "features": {
    "maglev": true,
    "turboshaft": true,
    "sparkplug": true,
    "webassembly": true,
    "sandbox": false,
    "i18n": true,
    "pointer_compression": true,
    "leaptiering": false
  },
  "third_party": {
    "abseil": true,
    "highway": true,
    "simdutf": true,
    "fp16": true,
    "dragonbox": true,
    "fast_float": true,
    "icu": true,
    "zlib": true
  }
}
```

### `scripts/generate_sources.py`

Parses BUILD.gn and generates cmake/sources.cmake.

```bash
python scripts/generate_sources.py \
  --source-dir v8-src \
  --features version_features.json \
  --output cmake/sources.cmake
```

### `scripts/parse_gn.py`

Library for parsing GN build files. Used by other scripts.

```python
from parse_gn import GnParser
parser = GnParser("v8-src/BUILD.gn")
sources = parser.get_sources("v8_compiler", platform="win", arch="x64")
```

## Manual Steps

These steps cannot be fully automated and require agent intelligence:

### 1. MSVC Patch Creation

Each V8 version has unique MSVC compilation issues. The agent must:
- Read error output
- Identify the root cause (using `docs/MSVC_PATTERNS.md`)
- Apply the minimal fix to V8 source
- Generate a clean patch

See `prompts/sub/patch_creation.md` for detailed guidance.

### 2. Build Error Triage

When the build produces hundreds of errors, the agent must:
- Identify root causes vs. cascade errors
- Fix root causes first
- Rebuild and re-evaluate

See `prompts/sub/error_analysis.md` for the categorization framework.

### 3. Source List Adjustment

The GN parser won't catch 100% of sources. The agent must:
- Cross-reference build errors with missing files
- Check the V8 source tree for files the parser missed
- Verify platform-conditional includes

## Feedback Loop Protocol

After each version is completed, update these files on `dev`:

1. **`docs/VERSION_GUIDE.md`** — Add notes about this version's quirks
2. **`docs/MSVC_PATTERNS.md`** — Add any new patterns discovered
3. **Prompts** — Refine any prompts that proved insufficient
4. **Scripts** — Fix any parser edge cases encountered

This ensures each subsequent version benefits from lessons learned.

## Target Versions (execution order)

| Order | V8 Version | Node.js | Difficulty |
|-------|-----------|---------|------------|
| 1 | 14.1.146.11 | v25 | Very Low |
| 2 | 13.6.233.17 | v24 LTS | Low |
| 3 | 12.4.254.21 | v22 LTS | Medium |
| 4 | 11.3.244.8 | v20 LTS | Medium-High |
| 5 | 10.2.154.26 | v18 LTS | High |
| 6 | 9.4.146.26 | v16 LTS | Very High |
