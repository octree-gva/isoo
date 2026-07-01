#!/usr/bin/env python3
"""Sync ISOO-original template descriptions to guidance, schemas, and front matter."""
from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1] / "data" / "templates" / "voca"
GUIDANCE = ROOT / "guidance" / "descriptions.yaml"

# Original ISOO voice — no vendor catalogue phrasing; varied structure per family.
DESCRIPTIONS: dict[str, str] = {
    "organisation-overview": """#### What you use this for
A short portrait of the organisation: what you do, where you operate, and how teams fit together.

#### When it counts
Fill this in before scope, risk work, or policies — everyone should share the same picture of the business.

#### Connected artefacts
- `context-of-organisation`
- `documented-isms-scope`

#### Review rhythm
**Yearly**, or when ownership, sites, or core services change.

#### First move
Answer “what would a new director need to know in ten minutes?” and stop there.""",
    "context-of-organisation": """#### What you use this for
Capture internal and external factors that shape security priorities (clause 4.1 context).

#### When it counts
Initial scoping, then whenever the market, regulation, or tech stack shifts materially.

#### Connected artefacts
- `organisation-overview`
- `legal-and-contractual-requirements-register`
- `isms-risk-register`

#### Review rhythm
**At least annually**; add an extra pass after major change (funding, product pivot, new jurisdiction).

#### First move
List three external pressures and three internal constraints — that is enough to start.""",
    "0c-iso-27001-implementation-checklist": """#### What you use this for
A phased workplan so a small team does not skip scope, risk treatment, or control justification.

#### When it counts
First months of building the management system; revisit before stage‑1 / stage‑2 audits.

#### Connected artefacts
- `isms-management-plan`
- `the-information-security-management-system-overview`

#### Review rhythm
**During build** (tick as you go); refresh the checklist itself when you rebaseline the programme.

#### First move
Pick the next open row and assign a name + date — not the whole sheet at once.""",
    "documented-isms-scope": """#### What you use this for
The signed boundary of what the management system covers: sites, services, teams, and explicit exclusions.

#### When it counts
Before certification and whenever you add a product line, region, or major outsource.

#### Connected artefacts
- `context-of-organisation`
- `statement-of-applicability-iso-27002-2022-and-2013`
- `isms-risk-register`

#### Review rhythm
**Annual** sign-off; out-of-cycle when scope arguments change.

#### First move
Write one paragraph a regulator could quote — then list exclusions with reasons.""",
    "legal-and-contractual-requirements-register": """#### What you use this for
A living index of laws, regulators, and contract clauses that impose security or privacy duties.

#### When it counts
Discovery phase; update when you enter a new country or sign enterprise terms.

#### Connected artefacts
- `context-of-organisation`
- `dp-01-data-protection-policy`
- `third-party-supplier-register`

#### Review rhythm
**Quarterly** scan; immediate entry when legal or sales closes a new obligation.

#### First move
Add the three obligations you already know you must meet — GDPR, customer DPA, sector rule, etc.""",
    "physical-and-virtual-assets-register": """#### What you use this for
Inventory of infrastructure (on‑prem, cloud, SaaS) with owners and business use.

#### When it counts
Alongside first risk pass; keep current as you adopt or retire systems.

#### Connected artefacts
- `is-03-asset-management-policy`
- `software-license-assets-register`
- `isms-risk-register`

#### Review rhythm
**Quarterly** owner check; **monthly** for production-critical rows.

#### First move
Export what IT already knows (CMDB, cloud console) — do not start from a blank grid.""",
    "data-asset-register-ropa": """#### What you use this for
Record what personal data you process, why, where it lives, and how long you keep it (privacy inventory / ROPA).

#### When it counts
Before scaling processing; update when you launch features that touch identity or health/financial data.

#### Connected artefacts
- `dp-01-data-protection-policy`
- `dp-02-data-retention-policy`
- `physical-and-virtual-assets-register`

#### Review rhythm
**Quarterly** with product/legal; **within 30 days** of a new processing purpose.

#### First move
Document one real customer or employee data flow end to end.""",
    "software-license-assets-register": """#### What you use this for
Track applications, versions, licence posture, and who answers for each tool.

#### When it counts
Supports patching, access reviews, and vendor risk — start when the stack stops fitting in one spreadsheet.

#### Connected artefacts
- `physical-and-virtual-assets-register`
- `is-25-patch-management-policy`

#### Review rhythm
**Quarterly**; on every major upgrade or renewal.

#### First move
List your top ten SaaS tools with an owner — expand later.""",
    "statement-of-applicability-iso-27002-2022-and-2013": """#### What you use this for
Your control selection record: which Annex A safeguards apply, how they are implemented, and why anything is out of scope.

#### When it counts
After risk treatment; this is the map reviewers use to test controls.

#### Connected artefacts
- `isms-risk-register`
- `ip-01-risk-management-procedure`
- `is-01-information-security-policy`

#### Review rhythm
**Quarterly** recommended; **annual** minimum; **30 days** after major control or risk change.

#### First move
Mark implementation status honestly on five controls you already know you have.""",
    "annual-risk-review-meeting-template": """#### What you use this for
Agenda shell for leadership to revisit risk appetite, treatments, and open exposures.

#### When it counts
Once per year before management review or recertification planning.

#### Connected artefacts
- `isms-risk-register`
- `managment-review-team-meeting-agenda-template`
- `ip-01-risk-management-procedure`

#### Review rhythm
**Per meeting** (archive notes); template itself **annual**.

#### First move
Attach the current risk register and only discuss rows that moved since last time.""",
    "managment-review-team-meeting-agenda-template": """#### What you use this for
Structured inputs and outputs for top management’s ISMS review (clause 9.3).

#### When it counts
At least once per year; extra session after serious incidents or scope changes.

#### Connected artefacts
- `is-01-information-security-policy`
- `audit-report-template`
- `incident-and-corrective-action-log`

#### Review rhythm
**Annual** minimum; year one often **quarterly**.

#### First move
Pre-fill incident, audit, and KPI sections — the meeting should decide actions, not hunt data.""",
    "the-information-security-management-system-overview": """#### What you use this for
Plain-language tour of how security is governed: policies, loops, roles, and improvement.

#### When it counts
Onboarding staff, briefing leadership, orienting external reviewers.

#### Connected artefacts
- `is-01-information-security-policy`
- `documented-isms-scope`
- `0c-iso-27001-implementation-checklist`

#### Review rhythm
**Annual**; after reorganisation or major control set change.

#### First move
Explain the system in one page as if to a smart colleague outside IT.""",
    "information-security-manager-job-description": """#### What you use this for
Defines authority and duties of the person accountable for the management system.

#### When it counts
Before claiming formal ISMS ownership; revisit when reporting lines change.

#### Connected artefacts
- `isms-rasci-matrix-basic-accountability-matrix`
- `the-information-security-management-system-overview`

#### Review rhythm
**Annual** or on restructure.

#### First move
Name the role holder and one escalation path to the board.""",
    "competency-matrix": """#### What you use this for
Maps security knowledge and training needs to job families.

#### When it counts
After core policies exist — shows who must understand what.

#### Connected artefacts
- `is-06-information-security-awareness-and-training-policy`
- `information-classification-summary`

#### Review rhythm
**Annual**; update when roles or tooling change.

#### First move
Pick three roles and list the one skill each must prove.""",
    "isms-rasci-matrix-basic-accountability-matrix": """#### What you use this for
Lightweight “who owns what” grid for core programme activities.

#### When it counts
When roles are first assigned; resolves “that’s not my job” before reviews.

#### Connected artefacts
- `information-security-manager-job-description`
- `isms-rasci-matrix-full`

#### Review rhythm
**Annual**; patch when someone leaves or outsourcing shifts work.

#### First move
Fill accountability for risk, incidents, and document control only — expand later.""",
    "isms-rasci-matrix-full": """#### What you use this for
Detailed responsibility map across controls and recurring tasks.

#### When it counts
When the basic matrix is too coarse for delegation and evidence collection.

#### Connected artefacts
- `isms-rasci-matrix-basic-accountability-matrix`
- `competency-matrix`

#### Review rhythm
**Quarterly** spot-check against reality.

#### First move
Import rows from the basic matrix before adding new lines.""",
    "information-classification-summary": """#### What you use this for
Staff-facing cheat sheet: labels, handling rules, and everyday examples.

#### When it counts
After the classification policy is approved — training handout, not a policy repeat.

#### Connected artefacts
- `is-05-information-classification-and-handling-policy`

#### Review rhythm
**Annual**; refresh when labels or tooling change.

#### First move
Give one real example per label (email subject, folder name, channel).""",
    "information-security-management-system-document-tracker": """#### What you use this for
Master index of controlled docs: version, owner, review date, status.

#### When it counts
From day one — stale documents are a common review finding.

#### Connected artefacts
- `is-23-document-and-record-policy`
- `change-log`

#### Review rhythm
**Monthly** glance; **quarterly** owner confirmations.

#### First move
Register every policy you already have, even if version is “draft”.""",
    "operations-security-manual-v1": """#### What you use this for
Runbook for IT/support: how controls actually work day to day.

#### When it counts
After policies exist — bridges “what we said” and “what we do”.

#### Connected artefacts
- `is-16-logging-and-monitoring-policy`
- `is-11-backup-policy`
- `is-13-change-management-policy`

#### Review rhythm
**Annual**; patch after tooling or on-call process changes.

#### First move
Document one routine (backup restore, access grant) exactly as performed today.""",
    "how-to-access-control-and-role-based-access": """#### What you use this for
Step-by-step for admins: grant, review, and revoke access using your role model.

#### When it counts
When onboarding tools or training new administrators.

#### Connected artefacts
- `is-02-access-control-policy`
- `role-based-access-control`
- `access-request-form`

#### Review rhythm
**Annual**; update when IdP or ticketing changes.

#### First move
Walk through a fictional new hire with your real tools.""",
    "role-based-access-control": """#### What you use this for
Defines application roles, permissions, and separation-of-duties rules.

#### When it counts
Before rolling out self-service access; revisit when org or apps change.

#### Connected artefacts
- `is-02-access-control-policy`
- `access-request-form`
- `starter-leaver-mover-system-access-process`

#### Review rhythm
**Quarterly** for privileged roles; **annual** full pass.

#### First move
List admin roles and who may hold them — defer fine-grained app roles.""",
    "access-request-form": """#### What you use this for
Standard request + approval trail for new or changed system access.

#### When it counts
Every access change — replaces ad hoc chat approvals.

#### Connected artefacts
- `is-02-access-control-policy`
- `role-based-access-control`
- `starter-leaver-mover-access-register`

#### Review rhythm
Template **annual**; each submission kept per records policy.

#### First move
Publish the form where people already ask for access (ticket template, intranet).""",
    "starter-leaver-mover-system-access-process": """#### What you use this for
Workflow when people **join, leave, or change role** — HR signal to IT action.

#### When it counts
From first hire; late offboarding is one of the most tested controls.

#### Connected artefacts
- `starter-leaver-mover-access-register`
- `access-request-form`
- `is-02-access-control-policy`

#### Review rhythm
**Annual** process review; execute **per HR event**.

#### First move
Time how long deprovisioning takes today — set a target.""",
    "starter-leaver-mover-access-register": """#### What you use this for
Evidence log tying HR lifecycle events to access changes.

#### When it counts
Each join/leave/role change; proves timely provisioning and removal.

#### Connected artefacts
- `starter-leaver-mover-system-access-process`
- `is-02-access-control-policy`

#### Review rhythm
**Per event** entry; **quarterly** reconciliation against HRIS.

#### First move
Backfill the last three leavers and verify accounts are gone.""",
    "threat-intelligence-process": """#### What you use this for
How you collect, judge, and act on relevant threat information.

#### When it counts
Once monitoring and incident basics exist.

#### Connected artefacts
- `threat-intelligence-report-template`
- `is-16-logging-and-monitoring-policy`
- `isms-risk-register`

#### Review rhythm
**Annual** process; intake **ongoing**.

#### First move
Subscribe to two free feeds your stack actually cares about (vendor + sector).""",
    "threat-intelligence-report-template": """#### What you use this for
Periodic briefing format for leadership on threat trends and actions taken.

#### When it counts
Monthly or quarterly rhythm depending on exposure.

#### Connected artefacts
- `threat-intelligence-process`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Monthly or quarterly** issues; template **annual**.

#### First move
One page: three headlines, two risks touched, one action ordered.""",
    "dp-01-data-protection-policy": """#### What you use this for
Organisation-wide rules for lawful, fair, transparent personal data processing.

#### When it counts
Before processing at scale; staff acknowledgement required.

#### Connected artefacts
- `data-asset-register-ropa`
- `dp-02-data-retention-policy`
- `is-05-information-classification-and-handling-policy`

#### Review rhythm
**Annual**; immediate review when law or processing model changes.

#### First move
State lawful bases you actually rely on — do not copy a generic list.""",
    "dp-02-data-retention-policy": """#### What you use this for
How long categories of data are kept and how deletion/anonymisation works.

#### When it counts
Alongside privacy inventory; applies to backups and archives too.

#### Connected artefacts
- `data-asset-register-ropa`
- `dp-01-data-protection-policy`
- `is-11-backup-policy`

#### Review rhythm
**Annual**; update when product retention or law shifts.

#### First move
Pick customer data and employee data — set realistic retention per category.""",
    "is-01-information-security-policy": """#### What you use this for
Board-level commitment: objectives, scope, and governance for protecting information.

#### When it counts
Approve before other security policies; communicate to all staff.

#### Connected artefacts
- `the-information-security-management-system-overview`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Annual** sign-off; sooner after major incident or reorg.

#### First move
One page maximum — link detail out to topic policies.""",
    "is-02-access-control-policy": """#### What you use this for
Rules for physical and logical access: who may see what, and how requests are approved.

#### When it counts
Before RBAC tables and access workflows go live.

#### Connected artefacts
- `role-based-access-control`
- `access-request-form`
- `starter-leaver-mover-system-access-process`

#### Review rhythm
**Annual**; review after access-related incidents.

#### First move
Define “privileged access” in one sentence your team recognises.""",
    "is-03-asset-management-policy": """#### What you use this for
Lifecycle rules for information assets: identify, own, protect, dispose.

#### When it counts
When standing up asset registers.

#### Connected artefacts
- `physical-and-virtual-assets-register`
- `software-license-assets-register`

#### Review rhythm
**Annual**.

#### First move
Require an owner field on every new system request.""",
    "is-04-risk-management-policy": """#### What you use this for
Method and appetite for identifying, analysing, treating, and monitoring risk.

#### When it counts
Before first formal risk assessment.

#### Connected artefacts
- `ip-01-risk-management-procedure`
- `isms-risk-register`

#### Review rhythm
**Annual**; after major risk events.

#### First move
Write how management accepts residual risk — one paragraph.""",
    "is-05-information-classification-and-handling-policy": """#### What you use this for
Defines sensitivity levels and handling rules in transit and at rest.

#### When it counts
Before labelling, DLP, or secure sharing rollouts.

#### Connected artefacts
- `information-classification-summary`
- `is-18-information-transfer-policy`

#### Review rhythm
**Annual**.

#### First move
Choose three labels maximum for a small team.""",
    "is-06-information-security-awareness-and-training-policy": """#### What you use this for
Commitment to train staff and measure whether security culture sticks.

#### When it counts
Launch with awareness programme; track completion.

#### Connected artefacts
- `competency-matrix`
- `communication-plan`

#### Review rhythm
**Annual**; refresh content when threats or policies change.

#### First move
Schedule one mandatory 30-minute session with attendance proof.""",
    "is-07-acceptable-use-policy": """#### What you use this for
Expectations for using company devices, networks, and data.

#### When it counts
Onboarding; requires acknowledgement.

#### Connected artefacts
- `is-08-clear-desk-and-clear-screen-policy`
- `is-28-ai-policy`

#### Review rhythm
**Annual**; update when tooling (AI, BYOD) changes.

#### First move
Cover what is obviously forbidden and what to do when unsure.""",
    "is-08-clear-desk-and-clear-screen-policy": """#### What you use this for
Reduce casual exposure: tidy desks, locked screens, clean shared spaces.

#### When it counts
Office and remote — easy to observe, easy to neglect.

#### Connected artefacts
- `is-07-acceptable-use-policy`
- `is-09a-mobile-and-teleworking-policy-office-based`

#### Review rhythm
**Annual**.

#### First move
Set auto-lock timeout and tell people in plain language.""",
    "is-09a-mobile-and-teleworking-policy-office-based": """#### What you use this for
Security expectations when most work happens on-site with occasional remote days.

#### When it counts
Hybrid workplaces — pick this or the remote-first variant, not both.

#### Connected artefacts
- `is-09b-mobile-and-teleworking-policy-fully-remote`
- `is-17-network-security-management-policy`

#### Review rhythm
**Annual**.

#### First move
State VPN, device, and visitor rules for “work from home Friday”.""",
    "is-09b-mobile-and-teleworking-policy-fully-remote": """#### What you use this for
Security expectations when distributed work is the default.

#### When it counts
Remote-first teams — home office, travel, and endpoint rules explicit.

#### Connected artefacts
- `is-09a-mobile-and-teleworking-policy-office-based`
- `is-20-physical-and-environmental-security-policy`

#### Review rhythm
**Annual**.

#### First move
Define minimum home network and device posture without over-policing.""",
    "is-10-business-continuity-policy": """#### What you use this for
Executive commitment to keep critical activities running through disruption.

#### When it counts
Before detailed continuity planning and impact analysis.

#### Connected artefacts
- `business-continuity-plan`
- `business-impact-assessment`

#### Review rhythm
**Annual**.

#### First move
Name the activities that must survive a bad week — three max.""",
    "is-11-backup-policy": """#### What you use this for
What is backed up, how often, where copies live, and how restores are proven.

#### When it counts
Pair with backup tooling and DR playbooks.

#### Connected artefacts
- `disaster-recovery-scenario-plans`
- `is-13-change-management-policy`

#### Review rhythm
**Annual** policy; **restore tests** at least yearly for critical data.

#### First move
Run one restore drill and write down what broke.""",
    "is-12-protection-against-malware-policy": """#### What you use this for
Requirements for endpoint, email, and server malware defences.

#### When it counts
Align with EDR/AV actually deployed.

#### Connected artefacts
- `is-25-patch-management-policy`
- `operations-security-manual-v1`

#### Review rhythm
**Annual**; check coverage when fleet changes.

#### First move
List platforms without protection — fix or justify.""",
    "is-13-change-management-policy": """#### What you use this for
How production changes are requested, reviewed, deployed, and recorded.

#### When it counts
Before change volume makes informal fixes dangerous.

#### Connected artefacts
- `change-log`
- `operations-security-manual-v1`

#### Review rhythm
**Annual**.

#### First move
Define what counts as emergency change and who may approve it.""",
    "is-14-third-party-supplier-security-policy": """#### What you use this for
Security expectations for vendors who touch your data or operations.

#### When it counts
Procurement and contract negotiation.

#### Connected artefacts
- `third-party-supplier-register`
- `is-26-cloud-service-policy`

#### Review rhythm
**Annual**; reassess on renewal or incident.

#### First move
Tier your top five vendors by data access — review deepest tier first.""",
    "is-15-continual-improvement-policy": """#### What you use this for
How feedback, nonconformities, and lessons become tracked improvements.

#### When it counts
When audits and incidents start producing actions.

#### Connected artefacts
- `incident-and-corrective-action-log`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Annual**.

#### First move
Link to the log where actions must land — no orphan findings.""",
    "is-16-logging-and-monitoring-policy": """#### What you use this for
What you log, how long you keep it, who watches alerts.

#### When it counts
With SIEM/log stack design.

#### Connected artefacts
- `operations-security-manual-v1`
- `threat-intelligence-process`

#### Review rhythm
**Annual**; tune retention when storage costs bite.

#### First move
List three events you must be able to reconstruct after an incident.""",
    "is-17-network-security-management-policy": """#### What you use this for
Segmentation, perimeter, wireless, and remote access principles.

#### When it counts
Align with network diagrams and cloud security groups.

#### Connected artefacts
- `operations-security-manual-v1`
- `is-26-cloud-service-policy`

#### Review rhythm
**Annual**; after architecture migrations.

#### First move
Sketch trust zones on one whiteboard photo — policy follows diagram.""",
    "is-18-information-transfer-policy": """#### What you use this for
Secure exchange of information inside and outside the organisation.

#### When it counts
Before wide file sharing, APIs, or removable media use.

#### Connected artefacts
- `is-05-information-classification-and-handling-policy`
- `is-22-cryptographic-control-and-encryption-policy`

#### Review rhythm
**Annual**.

#### First move
Ban “which channel for confidential data?” — pick approved tools.""",
    "is-19-secure-development-policy": """#### What you use this for
Security expectations for software you build or heavily customise.

#### When it counts
Before SDLC gates, CI security checks, or prod access for developers.

#### Connected artefacts
- `operations-security-manual-v1`
- `is-13-change-management-policy`

#### Review rhythm
**Annual**.

#### First move
Require security review on one class of change (auth, payments, PII).""",
    "is-20-physical-and-environmental-security-policy": """#### What you use this for
Protect premises, equipment, and environment (access, power, fire, etc.).

#### When it counts
Any office, closet, or co-lo you control.

#### Connected artefacts
- `physical-and-virtual-assets-register`

#### Review rhythm
**Annual**; walk-through after office moves.

#### First move
Document how visitors get in and who escorts them.""",
    "is-21-cryptographic-key-management-policy": """#### What you use this for
Generation, storage, rotation, and destruction of cryptographic keys.

#### When it counts
When you operate keys in-house (not only cloud-managed).

#### Connected artefacts
- `is-22-cryptographic-control-and-encryption-policy`

#### Review rhythm
**Annual**.

#### First move
Inventory where keys live — KMS, HSM, `.env`, password managers.""",
    "is-22-cryptographic-control-and-encryption-policy": """#### What you use this for
When encryption is required in transit and at rest, and which standards apply.

#### When it counts
Align with classification and regulatory minima.

#### Connected artefacts
- `is-21-cryptographic-key-management-policy`
- `is-18-information-transfer-policy`

#### Review rhythm
**Annual**.

#### First move
State defaults (TLS 1.2+, AES-256) and how to request an exception.""",
    "is-23-document-and-record-policy": """#### What you use this for
Creation, approval, versioning, distribution, and retention of ISMS records.

#### When it counts
Early — gives teeth to the document tracker and change log.

#### Connected artefacts
- `information-security-management-system-document-tracker`
- `change-log`

#### Review rhythm
**Annual**.

#### First move
Define who may approve a policy version — one role, one backup.""",
    "is-24-significant-incident-policy-and-collection-of-evidence": """#### What you use this for
Major incident criteria, escalation, and forensic evidence handling.

#### When it counts
Before incident forms and playbooks go live.

#### Connected artefacts
- `incident-and-breach-reporting-form`
- `post-incident-review-form`

#### Review rhythm
**Annual**; after any serious event.

#### First move
Define “significant” with examples your exec team recognises.""",
    "is-25-patch-management-policy": """#### What you use this for
Timelines for patching OS and applications by severity.

#### When it counts
With vulnerability scanning and change management.

#### Connected artefacts
- `is-12-protection-against-malware-policy`
- `software-license-assets-register`

#### Review rhythm
**Annual**; SLAs reviewed **quarterly** against scan results.

#### First move
Set critical patch days — realistic for a small ops team.""",
    "is-26-cloud-service-policy": """#### What you use this for
Adopting and operating SaaS, PaaS, and IaaS securely (shared responsibility).

#### When it counts
Cloud migrations and new SaaS approvals.

#### Connected artefacts
- `third-party-supplier-register`
- `is-14-third-party-supplier-security-policy`

#### Review rhythm
**Annual**.

#### First move
List configuration baselines for your primary cloud account.""",
    "is-27-intellectual-property-rights-policy": """#### What you use this for
Protect company IP; respect licences and third-party copyrights.

#### When it counts
Teams shipping code, design, or licensed media.

#### Connected artefacts
- `is-07-acceptable-use-policy`

#### Review rhythm
**Annual**.

#### First move
Clarify who owns code written on company time — one paragraph.""",
    "is-28-ai-policy": """#### What you use this for
Acceptable use of AI tools: data boundaries, oversight, vendor risk.

#### When it counts
Before generative AI is everywhere in workflows.

#### Connected artefacts
- `is-07-acceptable-use-policy`
- `dp-01-data-protection-policy`

#### Review rhythm
**Annual** minimum; **quarterly** while tooling shifts fast.

#### First move
Ban pasting customer/employee data into public models — say it plainly.""",
    "audit-plan-iso-27002-2013-and-2022-version": """#### What you use this for
Schedule internal audits: scope, criteria, auditors, timing across the cycle.

#### When it counts
Once the ISMS is operable enough to test.

#### Connected artefacts
- `1a-blank-audit-template-iso-27002-2013-and-2022-version`
- `1b-audit-template-iso-27002-2013-and-2022-version-pre-mapped`
- `statement-of-applicability-iso-27002-2022-and-2013`

#### Review rhythm
**Annual** programme; high-risk areas **more often**.

#### First move
Plan one audit quarter that covers clauses 4–10, not only Annex A.""",
    "change-log": """#### What you use this for
Trace material changes to ISMS documents and critical configurations.

#### When it counts
Every significant policy or infrastructure change.

#### Connected artefacts
- `is-13-change-management-policy`
- `information-security-management-system-document-tracker`

#### Review rhythm
**Per change** entry; **quarterly** review in management meeting.

#### First move
Log the last three production changes you remember — backfill.""",
    "communication-plan": """#### What you use this for
Who hears what about security: awareness, incidents, regulators, customers.

#### When it counts
Rollout with top policy; update when comms channels change.

#### Connected artefacts
- `is-06-information-security-awareness-and-training-policy`
- `is-01-information-security-policy`

#### Review rhythm
**Annual**.

#### First move
Name spokesperson for incidents — one primary, one backup.""",
    "isms-management-plan": """#### What you use this for
Programme plan: milestones, resources, priorities for building and running the ISMS.

#### When it counts
Kick-off; refresh after management review.

#### Connected artefacts
- `0c-iso-27001-implementation-checklist`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Annual**; **quarterly** during initial certification push.

#### First move
Pick a target certification window and work backwards.""",
    "incident-and-breach-reporting-form": """#### What you use this for
Simple channel for staff to report odd events and suspected breaches.

#### When it counts
Always available — training beats fine print.

#### Connected artefacts
- `is-24-significant-incident-policy-and-collection-of-evidence`
- `incident-and-corrective-action-log`

#### Review rhythm
Template **annual**; submissions **per event**.

#### First move
Put the link in onboarding and the office wiki — test it monthly.""",
    "incident-and-corrective-action-log": """#### What you use this for
Central record of incidents, causes, fixes, and closure.

#### When it counts
Every reportable event — demonstrates closed-loop improvement.

#### Connected artefacts
- `is-15-continual-improvement-policy`
- `post-incident-review-form`

#### Review rhythm
**Per incident**; **quarterly** trend review.

#### First move
Log the last near-miss even if it felt too small — practice the habit.""",
    "ip-01-risk-management-procedure": """#### What you use this for
Repeatable steps to find assets, threats, weaknesses, and treatments.

#### When it counts
Initial and periodic risk assessments.

#### Connected artefacts
- `is-04-risk-management-policy`
- `isms-risk-register`
- `statement-of-applicability-iso-27002-2022-and-2013`

#### Review rhythm
**Annual** full pass; **ad hoc** when context shifts.

#### First move
Run the procedure on one business process, not the entire company.""",
    "isms-risk-register": """#### What you use this for
Living list of risks, scores, owners, treatments, and residual status.

#### When it counts
Output of risk assessment; input to control selection and reviews.

#### Connected artefacts
- `ip-01-risk-management-procedure`
- `statement-of-applicability-iso-27002-2022-and-2013`
- `annual-risk-review-meeting-template`

#### Review rhythm
**Quarterly** touch; **annual** formal review.

#### First move
Ten honest risks beat fifty boilerplate rows.""",
    "third-party-supplier-register": """#### What you use this for
Vendors with data or operational dependency — tier, owner, review dates.

#### When it counts
Onboarding suppliers; renewals and incidents trigger reassessment.

#### Connected artefacts
- `is-14-third-party-supplier-security-policy`
- `legal-and-contractual-requirements-register`

#### Review rhythm
**Annual** minimum; **quarterly** for tier‑1.

#### First move
Your CRM, finance, and SSO vendor lists are the seed data.""",
    "1a-blank-audit-template-iso-27002-2013-and-2022-version": """#### What you use this for
Blank audit worksheet — you map questions to controls yourself.

#### When it counts
Custom engagements or experienced auditors who bring their own structure.

#### Connected artefacts
- `audit-plan-iso-27002-2013-and-2022-version`
- `audit-report-template`

#### Review rhythm
**Per audit**; template **annual**.

#### First move
Copy the sheet per audit and name the lead auditor upfront.""",
    "1b-audit-template-iso-27002-2013-and-2022-version-pre-mapped": """#### What you use this for
Audit worksheet with Annex A references prefilled to speed fieldwork.

#### When it counts
Routine internal audits and certification dry-runs.

#### Connected artefacts
- `audit-plan-iso-27002-2013-and-2022-version`
- `statement-of-applicability-iso-27002-2022-and-2013`

#### Review rhythm
**Per audit**; update mapping when standard or SoA changes.

#### First move
Filter to controls you marked “implemented” in the SoA — audit those first.""",
    "audit-meeting-template": """#### What you use this for
Opening and closing meeting notes with auditees.

#### When it counts
Start and end of each audit engagement.

#### Connected artefacts
- `audit-report-template`
- `1b-audit-template-iso-27002-2013-and-2022-version-pre-mapped`

#### Review rhythm
**Per engagement**.

#### First move
Confirm scope and evidence expectations in the opening meeting.""",
    "audit-report-template": """#### What you use this for
Formal report: scope, method, findings, recommendations.

#### When it counts
After each internal or supplier audit.

#### Connected artefacts
- `incident-and-corrective-action-log`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Per audit**; classify findings consistently.

#### First move
Write executive summary first — five bullets max.""",
    "business-impact-assessment": """#### What you use this for
Analyse how outages hit activities, dependencies, and recovery priorities.

#### When it counts
Before writing detailed continuity and DR material.

#### Connected artefacts
- `business-continuity-plan`
- `physical-and-virtual-assets-register`

#### Review rhythm
**Annual**; after major product or vendor change.

#### First move
Interview owners of three critical activities — not IT first.""",
    "business-impact-analysis-exec-summary": """#### What you use this for
Leadership-friendly summary of impact analysis for funding and priorities.

#### When it counts
After detailed BIA — input to management review.

#### Connected artefacts
- `business-impact-assessment`
- `business-continuity-objectives-and-strategy`

#### Review rhythm
**Annual** with BIA.

#### First move
One slide: worst plausible outage, cost of downtime, top dependency.""",
    "business-continuity-objectives-and-strategy": """#### What you use this for
Recovery targets and strategic choices (prevent, respond, recover).

#### When it counts
After BIA numbers exist — guides plan structure.

#### Connected artefacts
- `business-impact-assessment`
- `is-10-business-continuity-policy`

#### Review rhythm
**Annual**.

#### First move
Agree RTO/RPO for one service, not the entire catalogue.""",
    "business-continuity-plan": """#### What you use this for
Master playbook for keeping or restoring critical operations in a crisis.

#### When it counts
After objectives set; exercise regularly.

#### Connected artefacts
- `business-continuity-objectives-and-strategy`
- `business-impact-assessment`
- `communication-plan`

#### Review rhythm
**Annual** review; **≥1 exercise/year**.

#### First move
Verify contact tree dials real numbers — today.""",
    "business-continuity-incident-action-log": """#### What you use this for
Timestamped actions during a live continuity event.

#### When it counts
When the plan is activated.

#### Connected artefacts
- `business-continuity-plan`
- `post-incident-review-form`

#### Review rhythm
**Per activation**; review entries in debrief.

#### First move
Assign a scribe role before the next tabletop.""",
    "post-incident-review-form": """#### What you use this for
Blameless debrief after incidents or plan activations.

#### When it counts
Within days of stand-down while facts are fresh.

#### Connected artefacts
- `incident-and-corrective-action-log`
- `is-15-continual-improvement-policy`

#### Review rhythm
**Per event**.

#### First move
Capture timeline before debating root cause.""",
    "disaster-recovery-scenario-plans": """#### What you use this for
Technical recovery steps for named failure modes (site loss, ransomware, etc.).

#### When it counts
For systems the BIA marked critical.

#### Connected artefacts
- `is-11-backup-policy`
- `business-continuity-plan`
- `disaster-recovery-scenario-test-template`

#### Review rhythm
**Annual**; after infra changes.

#### First move
One scenario for your single most important database.""",
    "disaster-recovery-scenario-test-template": """#### What you use this for
Plan and record a DR exercise for a chosen scenario.

#### When it counts
At least yearly for critical systems.

#### Connected artefacts
- `disaster-recovery-scenario-plans`
- `business-continuity-test-report-template`

#### Review rhythm
**Annual** per critical scenario; rotate coverage.

#### First move
Schedule before the next busy season — or it will slip.""",
    "how-to-conduct-a-business-continuity-test": """#### What you use this for
Facilitator guide: plan, run, and score continuity exercises.

#### When it counts
Before your first tabletop or technical drill.

#### Connected artefacts
- `business-continuity-test-template`
- `business-continuity-plan-scenario`

#### Review rhythm
**Annual** refresh of the guide.

#### First move
Run a 60-minute tabletop with coffee — low stakes, real learning.""",
    "business-continuity-test-template": """#### What you use this for
Checklist and script so exercises run the same way each time.

#### When it counts
Every planned exercise.

#### Connected artefacts
- `how-to-conduct-a-business-continuity-test`
- `business-continuity-plan`

#### Review rhythm
**Per exercise**; template **annual**.

#### First move
Define success criteria before sending calendar invites.""",
    "business-continuity-test-report-template": """#### What you use this for
Executive summary of test goals, results, and follow-ups.

#### When it counts
Immediately after each exercise.

#### Connected artefacts
- `business-continuity-test-template`
- `managment-review-team-meeting-agenda-template`

#### Review rhythm
**Per exercise**.

#### First move
List what surprised the room — that is the valuable part.""",
    "business-continuity-plan-scenario": """#### What you use this for
Narrative disruption story to stress-test the master plan.

#### When it counts
Tabletops with leadership and IT.

#### Connected artefacts
- `business-continuity-plan`
- `how-to-conduct-a-business-continuity-test`

#### Review rhythm
**Rotate yearly** — avoid repeating the same fire drill.

#### First move
Pick a scenario your team worries about but has not rehearsed.""",
    "business-continuity-scenario": """#### What you use this for
Additional scenario material for training and tests.

#### When it counts
Supplement primary scenarios; variety builds muscle memory.

#### Connected artefacts
- `business-continuity-test-template`
- `business-continuity-plan-scenario`

#### Review rhythm
**When threat landscape shifts**.

#### First move
Adapt a recent industry incident into a tabletop inject.""",
    "business-continuity-test-report-findings": """#### What you use this for
Detailed gap list from continuity tests — strengths and fixes.

#### When it counts
Attach to formal test report; track until closed.

#### Connected artefacts
- `business-continuity-test-report-template`
- `incident-and-corrective-action-log`

#### Review rhythm
**Per test**; open items **monthly** until done.

#### First move
Assign an owner and date to every finding before the room disperses.""",
}


