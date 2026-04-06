# Post-run Validation

After the task finishes (either successfully or with an error), validate the outputs and write `run_checks.json`. This catches silent failures — jobs that exit 0 but produced garbage.

---

## Validation Checklist

Run these checks and record each result. Not all checks apply to every task — adapt based on `task_type` and which recording fields were declared.

| # | Check | Applies when | Pass condition |
|---|-------|-------------|----------------|
| 1 | Process exit code | Always | Exit code is 0 |
| 2 | scalars.csv exists and is non-empty | `scalar_fields` is non-empty | File exists, has header + at least 1 data row |
| 3 | events.jsonl exists and is non-empty | `intermediate_fields` is non-empty | File exists, has at least 1 valid JSON line |
| 4 | No NaN/Inf in scalars | `scalar_fields` is non-empty | `value` column contains no NaN, Inf, -Inf |
| 5 | All promised scalar fields present | `scalar_fields` is non-empty | Every field in `field_registry.json` → `scalar_fields` appears at least once in scalars.csv |
| 6 | All promised intermediate fields present | `intermediate_fields` is non-empty | Every field in `field_registry.json` → `intermediate_fields` appears as a key in at least one events.jsonl line |
| 7 | Expected count matches actual | When expected count is known (e.g., number of eval samples, number of epochs) | Actual row count or step count matches expected |
| 8 | Artifacts exist | `artifact_fields` is non-empty | Every declared artifact has at least one matching file in `artifacts/` |
| 9 | run_manifest.json has end_time | Always | `end_time` field is present and non-null |
| 10 | Monotonic steps in scalars | `scalar_fields` is non-empty | Within each phase, step values are non-decreasing |

---

## run_checks.json Format

```json
{
  "checked_at": "2026-04-06T16:45:30Z",
  "overall": "PASS",
  "checks": [
    {
      "id": 1,
      "name": "exit_code_zero",
      "status": "PASS",
      "detail": "Exit code: 0"
    },
    {
      "id": 2,
      "name": "scalars_csv_exists",
      "status": "PASS",
      "detail": "scalars.csv: 4523 rows"
    },
    {
      "id": 4,
      "name": "no_nan_inf",
      "status": "FAIL",
      "detail": "Found 3 NaN values in field 'grad_norm' at steps [1002, 1003, 1004]"
    },
    {
      "id": 5,
      "name": "all_scalar_fields_present",
      "status": "WARN",
      "detail": "Field 'gpu_memory_allocated' declared but never recorded"
    }
  ]
}
```

### Status values

- **PASS**: check succeeded
- **FAIL**: check failed — something is wrong with the run
- **WARN**: check detected a potential issue but it's not necessarily a failure (e.g., a declared field was never written)
- **SKIP**: check was not applicable to this run

### Overall status

- `"PASS"` if all checks are PASS or SKIP
- `"WARN"` if any check is WARN but none are FAIL
- `"FAIL"` if any check is FAIL

---

## Reporting to the User

After validation, print a summary:

```
═══════════════════════════════════════════
  Post-run Validation
═══════════════════════════════════════════

  Overall: PASS ✓  (or FAIL ✗ / WARN ⚠)

  ✓ exit_code_zero — Exit code: 0
  ✓ scalars_csv_exists — 4523 rows
  ✓ events_jsonl_exists — 10000 lines
  ✗ no_nan_inf — 3 NaN values in grad_norm at steps 1002-1004
  ⚠ all_scalar_fields_present — gpu_memory_allocated never recorded

  Results saved to: {exp_dir}/run_checks.json
═══════════════════════════════════════════
```

If any check is FAIL, flag it clearly: `[CHECK] FAILED: {detail}` — this makes it easy to grep logs for failures.

---

## Automated Validation Script

For use in job scripts, generate a validation script that runs after the entrypoint:

```python
import csv
import json
from pathlib import Path
import datetime

def validate_run(exp_dir: str) -> dict:
    exp = Path(exp_dir)
    checks = []

    # Check 1: exit code (passed from shell)
    # Check 2: scalars.csv
    scalars_path = exp / "records" / "scalars.csv"
    if scalars_path.exists():
        with open(scalars_path) as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        checks.append({
            "id": 2, "name": "scalars_csv_exists",
            "status": "PASS", "detail": f"scalars.csv: {len(rows)} rows"
        })

        # Check 4: NaN/Inf
        bad = [(r["step"], r["field"]) for r in rows
               if r["value"].lower() in ("nan", "inf", "-inf")]
        checks.append({
            "id": 4, "name": "no_nan_inf",
            "status": "FAIL" if bad else "PASS",
            "detail": f"Found {len(bad)} NaN/Inf values" if bad else "No NaN/Inf"
        })
    else:
        checks.append({
            "id": 2, "name": "scalars_csv_exists",
            "status": "FAIL", "detail": "scalars.csv not found"
        })

    # ... additional checks based on field_registry.json ...

    overall = "FAIL" if any(c["status"] == "FAIL" for c in checks) \
              else "WARN" if any(c["status"] == "WARN" for c in checks) \
              else "PASS"

    result = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "overall": overall,
        "checks": checks
    }

    (exp / "run_checks.json").write_text(json.dumps(result, indent=2))
    return result
```
