# =============================================================================
# V8 source file lists for x64 build (Windows MSVC / Linux GCC/Clang)
# Extracted from BUILD.gn (V8 12.4.254.21)
# =============================================================================

# Helper: prefix all paths with V8_ROOT
macro(v8_src OUT)
  set(_list "")
  foreach(_f ${ARGN})
    list(APPEND _list "${V8_ROOT}/${_f}")
  endforeach()
  set(${OUT} ${_list})
endmacro()

# =============================================================================
# v8_libbase sources
# =============================================================================
v8_src(V8_LIBBASE_SOURCES
  src/base/abort-mode.cc
  src/base/bits.cc
  src/base/bounded-page-allocator.cc
  src/base/cpu.cc
  src/base/debug/stack_trace.cc
  src/base/division-by-constant.cc
  src/base/emulated-virtual-address-subspace.cc
  src/base/file-utils.cc
  src/base/ieee754.cc
  src/base/logging.cc
  src/base/numbers/bignum-dtoa.cc
  src/base/numbers/bignum.cc
  src/base/numbers/cached-powers.cc
  src/base/numbers/diy-fp.cc
  src/base/numbers/dtoa.cc
  src/base/numbers/fast-dtoa.cc
  src/base/numbers/fixed-dtoa.cc
  src/base/numbers/strtod.cc
  src/base/once.cc
  src/base/page-allocator.cc
  src/base/platform/condition-variable.cc
  src/base/platform/memory-protection-key.cc
  src/base/platform/mutex.cc
  src/base/platform/platform.cc
  src/base/platform/semaphore.cc
  src/base/platform/time.cc
  src/base/region-allocator.cc
  src/base/sanitizer/lsan-page-allocator.cc
  src/base/sanitizer/lsan-virtual-address-space.cc
  src/base/strings.cc
  src/base/sys-info.cc
  src/base/utils/random-number-generator.cc
  src/base/virtual-address-space-page-allocator.cc
  src/base/virtual-address-space.cc
  src/base/vlq-base64.cc
)

# Platform-specific libbase sources
if(WIN32)
  list(APPEND V8_LIBBASE_SOURCES
    "${V8_ROOT}/src/base/debug/stack_trace_win.cc"
    "${V8_ROOT}/src/base/platform/platform-win32.cc"
  )
else()
  list(APPEND V8_LIBBASE_SOURCES
    "${V8_ROOT}/src/base/debug/stack_trace_posix.cc"
    "${V8_ROOT}/src/base/platform/platform-posix.cc"
    "${V8_ROOT}/src/base/platform/platform-posix-time.cc"
    "${V8_ROOT}/src/base/platform/platform-linux.cc"
  )
endif()

# =============================================================================
# v8_libplatform sources
# =============================================================================
v8_src(V8_LIBPLATFORM_SOURCES
  src/libplatform/default-foreground-task-runner.cc
  src/libplatform/default-job.cc
  src/libplatform/default-platform.cc
  src/libplatform/default-thread-isolated-allocator.cc
  src/libplatform/default-worker-threads-task-runner.cc
  src/libplatform/delayed-task-queue.cc
  src/libplatform/task-queue.cc
  src/libplatform/tracing/trace-buffer.cc
  src/libplatform/tracing/trace-config.cc
  src/libplatform/tracing/trace-object.cc
  src/libplatform/tracing/trace-writer.cc
  src/libplatform/tracing/tracing-controller.cc
  src/libplatform/worker-thread.cc
)

# Windows ETW recorder (no equivalent on Linux)
if(WIN32)
  list(APPEND V8_LIBPLATFORM_SOURCES "${V8_ROOT}/src/libplatform/tracing/recorder-win.cc")
endif()

# =============================================================================
# v8_libsampler sources
# =============================================================================
v8_src(V8_LIBSAMPLER_SOURCES
  src/libsampler/sampler.cc
)

# =============================================================================
# v8_bigint sources
# =============================================================================
v8_src(V8_BIGINT_SOURCES
  src/bigint/bigint-internal.cc
  src/bigint/bitwise.cc
  src/bigint/div-burnikel.cc
  src/bigint/div-helpers.cc
  src/bigint/div-schoolbook.cc
  src/bigint/fromstring.cc
  src/bigint/mul-karatsuba.cc
  src/bigint/mul-schoolbook.cc
  src/bigint/tostring.cc
  src/bigint/vector-arithmetic.cc
  # Advanced algorithms
  src/bigint/div-barrett.cc
  src/bigint/mul-fft.cc
  src/bigint/mul-toom.cc
)

# =============================================================================
# v8_heap_base sources
# =============================================================================
v8_src(V8_HEAP_BASE_SOURCES
  src/heap/base/active-system-pages.cc
  src/heap/base/incremental-marking-schedule.cc
  src/heap/base/memory-tagging.cc
  src/heap/base/stack.cc
  src/heap/base/worklist.cc
)

# x64 assembly for push_registers
if(WIN32)
  set(V8_HEAP_BASE_ASM_SOURCES
    "${V8_ROOT}/src/heap/base/asm/x64/push_registers_masm.asm"
  )
else()
  # On Linux, this is a C++ file with inline GAS assembly
  set(V8_HEAP_BASE_ASM_SOURCES
    "${V8_ROOT}/src/heap/base/asm/x64/push_registers_asm.cc"
  )
endif()

