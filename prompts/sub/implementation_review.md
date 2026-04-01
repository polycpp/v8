# Sub-Agent Prompt: Implementation Review

## Task

Review changes made during V8 `{V8_VERSION}` build support implementation and identify issues before the next build attempt.

## Input

- `CHANGES`: List of files modified and a summary of changes
- `BUILD_ERRORS_BEFORE`: Error analysis from the previous build attempt
- `FIXES_APPLIED`: Description of fixes that were applied
- `V8_VERSION`: Target version
- `FEATURES_JSON`: Version feature manifest

## Review Dimensions

### 1. Correctness
- Do the source list changes match actual files on disk?
- Are removed files actually absent from this V8 version?
- Are added files actually present?
- Do compile definition changes match the feature manifest?
- Does the patch apply cleanly?

### 2. Completeness
- Do the fixes address all reported errors, or just a subset?
- Are there likely cascade effects (fixing one error reveals others)?
- Are there files in the same directory as a fix that might need similar fixes?

### 3. Side Effects
- Could any fix break a previously-working compilation unit?
- Does a source list change affect multiple targets?
- Does a compile definition change affect all targets when it should only affect one?

### 4. Patch Quality
- Are patch changes minimal?
- Is each hunk necessary?
- Are there `#ifdef _MSC_VER` guards where needed?
- Would any fix break non-MSVC builds?

## Output

```json
{
  "verdict": "PROCEED|FIX_FIRST|ROLLBACK",
  "issues": [
    {
      "severity": "blocker|major|minor",
      "file": "...",
      "description": "...",
      "action": "..."
    }
  ],
  "confidence": "high|medium|low",
  "expected_errors_remaining": "N (estimate)",
  "recommendations": ["..."]
}
```

## Decision Criteria

- **PROCEED**: Fixes look correct, rebuild to see progress
- **FIX_FIRST**: Found issues that should be fixed before rebuilding (saves a build cycle)
- **ROLLBACK**: Fixes introduce new problems; revert and try a different approach
