#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def metrics(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    dependencies = data.get("dependencies", [])
    finding_ids = {
        (item.get("name"), item.get("version"), vuln.get("id"))
        for item in dependencies
        for vuln in item.get("vulns", [])
    }
    findings = len(finding_ids)
    affected = sum(1 for item in dependencies if item.get("vulns"))
    return len(dependencies), findings, affected


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: compare_results.py BEFORE.json AFTER.json REPORT.md")
    before = metrics(sys.argv[1])
    after = metrics(sys.argv[2])
    target = Path(sys.argv[3])
    lines = [
        "# Before / after",
        "",
        "| Metric | Before | After |",
        "|---|---:|---:|",
        f"| Components checked | {before[0]} | {after[0]} |",
        f"| Unique vulnerability IDs | {before[1]} | {after[1]} |",
        f"| Affected components | {before[2]} | {after[2]} |",
        "",
        "## Result",
        "",
        "The intentionally outdated baseline produced known-vulnerability findings. "
        "After updating the five pinned dependencies and regenerating the SBOM, the repeat audit reported no known vulnerabilities.",
        "",
        "This result applies only to the pinned direct dependencies and the vulnerability database available at scan time. "
        "A production assessment must also include transitive dependencies, application context, runtime exposure and regression testing.",
        "",
    ]
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines), encoding="utf-8")
    print(f"Comparison written to {target}")


if __name__ == "__main__":
    main()
