# Version-Specific Guide

Lessons learned and notes for each V8 version. Updated after completing each version.

## V8 14.3.127.18 (Node.js v25+, Chrome 143)

**Status**: Complete (reference branch)
**Difficulty**: Baseline
**Patch size**: ~830 lines, 21 files

### Key characteristics
- C++20 required
- All modern features: Maglev, Turboshaft, Sparkplug, Leaptiering
- Full third-party deps: abseil, highway, simdutf, fp16, dragonbox, fast_float
- Sandbox available but off by default
- ICU with embedded data

### MSVC issues encountered
- `__attribute__((packed))` in multiple headers (P1)
- `__attribute__((visibility))` in API headers (P2)
- `__attribute__((tls_model))` in thread_local vars (P7)
- Template qualified base class calls (P3)
- Zero-length array in caged heap (P5)
- `__PRETTY_FUNCTION__` usage (P6)
- Various template/constexpr issues (P4, P9)
- Macro expansion with VA_OPT (P10)

### Test results
- v8_unittests: 5728/5735 (99.88%)
- mjsunit: 967/992 (97.5%)

---

## V8 14.1.146.11 (Node.js v25)

**Status**: Complete
**Actual difficulty**: Very Low
**Patch size**: ~882 lines, 22 files
**Test results**: mjsunit 965/989 (97.6%)

### Actual differences from 14.3
- 11 source files removed (src/hwy/*.cc moved back to third_party, turbolev-frontend-pipeline.cc, save-flags.cc, maglev-known-node-aspects.cc, wasm-tracing.cc)
- Highway sources at `third_party/highway/src/hwy/` instead of `src/hwy/`
- wasm-revec-phase.cc and wasm-revec-reducer.cc exist but reference undefined flags — must NOT be added
- ICU version 74 (vs 78 in 14.3) — `generate_icu_data.py` updated to auto-detect
- Inspector stub needed updates: `associateExceptionData` returns `bool` not `void`, `connectShared` is a new pure virtual, `compileAndRunInternalScript` doesn't exist, `logAPICalled` doesn't exist
- `V8StackTraceId` constructors need definitions in the stub (normally in inspector sources)

### MSVC patch porting
- 15/21 hunks from 14.3 patch applied cleanly
- 6 files needed manual fixes: maglev-graph-builder.cc (leaptiering ifdefs in params), regexp-bytecodes-inl.h (lambda template call), regexp-code-generator.cc (same pattern), wasm-code-manager.h (not needed — packed struct absent), wasm-objects.cc/h + module-instantiate.cc (drumbrake ifdefs in params), bytecode-generator-unittest.cc (not needed)

### Build notes
- `-j 16` causes MSVC heap exhaustion on compiler files, use `-j 4` or `-j 8`
- v8_unittests crash on `InitializePlatformForTesting` re-init (same as 14.3)

---

## V8 13.6.233.17 (Node.js v24 LTS)

**Status**: Not started
**Expected difficulty**: Low

### Expected differences from 14.3
- Some Turboshaft files may differ
- Leaptiering likely absent
- Some compile definitions may not exist yet
- Third-party deps should all be present

---

## V8 12.4.254.21 (Node.js v22 LTS)

**Status**: Not started
**Expected difficulty**: Medium

### Expected differences from 14.3
- Turboshaft may be partial/experimental
- Some newer heap refactoring not yet done
- Sandbox likely absent or very experimental
- Continuation-preserved embedder data likely absent

---

## V8 11.3.244.8 (Node.js v20 LTS)

**Status**: Not started
**Expected difficulty**: Medium-High

### Expected differences from 14.3
- Maglev may be experimental/partial
- Turboshaft likely absent or very early
- Significant source file differences
- Some third-party deps may be older versions or absent

---

## V8 10.2.154.26 (Node.js v18 LTS)

**Status**: Not started
**Expected difficulty**: High

### Expected differences from 14.3
- No Maglev
- No Turboshaft
- C++17 may be sufficient (verify)
- Sparkplug present but younger
- Significant architectural differences in heap/GC
- Some third-party deps (highway, simdutf, fp16) may be absent

---

## V8 9.4.146.26 (Node.js v16 LTS)

**Status**: Not started
**Expected difficulty**: Very High

### Expected differences from 14.3
- No Maglev, no Turboshaft, possibly no Sparkplug
- C++14 or C++17
- Very different GC architecture
- No abseil (or very early)
- No highway, simdutf, fp16, dragonbox, fast_float
- Fundamentally different BUILD.gn structure
- Many more MSVC issues (V8 was less MSVC-friendly then)
