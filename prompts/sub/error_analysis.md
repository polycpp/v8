# Sub-Agent Prompt: Build Error Analysis

## Task

Analyze build errors from a V8 MSVC CMake build attempt and categorize them for the coordinator.

## Input

You will receive:
- `BUILD_LOG`: The build output containing errors
- `V8_VERSION`: The V8 version being built
- `FEATURES_JSON`: Path to the version features manifest

## Error Categories

Classify each unique error into exactly one category:

### 1. MISSING_SOURCE
The build references a .cc/.h file that doesn't exist or a .cc file that exists but isn't in sources.cmake.

**Indicators**: `cannot open source file`, `No such file or directory`, `fatal error C1083`
**Fix**: Add/remove files in `cmake/sources.cmake`
**Output format**:
```
MISSING_SOURCE: file_path
  action: add|remove
  target: v8_base|v8_compiler|v8_libbase|...
  reason: file exists but not in sources / file in sources but deleted
```

### 2. MISSING_DEFINITION
A compile definition is missing or incorrect.

**Indicators**: `undeclared identifier` for V8 config macros, `#error` directives, preprocessor failures
**Fix**: Add/modify definitions in `CMakeLists.txt`
**Output format**:
```
MISSING_DEFINITION: DEFINE_NAME
  action: add|remove|change
  value: (if applicable)
  reason: required by file X
```

### 3. MSVC_CODE_ISSUE
MSVC-specific compilation error that requires patching V8 source code.

**Indicators**: Template errors, attribute syntax, packed struct issues, constexpr differences, SFINAE differences
**Fix**: Create/extend `patches/001-msvc-compatibility.patch`
**Output format**:
```
MSVC_CODE_ISSUE: short description
  file: v8-src/path/to/file.cc
  line: N
  error: C2XXX or similar
  pattern: (match to known pattern from MSVC_PATTERNS.md if possible)
  suggested_fix: brief description
```

### 4. MISSING_DEPENDENCY
A third-party dependency is missing or misconfigured.

**Indicators**: Cannot find header from third_party/, linker errors for external symbols
**Fix**: Update `fetch_deps.py` or cmake dependency config
**Output format**:
```
MISSING_DEPENDENCY: dependency_name
  action: add|update|configure
  reason: needed by target X
```

### 5. LINKER_ERROR
Unresolved symbols or duplicate symbols at link time.

**Indicators**: `LNK2001`, `LNK2019`, `LNK4006`, `LNK2038`
**Fix**: Varies — could be missing source, wrong library order, CRT mismatch
**Output format**:
```
LINKER_ERROR: symbol_name
  type: unresolved|duplicate|mismatch
  likely_cause: missing source in target X / library order / CRT mismatch
  suggested_fix: brief description
```

### 6. UNKNOWN
Errors that don't fit the above categories.

**Output format**:
```
UNKNOWN: short description
  file: path
  error: full error text
  notes: any observations
```

## Output Structure

Return a JSON object:
```json
{
  "total_errors": N,
  "unique_errors": N,
  "categories": {
    "MISSING_SOURCE": [...],
    "MISSING_DEFINITION": [...],
    "MSVC_CODE_ISSUE": [...],
    "MISSING_DEPENDENCY": [...],
    "LINKER_ERROR": [...],
    "UNKNOWN": [...]
  },
  "summary": "Brief overview of the error landscape",
  "recommended_fix_order": ["category1", "category2", ...],
  "estimated_effort": "low|medium|high"
}
```

## Important Notes

- Group duplicate errors (same root cause, different files) into one entry
- For MSVC_CODE_ISSUE, check `docs/MSVC_PATTERNS.md` for known patterns first
- Prioritize fixes that unblock the most other errors (e.g., a missing header that causes 100 downstream errors)
- If >200 unique errors, focus on the top 20 root causes
