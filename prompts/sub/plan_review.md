# Sub-Agent Prompt: Plan Review

## Task

Review a proposed plan for adding V8 `{V8_VERSION}` MSVC CMake build support and identify issues before execution begins.

## Input

- `PLAN`: The proposed plan (steps, expected changes, etc.)
- `FEATURES_JSON`: The version feature manifest
- `REFERENCE_BRANCH`: The nearest working branch for comparison
- `VERSION_DIFF`: Key differences between target and reference version

## Review Checklist

### Completeness
- [ ] Does the plan account for all required CMake files?
- [ ] Are all V8 sub-targets covered (libbase, libplatform, compiler, base, initializers, snapshot)?
- [ ] Is ICU handling addressed?
- [ ] Is the patch strategy clear?
- [ ] Are test targets included?

### Feasibility
- [ ] Are there any features in the plan that don't exist in this V8 version?
  - e.g., Maglev before V8 ~10.x, Turboshaft before V8 ~11.x, Sandbox before V8 ~12.x
- [ ] Are third-party dependencies correct for this version?
  - e.g., highway/simdutf/fp16 are newer additions
- [ ] Is the C++ standard requirement correct? (C++17 for older, C++20 for V8 13+)
- [ ] Are compile definitions appropriate for this version?

### Risk Assessment
- [ ] What are the 3 biggest risks for this specific version?
- [ ] Which files will need the most manual work?
- [ ] Are there known breaking changes between reference and target?
- [ ] Estimated number of MSVC patch hunks needed?

## Output

```json
{
  "verdict": "APPROVE|REVISE|REJECT",
  "issues": [
    {
      "severity": "blocker|major|minor",
      "description": "...",
      "recommendation": "..."
    }
  ],
  "risks": [
    {
      "area": "...",
      "likelihood": "high|medium|low",
      "impact": "high|medium|low",
      "mitigation": "..."
    }
  ],
  "missing_steps": ["..."],
  "unnecessary_steps": ["..."],
  "revised_estimate": "low|medium|high effort"
}
```
