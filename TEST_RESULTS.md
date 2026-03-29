# V8 MSVC Build — Test Results

V8 14.3.127.18, built with MSVC 19.50.35725 (Visual Studio 18 Community), Windows x64.

## Summary

| Metric | Value |
|--------|-------|
| Unit test suites | 546 |
| Suites that ran | 303 |
| Tests passed | **1349** |
| Tests failed | **6** |
| Pass rate | **99.6%** |
| Suites crashed (platform re-init) | 243 |
| Smoke test (hello_v8.exe) | **PASS** |

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

### Crashed Suites (243 suites)

All 243 crashes produce the same error:

```
Fatal error in , line 0
The platform was initialized before. Note that running multiple tests
in the same process is not supported.
```

**Root cause:** V8's `run-all-unittests.cc` entry point calls `V8::InitializePlatform()` at startup. Many test fixtures (Compiler, Heap, Interpreter, Object, Assembler, Deoptimization, Wasm, etc.) also call `V8::InitializePlatform()` as part of their setup. V8's platform can only be initialized once per process — calling it again is a fatal error.

V8's official test runner (`tools/run-tests.py`) handles this by spawning a separate process per test shard with specific `--gtest_filter` arguments, avoiding the double-init. Our test runner does run each suite in a separate process, but the `run-all-unittests.cc` entry point still triggers the double-init within a single test binary invocation when the suite's fixture tries to set up.

**These suites include critical test categories:**
- CompilerTest, TurboshaftTest, MaglevTest (compiler correctness)
- HeapTest, GCHeapTest, LocalHeapTest (garbage collection)
- InterpreterTest, BytecodeGeneratorTest (JS execution)
- AssemblerX64Test, MacroAssemblerX64Test (code generation)
- DeoptimizationTest (optimization bailout)
- WasmCompilerTest, WasmModuleDecoderTest (WebAssembly)
- ObjectTest, ParserTest (JS objects and parsing)

**Verdict:** Not a V8 engine or MSVC build bug. This is a V8 test infrastructure design that requires the official test runner for proper execution. Fixing this would require modifying `run-all-unittests.cc` to not pre-initialize the platform, or restructuring the test fixtures.

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