def load_manifest_ids() -> list[str]:
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text(encoding="utf-8"))
    return [doc["doc_id"] for doc in manifest["documents"]]


def write_guidance_yaml() -> None:
    ordered_ids = load_manifest_ids()
    missing = set(ordered_ids) - set(DESCRIPTIONS)
    extra = set(DESCRIPTIONS) - set(ordered_ids)
    if missing:
        raise SystemExit(f"Missing descriptions for: {sorted(missing)}")
    if extra:
        raise SystemExit(f"Unexpected description keys: {sorted(extra)}")

    lines = [
        "# Dashboard and document header copy for the ISOO standard template bundle.",
        "# Markdown supported. Keep voice original — do not mirror third-party catalogue wording.",
        "",
    ]
    for doc_id in ordered_ids:
        text = DESCRIPTIONS[doc_id].rstrip() + "\n"
        lines.append(f"{doc_id}: |")
        for line in text.splitlines():
            lines.append(f"  {line}")
        lines.append("")
    GUIDANCE.write_text("\n".join(lines), encoding="utf-8")


def replace_root_schema_description(content: str, new_text: str) -> str:
    pattern = re.compile(
        r"(?ms)^description:\s*(?:\|\s*\n(?:  .*\n)*|(?:>.+\n(?:  .+\n)*)|(?:['\"]?)(?:.+?)(?:['\"]?)\s*\n)(?=^[a-z_]|export_tags:|$)"
    )
    block = "description: |\n" + "\n".join(f"  {line}" for line in new_text.rstrip().splitlines()) + "\n"
    if re.search(r"(?m)^description:", content):
        return pattern.sub(block, content, count=1)
    if "export_tags:" in content:
        return content.replace("export_tags:", block + "export_tags:", 1)
    return content.rstrip() + "\n" + block


