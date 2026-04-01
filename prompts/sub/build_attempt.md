# Sub-Agent Prompt: Build Attempt & Error Capture

## Task

Attempt to build V8 `{V8_VERSION}` and capture the results for analysis.

## Input

- `BUILD_DIR`: Path to the build directory (e.g., `E:/work/v8/build`)
- `SOURCE_DIR`: Path to the repo root (e.g., `E:/work/v8`)
- `BUILD_TYPE`: `Release` or `Debug`
- `PHASE`: Which build phase to attempt (`configure`, `build_libs`, `build_all`)

## Steps

### Phase: configure
```bash
cmake -B {BUILD_DIR} -G Ninja -DCMAKE_BUILD_TYPE={BUILD_TYPE}
```
Capture full output. Success = exit code 0 and "Configuring done" in output.

### Phase: build_libs
Build just the V8 libraries (not d8, not tests):
```bash
cmake --build {BUILD_DIR} --target v8 -j 16 2>&1
```
This builds: torque → generated code → mksnapshot → snapshot → all v8 libs.

### Phase: build_all
Build everything including d8 and tests:
```bash
cmake --build {BUILD_DIR} -j 16 2>&1
```

## Output Format

Return a JSON report:
```json
{
  "phase": "configure|build_libs|build_all",
  "success": true|false,
  "exit_code": N,
  "duration_seconds": N,
  "progress": "X/Y steps completed",
  "errors": [
    {
      "file": "path/to/file.cc",
      "line": N,
      "code": "C2xxx or LINK error code",
      "message": "full error message",
      "context": "2 lines before and after"
    }
  ],
  "warnings_count": N,
  "first_error_at_step": "X/Y",
  "log_tail": "last 100 lines of output"
}
```

## Important

- Use `-j 16` for parallel builds but note that parallel error output can interleave
- If configure fails, do NOT attempt build
- If build_libs succeeds, report and let coordinator decide whether to proceed to build_all
- Capture BOTH stdout and stderr (`2>&1`)
- For very large error output (>500 errors), truncate to first 50 unique errors
- Note the last successfully compiled file before the first error — this helps identify progress
