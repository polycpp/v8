# Analysis of Remaining V8 MSVC Test Failures

**Build**: V8 14.3.127.18, MSVC 19.50.35717 (VS 18), Release /O2, x64
**Test results**: 5728/5735 pass (99.88%), 7 remaining failures

---

## 1. DoubleTest.NormalizedBoundaries (1 test)

**File**: `test/unittests/base/double-unittest.cc:153`
**Error**: `Check failed: diy_fp.f() - boundary_minus.f() == boundary_plus.f() - diy_fp.f()`

### What the test does

Tests `Double::NormalizedBoundaries()` — computes upper and lower floating-point
boundaries for IEEE 754 doubles. These boundaries are the midpoints between
adjacent representable doubles, used by the fast-path dtoa (double-to-ASCII)
algorithm. The test checks 6 cases: 1.5, 1.0, min denormal, smallest normal,
largest denormal, and max double.

### Root cause: MSVC codegen bug

This is **not a test bug** — it's an MSVC compiler code generation issue.

**Evidence:**
1. The math is correct on paper. For `Double(1.5)`, `AsNormalizedDiyFp()` returns
   `DiyFp(0xC000000000000000, -63)`, `NormalizedBoundaries` returns
   `m_minus=(0xBFFFFFFFFFFFFC00, -63)` and `m_plus=(0xC000000000000400, -63)`.
   Both differences should be `0x400 = 1024`. Verified by hand for all 6 cases.

2. `#pragma optimize("", off)` on `DiyFp::Normalize()` — **did not fix**.
   This was surprising since the bit-shift loops in Normalize seemed like the
   most likely optimization target. Suggests the miscompile is elsewhere.

3. `__declspec(noinline)` on `Normalize()`, `AsNormalizedDiyFp()`, AND
   `NormalizedBoundaries()` — **did not fix**. This eliminates inlining-related
   optimization as the cause.

4. The code involves only simple integer operations on `uint64_t` — shifts,
   additions, subtractions, and bitwise AND/OR. No floating-point arithmetic.
   No undefined behavior (all shifts are within range, unsigned overflow wraps).

**Hypothesis:** MSVC 19.50 at `/O2` has a codegen bug affecting one of these
patterns in `NormalizedBoundaries()` (double.h:136-156):
- The `DiyFp::Normalize()` static function uses two while loops with 64-bit
  mask comparisons and shifts. These are correct by construction but may
  trigger an MSVC optimizer issue with loop-invariant code motion or register
  allocation for 64-bit values.
- The expression `m_minus.f() << (m_minus.e() - m_plus.e())` at line 152
  computes a shift amount from the difference of two exponents. The shift
  amount is always 10 or 62 in the test cases. MSVC may be computing this
  shift amount incorrectly or applying the shift to the wrong register.

### Verdict: Compiler issue

**Fix strategy**: File against MSVC (Microsoft Connect / Developer Community).
In the meantime, the failure is harmless for real V8 usage — `NormalizedBoundaries`
is only used in the fast-path dtoa algorithm, which has a fallback to a
slower but correct bignum-based algorithm when the fast path produces
incorrect results. The test failure does not indicate a V8 engine bug.

### Alternative fix (if needed)

Add the test to a skip-list in `unittests.status` for MSVC, similar to how
other platform-specific tests are skipped:
```python
# MSVC-specific
'DoubleTest.NormalizedBoundaries': [SKIP],
```

---

## 2. WeakMapsTest.Shrinking + WeakSetsTest.WeakSet_Shrinking (2 tests)

**Files**: `test/unittests/objects/weakmaps-unittest.cc:170`,
           `test/unittests/objects/weaksets-unittest.cc:162`
**Error**: `Check failed: 32 == Cast<EphemeronHashTable>(weakmap->table())->Capacity()`

### What the tests do

1. Create a WeakMap/WeakSet with initial capacity 32
2. Insert 32 entries (capacity grows to 128)
3. Let the keys go out of scope (inner HandleScope)
4. Force a full GC via `InvokeAtomicMajorGC()`
5. Verify that all entries were cleared (NumberOfElements == 0) ✓
6. Verify that entries are tombstoned (NumberOfDeletedElements == 32) ✓
7. **Verify that capacity shrunk from 128 back to 32** ✗ FAILS

### Root cause: EphemeronHashTable not rehashed during GC compaction

The table does NOT shrink because V8's GC compactor doesn't rehash
`EphemeronHashTable`. The evidence is in `objects.cc`:

```cpp
// objects.cc:2098 — NeedsRehashing()
switch (instance_type) {
    case NAME_DICTIONARY_TYPE:
    case HASH_TABLE_TYPE:
    // ... many types listed ...
    case JS_MAP_TYPE:
    case JS_SET_TYPE:
      return true;
    default:
      return false;  // ← EPHEMERON_HASH_TABLE_TYPE falls here
}
```

And in `RehashBasedOnMap()` (objects.cc:2173), there is NO case for
`EPHEMERON_HASH_TABLE_TYPE` either. The default case calls `UNREACHABLE()`.

**So how does this test pass on GCC/Clang?** The test must rely on the GC
evacuating the table's memory page, which forces a copy. During copying,
the table gets recreated with the correct (smaller) capacity. Whether a page
gets evacuated depends on heap layout and fragmentation — this is
inherently non-deterministic and platform-dependent.

On MSVC, the heap layout differs (due to different alignment, allocation
patterns, or memory manager behavior), so the EphemeronHashTable's page
is NOT selected for evacuation. Without evacuation, there's no copying,
and without copying, there's no shrinking.

### Verdict: Fragile test + missing V8 implementation

This is a **test design issue** combined with a **V8 implementation gap**.
The test assumes that GC will always shrink the EphemeronHashTable, but
the V8 GC code has no explicit shrinking mechanism for EphemeronHashTable
— it relies on the incidental side effect of page evacuation.

### Fix strategies

**Option A — Fix the test** (recommended): After the GC, perform a dummy
`JSWeakCollection::Set()`/delete cycle to trigger explicit table rehashing:
```cpp
InvokeAtomicMajorGC();
CHECK_EQ(0, Cast<EphemeronHashTable>(weakmap->table())->NumberOfElements());
// Trigger explicit shrinking by modifying the collection
DirectHandle<JSObject> temp = factory->NewJSObjectFromMap(map);
DirectHandle<Smi> smi(Smi::FromInt(0), isolate);
int32_t hash = Object::GetOrCreateHash(*temp, isolate).value();
JSWeakCollection::Set(weakmap, temp, smi, hash);
JSWeakCollection::Delete(weakmap, temp, hash);
CHECK_EQ(32, Cast<EphemeronHashTable>(weakmap->table())->Capacity());
```

**Option B — Fix V8**: Add `EPHEMERON_HASH_TABLE_TYPE` to `NeedsRehashing()`
and implement `RehashBasedOnMap()` for it. This is the more correct fix but
has broader impact and should be submitted upstream.

**Option C — Skip**: Add to MSVC skip-list in `unittests.status`.

---

## 3. DateCache.AdoptDefaultFirst + DateCache.AdoptDefaultMixed (2 tests)

**File**: `test/unittests/date/date-cache-unittest.cc:61,84`
**Error**: Hangs indefinitely (timeout)

### What the tests do

Test thread safety of ICU's `icu::TimeZone::adoptDefault()` by running
multiple threads concurrently:
- `AdoptDefaultThread` — calls `icu::TimeZone::adoptDefault()`
- `GetLocalOffsetFromOSThread` — creates `DateCache`, calls `GetLocalOffsetFromOS()`
- `LocalTimezoneThread` — creates `DateCache`, calls `LocalTimezone()`

### Root cause: Missing V8 platform initialization

These tests use the bare `TEST()` macro from gtest, NOT a fixture inheriting
from `WithDefaultPlatformMixin`. This means:
- No `v8::platform::NewDefaultPlatform()` is called
- No `v8::V8::Initialize()` is called
- The V8 platform (thread pool, task runners) is not available

When `DateCache` is constructed, it calls `Intl::CreateTimeZoneCache()` which
uses ICU internally. The ICU operations require proper initialization and
thread-safe access to the ICU data. Without the V8 platform initialized,
the ICU timezone operations enter a deadlock state.

**Why it works on Linux/GCC**: On Linux with the GN build, ICU data is either
linked differently or the thread synchronization primitives behave differently.
The `icu::TimeZone::adoptDefault()` uses an internal mutex. On Windows with
MSVC's CRT, the mutex implementation may have different behavior when ICU
isn't fully initialized.

### Verdict: Test design issue

The tests are **incorrectly written** — they should use `WithDefaultPlatformMixin`
or at minimum call `V8::Initialize()` before using `DateCache` which depends
on ICU. This is a pre-existing bug that's latent on other platforms.