# =============================================================================
# cppgc_base sources
# =============================================================================
v8_src(V8_CPPGC_SOURCES
  src/heap/cppgc/allocation.cc
  src/heap/cppgc/compaction-worklists.cc
  src/heap/cppgc/compactor.cc
  src/heap/cppgc/concurrent-marker.cc
  src/heap/cppgc/explicit-management.cc
  src/heap/cppgc/free-list.cc
  src/heap/cppgc/gc-info-table.cc
  src/heap/cppgc/gc-info.cc
  src/heap/cppgc/gc-invoker.cc
  src/heap/cppgc/heap-base.cc
  src/heap/cppgc/heap-consistency.cc
  src/heap/cppgc/heap-growing.cc
  src/heap/cppgc/heap-object-header.cc
  src/heap/cppgc/heap-page.cc
  src/heap/cppgc/heap-space.cc
  src/heap/cppgc/heap-state.cc
  src/heap/cppgc/heap-statistics-collector.cc
  src/heap/cppgc/heap.cc
  src/heap/cppgc/liveness-broker.cc
  src/heap/cppgc/logging.cc
  src/heap/cppgc/marker.cc
  src/heap/cppgc/marking-state.cc
  src/heap/cppgc/marking-verifier.cc
  src/heap/cppgc/marking-visitor.cc
  src/heap/cppgc/marking-worklists.cc
  src/heap/cppgc/member-storage.cc
  src/heap/cppgc/memory.cc
  src/heap/cppgc/name-trait.cc
  src/heap/cppgc/object-allocator.cc
  src/heap/cppgc/object-size-trait.cc
  src/heap/cppgc/page-memory.cc
  src/heap/cppgc/persistent-node.cc
  src/heap/cppgc/platform.cc
  src/heap/cppgc/pointer-policies.cc
  src/heap/cppgc/prefinalizer-handler.cc
  src/heap/cppgc/process-heap-statistics.cc
  src/heap/cppgc/process-heap.cc
  src/heap/cppgc/raw-heap.cc
  src/heap/cppgc/remembered-set.cc
  src/heap/cppgc/stats-collector.cc
  src/heap/cppgc/sweeper.cc
  src/heap/cppgc/testing.cc
  src/heap/cppgc/trace-trait.cc
  src/heap/cppgc/virtual-memory.cc
  src/heap/cppgc/visitor.cc
  src/heap/cppgc/write-barrier.cc
  # Caged heap (64-bit)
  src/heap/cppgc/caged-heap-local-data.cc
  src/heap/cppgc/caged-heap.cc
)

# =============================================================================
# Third-party sources
# =============================================================================

# Highway (SIMD library)
v8_src(V8_HIGHWAY_SOURCES
)

# simdutf (Unicode conversion)
v8_src(V8_SIMDUTF_SOURCES
)

# siphash
v8_src(V8_SIPHASH_SOURCES
)

