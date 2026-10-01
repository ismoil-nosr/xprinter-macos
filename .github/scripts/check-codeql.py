#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail closed on high/critical CodeQL findings, including SARIF extension rules."""
from datetime import date, datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import sys


class GateError(ValueError):
    pass


def rule_for(run, result):
    tool = run["tool"]
    reference = result.get("rule", {})
    component_ref = reference.get("toolComponent", {})
    component = tool["driver"]
    if "index" in component_ref:
        index = component_ref["index"]
        if not isinstance(index, int) or index < 0:
            raise GateError("Invalid SARIF component index.")
        component = tool.get("extensions", [])[index]
    elif component_ref:
        candidates = [c for c in [tool["driver"], *tool.get("extensions", [])]
                      if all(c.get(k) == v for k, v in component_ref.items())]
        if len(candidates) != 1:
            raise GateError("Unresolved SARIF tool component.")
        component = candidates[0]
    rule_id = reference.get("id", result.get("ruleId"))
    index = reference.get("index", result.get("ruleIndex"))
    if index is not None:
        if not isinstance(index, int) or index < 0:
            raise GateError("Invalid SARIF rule index.")
        rule = component.get("rules", [])[index]
        if rule_id is not None and rule["id"] != rule_id:
            raise GateError("Conflicting SARIF rule references.")
    else:
        components = [component] if component_ref else [tool["driver"], *tool.get("extensions", [])]
        candidates = [r for c in components for r in c.get("rules", []) if r.get("id") == rule_id]
        if not rule_id or len(candidates) != 1:
            raise GateError("Unresolved SARIF rule.")
        rule = candidates[0]
    if result.get("ruleId", rule["id"]) != rule["id"]:
        raise GateError("Conflicting SARIF rule IDs.")
    properties = rule.get("properties", {})
    value = properties.get("security-severity")
    if value is None:
        if "security" in properties.get("tags", []):
            raise GateError("Security rule has no severity.")
        return rule["id"], 0
    severity = float(value)
    if not math.isfinite(severity) or not 0 <= severity <= 10:
        raise GateError("Invalid security severity.")
    return rule["id"], severity


def exceptions_for(root, today):
    path = root / ".github/codeql-triage.json"
    if not path.exists():
        return []
    document = json.loads(path.read_text())
    if document.get("version") != 1:
        raise GateError("Unsupported triage schema.")
    entries = document["exceptions"]
    for entry in entries:
        if not entry["reason"].strip() or date.fromisoformat(entry["expires"]) <= today:
            raise GateError("Missing rationale or expired CodeQL triage.")
        files = entry["files"]
        if not files or entry["path"] not in files:
            raise GateError("Triage must bind its source file.")
        for name, expected in files.items():
            relative = Path(name)
            source = (root / relative).resolve()
            if relative.is_absolute() or not source.is_relative_to(root.resolve()):
                raise GateError("Triage source is outside the repository.")
            if not re.fullmatch(r"[0-9a-f]{64}", expected):
                raise GateError("Invalid triage source hash.")
            if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
                raise GateError("Source changed; re-review or remove CodeQL triage.")
        region = entry["region"]
        if set(region) != {"startLine", "endLine", "startColumn", "endColumn"}:
            raise GateError("Triage must identify one exact location.")
        if any(not isinstance(v, int) or v < 1 for v in region.values()):
            raise GateError("Invalid triage location.")
    return entries


def evaluate(directory, root, today=None):
    reports = sorted(Path(directory).glob("*.sarif"))
    if not reports:
        raise GateError("CodeQL produced no SARIF reports.")
    exceptions = exceptions_for(Path(root), today or datetime.now(timezone.utc).date())
    blocked = reviewed = 0
    for report in reports:
        runs = json.loads(report.read_text())["runs"]
        if not runs:
            raise GateError("Empty SARIF run list.")
        for run in runs:
            for result in run.get("results", []):
                rule_id, severity = rule_for(run, result)
                if severity < 7:
                    continue
                locations = result.get("locations", [])
                location = locations[0].get("physicalLocation", {}) if len(locations) == 1 else {}
                uri = location.get("artifactLocation", {}).get("uri")
                raw_region = location.get("region", {})
                # SARIF omits endLine for a single-line region. GitHub's export
                # expands it, so compare the same exact span in both formats.
                region = {"startLine": raw_region.get("startLine"),
                          "endLine": raw_region.get("endLine", raw_region.get("startLine")),
                          "startColumn": raw_region.get("startColumn"),
                          "endColumn": raw_region.get("endColumn")}
                matches = [e for e in exceptions if e["ruleId"] == rule_id
                           and e["path"] == uri and e["region"] == region]
                if len(matches) == 1:
                    reviewed += 1
                else:
                    blocked += 1
    return {"sarifReports": len(reports), "highOrCriticalFindings": blocked,
            "reviewedFalsePositives": reviewed}


def main():
    try:
        if len(sys.argv) != 2:
            raise GateError("Usage: check-codeql.py SARIF_DIRECTORY")
        result = evaluate(sys.argv[1], Path(__file__).resolve().parents[2])
        print(json.dumps(result))
        if result["highOrCriticalFindings"]:
            raise GateError("Resolve high/critical CodeQL findings before release.")
    except (GateError, KeyError, IndexError, TypeError, ValueError, OSError) as error:
        # Reports and source may contain private data. Emit only gate diagnostics.
        print(str(error) if isinstance(error, GateError) else "Invalid or unreadable security inputs.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