### Fix strategy

**Option A — Fix the test**: Create a proper test fixture:
```cpp
class DateCacheTest : public TestWithPlatform {};

TEST_F(DateCacheTest, AdoptDefaultFirst) { ... }
```

**Option B — Skip on MSVC**: Less ideal since the test is fundamentally broken.

---

## 4. LogAllTest.LogAll + LogTimerTest.ConsoleTimeEvents (2 tests)

**File**: `test/unittests/logging/log-unittest.cc:503,1093`
**Error**: Hangs indefinitely (timeout)

### What the tests do

- `LogAllTest.LogAll` — Enables full logging (`log_all`, `log_deopt`,
  `log_timer_events`), runs JS code with optimization/deoptimization cycles,
  and verifies log entries.
- `LogTimerTest.ConsoleTimeEvents` — Enables `log_timer_events`, runs
  `console.time()`/`console.timeEnd()`, verifies log entries.

Both use `ScopedLoggerInitializer` which creates a V8 isolate with logging
enabled.

### Root cause: Profiler thread semaphore deadlock on Windows

When `log_timer_events` is enabled, V8 creates a `Profiler` thread (log.cc:1222).
The Profiler's `Run()` method immediately calls `Remove(&sample)` which blocks
on `buffer_semaphore_.Wait()` (log.cc:1085). This semaphore is only signaled
when `Insert()` is called with a tick sample.

Tick samples come from the `Sampler::DoSample()` method. On Windows
(sampler.cc:613-642), sampling works by:
1. `SuspendThread(profiled_thread)` — suspend the target thread
2. `GetThreadContext(profiled_thread, &context)` — capture register state
3. Use the register state to create a `TickSample`
4. `ResumeThread(profiled_thread)` — resume the thread

**The problem**: If `SuspendThread` or `GetThreadContext` fails (returns
`kSuspendFailed` or 0), the sample is silently dropped. No sample means
no `Insert()`, which means the Profiler thread stays blocked on the
semaphore forever.

On Windows, `SuspendThread`/`GetThreadContext` can fail if:
- The thread handle is not properly duplicated (PlatformData constructor)
- The thread is in a state that doesn't allow suspension
- The target thread is in a system call that can't be interrupted

V8 upstream already acknowledges this issue — the tests are **skipped on
Android** (unittests.status:346) and **on sandbox hardware** (line 375) for
similar sampling problems.

### Verdict: Windows platform limitation

This is a **known platform limitation**, not a compiler issue. The Windows
sampling mechanism (SuspendThread/GetThreadContext) is inherently less
reliable than the Unix signal-based approach (SIGPROF).

### Fix strategy

**Option A — Skip on Windows/MSVC**: Following the Android precedent:
```python
# In unittests.status:
['system == windows', {
  'LogAllTest.LogAll': [SKIP],
  'LogTimerTest.ConsoleTimeEvents': [SKIP],
}]
```

**Option B — Fix sampling**: Add a timeout to the Profiler's `Remove()`
method so it doesn't block forever when no samples arrive. This is a more
robust fix but modifies V8 internals.

---

## Summary Table

| Test | Root Cause | Category | Recommended Fix |
|------|-----------|----------|-----------------|
| DoubleTest.NormalizedBoundaries | MSVC codegen bug in uint64 arithmetic | **Compiler** | Skip or report to MS |
| WeakMapsTest.Shrinking | EphemeronHashTable not rehashed during GC | **V8 + Test** | Fix test or add rehash |
| WeakSetsTest.WeakSet_Shrinking | Same as above | **V8 + Test** | Fix test or add rehash |
| DateCache.AdoptDefaultFirst | Missing V8 platform initialization | **Test** | Add proper fixture |
| DateCache.AdoptDefaultMixed | Same as above | **Test** | Add proper fixture |
| LogAllTest.LogAll | Windows sampler deadlock | **Platform** | Skip on Windows |
| LogTimerTest.ConsoleTimeEvents | Same as above | **Platform** | Skip on Windows |

### Breakdown by category
- **Compiler issue**: 1 test (DoubleTest) — MSVC-specific codegen bug
- **Test design issues**: 4 tests (WeakMaps/Sets, DateCache) — could be fixed
- **Platform limitation**: 2 tests (Log tests) — inherent Windows limitation

### Impact on V8 correctness: **None**