# =============================================================================
# v8_compiler sources (TurboFan + Turboshaft)
# =============================================================================
v8_src(V8_COMPILER_SOURCES
  src/compiler/access-builder.cc
  src/compiler/access-info.cc
  src/compiler/add-type-assertions-reducer.cc
  src/compiler/all-nodes.cc
  src/compiler/backend/bitcast-elider.cc
  src/compiler/backend/code-generator.cc
  src/compiler/backend/frame-elider.cc
  src/compiler/backend/gap-resolver.cc
  src/compiler/backend/instruction-scheduler.cc
  src/compiler/backend/instruction-selector.cc
  src/compiler/backend/instruction.cc
  src/compiler/backend/jump-threading.cc
  src/compiler/backend/move-optimizer.cc
  src/compiler/backend/register-allocator-verifier.cc
  src/compiler/backend/register-allocator.cc
  src/compiler/backend/spill-placer.cc
  src/compiler/basic-block-instrumentor.cc
  src/compiler/branch-elimination.cc
  src/compiler/branch-condition-duplicator.cc
  src/compiler/bytecode-analysis.cc
  src/compiler/bytecode-graph-builder.cc
  src/compiler/bytecode-liveness-map.cc
  src/compiler/c-linkage.cc
  src/compiler/checkpoint-elimination.cc
  src/compiler/code-assembler.cc
  src/compiler/common-node-cache.cc
  src/compiler/common-operator-reducer.cc
  src/compiler/common-operator.cc
  src/compiler/compilation-dependencies.cc
  src/compiler/compiler-source-position-table.cc
  src/compiler/const-tracking-let-helpers.cc
  src/compiler/constant-folding-reducer.cc
  src/compiler/control-flow-optimizer.cc
  src/compiler/control-equivalence.cc
  src/compiler/csa-load-elimination.cc
  src/compiler/dead-code-elimination.cc
  src/compiler/decompression-optimizer.cc
  src/compiler/effect-control-linearizer.cc
  src/compiler/escape-analysis-reducer.cc
  src/compiler/escape-analysis.cc
  src/compiler/fast-api-calls.cc
  src/compiler/feedback-source.cc
  src/compiler/frame-states.cc
  src/compiler/frame.cc
  src/compiler/graph-assembler.cc
  src/compiler/graph-reducer.cc
  src/compiler/graph.cc
  src/compiler/graph-trimmer.cc
  src/compiler/graph-visualizer.cc
  src/compiler/heap-refs.cc
  src/compiler/js-call-reducer.cc
  src/compiler/js-context-specialization.cc
  src/compiler/js-create-lowering.cc
  src/compiler/js-generic-lowering.cc
  src/compiler/js-graph.cc
  src/compiler/js-heap-broker.cc
  src/compiler/js-inlining-heuristic.cc
  src/compiler/js-inlining.cc
  src/compiler/js-intrinsic-lowering.cc
  src/compiler/js-native-context-specialization.cc
  src/compiler/js-operator.cc
  src/compiler/js-type-hint-lowering.cc
  src/compiler/js-typed-lowering.cc
  src/compiler/late-escape-analysis.cc
  src/compiler/load-elimination.cc
  src/compiler/loop-analysis.cc
  src/compiler/loop-peeling.cc
  src/compiler/loop-unrolling.cc
  src/compiler/loop-variable-optimizer.cc
  src/compiler/machine-graph-verifier.cc
  src/compiler/machine-graph.cc
  src/compiler/machine-operator-reducer.cc
  src/compiler/machine-operator.cc
  src/compiler/map-inference.cc
  src/compiler/memory-lowering.cc
  src/compiler/memory-optimizer.cc
  src/compiler/node-marker.cc
  src/compiler/node-matchers.cc
  src/compiler/node-observer.cc
  src/compiler/node-origin-table.cc
  src/compiler/node-properties.cc
  src/compiler/node.cc
  src/compiler/opcodes.cc
  src/compiler/operation-typer.cc
  src/compiler/operator-properties.cc
  src/compiler/operator.cc
  src/compiler/osr.cc
  src/compiler/pair-load-store-reducer.cc
  src/compiler/pipeline-statistics.cc
  src/compiler/pipeline.cc
  src/compiler/property-access-builder.cc
  src/compiler/raw-machine-assembler.cc
  src/compiler/redundancy-elimination.cc
  src/compiler/refs-map.cc
  src/compiler/representation-change.cc
  src/compiler/schedule.cc
  src/compiler/scheduler.cc
  src/compiler/select-lowering.cc
  src/compiler/simplified-lowering-verifier.cc
  src/compiler/simplified-lowering.cc
  src/compiler/simplified-operator-reducer.cc
  src/compiler/simplified-operator.cc
  src/compiler/state-values-utils.cc
  src/compiler/store-store-elimination.cc
  src/compiler/string-builder-optimizer.cc
  src/compiler/linear-scheduler.cc
  src/compiler/revectorizer.cc
  src/compiler/turbofan-enabled.cc
  src/compiler/turboshaft/analyzer-iterator.cc
  src/compiler/turboshaft/assembler.cc
  src/compiler/turboshaft/build-graph-phase.cc
  src/compiler/turboshaft/code-elimination-and-simplification-phase.cc
  src/compiler/turboshaft/copying-phase.cc
  src/compiler/turboshaft/csa-optimize-phase.cc
  src/compiler/turboshaft/debug-feature-lowering-phase.cc
  src/compiler/turboshaft/decompression-optimization-phase.cc
  src/compiler/turboshaft/decompression-optimization.cc
  src/compiler/turboshaft/graph-builder.cc
  src/compiler/turboshaft/graph-visualizer.cc
  src/compiler/turboshaft/graph.cc
  src/compiler/turboshaft/instruction-selection-phase.cc
  src/compiler/turboshaft/late-escape-analysis-reducer.cc
  src/compiler/turboshaft/late-load-elimination-reducer.cc
  src/compiler/turboshaft/loop-finder.cc
  src/compiler/turboshaft/loop-peeling-phase.cc
  src/compiler/turboshaft/loop-unrolling-phase.cc
  src/compiler/turboshaft/loop-unrolling-reducer.cc
  src/compiler/turboshaft/machine-lowering-phase.cc
  src/compiler/turboshaft/maglev-graph-building-phase.cc
  src/compiler/turboshaft/memory-optimization-reducer.cc
  src/compiler/turboshaft/operations.cc
  src/compiler/turboshaft/optimize-phase.cc
  src/compiler/turboshaft/phase.cc
  src/compiler/turboshaft/pretenuring-propagation-reducer.cc
  src/compiler/turboshaft/recreate-schedule-phase.cc
  src/compiler/turboshaft/recreate-schedule.cc
  src/compiler/turboshaft/representations.cc
  src/compiler/turboshaft/sidetable.cc
  src/compiler/turboshaft/simplified-lowering-phase.cc
  src/compiler/turboshaft/simplify-tf-loops.cc
  src/compiler/turboshaft/store-store-elimination-phase.cc
  src/compiler/turboshaft/type-assertions-phase.cc
  src/compiler/turboshaft/type-parser.cc
  src/compiler/turboshaft/typed-optimizations-phase.cc
  src/compiler/turboshaft/typer.cc
  src/compiler/turboshaft/types.cc
  src/compiler/turboshaft/use-map.cc
  src/compiler/turboshaft/utils.cc
  src/compiler/type-cache.cc
  src/compiler/type-narrowing-reducer.cc
  src/compiler/typer.cc
  src/compiler/typed-optimization.cc
  src/compiler/types.cc
  src/compiler/value-numbering-reducer.cc
  src/compiler/verifier.cc
  src/compiler/zone-stats.cc
  # x64 backend
  src/compiler/backend/x64/code-generator-x64.cc
  src/compiler/backend/x64/instruction-scheduler-x64.cc
  src/compiler/backend/x64/instruction-selector-x64.cc
  src/compiler/backend/x64/unwinding-info-writer-x64.cc
)

# WebAssembly compiler sources
v8_src(V8_COMPILER_WASM_SOURCES
  src/compiler/int64-lowering.cc
  src/compiler/turboshaft/int64-lowering-phase.cc
  src/compiler/turboshaft/wasm-dead-code-elimination-phase.cc
  src/compiler/turboshaft/wasm-gc-optimize-phase.cc
  src/compiler/turboshaft/wasm-gc-typed-optimization-reducer.cc
  src/compiler/turboshaft/wasm-lowering-phase.cc
  src/compiler/turboshaft/wasm-optimize-phase.cc
  src/compiler/turboshaft/wasm-revec-phase.cc
  src/compiler/turboshaft/wasm-revec-reducer.cc
  src/compiler/turboshaft/wasm-turboshaft-compiler.cc
  src/compiler/wasm-address-reassociation.cc
  src/compiler/wasm-call-descriptors.cc
  src/compiler/wasm-compiler.cc
  src/compiler/wasm-escape-analysis.cc
  src/compiler/wasm-gc-lowering.cc
  src/compiler/wasm-gc-operator-reducer.cc
  src/compiler/wasm-graph-assembler.cc
  src/compiler/wasm-inlining-into-js.cc
  src/compiler/wasm-inlining.cc
  src/compiler/wasm-js-lowering.cc
  src/compiler/wasm-load-elimination.cc
  src/compiler/wasm-loop-peeling.cc
  src/compiler/wasm-typer.cc
  src/wasm/fuzzing/random-module-generation-stub.cc
  src/wasm/graph-builder-interface.cc
  src/wasm/memory-tracing.cc
  src/wasm/turboshaft-graph-interface.cc
  src/wasm/wrappers.cc
)

