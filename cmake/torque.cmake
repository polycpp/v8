# =============================================================================
# Torque code generation
# =============================================================================
# Torque is V8's domain-specific language for builtins. It generates C++ code
# that must be compiled as part of the V8 build.
#
# Build flow:
#   1. Build the 'torque' compiler executable
#   2. Run torque on .tq files to generate C++ sources
#   3. The generated C++ is compiled into v8_initializers and v8_base
# =============================================================================

set(V8_TORQUE_OUTPUT_DIR "${V8_GENERATED_DIR}/torque-generated")

# =============================================================================
# Torque input files (.tq)
# =============================================================================
set(V8_TORQUE_FILES
  src/builtins/aggregate-error.tq
  src/builtins/array-at.tq
  src/builtins/array-concat.tq
  src/builtins/array-copywithin.tq
  src/builtins/array-every.tq
  src/builtins/array-filter.tq
  src/builtins/array-find.tq
  src/builtins/array-findindex.tq
  src/builtins/array-findlast.tq
  src/builtins/array-findlastindex.tq
  src/builtins/array-flat.tq
  src/builtins/array-foreach.tq
  src/builtins/array-from-async.tq
  src/builtins/array-from.tq
  src/builtins/array-isarray.tq
  src/builtins/array-join.tq
  src/builtins/array-lastindexof.tq
  src/builtins/array-map.tq
  src/builtins/array-of.tq
  src/builtins/array-reduce-right.tq
  src/builtins/array-reduce.tq
  src/builtins/array-reverse.tq
  src/builtins/array-shift.tq
  src/builtins/array-slice.tq
  src/builtins/array-some.tq
  src/builtins/array-splice.tq
  src/builtins/array-to-reversed.tq
  src/builtins/array-to-sorted.tq
  src/builtins/array-to-spliced.tq
  src/builtins/array-unshift.tq
  src/builtins/array-with.tq
  src/builtins/array.tq
  src/builtins/arraybuffer.tq
  src/builtins/base.tq
  src/builtins/boolean.tq
  src/builtins/builtins-bigint.tq
  src/builtins/builtins-string.tq
  src/builtins/cast.tq
  src/builtins/collections.tq
  src/builtins/constructor.tq
  src/builtins/conversion.tq
  src/builtins/convert.tq
  src/builtins/console.tq
  src/builtins/data-view.tq
  src/builtins/finalization-registry.tq
  src/builtins/frames.tq
  src/builtins/frame-arguments.tq
  src/builtins/function.tq
  src/builtins/growable-fixed-array.tq
  src/builtins/ic-callable.tq
  src/builtins/ic.tq
  src/builtins/internal-coverage.tq
  src/builtins/internal.tq
  src/builtins/iterator.tq
  src/builtins/iterator-from.tq
  src/builtins/iterator-helpers.tq
  src/builtins/map-groupby.tq
  src/builtins/math.tq
  src/builtins/number.tq
  src/builtins/object-fromentries.tq
  src/builtins/object-groupby.tq
  src/builtins/object.tq
  src/builtins/promise-abstract-operations.tq
  src/builtins/promise-all.tq
  src/builtins/promise-all-element-closure.tq
  src/builtins/promise-any.tq
  src/builtins/promise-constructor.tq
  src/builtins/promise-finally.tq
  src/builtins/promise-jobs.tq
  src/builtins/promise-misc.tq
  src/builtins/promise-race.tq
  src/builtins/promise-reaction-job.tq
  src/builtins/promise-resolve.tq
  src/builtins/promise-then.tq
  src/builtins/promise-withresolvers.tq
  src/builtins/proxy-constructor.tq
  src/builtins/proxy-delete-property.tq
  src/builtins/proxy-get-property.tq
  src/builtins/proxy-get-prototype-of.tq
  src/builtins/proxy-has-property.tq
  src/builtins/proxy-is-extensible.tq
  src/builtins/proxy-prevent-extensions.tq
  src/builtins/proxy-revocable.tq
  src/builtins/proxy-revoke.tq
  src/builtins/proxy-set-property.tq
  src/builtins/proxy-set-prototype-of.tq
  src/builtins/proxy.tq
  src/builtins/reflect.tq
  src/builtins/regexp-exec.tq
  src/builtins/regexp-match-all.tq
  src/builtins/regexp-match.tq
  src/builtins/regexp-replace.tq
  src/builtins/regexp-search.tq
  src/builtins/regexp-source.tq
  src/builtins/regexp-split.tq
  src/builtins/regexp-test.tq
  src/builtins/regexp.tq
  src/builtins/set-difference.tq
  src/builtins/set-intersection.tq
  src/builtins/set-is-disjoint-from.tq
  src/builtins/set-is-subset-of.tq
  src/builtins/set-is-superset-of.tq
  src/builtins/set-symmetric-difference.tq
  src/builtins/set-union.tq
  src/builtins/string-at.tq
  src/builtins/string-endswith.tq
  src/builtins/string-html.tq
  src/builtins/string-includes.tq
  src/builtins/string-indexof.tq
  src/builtins/string-iswellformed.tq
  src/builtins/string-iterator.tq
  src/builtins/string-match-search.tq
  src/builtins/string-pad.tq
  src/builtins/string-repeat.tq
  src/builtins/string-replaceall.tq
  src/builtins/string-slice.tq
  src/builtins/string-startswith.tq
  src/builtins/string-substr.tq
  src/builtins/string-substring.tq
  src/builtins/string-towellformed.tq
  src/builtins/string-trim.tq
  src/builtins/suppressed-error.tq
  src/builtins/symbol.tq
  src/builtins/torque-internal.tq
  src/builtins/typed-array-at.tq
  src/builtins/typed-array-createtypedarray.tq
  src/builtins/typed-array-every.tq
  src/builtins/typed-array-entries.tq
  src/builtins/typed-array-filter.tq
  src/builtins/typed-array-find.tq
  src/builtins/typed-array-findindex.tq
  src/builtins/typed-array-findlast.tq
  src/builtins/typed-array-findlastindex.tq
  src/builtins/typed-array-foreach.tq
  src/builtins/typed-array-from.tq
  src/builtins/typed-array-keys.tq
  src/builtins/typed-array-of.tq
  src/builtins/typed-array-reduce.tq
  src/builtins/typed-array-reduceright.tq
  src/builtins/typed-array-set.tq
  src/builtins/typed-array-slice.tq
  src/builtins/typed-array-some.tq
  src/builtins/typed-array-sort.tq
  src/builtins/typed-array-subarray.tq
  src/builtins/typed-array-to-reversed.tq
  src/builtins/typed-array-to-sorted.tq
  src/builtins/typed-array-values.tq
  src/builtins/typed-array-with.tq
  src/builtins/typed-array.tq
  src/builtins/weak-ref.tq
  src/ic/handler-configuration.tq
  src/objects/allocation-site.tq
  src/objects/api-callbacks.tq
  src/objects/arguments.tq
  src/objects/bigint.tq
  src/objects/call-site-info.tq
  src/objects/cell.tq
  src/objects/bytecode-array.tq
  src/objects/contexts.tq
  src/objects/data-handler.tq
  src/objects/debug-objects.tq
  src/objects/descriptor-array.tq
  src/objects/embedder-data-array.tq
  src/objects/feedback-cell.tq
  src/objects/feedback-vector.tq
  src/objects/fixed-array.tq
  src/objects/foreign.tq
  src/objects/free-space.tq
  src/objects/heap-number.tq
  src/objects/heap-object.tq
  src/objects/js-array-buffer.tq
  src/objects/js-array.tq
  src/objects/js-atomics-synchronization.tq
  src/objects/js-collection-iterator.tq
  src/objects/js-collection.tq
  src/objects/js-function.tq
  src/objects/js-generator.tq
  src/objects/js-iterator-helpers.tq
  src/objects/js-objects.tq
  src/objects/js-promise.tq
  src/objects/js-proxy.tq
  src/objects/js-raw-json.tq
  src/objects/js-regexp-string-iterator.tq
  src/objects/js-regexp.tq
  src/objects/js-shadow-realm.tq
  src/objects/js-shared-array.tq
  src/objects/js-struct.tq
  src/objects/js-temporal-objects.tq
  src/objects/js-weak-refs.tq
  src/objects/literal-objects.tq
  src/objects/map.tq
  src/objects/megadom-handler.tq
  src/objects/microtask.tq
  src/objects/module.tq
  src/objects/name.tq
  src/objects/oddball.tq
  src/objects/hole.tq
  src/objects/trusted-object.tq
  src/objects/ordered-hash-table.tq
  src/objects/primitive-heap-object.tq
  src/objects/promise.tq
  src/objects/property-array.tq
  src/objects/property-cell.tq
  src/objects/property-descriptor-object.tq
  src/objects/prototype-info.tq
  src/objects/regexp-match-info.tq
  src/objects/scope-info.tq
  src/objects/script.tq
  src/objects/shared-function-info.tq
  src/objects/source-text-module.tq
  src/objects/string.tq
  src/objects/struct.tq
  src/objects/swiss-hash-table-helpers.tq
  src/objects/swiss-name-dictionary.tq
  src/objects/synthetic-module.tq
  src/objects/template-objects.tq
  src/objects/templates.tq
  src/objects/torque-defined-classes.tq
  src/objects/turbofan-types.tq
  src/objects/turboshaft-types.tq
  test/torque/test-torque.tq
  third_party/v8/builtins/array-sort.tq
)