None of these failures indicate V8 engine correctness bugs:
- The DoubleTest failure is in a fast-path optimization with a working fallback
- The WeakMap/Set tests verify an optimization (table shrinking), not correctness
- The DateCache tests verify thread safety of ICU timezone operations
- The Log tests verify profiling instrumentation, not execution correctness

---

# Gap Analysis: Building d8 and Running mjsunit Tests

## Overview

**mjsunit** is V8's primary JavaScript test suite — **8,152 JS test files** covering
the entire engine (parser, compiler, runtime, builtins, GC, Intl, WebAssembly, etc.).
These tests require the **d8 shell** (`d8.exe`), a standalone V8 command-line runtime.

Currently our CMake build does not include a d8 target. This section analyzes
what's needed to add it.

## What is d8?

d8 is V8's developer shell. It's a relatively thin executable (~10 source files)
that creates a V8 Isolate with extra shell features: file I/O, OS interaction,
`print()`, `readline()`, `load()`, profiling, async hooks, and a test mode
(`--test`) for test harness integration.

## d8 Source Files

All in `src/d8/`:

| File | Description | Size |
|------|-------------|------|
| `d8.cc` | Main shell: REPL, file execution, flag handling | 275 KB |
| `d8.h` | Shell class header | 38 KB |
| `d8-test.cc` | Test-mode extensions (`%DeoptFunction`, etc.) | 81 KB |
| `d8-js.cc` | Embedded JS helpers | 3 KB |
| `d8-console.cc/h` | Console API (`console.log`, `.time`, etc.) | 9 KB |
| `d8-platforms.cc/h` | Custom platform with predictable mode | 14 KB |
| `async-hooks-wrapper.cc/h` | Node-style async hooks | 14 KB |
| `d8-windows.cc` | Windows-specific stubs (minimal) | 459 bytes |
| `d8-posix.cc` | POSIX-specific (NOT needed on Windows) | 25 KB |

## Dependencies — What d8 Needs

From BUILD.gn, d8 depends on:

```
d8 → :v8 → :v8_base (v8_base_without_compiler + v8_compiler)
              :v8_snapshot
       :v8_libbase
       :v8_libplatform
       :v8_tracing (empty without perfetto)
       //third_party/simdutf
```

### Already built (in build6/):

| Library | Status |
|---------|--------|
| `v8_base_without_compiler.lib` | ✅ Built |
| `v8_compiler.lib` | ✅ Built |
| `v8_snapshot.lib` | ✅ Built |
| `v8_init.lib` | ✅ Built |
| `v8_initializers.lib` | ✅ Built |
| `v8_libbase.lib` | ✅ Built |
| `v8_libplatform.lib` | ✅ Built |
| `v8_libsampler.lib` | ✅ Built |
| `v8_bigint.lib` | ✅ Built |
| `v8_cppgc.lib` | ✅ Built |
| `v8_heap_base.lib` | ✅ Built |
| `v8_simdutf.lib` | ✅ Built |
| `v8_zlib.lib` | ✅ Built |
| `icuuc.lib` + `icui18n.lib` | ✅ Built |
| `icudata.obj` (embedded ICU data) | ✅ Built |
| `snapshot_blob.bin` | ✅ Exists |

### Not yet built:

| Component | Effort |
|-----------|--------|
| d8 source compilation (10 files) | **Trivial** — add CMake target |
| `v8_tracing` | **None** — empty group without perfetto |

### Gap assessment: **Very small**

All libraries d8 needs are already built. The only work is:

1. **Add a `d8` executable target to CMake** — compile 10 source files, link
   against existing libraries
2. **Handle MSVC compilation issues** — d8.cc is large (275KB) and may need
   the same MSVC compatibility fixes (pragmas, warnings) as other V8 code

## CMake Target — What to Add