# =============================================================================
# v8_base_without_compiler sources (the massive core)
# =============================================================================
v8_src(V8_BASE_SOURCES
  src/api/api-arguments.cc
  src/api/api-natives.cc
  src/api/api.cc
  src/ast/ast-function-literal-id-reindexer.cc
  src/ast/ast-value-factory.cc
  src/ast/ast.cc
  src/ast/modules.cc
  src/ast/prettyprinter.cc
  src/ast/scopes.cc
  src/ast/source-range-ast-visitor.cc
  src/ast/variables.cc
  src/baseline/baseline.cc
  src/baseline/bytecode-offset-iterator.cc
  src/builtins/accessors.cc
  src/builtins/builtins-api.cc
  src/builtins/builtins-array.cc
  src/builtins/builtins-arraybuffer.cc
  src/builtins/builtins-async-module.cc
  src/builtins/builtins-atomics-synchronization.cc
  src/builtins/builtins-bigint.cc
  src/builtins/builtins-callsite.cc
  src/builtins/builtins-collections.cc
  src/builtins/builtins-console.cc
  src/builtins/builtins-dataview.cc
  src/builtins/builtins-date.cc
  src/builtins/builtins-error.cc
  src/builtins/builtins-function.cc
  src/builtins/builtins-global.cc
  src/builtins/builtins-internal.cc
  src/builtins/builtins-intl.cc
  src/builtins/builtins-json.cc
  src/builtins/builtins-lazy-gen.cc
  src/builtins/builtins-number.cc
  src/builtins/builtins-object.cc
  src/builtins/builtins-reflect.cc
  src/builtins/builtins-regexp.cc
  src/builtins/builtins-shadow-realm.cc
  src/builtins/builtins-shared-array.cc
  src/builtins/builtins-sharedarraybuffer.cc
  src/builtins/builtins-string.cc
  src/builtins/builtins-struct.cc
  src/builtins/builtins-symbol.cc
  src/builtins/builtins-temporal-gen.cc
  src/builtins/builtins-temporal.cc
  src/builtins/builtins-trace.cc
  src/builtins/builtins-typed-array.cc
  src/builtins/builtins-weak-refs.cc
  src/builtins/builtins.cc
  src/builtins/constants-table-builder.cc
  src/codegen/aligned-slot-allocator.cc
  src/codegen/assembler.cc
  src/codegen/bailout-reason.cc
  src/codegen/code-comments.cc
  src/codegen/code-desc.cc
  src/codegen/code-factory.cc
  src/codegen/code-reference.cc
  src/codegen/constant-pool.cc
  src/codegen/compilation-cache.cc
  src/codegen/compiler.cc
  src/codegen/external-reference-encoder.cc
  src/codegen/external-reference-table.cc
  src/codegen/external-reference.cc
  src/codegen/flush-instruction-cache.cc
  src/codegen/handler-table.cc
  src/codegen/interface-descriptors.cc
  src/codegen/machine-type.cc
  src/codegen/macro-assembler-base.cc
  src/codegen/maglev-safepoint-table.cc
  src/codegen/optimized-compilation-info.cc
  src/codegen/pending-optimization-table.cc
  src/codegen/register-configuration.cc
  src/codegen/reloc-info.cc
  src/codegen/safepoint-table.cc
  src/codegen/source-position-table.cc
  src/codegen/source-position.cc
  src/codegen/tick-counter.cc
  src/codegen/tnode.cc
  src/codegen/unoptimized-compilation-info.cc
  src/common/assert-scope.cc
  src/common/code-memory-access.cc
  src/common/ptr-compr.cc
  src/compiler-dispatcher/lazy-compile-dispatcher.cc
  src/compiler-dispatcher/optimizing-compile-dispatcher.cc
  src/compiler/linkage.cc
  src/date/date.cc
  src/date/dateparser.cc
  src/debug/debug-coverage.cc
  src/debug/debug-evaluate.cc
  src/debug/debug-frames.cc
  src/debug/debug-interface.cc
  src/debug/debug-property-iterator.cc
  src/debug/debug-scope-iterator.cc
  src/debug/debug-scopes.cc
  src/debug/debug-stack-trace-iterator.cc
  src/debug/debug.cc
  src/debug/liveedit-diff.cc
  src/debug/liveedit.cc
  src/deoptimizer/deoptimize-reason.cc
  src/deoptimizer/deoptimized-frame-info.cc
  src/deoptimizer/deoptimizer.cc
  src/deoptimizer/frame-translation-builder.cc
  src/deoptimizer/materialized-object-store.cc
  src/deoptimizer/translated-state.cc
  src/diagnostics/basic-block-profiler.cc
  src/diagnostics/compilation-statistics.cc
  src/diagnostics/disassembler.cc
  src/diagnostics/eh-frame.cc
  src/diagnostics/gdb-jit.cc
  src/diagnostics/objects-debug.cc
  src/diagnostics/objects-printer.cc
  src/diagnostics/perf-jit.cc
  src/diagnostics/unwinder.cc
  src/execution/arguments.cc
  src/execution/clobber-registers.cc
  src/execution/embedder-state.cc
  src/execution/encoded-c-signature.cc
  src/execution/execution.cc
  src/execution/frames.cc
  src/execution/futex-emulation.cc
  src/execution/interrupts-scope.cc
  src/execution/isolate.cc
  src/execution/local-isolate.cc
  src/execution/messages.cc
  src/execution/microtask-queue.cc
  src/execution/protectors.cc
  src/execution/simulator-base.cc
  src/execution/stack-guard.cc
  src/execution/thread-id.cc
  src/execution/thread-local-top.cc
  src/execution/tiering-manager.cc
  src/execution/v8threads.cc
  src/extensions/cputracemark-extension.cc
  src/extensions/externalize-string-extension.cc
  src/extensions/gc-extension.cc
  src/extensions/ignition-statistics-extension.cc
  src/extensions/statistics-extension.cc
  src/extensions/trigger-failure-extension.cc
  src/flags/flags.cc
  src/handles/global-handles.cc
  src/handles/handles.cc
  src/handles/local-handles.cc
  src/handles/persistent-handles.cc
  src/handles/shared-object-conveyor-handles.cc
  src/handles/traced-handles.cc
  src/heap/allocation-observer.cc
  src/heap/array-buffer-sweeper.cc
  src/heap/code-range.cc
  src/heap/code-stats.cc
  src/heap/collection-barrier.cc
  src/heap/combined-heap.cc
  src/heap/concurrent-marking.cc
  src/heap/cppgc-js/cpp-heap.cc
  src/heap/cppgc-js/cpp-snapshot.cc
  src/heap/cppgc-js/cross-heap-remembered-set.cc
  src/heap/cppgc-js/unified-heap-marking-state.cc
  src/heap/cppgc-js/unified-heap-marking-verifier.cc
  src/heap/cppgc-js/unified-heap-marking-visitor.cc
  src/heap/ephemeron-remembered-set.cc
  src/heap/evacuation-allocator.cc
  src/heap/evacuation-verifier.cc
  src/heap/factory-base.cc
  src/heap/factory.cc
  src/heap/finalization-registry-cleanup-task.cc
  src/heap/free-list.cc
  src/heap/gc-idle-time-handler.cc
  src/heap/gc-tracer.cc
  src/heap/heap-allocator.cc
  src/heap/heap-controller.cc
  src/heap/heap-layout-tracer.cc
  src/heap/heap-verifier.cc
  src/heap/heap-write-barrier.cc
  src/heap/heap.cc
  src/heap/incremental-marking-job.cc
  src/heap/incremental-marking.cc
  src/heap/index-generator.cc
  src/heap/large-spaces.cc
  src/heap/local-factory.cc
  src/heap/large-page.cc
  src/heap/local-heap.cc
  src/heap/main-allocator.cc
  src/heap/mark-compact.cc
  src/heap/mark-sweep-utilities.cc
  src/heap/marking-barrier.cc
  src/heap/memory-chunk-layout.cc
  src/heap/mutable-page.cc
  src/heap/marking-worklist.cc
  src/heap/marking.cc
  src/heap/memory-allocator.cc
  src/heap/memory-balancer.cc
  src/heap/memory-chunk-metadata.cc
  src/heap/memory-chunk.cc
  src/heap/memory-measurement.cc
  src/heap/memory-reducer.cc
  src/heap/minor-gc-job.cc
  src/heap/minor-mark-sweep.cc
  src/heap/new-spaces.cc
  src/heap/objects-visiting.cc
  src/heap/page.cc
  src/heap/object-stats.cc
  src/heap/paged-spaces.cc
  src/heap/pretenuring-handler.cc
  src/heap/read-only-heap.cc
  src/heap/read-only-promotion.cc
  src/heap/reference-summarizer.cc
  src/heap/read-only-spaces.cc
  src/heap/safepoint.cc
  src/heap/scavenger.cc
  src/heap/slot-set.cc
  src/heap/spaces.cc
  src/heap/stress-scavenge-observer.cc
  src/heap/sweeper.cc
  src/heap/traced-handles-marking-visitor.cc
  src/heap/trusted-range.cc
  src/heap/weak-object-worklists.cc
  src/heap/zapping.cc
  src/ic/call-optimization.cc
  src/ic/handler-configuration.cc
  src/ic/ic-stats.cc
  src/ic/ic.cc
  src/ic/stub-cache.cc
  src/init/bootstrapper.cc
  src/init/icu_util.cc
  src/init/isolate-allocator.cc
  src/init/startup-data-util.cc
  src/init/v8.cc
  src/interpreter/bytecode-array-builder.cc
  src/interpreter/bytecode-array-iterator.cc
  src/interpreter/bytecode-array-random-iterator.cc
  src/interpreter/bytecode-array-writer.cc
  src/interpreter/bytecode-decoder.cc
  src/interpreter/bytecode-flags.cc
  src/interpreter/bytecode-generator.cc
  src/interpreter/bytecode-label.cc
  src/interpreter/bytecode-node.cc
  src/interpreter/bytecode-operands.cc
  src/interpreter/bytecode-register-optimizer.cc
  src/interpreter/bytecode-register.cc
  src/interpreter/bytecode-source-info.cc
  src/interpreter/bytecodes.cc
  src/interpreter/constant-array-builder.cc
  src/interpreter/control-flow-builders.cc
  src/interpreter/handler-table-builder.cc
  src/interpreter/interpreter-intrinsics.cc
  src/interpreter/interpreter.cc
  src/json/json-parser.cc
  src/json/json-stringifier.cc
  src/logging/counters.cc
  src/logging/local-logger.cc
  src/logging/log-file.cc
  src/logging/log.cc
  src/logging/metrics.cc
  src/logging/runtime-call-stats.cc
  src/logging/tracing-flags.cc
  src/numbers/conversions.cc
  src/numbers/math-random.cc
  src/objects/abstract-code.cc
  src/objects/backing-store.cc
  src/objects/bigint.cc
  src/objects/bytecode-array.cc
  src/objects/call-site-info.cc
  src/objects/code-kind.cc
  src/objects/code.cc
  src/objects/compilation-cache-table.cc
  src/objects/contexts.cc
  src/objects/debug-objects.cc
  src/objects/deoptimization-data.cc
  src/objects/dependent-code.cc
  src/objects/elements-kind.cc
  src/objects/elements.cc
  src/objects/embedder-data-array.cc
  src/objects/feedback-vector.cc
  src/objects/field-type.cc
  src/objects/fixed-array.cc
  src/objects/instruction-stream.cc
  src/objects/intl-objects.cc
  src/objects/js-array-buffer.cc
  src/objects/js-atomics-synchronization.cc
  src/objects/js-break-iterator.cc
  src/objects/js-collator.cc
  src/objects/js-date-time-format.cc
  src/objects/js-display-names.cc
  src/objects/js-duration-format.cc
  src/objects/js-function.cc
  src/objects/js-list-format.cc
  src/objects/js-locale.cc
  src/objects/js-number-format.cc
  src/objects/js-objects.cc
  src/objects/js-plural-rules.cc
  src/objects/js-raw-json.cc
  src/objects/js-regexp.cc
  src/objects/js-relative-time-format.cc
  src/objects/js-segment-iterator.cc
  src/objects/js-segmenter.cc
  src/objects/js-segments.cc
  src/objects/js-struct.cc
  src/objects/js-temporal-objects.cc
  src/objects/keys.cc
  src/objects/literal-objects.cc
  src/objects/lookup-cache.cc
  src/objects/lookup.cc
  src/objects/managed.cc
  src/objects/map-updater.cc
  src/objects/map.cc
  src/objects/module.cc
  src/objects/object-type.cc
  src/objects/objects.cc
  src/objects/option-utils.cc
  src/objects/ordered-hash-table.cc
  src/objects/property-descriptor.cc
  src/objects/property.cc
  src/objects/regexp-match-info.cc
  src/objects/scope-info.cc
  src/objects/shared-function-info.cc
  src/objects/simd.cc
  src/objects/source-text-module.cc
  src/objects/string-comparator.cc
  src/objects/string-forwarding-table.cc
  src/objects/string-table.cc
  src/objects/string.cc
  src/objects/swiss-name-dictionary.cc
  src/objects/symbol-table.cc
  src/objects/synthetic-module.cc
  src/objects/tagged-impl.cc
  src/objects/template-objects.cc
  src/objects/templates.cc
  src/objects/transitions.cc
  src/objects/type-hints.cc
  src/objects/value-serializer.cc
  src/objects/visitors.cc
  src/parsing/func-name-inferrer.cc
  src/parsing/import-assertions.cc
  src/parsing/literal-buffer.cc
  src/parsing/parse-info.cc
  src/parsing/parser.cc
  src/parsing/parsing.cc
  src/parsing/pending-compilation-error-handler.cc
  src/parsing/preparse-data.cc
  src/parsing/preparser.cc
  src/parsing/rewriter.cc
  src/parsing/scanner-character-streams.cc
  src/parsing/scanner.cc
  src/parsing/token.cc
  src/profiler/allocation-tracker.cc
  src/profiler/cpu-profiler.cc
  src/profiler/heap-profiler.cc
  src/profiler/heap-snapshot-generator.cc
  src/profiler/profile-generator.cc
  src/profiler/profiler-listener.cc
  src/profiler/profiler-stats.cc
  src/profiler/sampling-heap-profiler.cc
  src/profiler/strings-storage.cc
  src/profiler/symbolizer.cc
  src/profiler/tick-sample.cc
  src/profiler/tracing-cpu-profiler.cc
  src/profiler/weak-code-registry.cc
  src/regexp/experimental/experimental-bytecode.cc
  src/regexp/experimental/experimental-compiler.cc
  src/regexp/experimental/experimental-interpreter.cc
  src/regexp/experimental/experimental.cc
  src/regexp/regexp-ast.cc
  src/regexp/regexp-bytecode-generator.cc
  src/regexp/regexp-bytecode-peephole.cc
  src/regexp/regexp-bytecodes.cc
  src/regexp/regexp-compiler-tonode.cc
  src/regexp/regexp-compiler.cc
  src/regexp/regexp-dotprinter.cc
  src/regexp/regexp-error.cc
  src/regexp/regexp-interpreter.cc
  src/regexp/regexp-macro-assembler-tracer.cc
  src/regexp/regexp-macro-assembler.cc
  src/regexp/regexp-parser.cc
  src/regexp/regexp-stack.cc
  src/regexp/regexp-utils.cc
  src/regexp/regexp.cc
  src/roots/roots.cc
  src/runtime/runtime-array.cc
  src/runtime/runtime-atomics.cc
  src/runtime/runtime-bigint.cc
  src/runtime/runtime-classes.cc
  src/runtime/runtime-collections.cc
  src/runtime/runtime-compiler.cc
  src/runtime/runtime-date.cc
  src/runtime/runtime-debug.cc
  src/runtime/runtime-forin.cc
  src/runtime/runtime-function.cc
  src/runtime/runtime-futex.cc
  src/runtime/runtime-generator.cc
  src/runtime/runtime-internal.cc
  src/runtime/runtime-intl.cc
  src/runtime/runtime-literals.cc
  src/runtime/runtime-module.cc
  src/runtime/runtime-numbers.cc
  src/runtime/runtime-object.cc
  src/runtime/runtime-operators.cc
  src/runtime/runtime-promise.cc
  src/runtime/runtime-proxy.cc
  src/runtime/runtime-regexp.cc
  src/runtime/runtime-scopes.cc
  src/runtime/runtime-shadow-realm.cc
  src/runtime/runtime-strings.cc
  src/runtime/runtime-symbol.cc
  src/runtime/runtime-temporal.cc
  src/runtime/runtime-test.cc
  src/runtime/runtime-test-wasm.cc
  src/runtime/runtime-trace.cc
  src/runtime/runtime-typedarray.cc
  src/runtime/runtime-weak-refs.cc
  src/runtime/runtime.cc
  src/temporal/temporal-parser.cc
  src/sandbox/code-pointer-table.cc
  src/sandbox/external-pointer-table.cc
  src/sandbox/sandbox.cc
  src/sandbox/testing.cc
  src/sandbox/trusted-pointer-table.cc
  src/snapshot/code-serializer.cc
  src/snapshot/context-deserializer.cc
  src/snapshot/context-serializer.cc
  src/snapshot/deserializer.cc
  src/snapshot/embedded/embedded-data.cc
  src/snapshot/object-deserializer.cc
  src/snapshot/read-only-deserializer.cc
  src/snapshot/read-only-serializer.cc
  src/snapshot/roots-serializer.cc
  src/snapshot/serializer-deserializer.cc
  src/snapshot/serializer.cc
  src/snapshot/shared-heap-deserializer.cc
  src/snapshot/shared-heap-serializer.cc
  src/snapshot/snapshot-data.cc
  src/snapshot/snapshot-source-sink.cc
  src/snapshot/snapshot-utils.cc
  src/snapshot/snapshot.cc
  src/snapshot/snapshot-compression.cc
  src/snapshot/sort-builtins.cc
  src/snapshot/startup-deserializer.cc
  src/snapshot/startup-serializer.cc
  src/strings/char-predicates.cc
  src/strings/string-builder.cc
  src/strings/string-case.cc
  src/strings/string-stream.cc
  src/strings/unicode-decoder.cc
  src/strings/unicode.cc
  src/strings/uri.cc
  src/tasks/cancelable-task.cc
  src/tasks/operations-barrier.cc
  src/tasks/task-utils.cc
  src/tracing/trace-event.cc
  src/tracing/traced-value.cc
  src/tracing/tracing-category-observer.cc
  src/utils/address-map.cc
  src/utils/allocation.cc
  src/utils/bit-vector.cc
  src/utils/detachable-vector.cc
  src/utils/hex-format.cc
  src/utils/identity-map.cc
  src/utils/memcopy.cc
  src/utils/ostreams.cc
  src/utils/sha-256.cc
  src/utils/utils.cc
  src/utils/version.cc
  src/zone/accounting-allocator.cc
  src/zone/type-stats.cc
  src/zone/zone-segment.cc
  src/zone/zone.cc
  # x64 architecture-specific
  src/codegen/shared-ia32-x64/macro-assembler-shared-ia32-x64.cc
  src/codegen/x64/assembler-x64.cc
  src/codegen/x64/cpu-x64.cc
  src/codegen/x64/macro-assembler-x64.cc
  src/deoptimizer/x64/deoptimizer-x64.cc
  src/diagnostics/x64/disasm-x64.cc
  src/diagnostics/x64/eh-frame-x64.cc
  src/diagnostics/x64/unwinder-x64.cc
  src/execution/x64/frame-constants-x64.cc
  src/regexp/x64/regexp-macro-assembler-x64.cc
  # halfsiphash
)