# I18N torque files
if(V8_ENABLE_I18N)
  list(APPEND V8_TORQUE_FILES
    src/objects/intl-objects.tq
    src/objects/js-break-iterator.tq
    src/objects/js-collator.tq
    src/objects/js-date-time-format.tq
    src/objects/js-display-names.tq
    src/objects/js-duration-format.tq
    src/objects/js-list-format.tq
    src/objects/js-locale.tq
    src/objects/js-number-format.tq
    src/objects/js-plural-rules.tq
    src/objects/js-relative-time-format.tq
    src/objects/js-segment-iterator.tq
    src/objects/js-segmenter.tq
    src/objects/js-segments.tq
  )
endif()

# WebAssembly torque files
if(V8_ENABLE_WEBASSEMBLY)
  list(APPEND V8_TORQUE_FILES
    src/builtins/js-to-js.tq
    src/builtins/js-to-wasm.tq
    src/builtins/wasm.tq
    src/builtins/wasm-strings.tq
    src/builtins/wasm-to-js.tq
    src/debug/debug-wasm-objects.tq
    src/wasm/wasm-objects.tq
  )
endif()

# Convert to absolute paths
set(V8_TORQUE_FILES_ABS "")
foreach(_tq ${V8_TORQUE_FILES})
  list(APPEND V8_TORQUE_FILES_ABS "${V8_ROOT}/${_tq}")
