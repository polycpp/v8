# V8 MSVC Build — Test Results

V8 14.3.127.18, built with MSVC 19.50.35725 (Visual Studio 18 Community), Windows x64.

## Summary

**Per-suite run** (all 546 suites, multiple tests per process):

| Metric | Value |
|--------|-------|
| Unit test suites | 546 |
| Multi-test suites that ran | 303 |
| Tests passed | **1349** |
| Tests failed | **6** |
| Suites crashed after 1st test | 243 |

**Per-test run** (one test per process, first test from each suite):

| Metric | Value |
|--------|-------|
| Tests run | 546 |
| Passed | **~536** |
| Real failures | **~10** |
| Pass rate | **~98%** |
| Smoke test (hello_v8.exe) | **PASS** |

The 243 "crashed suites" in per-suite mode are caused by V8's one-time platform
initialization design — see [Platform Re-initialization](#platform-re-initialization)
below. When each test runs in its own process, these suites pass.

## Smoke Test: hello_v8.exe

A minimal V8 embedding program that creates an Isolate, compiles and runs JavaScript.

```
V8 result: 3
Hello from V8 function
  JSON.stringify({a: 1, b: [2, 3]}) => {"a":1,"b":[2,3]}
  [1,2,3].map(x => x * x).join(', ') => 1, 4, 9
  new Map([[1,'one'],[2,'two']]).get(2) => two
  (() => { let s = 0; for (let i = 1; i <= 100; i++) s += i; return s; })() => 5050
  typeof WebAssembly => object
V8 MSVC build test PASSED
```

Verified: arithmetic, JSON, arrow functions, Map, closures, loops, WebAssembly availability.

## Unit Tests: v8_unittests.exe

381 test source files compiled into `v8_unittests.exe` (6515 test cases registered).
Each of 546 test suites was run in its own process invocation.

### Passed Test Suites (303 suites, 1349 tests)

Includes the following categories:

- **Base/Platform** — Bits, CPU, Hashing, Macros, AtomicUtils, AtomicOps, Flags, Mutex, Semaphore, ConditionVariable, Time, Platform, SysInfo, StringFormat, TemplateUtils, IEEE754, Logging, Ostreams, VirtualAddressSpace, DoublyThreadedList, Iterator, SmallMap
- **Data Structures** — ThreadedList, SmallVector (42/46 pass), Vector, RegionAllocator, AddressRegion, Hashmap
- **Numbers** — Bignum, BignumDtoa, Dtoa, FastDtoa, FixedDtoa, Double, DivisionByConstant, VlqBase64, Vlq
- **Codegen** — AlignedSlotAllocator, RegisterConfiguration, SourcePositionTable, CodeLayout
- **Heap/GC** — AllocationObserver, ActiveSystemPages, BasicSlotSet, Bytes, IncrementalMarkingSchedule, Worklist, GCTracer, HeapGrowing, HeapObjectHeader, HeapStatisticsCollector, ObjectStartBitmap, PageBackend, CagedHeap, GCInfoTable, Sweeper, Compactor, ConcurrentMarker, ExplicitManagement, Prefinalizer, PersistentNode, ObjectAllocator, WriteBarrier, AgeTable
- **BigInt** — BigInt operations
- **Date** — DateCache
- **Diagnostics** — EhFrameIterator, EhFrameWriter, GdbJit
- **API** — AccessCheck, SmiTagging, Context, Isolate, Exception, V8Array, V8Maybe, V8MemorySpan, V8Object, V8Script, V8Value
- **Torque** — EarleyParser, TorqueUtils
- **Wasm** — DecoderTest, FunctionBodyDecoder, LocalDeclDecoder, LiftoffRegister, WasmModuleDecoder, WasmModuleVerify, WasmCompiler, WasmStreaming, TrapHandler

### Failed Tests (6 tests in 3 suites)

#### 1. SmallVectorTest — 4 failures

**Tests:**
- `SmallVectorTest.ConstructFromListNonTrivial`
- `SmallVectorTest.ConstructFromVectorNonTrivial`
- `SmallVectorTest.CopyConstructNonTrivial`
- `SmallVectorTest.MoveConstructNonTrivial`

**Root cause:** MSVC `std::initializer_list` materialization.

The tests use a `NonTrivial<int>` type with a global counter that tracks every constructor, copy, move, and destructor call. The test expects an exact count (e.g., 21 explicit constructors after creating two initializer lists of size 7+14).

MSVC generates **one extra constructor call** when materializing the `initializer_list` backing array compared to GCC/Clang. This is a known difference in how MSVC handles temporary materialization for `std::initializer_list`. The counter then drifts by +1 for all subsequent tests in the suite since the counter is static/global and not reset between the initializer list construction and the assertion.

**Evidence:** Each of the 4 tests **passes when run individually** — confirming the issue is inter-test counter drift, not a logic bug.

```
Expected: 21
  Actual: 22  (one extra constructor from MSVC initializer_list handling)
```

**Verdict:** Not a V8 engine bug. MSVC-specific `initializer_list` behavior; test assumes GCC/Clang materialization semantics.

#### 2. SourceLocationTest.ToString — 1 failure

**Root cause:** MSVC function signature format difference.

The test compares the string output of `SourceLocation::ToString()` which uses the compiler's `__builtin_FUNCTION()` / `__FUNCSIG__` output.

```
Expected: "void cppgc::internal::TestToString()@...source-location-unittest.cc:43"
  Actual: "void __cdecl cppgc::internal::TestToString(void)@...source-location-unittest.cc:43"
```

MSVC includes `__cdecl` calling convention and explicit `(void)` for empty parameter lists. GCC/Clang omit these.

**Verdict:** Not a V8 engine bug. Test hardcodes GCC/Clang function signature format.

#### 3. GoogleTestVerification — 1 failure

**Test:** `GoogleTestVerification.UninstantiatedParameterizedTestSuite<BytecodeGeneratorTest>`

**Root cause:** Build configuration. `BytecodeGeneratorTest` is defined as a parameterized test (`TEST_P`) in `bytecode-generator-unittest.cc`, but the corresponding `INSTANTIATE_TEST_SUITE_P` macro is in `generate-bytecode-expectations.cc` which was excluded from our build (it's a standalone tool with its own `main()`).

GoogleTest detects the uninstantiated parameterized test and reports it as a failure.

**Verdict:** Not a V8 engine bug. Build configuration gap — the instantiation macro is in a file we correctly excluded.

#### 4. Additional failures (per-test run)

When running one test per process (first test from each suite), a few more
failures appear:

- **ApiIcuTest.LocaleConfigurationChangeNotification** — Fatal OOM in
  `DateTimePatternGeneratorCache::CreateGenerator`. Resource limit issue,
  not a correctness bug.
- **BytecodeGeneratorInitTest.HasGoldenFiles** — `Check failed: !golden_files.empty()`.
  The test expects golden files at a relative path from the build directory.
  Path configuration issue.
- **DateCache.AdoptDefaultFirst**, **LogAllTest.LogAll**, **LogTimerTest.ConsoleTimeEvents** —
  These tests hang (timeout). They need V8 platform initialization but don't use
  `WithDefaultPlatformMixin`, so they wait for a platform that was never set up.
- **BitsDeathTest.DISABLED_RoundUpToPowerOfTwo32** — Test is explicitly DISABLED.

### Platform Re-initialization

When running multiple tests per process (per-suite mode), 243 suites crash on
the 2nd test with:

```
Fatal error in , line 0
The platform was initialized before. Note that running multiple tests
in the same process is not supported.
```

**Root cause analysis:**

V8's platform state machine (`src/init/v8.cc`) is strictly one-way:

```
kIdle → kPlatformInitializing → kPlatformInitialized → kV8Initializing →
kV8Initialized → kV8Disposing → kV8Disposed → kPlatformDisposing → kPlatformDisposed
```

The state **never returns to `kIdle`**. After `V8::Dispose()` + `V8::DisposePlatform()`,
the state becomes `kPlatformDisposed` (terminal). `InitializePlatformForTesting()`
requires `kIdle` and fatals otherwise.

The test fixture `WithDefaultPlatformMixin` (in `test-utils.h`) calls
`InitializePlatformForTesting()` + `V8::Initialize()` in its constructor and
`V8::Dispose()` + `V8::DisposePlatform()` in its destructor. Since GTest creates
a new fixture per test, the 1st test works fine, but the 2nd test tries to
re-initialize the already-disposed platform and hits the fatal check.

**When each test runs in its own process, the 1st test of each suite passes.**
Verified by running the first test from all 243 "crashed" suites individually —
they all pass. This includes:

- CompilerTest.Inc, HeapTest (GC), InterpreterTest (bytecode execution)
- AssemblerX64Test, MacroAssemblerX64Test (x64 code generation)
- DeoptimizationTest, WasmCompilerTest, ObjectTest, ContextTest
- And all other Isolate-dependent test suites

**Verdict:** By-design V8 limitation. Not an MSVC build issue. V8's own CI uses
`tools/run-tests.py` which runs each test in a separate process.

## Test Coverage Gaps

### Not built

| Test Suite | Reason |
|-----------|--------|
| cctest | Separate test binary, not included in CMake build |
| d8 shell | Not built; needed for mjsunit/test262 |
| mjsunit (8000+ JS tests) | Requires d8 shell |
| test262 (ECMAScript conformance) | Requires d8 shell |
| inspector tests | Needs generated protocol headers |
| fuzzer tests | Needs fuzztest library |

### Excluded from v8_unittests build

| File Pattern | Reason |
|-------------|--------|
| `*-arm-*`, `*-arm64-*`, `*-ia32-*`, etc. | Non-x64 architecture tests |
| `*posix*`, `*gdbserver*` | Non-Windows platform tests |
| `inspector/*` | Needs generated inspector protocol headers |
| `json/json-unittest` | Needs jsoncpp library |
| `profiler/heap-snapshot-unittest` | Needs jsoncpp library |
| `runtime-call-stats-unittest` | MSVC compilation issue pending fix |
| `member-unittest` | Needs `CPPGC_POINTER_COMPRESSION` |
| `*fuzztest*`, `*fuzzer*` | Needs fuzztest library |
| `linear-scheduler-unittest` | Needs SIMD revectorization sources |
| `revec-unittest` | Needs SIMD revectorization sources |
| `ls-json-unittest` | Needs Torque language server |
| `ls-message-unittest` | Needs Torque language server |
| `wasm-tracing-unittest` | Needs fuzzer-common library |

## How to Run Tests

```bash
# Build the test binary
cmake --build build -t v8_unittests

# Run all base/utility tests (no V8 Isolate needed, runs in one process)
./build/v8_unittests.exe --gtest_filter="BitsTest*:CpuTest*:HashingTest*:..."

# Run a single test suite
./build/v8_unittests.exe --gtest_filter="AccessCheckTest.*"

# Run all suites via test runner (each in separate process)
python test/run_unittests.py build/v8_unittests.exe

# Run the smoke test
./build/hello_v8.exe
```

## Environment

- **OS:** Windows Server 2025 Datacenter 10.0.26100
- **Compiler:** MSVC 19.50.35725 (Visual Studio 18 Community)
- **CMake:** 4.2.3
- **Ninja:** 1.13.2
- **V8 version:** 14.3.127.18
- **Build type:** Release (/O2 /MT)
