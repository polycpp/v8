# Agentic Workflow: Adding V8 Version Support

This document defines the complete workflow for adding MSVC CMake build support
for a new V8 version. It is designed to be executed by a coordinator agent
that delegates to specialized sub-agents.

## Overview

```
┌─────────────────────────────────────────────────┐
│                  COORDINATOR                     │
│  Reads: prompts/coordinator.md                   │
│  Manages state, makes decisions, delegates       │
└──────────┬──────────────────────────┬────────────┘
           │                          │
    ┌──────▼──────┐           ┌──────▼──────┐
    │  Sub-Agents │           │  Sub-Agents │
    │  (Phase 1-2)│           │  (Phase 3-5)│
    │  Discovery  │           │  Build Loop │
    └─────────────┘           └─────────────┘
```

## Phase 0: Branch Creation

**IMPORTANT**: Version branches must be **orphan branches** (no shared history
with `dev` or other version branches). Each version branch contains only the
build files for that specific V8 version.

```
Coordinator:
  1. Work in a temporary area or on dev initially
  2. After everything is ready, create an orphan branch:
     git checkout --orphan v8-{VERSION}
     git rm -rf . && git clean -fd
     # Add only the build files (CMakeLists.txt, cmake/, fetch_deps.py, patches/, test/)
     git add CMakeLists.txt cmake/ fetch_deps.py patches/ test/
     git commit -m "Add V8 {VERSION} MSVC CMake build"
```

## Phase 1: Setup & Discovery

```
Coordinator:
  1. Generate fetch_deps.py: python scripts/generate_fetch_deps.py --version {VERSION}
  2. Execute fetch_deps.py to download V8 source + deps
  3. Run feature detection: python scripts/detect_features.py --source-dir v8-src
  4. Review features manifest
  5. If features look wrong → investigate manually
  6. If features look right → proceed to Phase 2
```

## Phase 2: Source Adaptation

The most effective approach (proven on 14.1) is to copy cmake files from the
**nearest working version branch** and adapt, rather than generating from scratch.

```
Coordinator:
  1. Copy cmake/ files from nearest version branch (e.g., git show v8-14.3:cmake/sources.cmake)
  2. Run source diff check (see "Source Diff Workflow" below)
  3. Remove files that don't exist in the new version
  4. Add files that are new in this version (verify they compile)
  5. Check torque files: verify all .tq files in torque.cmake exist
  6. Update CMakeLists.txt version number
  7. Update generate_icu_data.py (ICU version auto-detection handles this)
  8. Delegate → [source_generation] generate torque file list
  3. Generate CMakeLists.txt from template + features
  4. Copy stable cmake modules
  5. Delegate → [plan_review] review the generated files
  6. If review says REVISE → fix issues, re-review
  7. If review says APPROVE → proceed to Phase 3
```

## Phase 3: Build Loop (the core feedback loop)

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │  BUILD    │───►│ ERROR        │───►│ CATEGORIZE &  │  │
│  │  ATTEMPT  │    │ CAPTURE      │    │ PRIORITIZE    │  │
│  └──────────┘    └──────────────┘    └───────┬───────┘  │
│       ▲                                       │          │
│       │          ┌──────────────┐    ┌───────▼───────┐  │
│       │          │ REVIEW       │◄───│ APPLY         │  │
│       └──────────│ CHANGES      │    │ FIXES         │  │
│                  └──────────────┘    └───────────────┘  │
│                                                          │
│  Exit conditions:                                        │
│  - Build succeeds → Phase 4                              │
│  - 20 iterations → escalate to human                     │
│  - Errors not decreasing for 3 iterations → rethink      │
└──────────────────────────────────────────────────────────┘

Coordinator:
  iteration = 0
  prev_error_count = infinity
  stall_count = 0

  while true:
    iteration += 1

    # Step 1: Build
    result = delegate → [build_attempt] attempt build
    if result.success:
      break → Phase 4

    # Step 2: Analyze errors
    analysis = delegate → [error_analysis] analyze errors
    error_count = analysis.unique_errors

    # Step 3: Check progress
    if error_count >= prev_error_count:
      stall_count += 1
    else:
      stall_count = 0

    if iteration >= 20 or stall_count >= 3:
      escalate to human with full report
      break

    # Step 4: Fix
    for category in analysis.recommended_fix_order:
      if category == "MISSING_SOURCE":
        fix sources.cmake directly
      elif category == "MISSING_DEFINITION":
        fix CMakeLists.txt directly
      elif category == "MSVC_CODE_ISSUE":
        delegate → [patch_creation] create/extend patch
      elif category == "MISSING_DEPENDENCY":
        fix fetch_deps.py and re-fetch
      elif category == "LINKER_ERROR":
        analyze and fix (may need sources.cmake or library order)

    # Step 5: Review fixes before rebuilding
    review = delegate → [implementation_review] review changes
    if review.verdict == "ROLLBACK":
      revert changes, try different approach
    elif review.verdict == "FIX_FIRST":
      apply recommended additional fixes

    prev_error_count = error_count
