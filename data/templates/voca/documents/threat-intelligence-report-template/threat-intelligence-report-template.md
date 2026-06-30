---
type: ISO27001 Procedure
title: Threat Intelligence Report Template
description:
  Format for documenting periodic threat landscape summaries for leadership.
  Complete it on your defined cadence—monthly or quarterly. Link findings to risks
  or controls that need adjustment.
okf_version: "0.1"
tags:
  - iso27001
timestamp: 2026-01-01 00:00:00.000000000 Z
iso27001:
  doc_id: threat-intelligence-report-template
  seq: 35
  version: 0.1.0
  kind: form
  response_kind: text
  classification: Confidential
  schema: threat-intelligence-report-template.schema.yaml
  data:
resource:
---

# Threat Summary

Guide: For each threat in the summary detail provide the following threat detail. Copy and paste the section to complete it for each threat.

## Threat Name

(EXAMPLE: ) CVE-2026-12345 — critical RCE in dependency X

## Threat Source:

(EXAMPLE: ) National CSIRT advisory and vendor bulletin

## Initial Risk and Impact Assessment:

- SAMPLE High likelihood on internet-facing services; treat as urgent patch candidate.

## Recommended Next Steps:

- SAMPLE Patch within 7 days, verify in staging, confirm via vulnerability rescan.

## Added to Risk Register:

(EXAMPLE: ) Yes

## Risk Register Reference:

(EXAMPLE: ) R-2026-022