def replace_front_matter_description(content: str, new_text: str) -> str:
    if not content.startswith("---"):
        return content
    parts = content.split("---", 2)
    if len(parts) < 3:
        return content
    meta = yaml.safe_load(parts[1]) or {}
    meta["description"] = new_text.rstrip()
    dumped = yaml.safe_dump(meta, sort_keys=False, allow_unicode=True, default_style=None).strip()
    if "description:" in dumped and "\n" in new_text:
        dumped = re.sub(
            r"(?ms)^description: .+$",
            "description: |\n" + "\n".join(f"  {line}" for line in new_text.rstrip().splitlines()),
            dumped,
            count=1,
        )
    return f"---\n{dumped}\n---{parts[2]}"


def sync_files() -> None:
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text(encoding="utf-8"))
    for doc in manifest["documents"]:
        doc_id = doc["doc_id"]
        text = DESCRIPTIONS[doc_id]
        base = ROOT / doc["path"]
        schema_path = base / f"{doc_id}.schema.yaml"
        md_path = base / f"{doc_id}.md"

        if schema_path.is_file():
            schema_path.write_text(
                replace_root_schema_description(schema_path.read_text(encoding="utf-8"), text),
                encoding="utf-8",
            )
        if md_path.is_file():
            md_path.write_text(
                replace_front_matter_description(md_path.read_text(encoding="utf-8"), text),
                encoding="utf-8",
            )


def main() -> None:
    write_guidance_yaml()
    sync_files()
    print(f"Synced {len(DESCRIPTIONS)} descriptions to {GUIDANCE} + schemas + markdown")


if __name__ == "__main__":
    main()