endforeach()

# =============================================================================
# Compute torque-generated output file lists
# =============================================================================

# Fixed torque outputs (not per-file)
set(TORQUE_GENERATED_FIXED
  "${V8_TORQUE_OUTPUT_DIR}/bit-fields.h"
  "${V8_TORQUE_OUTPUT_DIR}/builtin-definitions.h"
  "${V8_TORQUE_OUTPUT_DIR}/class-debug-readers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/class-debug-readers.h"
  "${V8_TORQUE_OUTPUT_DIR}/class-forward-declarations.h"
  "${V8_TORQUE_OUTPUT_DIR}/class-verifiers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/class-verifiers.h"
  "${V8_TORQUE_OUTPUT_DIR}/csa-types.h"
  "${V8_TORQUE_OUTPUT_DIR}/debug-macros.cc"
  "${V8_TORQUE_OUTPUT_DIR}/debug-macros.h"
  "${V8_TORQUE_OUTPUT_DIR}/enum-verifiers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/exported-macros-assembler.cc"
  "${V8_TORQUE_OUTPUT_DIR}/exported-macros-assembler.h"
  "${V8_TORQUE_OUTPUT_DIR}/factory.cc"
  "${V8_TORQUE_OUTPUT_DIR}/factory.inc"
  "${V8_TORQUE_OUTPUT_DIR}/instance-types.h"
  "${V8_TORQUE_OUTPUT_DIR}/interface-descriptors.inc"
  "${V8_TORQUE_OUTPUT_DIR}/objects-body-descriptors-inl.inc"
  "${V8_TORQUE_OUTPUT_DIR}/objects-printer.cc"
  "${V8_TORQUE_OUTPUT_DIR}/visitor-lists.h"
)

