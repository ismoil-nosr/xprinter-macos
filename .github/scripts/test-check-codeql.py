#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Regression checks for real CodeQL/SARIF rule shapes and narrowly scoped triage."""
from datetime import date
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("gate", Path(__file__).with_name("check-codeql.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.reports = self.root / "reports"
        self.reports.mkdir()
        self.rule = {"id": "test/security", "properties": {"security-severity": "7.8", "tags": ["security"]}}
        self.region = {"startLine": 50, "endLine": 50, "startColumn": 13, "endColumn": 68}

    def save(self, document):
        (self.reports / "results.sarif").write_text(json.dumps(document))

    def report(self, extension=False):
        tool = {"driver": {"name": "CodeQL", "rules": [] if extension else [self.rule]}}
        result = {"ruleId": self.rule["id"], "locations": [{"physicalLocation": {
            "artifactLocation": {"uri": "src/http.ts"}, "region": self.region}}]}
        if extension:
            tool["extensions"] = [{"name": "queries", "rules": [self.rule]}]
            result["rule"] = {"id": self.rule["id"], "index": 0, "toolComponent": {"index": 0}}
        else:
            result["ruleIndex"] = 0
        document = {"version": "2.1.0", "runs": [{"tool": tool, "results": [result]}]}
        self.save(document)
        return document

    def evaluate(self):
        return gate.evaluate(self.reports, self.root, date(2026, 10, 1))

    def triage(self, expires="2026-12-30"):
        source = self.root / "src/http.ts"
        source.parent.mkdir()
        source.write_text("fixed public discovery; protected MCP requires auth")
        entry = {"ruleId": self.rule["id"], "path": "src/http.ts", "region": self.region,
                 "reason": "Only fixed public metadata; no protected handler is dispatched.", "expires": expires,
                 "files": {"src/http.ts": hashlib.sha256(source.read_bytes()).hexdigest()}}
        path = self.root / ".github/codeql-triage.json"
        path.parent.mkdir()
        path.write_text(json.dumps({"version": 1, "exceptions": [entry]}))

    def test_driver_and_extension_high_findings(self):
        for extension in [False, True]:
            with self.subTest(extension=extension):
                self.report(extension)
                self.assertEqual(self.evaluate()["highOrCriticalFindings"], 1)

    def test_threshold(self):
        for severity, expected in [("6.9", 0), ("7", 1), ("9.5", 1)]:
            self.rule["properties"]["security-severity"] = severity
            self.report(True)
            self.assertEqual(self.evaluate()["highOrCriticalFindings"], expected)

    def test_id_only_extension_resolution(self):
        document = self.report(True)
        del document["runs"][0]["results"][0]["rule"]
        self.save(document)
        self.assertEqual(self.evaluate()["highOrCriticalFindings"], 1)

    def test_index_only_extension_resolution(self):
        document = self.report(True)
        result = document["runs"][0]["results"][0]
        del result["ruleId"]
        del result["rule"]["id"]
        self.save(document)
        self.assertEqual(self.evaluate()["highOrCriticalFindings"], 1)

    def test_unknown_or_conflicting_rules_fail_closed(self):
        for mutation in ["unknown", "conflict", "negative"]:
            document = self.report(True)
            result = document["runs"][0]["results"][0]
            if mutation == "unknown":
                result.pop("rule")
                result["ruleId"] = "unknown"
            elif mutation == "conflict":
                result["ruleId"] = "different"
            else:
                result["rule"]["index"] = -1
            self.save(document)
            with self.assertRaises(gate.GateError):
                self.evaluate()

    def test_security_severity_missing_or_invalid_fails(self):
        for severity in [None, "nan", "infinity", "-1", "11"]:
            self.rule["properties"]["security-severity"] = severity
            self.report()
            with self.assertRaises(gate.GateError):
                self.evaluate()

    def test_missing_sarif_fails(self):
        with self.assertRaises(gate.GateError):
            self.evaluate()

    def test_empty_runs_fail(self):
        self.save({"runs": []})
        with self.assertRaises(gate.GateError):
            self.evaluate()

    def test_exact_reviewed_exception(self):
        self.report(True)
        self.triage()
        self.assertEqual(self.evaluate()["reviewedFalsePositives"], 1)
        self.assertEqual(self.evaluate()["highOrCriticalFindings"], 0)

    def test_changed_source_invalidates_exception(self):
        self.report(True)
        self.triage()
        (self.root / "src/http.ts").write_text("changed auth routing")
        with self.assertRaises(gate.GateError):
            self.evaluate()

    def test_expired_exception_fails(self):
        self.report(True)
        self.triage("2026-10-01")
        with self.assertRaises(gate.GateError):
            self.evaluate()

    def test_other_location_still_blocks(self):
        document = self.report(True)
        self.triage()
        document["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["region"] = {
            **self.region, "startColumn": 14}
        self.save(document)
        self.assertEqual(self.evaluate()["highOrCriticalFindings"], 1)


if __name__ == "__main__":
    unittest.main()