# Windows-specific v8_base source
if(WIN32)
  list(APPEND V8_BASE_SOURCES "${V8_ROOT}/src/diagnostics/unwinding-info-win64.cc")
endif()

# Sparkplug sources (baseline compiler)
v8_src(V8_SPARKPLUG_SOURCES
  src/baseline/baseline-batch-compiler.cc
  src/baseline/baseline-compiler.cc
)

# Maglev sources (mid-tier compiler)
v8_src(V8_MAGLEV_SOURCES
  src/maglev/maglev-assembler.cc
  src/maglev/maglev-code-generator.cc
  src/maglev/maglev-compilation-info.cc
  src/maglev/maglev-compilation-unit.cc
  src/maglev/maglev-compiler.cc
  src/maglev/maglev-concurrent-dispatcher.cc
  src/maglev/maglev-graph-builder.cc
  src/maglev/maglev-graph-printer.cc
  src/maglev/maglev-interpreter-frame-state.cc
  src/maglev/maglev-ir.cc
  src/maglev/maglev-phi-representation-selector.cc
  src/maglev/maglev-pipeline-statistics.cc
  src/maglev/maglev-regalloc.cc
  src/maglev/maglev.cc
  # x64
  src/maglev/x64/maglev-assembler-x64.cc
  src/maglev/x64/maglev-ir-x64.cc
)

