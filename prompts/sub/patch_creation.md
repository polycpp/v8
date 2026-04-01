# Sub-Agent Prompt: MSVC Compatibility Patch Creation

## Task

Fix MSVC compilation errors in V8 `{V8_VERSION}` source code by creating or extending `patches/001-msvc-compatibility.patch`.

## Input

- `V8_SOURCE_DIR`: Path to V8 source tree
- `ERROR_ANALYSIS`: JSON output from error analysis (MSVC_CODE_ISSUE entries)
- `MSVC_PATTERNS`: Content of `docs/MSVC_PATTERNS.md` (known fix patterns)
- `REFERENCE_PATCH`: Path to patch from nearest version (for reference, NOT to copy blindly)

## Rules

1. **Minimal changes** — fix only what MSVC requires. Do not refactor, clean up, or "improve" V8 code.
2. **No functional changes** — the fix must produce identical behavior to the original code.
3. **Prefer standard C++** — if there's a standards-compliant way to fix it, prefer that over MSVC-specific workarounds.
4. **Use `#ifdef _MSC_VER`** only when the fix would break other compilers.
5. **Document each fix** — add a brief comment explaining why the change is needed.

## Common MSVC Fix Patterns

Apply these known patterns (see `docs/MSVC_PATTERNS.md` for details):

### P1: `__attribute__((packed))` → `#pragma pack`
```cpp
// Before (GCC/Clang):
struct __attribute__((packed)) Foo { ... };

// After (MSVC):
#pragma pack(push, 1)
struct Foo { ... };
#pragma pack(pop)
```

### P2: `__attribute__((visibility("...")))` → remove for static builds
```cpp
// Before:
class __attribute__((visibility("default"))) Foo { ... };
// After:
class Foo { ... };
```

### P3: Template qualified base class calls
```cpp
// Before (MSVC rejects):
Base<T>::method();
// After:
this->method();  // or using Base<T>::method;
```

### P4: constexpr + inline conflicts
MSVC sometimes needs `inline` removed when `constexpr` is present, or vice versa.

### P5: Zero-length array in struct
```cpp
// Before:
char data[0];
// After (MSVC):
char data[1];  // or use flexible array member
```

### P6: `__PRETTY_FUNCTION__` → `__FUNCSIG__`
```cpp
#ifdef _MSC_VER
#define PRETTY_FUNCTION __FUNCSIG__
#else
#define PRETTY_FUNCTION __PRETTY_FUNCTION__
#endif
```

### P7: `thread_local` with `__attribute__((tls_model(...)))`
```cpp
// Before:
thread_local __attribute__((tls_model("initial-exec"))) int x;
// After:
thread_local int x;
```

### P8: Aggregate initialization differences
MSVC is stricter about aggregate initialization with deleted/explicit constructors.

### P9: SFINAE / template metaprogramming differences
MSVC evaluates templates differently. Common fixes:
- Add explicit `typename` keywords
- Break complex expressions into steps
- Use `if constexpr` instead of SFINAE where possible

## Workflow

1. Sort errors by file to minimize patch hunks
2. For each error:
   a. Read the source file around the error line
   b. Identify which pattern applies (P1-P9 or new)
   c. Apply the minimal fix
   d. If it's a new pattern, document it
3. Generate the patch using `git diff` from the V8 source directory
4. Verify the patch applies cleanly: `cd v8-src && git apply --check ../patches/001-msvc-compatibility.patch`

## Output

1. The patch file content
2. A summary table:

```
| File | Line | Error | Pattern | Fix |
|------|------|-------|---------|-----|
| src/foo.cc | 123 | C2xxx | P3 | Added this-> prefix |
```

3. Any new patterns discovered (to add to MSVC_PATTERNS.md)

## Gotchas

- Don't fix warnings, only errors (unless a warning is promoted to error by /WX)
- Some errors cascade — fix the root cause first, rebuild, then check if downstream errors resolve
- V8 uses a lot of macros — sometimes the fix needs to be in the macro definition, not the usage site
- Check if the error is in generated code (torque output) — those need fixes in the torque source or generator, not the output
