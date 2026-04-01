# MSVC Compatibility Fix Patterns

This is a living catalog of MSVC-specific issues encountered when building V8
and their standard fixes. Each pattern has an ID (P1, P2, ...) referenced by
the error analysis and patch creation prompts.

## P1: `__attribute__((packed))` → `#pragma pack`

**Error**: `warning C4068: unknown pragma` or struct size mismatch
**Versions affected**: All

```cpp
// Before (GCC/Clang):
struct __attribute__((packed)) Foo {
  uint8_t a;
  uint32_t b;
};

// After (MSVC-compatible):
#pragma pack(push, 1)
struct Foo {
  uint8_t a;
  uint32_t b;
};
#pragma pack(pop)
```

## P2: `__attribute__((visibility(...)))` → remove

**Error**: `error C2059: syntax error: '__attribute__'`
**Versions affected**: All

For static library builds, visibility attributes are unnecessary.

```cpp
// Before:
class __attribute__((visibility("default"))) V8_EXPORT Foo {};
// After:
class V8_EXPORT Foo {};
```

Note: V8 usually uses `V8_EXPORT` macros which handle this. Check if the macro
definition itself needs fixing rather than each usage.

## P3: Qualified base class method calls

**Error**: `error C2352: illegal call of non-static member function`
**Versions affected**: All

MSVC sometimes rejects explicit base class qualification in templates.

```cpp
// Before:
template <typename T>
void Derived<T>::foo() {
  Base<T>::bar();  // MSVC may reject this
}

// After:
template <typename T>
void Derived<T>::foo() {
  this->bar();  // Works everywhere
}
```

## P4: `constexpr` + `inline` conflicts

**Error**: Various, often `error C2131: expression did not evaluate to a constant`
**Versions affected**: V8 10+

MSVC has different rules for constexpr evaluation in some contexts.

```cpp
// Before:
static constexpr inline int kFoo = ComputeFoo();
// After (if ComputeFoo isn't constexpr in MSVC's view):
static inline int kFoo = ComputeFoo();
```

## P5: Zero-length arrays

**Error**: `error C2466: cannot allocate an array of constant size 0`
**Versions affected**: All

```cpp
// Before:
char data[0];

// After — use V8's padding template if available:
V8MsvcPadding<0> data;

// Or simply:
char data[1];  // with appropriate size adjustments
```

## P6: `__PRETTY_FUNCTION__` → `__FUNCSIG__`

**Error**: `error C2065: '__PRETTY_FUNCTION__': undeclared identifier`
**Versions affected**: All

```cpp
#ifdef _MSC_VER
#define V8_PRETTY_FUNCTION __FUNCSIG__
#else
#define V8_PRETTY_FUNCTION __PRETTY_FUNCTION__
#endif
```

Note: V8 14+ usually handles this in `v8config.h`. Older versions may not.

## P7: `__attribute__((tls_model(...)))` on thread_local

**Error**: `error C2059: syntax error`
**Versions affected**: All

```cpp
// Before:
thread_local __attribute__((tls_model("initial-exec"))) int counter;
// After:
thread_local int counter;
```

MSVC doesn't support TLS model hints. The default model works fine on Windows.

## P8: Aggregate initialization strictness

**Error**: `error C2440: 'initializing': cannot convert` or `C2280: attempting to reference a deleted function`
**Versions affected**: V8 12+ (C++20 aggregate changes)

MSVC is stricter about C++20 aggregate initialization rules.

```cpp
// Before (works in GCC/Clang):
struct Foo { int x; Foo() = delete; };
Foo f{42};  // MSVC rejects: Foo is not an aggregate

// After:
struct Foo { int x; };  // Remove deleted constructor
Foo f{42};
```

## P9: Template instantiation / SFINAE differences

**Error**: Various template errors
**Versions affected**: All

MSVC evaluates templates differently, especially:
- Two-phase lookup is stricter in some cases
- Dependent name resolution differs
- `requires` clause evaluation order may differ

Common fix: Add `typename` keyword for dependent types.

```cpp
// Before:
template <typename T>
void foo(typename T::value_type* p = T::null());
// After (explicit typename):
template <typename T>
void foo(typename T::value_type* p = T::null());  // usually already correct
```

## P10: Macro expansion with `__VA_OPT__` / variadic macros

**Error**: Various preprocessor errors
**Versions affected**: V8 13+ (uses C++20 preprocessor features)

Requires `/Zc:preprocessor` flag (already set in our build). If still failing,
the macro may need restructuring.

## P11: `alignas` on zero-length or flexible array members

**Error**: `error C2719` or alignment-related errors
**Versions affected**: V8 12+

```cpp
// Before:
alignas(8) char data[];
// After:
char data[];  // Remove alignas from flexible member
```

## P12: Enum forward declarations

**Error**: `error C2371: redefinition; different basic types`
**Versions affected**: V8 9-11

MSVC requires enum underlying types to match between forward declaration and definition.

## P13: `[[maybe_unused]]` on template parameters

**Error**: `error C7608` or ignored attribute warnings
**Versions affected**: V8 12+

Some MSVC versions don't support `[[maybe_unused]]` on template parameters.
Use `(void)param;` cast instead.

---

## Adding New Patterns

When you discover a new MSVC fix pattern:
1. Assign it the next ID (P14, P15, ...)
2. Document: error message, affected versions, before/after code
3. Add it to this file
4. Reference it in your error analysis output
