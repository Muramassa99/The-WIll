"""Compare the complete measured grip sequence before/after duration-only work."""
import argparse
import hashlib
import json
from pathlib import Path


def semantics(value):
    if isinstance(value, dict):
        return {
            key: semantics(item)
            for key, item in value.items()
            if not (key.endswith("_ms") and isinstance(item, (int, float)))
            and key not in {"saved_contact_cache_statistics", "work_counts"}
        }
    if isinstance(value, list):
        return [semantics(item) for item in value]
    return value


def differences(before, after, path="$", out=None):
    out = [] if out is None else out
    if len(out) >= 20:
        return out
    if type(before) is not type(after):
        out.append({"path": path, "before": before, "after": after})
    elif isinstance(before, dict):
        for key in sorted(set(before) | set(after)):
            if key not in before or key not in after:
                out.append({"path": f"{path}.{key}", "missing_from": "before" if key not in before else "after"})
            else:
                differences(before[key], after[key], f"{path}.{key}", out)
            if len(out) >= 20:
                break
    elif isinstance(before, list):
        if len(before) != len(after):
            out.append({"path": path, "length_before": len(before), "length_after": len(after)})
        for index, (first, second) in enumerate(zip(before, after)):
            differences(first, second, f"{path}[{index}]", out)
            if len(out) >= 20:
                break
    elif before != after:
        out.append({"path": path, "before": before, "after": after})
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    first, second = [json.loads(path.read_text(encoding="utf-8")) for path in (args.before, args.after)]
    delta = differences(semantics(first), semantics(second))
    measured = []
    for before, after in zip(first["cases"], second["cases"]):
        old, new = before["total_ms"], after["total_ms"]
        measured.append({"slot": before["slot"], "before_ms": old, "after_ms": new,
                         "reduction_percent": 100 * (old - new) / old,
                         "speedup": old / new,
                         "after_totals": after["totals"]})
    clean = not first.get("failures") and not second.get("failures")
    report = {"schema": "grip_duration_equivalence_v1", "passed": not delta and clean,
              "exact_semantic_match": not delta, "source_checks_passed": clean,
              "excluded": ["numeric *_ms timing fields", "saved_contact_cache_statistics", "work_counts"],
              "scope": "complete report: all recorded poses, contacts, rejection events, source records and non-timing counters",
              "before": str(args.before), "after": str(args.after),
              "before_sha256": hashlib.sha256(args.before.read_bytes()).hexdigest(),
              "after_sha256": hashlib.sha256(args.after.read_bytes()).hexdigest(),
              "differences": delta, "cases": measured}
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "differences": delta,
                      "cases": [{k: v for k, v in case.items() if k != "after_totals"} for case in measured]}, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