# WebAssembly base sources
v8_src(V8_WASM_SOURCES
  src/asmjs/asm-js.cc
  src/asmjs/asm-parser.cc
  src/asmjs/asm-scanner.cc
  src/asmjs/asm-types.cc
  src/compiler/wasm-compiler-definitions.cc
  src/debug/debug-wasm-objects.cc
  src/runtime/runtime-wasm.cc
  src/trap-handler/handler-inside.cc
  src/trap-handler/handler-outside.cc
  src/trap-handler/handler-shared.cc
  src/wasm/baseline/liftoff-assembler.cc
  src/wasm/baseline/liftoff-compiler.cc
  src/wasm/baseline/parallel-move.cc
  src/wasm/canonical-types.cc
  src/wasm/code-space-access.cc
  src/wasm/constant-expression-interface.cc
  src/wasm/constant-expression.cc
  src/wasm/function-body-decoder.cc
  src/wasm/function-compiler.cc
  src/wasm/jump-table-assembler.cc
  src/wasm/local-decl-encoder.cc
  src/wasm/module-compiler.cc
  src/wasm/module-decoder.cc
  src/wasm/module-instantiate.cc
  src/wasm/names-provider.cc
  src/wasm/pgo.cc
  src/wasm/simd-shuffle.cc
  src/wasm/stacks.cc
  src/wasm/streaming-decoder.cc
  src/wasm/sync-streaming-decoder.cc
  src/wasm/value-type.cc
  src/wasm/wasm-code-manager.cc
  src/wasm/wasm-debug.cc
  src/wasm/wasm-disassembler.cc
  src/wasm/wasm-engine.cc
  src/wasm/wasm-external-refs.cc
  src/wasm/wasm-features.cc
  src/wasm/wasm-import-wrapper-cache.cc
  src/wasm/wasm-js.cc
  src/wasm/wasm-module-builder.cc
  src/wasm/wasm-module-sourcemap.cc
  src/wasm/wasm-module.cc
  src/wasm/wasm-objects.cc
  src/wasm/wasm-opcodes.cc
  src/wasm/wasm-result.cc
  src/wasm/wasm-serialization.cc
  src/wasm/wasm-subtyping.cc
  src/wasm/well-known-imports.cc
)

