---
name: verify
description: Run real verification — tests, type checks, and linting
allowed-tools: Bash
---

Run actual verification checks on the current project. Do NOT simulate or guess results — execute real commands and report their actual output.

## Steps

1. Auto-detect the project type from the working directory
2. Run the appropriate checks:

### Tests
- `pubspec.yaml` → `flutter test`
- `package.json` with test script → `npm test`
- `pyproject.toml` / `pytest.ini` → `python -m pytest`
- `Cargo.toml` → `cargo test`
- `go.mod` → `go test ./...`

### Type Checks
- TypeScript → `npx tsc --noEmit`
- Python (mypy) → `python -m mypy .`
- Dart → `flutter analyze`

### Linting
- TypeScript/JS → `npx eslint .`
- Python → `python -m ruff check .`
- Dart → `dart analyze`

3. Report the REAL output from each command. Format:

```
✅ Tests: 42 passed, 0 failed
⚠️ TypeCheck: 2 errors in src/utils.ts
✅ Lint: clean
```

CRITICAL: Never fabricate results. If a check fails, report the failure honestly.