# Per-file torque outputs: for each foo.tq, we get foo-tq-csa.cc, foo-tq.cc, etc.
set(TORQUE_GENERATED_CSA_SOURCES "")   # For v8_initializers (torque_generated_initializers)
set(TORQUE_GENERATED_DEF_SOURCES "")   # For v8_base (torque_generated_definitions)

foreach(_tq ${V8_TORQUE_FILES})
  # Convert src/builtins/array-at.tq -> torque-generated/src/builtins/array-at
  get_filename_component(_dir "${_tq}" DIRECTORY)
  get_filename_component(_name "${_tq}" NAME_WE)
  set(_prefix "${V8_TORQUE_OUTPUT_DIR}/${_dir}/${_name}")

  list(APPEND TORQUE_GENERATED_CSA_SOURCES "${_prefix}-tq-csa.cc")
  list(APPEND TORQUE_GENERATED_DEF_SOURCES "${_prefix}-tq.cc")
endforeach()

# Initializer sources = CSA sources + fixed enum/exported
set(TORQUE_GENERATED_INITIALIZERS_SOURCES
  ${TORQUE_GENERATED_CSA_SOURCES}
  "${V8_TORQUE_OUTPUT_DIR}/enum-verifiers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/exported-macros-assembler.cc"
)

# Definition sources = per-file -tq.cc + fixed class-verifiers, factory, objects-printer
set(TORQUE_GENERATED_DEFINITIONS_SOURCES
  ${TORQUE_GENERATED_DEF_SOURCES}
  "${V8_TORQUE_OUTPUT_DIR}/class-verifiers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/factory.cc"
  "${V8_TORQUE_OUTPUT_DIR}/objects-printer.cc"
  "${V8_TORQUE_OUTPUT_DIR}/class-debug-readers.cc"
  "${V8_TORQUE_OUTPUT_DIR}/debug-macros.cc"
)

# =============================================================================
# Build torque compiler
# =============================================================================
add_executable(torque
  ${V8_TORQUE_BASE_SOURCES}
  ${V8_TORQUE_SOURCES}
  ${V8_LIBBASE_SOURCES}
)
target_compile_definitions(torque PRIVATE V8_TORQUE_COMPILER _CRT_SECURE_NO_WARNINGS)
target_link_libraries(torque PRIVATE dbghelp.lib winmm.lib ws2_32.lib)
# Torque includes v8_libbase sources which depend on abseil headers
target_link_libraries(torque PRIVATE v8_abseil)

# =============================================================================
# Build bytecode builtins list generator
# =============================================================================
add_executable(bytecode_builtins_list_generator
  ${V8_BYTECODE_BUILTINS_LIST_GENERATOR_SOURCES}
)
target_include_directories(bytecode_builtins_list_generator PRIVATE "${V8_ROOT}")
target_link_libraries(bytecode_builtins_list_generator PRIVATE v8_libbase v8_abseil)

# =============================================================================
# Run bytecode builtins list generator
# =============================================================================
set(BYTECODES_BUILTINS_LIST_H "${V8_GENERATED_DIR}/builtins-generated/bytecodes-builtins-list.h")
file(MAKE_DIRECTORY "${V8_GENERATED_DIR}/builtins-generated")