# Platform-specific trap handlers
if(WIN32)
  list(APPEND V8_WASM_SOURCES
    "${V8_ROOT}/src/trap-handler/handler-inside-win.cc"
    "${V8_ROOT}/src/trap-handler/handler-outside-win.cc"
  )
else()
  list(APPEND V8_WASM_SOURCES
    "${V8_ROOT}/src/trap-handler/handler-inside-posix.cc"
    "${V8_ROOT}/src/trap-handler/handler-outside-posix.cc"
  )
endif()

# ETW diagnostics sources (Windows)
v8_src(V8_ETW_SOURCES
  src/diagnostics/etw-jit-win.cc
)

# =============================================================================
# v8_initializers sources (builtins setup)
# =============================================================================
v8_src(V8_INITIALIZERS_SOURCES
  src/builtins/builtins-array-gen.cc
  src/builtins/builtins-async-function-gen.cc
  src/builtins/builtins-async-gen.cc
  src/builtins/builtins-async-generator-gen.cc
  src/builtins/builtins-async-iterator-gen.cc
  src/builtins/builtins-bigint-gen.cc
  src/builtins/builtins-call-gen.cc
  src/builtins/builtins-collections-gen.cc
  src/builtins/builtins-constructor-gen.cc
  src/builtins/builtins-conversion-gen.cc
  src/builtins/builtins-date-gen.cc
  src/builtins/builtins-generator-gen.cc
  src/builtins/builtins-global-gen.cc
  src/builtins/builtins-handler-gen.cc
  src/builtins/builtins-ic-gen.cc
  src/builtins/builtins-internal-gen.cc
  src/builtins/builtins-interpreter-gen.cc
  src/builtins/builtins-intl-gen.cc
  src/builtins/builtins-iterator-gen.cc
  src/builtins/builtins-microtask-queue-gen.cc
  src/builtins/builtins-number-gen.cc
  src/builtins/builtins-object-gen.cc
  src/builtins/builtins-promise-gen.cc
  src/builtins/builtins-proxy-gen.cc
  src/builtins/builtins-regexp-gen.cc
  src/builtins/builtins-shadow-realm-gen.cc
  src/builtins/builtins-sharedarraybuffer-gen.cc
  src/builtins/builtins-string-gen.cc
  src/builtins/builtins-typed-array-gen.cc
  src/builtins/growable-fixed-array-gen.cc
  src/builtins/profile-data-reader.cc
  src/builtins/setup-builtins-internal.cc
  src/codegen/code-stub-assembler.cc
  src/heap/setup-heap-internal.cc
  src/ic/accessor-assembler.cc
  src/ic/binary-op-assembler.cc
  src/ic/keyed-store-generic.cc
  src/ic/unary-op-assembler.cc
  src/interpreter/interpreter-assembler.cc
  src/interpreter/interpreter-generator.cc
  src/interpreter/interpreter-intrinsics-generator.cc
  # x64 builtins
  src/builtins/x64/builtins-x64.cc
)