```

## Phase 4: Verification

```
Coordinator:
  1. Delegate → [test_verification] run all tests
  2. Review results:
     - PASS → proceed to Phase 5
     - ACCEPTABLE → note issues, proceed to Phase 5
     - FAIL → analyze failures, may loop back to Phase 3
```

## Phase 5: Polish

```
Coordinator:
  1. Minimize patch (remove unnecessary hunks)
  2. Update README with version info and test results
  3. Verify cmake install and find_package work
  4. Final human review
  5. Push branch
  6. Update main branch version table
```

## State Tracking

The coordinator should maintain a state file (`build_state.json`) during the process:

```json
{
  "version": "13.6.233.17",
  "phase": "build_loop",
  "iteration": 5,
  "prev_error_count": 42,
  "stall_count": 0,
  "errors_history": [312, 156, 89, 52, 42],
  "patches_applied": 3,
  "sources_modified": 12,
  "elapsed_minutes": 45,
  "notes": ["Disabled Maglev — too many errors, version predates stabilization"]
}
```

## Prompt Templates

The coordinator generates sub-agent prompts by filling in templates from `prompts/sub/`:

```
For each sub-agent call:
  1. Read the template from prompts/sub/{task}.md
  2. Replace {VARIABLES} with current context
  3. Append any iteration-specific context (previous errors, etc.)
  4. Send to sub-agent
  5. Validate sub-agent output format matches expected schema
  6. If output is malformed, retry with clarification
```

## Version Execution Order

Work from newest to oldest (smallest diff first):

1. **V8 14.1.146.11** (Node 25) — nearly identical to 14.3, validates tooling
2. **V8 13.6.233.17** (Node 24 LTS) — small differences, high value
3. **V8 12.4.254.21** (Node 22 LTS) — moderate differences
4. **V8 11.3.244.8** (Node 20 LTS) — Maglev/Turboshaft boundary
5. **V8 10.2.154.26** (Node 18 LTS) — major architectural differences
6. **V8 9.4.146.26** (Node 16 LTS) — most different, hardest

After each version is complete:
- Update `main` branch version table
- Document lessons learned in `docs/VERSION_GUIDE.md`
- Update `docs/MSVC_PATTERNS.md` with new patterns discovered
- Refine prompts based on what worked/didn't work

## Practical Tips (learned from V8 14.1 port)

### Source Diff Workflow

The fastest way to adapt sources.cmake for a new version:

```python
# Check which files from the reference sources.cmake are missing
import re, os
with open('cmake/sources.cmake') as f:
    files = re.findall(r'src/[^\s)]+\.(?:cc|c|cpp)', f.read())
missing = [f for f in files if not os.path.exists(f'v8-src/{f}')]
print(f'Missing: {len(missing)}')
for m in missing: print(f'  - {m}')
```

Then check key directories for new files:
```python
check_dirs = ['src/compiler/turboshaft', 'src/maglev', 'src/wasm', 'src/sandbox']
# Compare .cc files on disk vs files in sources.cmake
```

### MSVC Patch Application

When porting a patch from a nearby version:
1. Try `git apply --check` first to see which hunks fail
2. Use `git apply --exclude=<file>` to apply everything that works
3. Manually fix the excluded files by reading the patch and adapting

### Highway Source Location

Highway .cc files moved between versions:
- V8 14.3+: `src/hwy/*.cc` (V8-local copy)
- V8 14.1 and earlier: `third_party/highway/src/hwy/*.cc`

Check which exists and adjust `V8_HIGHWAY_SOURCES` accordingly.

### ICU Version

Each V8 version bundles a different ICU version. The ICU data symbol name
includes the version (e.g., `icudt74_dat`, `icudt78_dat`). The
`generate_icu_data.py` auto-detects this from `uvernum.h`.

### Inspector Stub

The `v8-inspector-stub.cc` file provides minimal implementations of the
`V8Inspector` pure virtual methods so d8 can link without the full inspector
protocol generator. Each V8 version has slightly different API methods.

To regenerate the stub for a new version:
1. Read `include/v8-inspector.h`
2. Find all pure virtual methods in the `V8Inspector` class
3. Provide no-op implementations
4. Provide constructor definitions for `V8StackTraceId` (declared but defined in inspector sources)

### Build Parallelism

MSVC runs out of heap space (`C1060`) when compiling many V8 compiler files
in parallel. Use `-j 4` or `-j 8` instead of `-j 16` for the build step.
The compiler files in `src/compiler/` are especially heavy.

### Test Considerations

**mjsunit**: Must run from `v8-src/` directory. Test flag parsing must scan
the first ~30 lines of each file (not stop at first non-comment line).
Expected pass rate: ~97% for modern versions.

**v8_unittests**: `InitializePlatformForTesting` aborts if the V8 platform
was already initialized. This prevents running all tests in a single process.
Individual test suites work fine. This is a V8 test infrastructure limitation,
not a build issue.