add_custom_command(
  OUTPUT "${BYTECODES_BUILTINS_LIST_H}"
  COMMAND $<TARGET_FILE:bytecode_builtins_list_generator> "${BYTECODES_BUILTINS_LIST_H}"
  DEPENDS bytecode_builtins_list_generator
  COMMENT "Generating bytecodes builtins list"
)
add_custom_target(generate_bytecodes_builtins_list DEPENDS "${BYTECODES_BUILTINS_LIST_H}")

# =============================================================================
# Build gen-regexp-special-case generator
# =============================================================================
add_executable(gen_regexp_special_case
  "${V8_ROOT}/src/regexp/gen-regexp-special-case.cc"
)
target_link_libraries(gen_regexp_special_case PRIVATE v8_libbase v8_abseil icu_interface)

# Run it to generate special-case.cc
set(SPECIAL_CASE_CC "${V8_GENERATED_DIR}/src/regexp/special-case.cc")
file(MAKE_DIRECTORY "${V8_GENERATED_DIR}/src/regexp")

add_custom_command(
  OUTPUT "${SPECIAL_CASE_CC}"
  COMMAND $<TARGET_FILE:gen_regexp_special_case> "${SPECIAL_CASE_CC}"
  DEPENDS gen_regexp_special_case
  COMMENT "Generating regexp special-case.cc"
)
add_custom_target(generate_regexp_special_case DEPENDS "${SPECIAL_CASE_CC}")

# =============================================================================
# Run torque compiler
# =============================================================================
# Build the torque invocation command
set(TORQUE_ARGS
  -o "${V8_TORQUE_OUTPUT_DIR}"
  -v8-root "${V8_ROOT}"
)

# All torque output files
set(TORQUE_ALL_OUTPUTS
  ${TORQUE_GENERATED_FIXED}
  ${TORQUE_GENERATED_CSA_SOURCES}
  ${TORQUE_GENERATED_DEF_SOURCES}
)

# Write a helper script to run torque with all .tq files
# (Windows command line limit prevents passing hundreds of file args directly)
set(TORQUE_SCRIPT "${CMAKE_BINARY_DIR}/run_torque.cmake")
set(TORQUE_FILELIST "${CMAKE_BINARY_DIR}/torque_files.txt")

# Write the file list (one per line, relative to V8_ROOT for torque)
set(_tq_content "")
foreach(_tq ${V8_TORQUE_FILES})
  string(APPEND _tq_content "${_tq}\n")
endforeach()
file(WRITE "${TORQUE_FILELIST}" "${_tq_content}")

# Write a cmake script that reads the file list and invokes torque
file(WRITE "${TORQUE_SCRIPT}" "
file(STRINGS \"\${FILELIST}\" TQ_FILES)
execute_process(
  COMMAND \"\${TORQUE_EXE}\" -o \"\${OUTPUT_DIR}\" -v8-root \"\${V8_ROOT}\" \${TQ_FILES}
  WORKING_DIRECTORY \"\${V8_ROOT}\"
  RESULT_VARIABLE _result
)
if(_result)
  message(FATAL_ERROR \"Torque failed with exit code \${_result}\")
endif()
")

add_custom_command(
  OUTPUT ${TORQUE_ALL_OUTPUTS}
  COMMAND ${CMAKE_COMMAND}
    -DTORQUE_EXE=$<TARGET_FILE:torque>
    -DFILELIST=${TORQUE_FILELIST}
    -DOUTPUT_DIR=${V8_TORQUE_OUTPUT_DIR}
    -DV8_ROOT=${V8_ROOT}
    -P "${TORQUE_SCRIPT}"
  DEPENDS torque ${V8_TORQUE_FILES_ABS}
  WORKING_DIRECTORY "${V8_ROOT}"
  COMMENT "Running Torque compiler"
)

add_custom_target(run_torque DEPENDS ${TORQUE_ALL_OUTPUTS})