# WebAssembly builtins
v8_src(V8_INITIALIZERS_WASM_SOURCES
  src/builtins/builtins-wasm-gen.cc
)

# =============================================================================
# Torque compiler sources
# =============================================================================
v8_src(V8_TORQUE_BASE_SOURCES
  src/torque/cc-generator.cc
  src/torque/cfg.cc
  src/torque/class-debug-reader-generator.cc
  src/torque/cpp-builder.cc
  src/torque/csa-generator.cc
  src/torque/declarable.cc
  src/torque/declaration-visitor.cc
  src/torque/declarations.cc
  src/torque/earley-parser.cc
  src/torque/global-context.cc
  src/torque/implementation-visitor.cc
  src/torque/instance-type-generator.cc
  src/torque/instructions.cc
  src/torque/kythe-data.cc
  src/torque/server-data.cc
  src/torque/source-positions.cc
  src/torque/torque-code-generator.cc
  src/torque/torque-compiler.cc
  src/torque/torque-parser.cc
  src/torque/type-inference.cc
  src/torque/type-oracle.cc
  src/torque/type-visitor.cc
  src/torque/types.cc
  src/torque/utils.cc
)

v8_src(V8_TORQUE_SOURCES
  src/torque/torque.cc
)

# =============================================================================
# mksnapshot sources
# =============================================================================
v8_src(V8_MKSNAPSHOT_SOURCES
  src/snapshot/embedded/embedded-empty.cc
  src/snapshot/embedded/embedded-file-writer.cc
  src/snapshot/embedded/platform-embedded-file-writer-aix.cc
  src/snapshot/embedded/platform-embedded-file-writer-base.cc
  src/snapshot/embedded/platform-embedded-file-writer-generic.cc
  src/snapshot/embedded/platform-embedded-file-writer-mac.cc
  src/snapshot/embedded/platform-embedded-file-writer-win.cc
  src/snapshot/mksnapshot.cc
  src/snapshot/snapshot-empty.cc
  src/snapshot/static-roots-gen.cc
)

# =============================================================================
# v8_snapshot sources (used in final library)
# =============================================================================
v8_src(V8_SNAPSHOT_SOURCES
  src/init/setup-isolate-deserialize.cc
)

# v8_init (for mksnapshot, sets up full isolate)
v8_src(V8_INIT_SOURCES
  src/init/setup-isolate-full.cc
)

# =============================================================================
# Bytecode builtins list generator
# =============================================================================
v8_src(V8_BYTECODE_BUILTINS_LIST_GENERATOR_SOURCES
  src/builtins/generate-bytecodes-builtins-list.cc
  src/interpreter/bytecode-operands.cc
  src/interpreter/bytecodes.cc
)
