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

## Phase 1: Setup & Discovery

```
Coordinator:
  1. Create branch v8-{VERSION} from dev
  2. Delegate → [source_generation] generate fetch_deps.py
  3. Execute fetch_deps.py
  4. Delegate → [feature_detection] detect version features
  5. Review features manifest
  6. If features look wrong → investigate manually
  7. If features look right → proceed to Phase 2
```

## Phase 2: Code Generation

```
Coordinator:
  1. Delegate → [source_generation] generate sources.cmake
  2. Delegate → [source_generation] generate torque file list
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
