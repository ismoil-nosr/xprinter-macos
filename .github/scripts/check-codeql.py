#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Gate releases on CodeQL security severity; never print source or diagnostic contents."""
import json
from pathlib import Path
import sys

reports = list(Path(sys.argv[1]).glob('*.sarif'))
if not reports:
    raise SystemExit('CodeQL produced no SARIF reports.')
blocked = 0
for report in reports:
    for run in json.loads(report.read_text())['runs']:
        rules = run['tool']['driver'].get('rules', [])
        by_id = {rule['id']: rule for rule in rules}
        for result in run.get('results', []):
            rule = by_id.get(result.get('ruleId'), {})
            if not rule and 'ruleIndex' in result:
                rule = rules[result['ruleIndex']]
            severity = float(rule.get('properties', {}).get('security-severity', 0))
            if severity >= 7:
                blocked += 1
print(json.dumps({'sarifReports': len(reports), 'highOrCriticalFindings': blocked}))
if blocked:
    raise SystemExit('Resolve high/critical CodeQL findings before release.')