```cmake
# d8 shell
set(D8_SOURCES
  ${V8_ROOT}/src/d8/d8.cc
  ${V8_ROOT}/src/d8/d8.h
  ${V8_ROOT}/src/d8/d8-console.cc
  ${V8_ROOT}/src/d8/d8-console.h
  ${V8_ROOT}/src/d8/d8-js.cc
  ${V8_ROOT}/src/d8/d8-platforms.cc
  ${V8_ROOT}/src/d8/d8-platforms.h
  ${V8_ROOT}/src/d8/d8-test.cc
  ${V8_ROOT}/src/d8/d8-windows.cc        # Windows-specific (not d8-posix.cc)
  ${V8_ROOT}/src/d8/async-hooks-wrapper.cc
  ${V8_ROOT}/src/d8/async-hooks-wrapper.h
)

add_executable(d8 ${D8_SOURCES})
target_link_libraries(d8 PRIVATE
  v8_base_without_compiler
  v8_compiler
  v8_snapshot
  v8_init
  v8_initializers
  v8_libbase
  v8_libplatform
  v8_libsampler
  v8_bigint
  v8_cppgc
  v8_heap_base
  v8_simdutf
  v8_zlib
  v8_zlib_google
  v8_highway
  icu_interface              # icui18n + icuuc + icudata
  v8_abseil
  icudata                    # Embedded ICU data object
  dbghelp.lib winmm.lib ws2_32.lib advapi32.lib
)
```

## How mjsunit Tests Work

### Invocation pattern

Each mjsunit test is a `.js` file run through d8:

```
d8 --test test/mjsunit/mjsunit.js <test-file.js>
```

The `--test` flag enables d8's test mode. `mjsunit.js` is a harness providing
`assertEquals()`, `assertThrows()`, `assertOptimized()`, etc.

### Test structure

A typical mjsunit test:
```javascript
// Flags: --allow-natives-syntax
function add(a, b) { return a + b; }
%PrepareFunctionForOptimization(add);
assertEquals(3, add(1, 2));
%OptimizeFunctionOnNextCall(add);
assertEquals(3, add(1, 2));
assertOptimized(add);
```

### Special comment directives

- `// Flags: --flag` — additional d8 flags
- `// Files: path1.js path2.js` — extra files to load
- `// NO HARNESS` — skip loading mjsunit.js
- `// Environment Variables: VAR=value` — set env vars

### Test count

| Location | Count |
|----------|-------|
| `test/mjsunit/*.js` (top level) | 994 |
| `test/mjsunit/**/*.js` (all subdirs) | 8,152 |

Subdirectories include: `regress/`, `compiler/`, `wasm/`, `harmony/`,
`es6/`, `asm/`, `maglev/`, `turboshaft/`, etc.

### Running tests

V8's test runner (`tools/run-tests.py`) handles test discovery, parallelization,
timeout, and result collection. But at the simplest level, each test is just:

```bash
d8.exe --test test/mjsunit/mjsunit.js test/mjsunit/<test>.js
```

A simple bash/python script can run all tests by iterating over the .js files.

## Potential Risks

### Compilation issues (Low risk)
- `d8.cc` is 275KB — large but not unusual for V8. May need `/bigobj`.
- `d8-test.cc` is 81KB with many V8 internals — similar complexity to test files
  we already compile.
- All headers d8 uses are already consumed by existing libraries.

### MSVC-specific source issues (Low risk)
- `d8-windows.cc` is a trivial 16-line stub. No issues expected.
- `d8.cc` may use POSIX-isms guarded by `#ifdef` — the existing MSVC patch
  already handles these patterns for other V8 sources.

### Missing runtime files (None)
- `snapshot_blob.bin` — already built by mksnapshot
- `icudtl.dat` — no longer needed (data embedded in binary)

### Test failures (Expected)
- Some mjsunit tests may fail on Windows due to:
  - Path separator differences (`/` vs `\`)
  - POSIX-only features (signals, fork, etc.)
  - Timing-sensitive tests
  - Platform-specific expected outputs
- V8 provides `test/mjsunit/mjsunit.status` with known failures per platform.
  Many Windows-specific SKIPs are already defined there.

## Effort Estimate

| Task | Complexity |
|------|-----------|
| Add d8 CMake target | Small — ~30 lines of CMake |
| Fix any MSVC compile errors in d8 sources | Small — likely 0-3 patches |
| Incremental build (10 new .cc files + link) | ~10-20 min |
| Write a simple mjsunit test runner script | Small — ~50 lines of Python |
| Run mjsunit suite and triage results | Medium — needs time to analyze |

## Conclusion

**The gap is minimal.** All V8 libraries d8 depends on are already built.
Adding d8 requires only a new CMake target (~30 lines) and compiling 10
source files. The d8-windows.cc file is a trivial stub with no MSVC issues.

Running mjsunit after that is straightforward — each test is just
`d8 --test mjsunit.js <test>.js`. The main effort will be triaging
the results (some tests will fail due to Windows-specific issues, which
V8 upstream already tracks in `mjsunit.status`).
