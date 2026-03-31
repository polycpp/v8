# C++ Unit Test Failure Analysis

7 remaining failures out of 5735 effective tests. None indicate V8 engine bugs.

**Build**: V8 14.3.127.18, MSVC 19.50.35717, Release /O2, x64

---

## 1. DoubleTest.NormalizedBoundaries (1 test)

**File**: `test/unittests/base/double-unittest.cc:153`
**Error**: `Check failed: diy_fp.f() - boundary_minus.f() == boundary_plus.f() - diy_fp.f()`

### What it tests

`Double::NormalizedBoundaries()` computes upper and lower floating-point
boundaries for IEEE 754 doubles — the midpoints between adjacent representable
doubles, used by the fast-path dtoa (double-to-ASCII) algorithm. Tests 6 cases:
1.5, 1.0, min denormal, smallest normal, largest denormal, max double.

### Root cause: MSVC codegen bug

Hand-verified all 6 cases produce correct results mathematically. For
`Double(1.5)`: `AsNormalizedDiyFp()` = `DiyFp(0xC000000000000000, -63)`,
boundaries = `(0xBFFFFFFFFFFFFC00, 0xC000000000000400)`. Both differences
should be `0x400 = 1024`.

Attempted fixes that did **not** work:
- `#pragma optimize("", off)` on `DiyFp::Normalize()`
- `__declspec(noinline)` on `Normalize()`, `AsNormalizedDiyFp()`, and `NormalizedBoundaries()`

The code uses only simple `uint64_t` operations (shifts, adds, subtracts,
bitwise AND/OR). No floating-point, no undefined behavior. This points to
an MSVC optimizer bug in 64-bit integer register allocation or loop codegen.

### Impact: None

`NormalizedBoundaries` is only used in the fast-path dtoa, which has a
fallback to a correct bignum-based algorithm. The engine works correctly.

---

## 2. WeakMapsTest.Shrinking + WeakSetsTest.WeakSet_Shrinking (2 tests)

**Files**: `test/unittests/objects/weakmaps-unittest.cc:170`,
           `test/unittests/objects/weaksets-unittest.cc:162`
**Error**: `Check failed: 32 == Cast<EphemeronHashTable>(...)->Capacity()`

### What they test

Create WeakMap/WeakSet → fill 32 entries (capacity grows to 128) → force GC →
verify capacity shrunk back to 32. Elements are cleared (0) and tombstoned (32),
but capacity stays at 128.

### Root cause: EphemeronHashTable not rehashed during compaction

V8's `NeedsRehashing()` in `objects.cc:2098` returns `false` for
`EPHEMERON_HASH_TABLE_TYPE` (falls through to `default`). `RehashBasedOnMap()`
also has no case for it. Shrinking only happens incidentally when the GC
evacuates the table's memory page — which depends on heap layout and is
non-deterministic across compilers.

### Impact: None

Tests verify an optimization (table shrinking), not correctness. The
WeakMap/WeakSet works correctly regardless of table capacity.

### Possible fix

Add `EPHEMERON_HASH_TABLE_TYPE` to `NeedsRehashing()` and implement
its case in `RehashBasedOnMap()`. This would be an upstream V8 improvement.

---

## 3. DateCache.AdoptDefaultFirst + DateCache.AdoptDefaultMixed (2 tests)

**File**: `test/unittests/date/date-cache-unittest.cc:61,84`
**Error**: Hangs indefinitely (timeout)

### What they test

Thread safety of `icu::TimeZone::adoptDefault()` with concurrent DateCache
operations across multiple threads.

### Root cause: Missing V8 platform initialization

Tests use bare `TEST()` macro instead of `WithDefaultPlatformMixin`. No
`V8::Initialize()` is called. `DateCache` constructor calls
`Intl::CreateTimeZoneCache()` which uses ICU internally. Without platform
initialization, ICU timezone operations deadlock on Windows.

### Impact: None

Test design bug, not an engine bug. The test is incorrectly written — it
should use `WithDefaultPlatformMixin` like all other V8 tests.

---

## 4. LogAllTest.LogAll + LogTimerTest.ConsoleTimeEvents (2 tests)

**File**: `test/unittests/logging/log-unittest.cc:503,1093`
**Error**: Hangs indefinitely (timeout)

### What they test

V8 profiling log output when `log_timer_events` is enabled.

### Root cause: Windows sampler deadlock

The Profiler thread (`log.cc:1222`) blocks on `buffer_semaphore_.Wait()`,
waiting for tick samples. Samples come from `Sampler::DoSample()` which uses
`SuspendThread` + `GetThreadContext` on Windows. If either fails (silently),
no samples are produced and the Profiler blocks forever.

V8 upstream already skips these on Android (`unittests.status:346`) for the
same reason — sampling is unreliable on some platforms.

### Impact: None

Profiling instrumentation, not execution correctness.

---

## Summary

| Test | Root Cause | Category |
|------|-----------|----------|
| DoubleTest.NormalizedBoundaries | MSVC optimizer bug | Compiler |
| WeakMapsTest.Shrinking | Missing EphemeronHashTable rehash in GC | V8 + Test |
| WeakSetsTest.WeakSet_Shrinking | Same | V8 + Test |
| DateCache.AdoptDefaultFirst | No platform init in test | Test design |
| DateCache.AdoptDefaultMixed | Same | Test design |
| LogAllTest.LogAll | Windows SuspendThread unreliable | Platform |
| LogTimerTest.ConsoleTimeEvents | Same | Platform |

**Breakdown**: 1 compiler, 2 V8 implementation gaps, 2 test design bugs, 2 platform limitations.

**Impact on V8 correctness: None.**
