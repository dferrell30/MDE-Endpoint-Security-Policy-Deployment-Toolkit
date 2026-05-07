# 🚀 Microsoft Defender for Endpoint Deployment Tool — Runbook

A PowerShell-based deployment and validation tool for Microsoft Defender for Endpoint Settings Catalog policies.


## 📚 Table of Contents

Overview
Capabilities
Prerequisites
Repository Structure
Launching the Tool
Initialize Microsoft Graph
Refresh JSON List
Validate JSON
WhatIf / Validation Mode
Deploying Policies
Assigning Policies
Export Existing Policies
Backup All Policies
Generate HTML Reports
Open Config / Logs / Reports
Clear Results
Scenarios and Expected Outcomes
Operational Notes
Recommended Workflow

# 🔍 Overview

The Microsoft Defender for Endpoint Deployment Tool is a PowerShell-based utility designed to simplify deployment and validation of Microsoft Defender for Endpoint related Intune Settings Catalog policies.

The tool supports:

✅ JSON-driven deployments
✅ Intune Settings Catalog policies
✅ Dynamic JSON loading
✅ Policy export
✅ Policy backup
✅ Assignment automation
✅ HTML reporting
✅ Zero Trust visibility
✅ Deployment validation

# ⚡ Capabilities
Capability	Description
Settings Catalog Deployment	Deploy Defender Settings Catalog policies
JSON Validation	Validate JSON before deployment
WhatIf Validation	Safe deployment testing
Policy Export	Export existing Intune policies
Policy Backup	Backup deployed policies
Dynamic JSON Discovery	Auto-load JSON from repo
Assignment Support	Assign policies automatically
HTML Reporting	Generate deployment evidence reports
Zero Trust Checklist	Visibility into baseline alignment
Logging	Detailed deployment logging

# 📋 Prerequisites

-Requirements
-Requirement	Details
-OS	Windows
-PowerShell	5.1 or later
-Microsoft Graph SDK	Required
-Intune Permissions	Device Configuration Administrator or equivalent
-Entra ID Group	Required for assignments
-Install Microsoft Graph SDK

Run PowerShell as Administrator:

Install-Module Microsoft.Graph -Scope CurrentUser

# 📁 Repository Structure

Expected repository structure:

MDE-EndpointSecurityPolicyDeployment-Tool-main
│
├─ MDE-Deployment-Tool.ps1
│
├─ Config
│  └─ SettingsCatalog
│     ├─ firewall.json
│     ├─ asr.json
│     ├─ edr.json
│     ├─ windows-security-experience.json
│     └─ avc-update-controls.json
│
├─ Logs
├─ Reports
└─ Backups

# ▶️ Launching the Tool

Step 1 — Open PowerShell

Open PowerShell normally or as Administrator.

Step 2 — Navigate to Repository

Powershell``
cd "C:\Users\derri\OneDrive\Documents\Github\MDE-EndpointSecurityPolicyDeployment-Tool-main"
``

Step 3 — Launch Tool

Powershell``
.\MDE-Deployment-Tool.ps1
``

# ✅ Expected Outcome

Result
Defender for Endpoint Deployment Tool UI launches

## 🔐 Initialize Microsoft Graph

Click:

Initialize Graph

Authenticate when prompted.

✅ Expected Outcome

Connected to Microsoft Graph.

❌ Common Failures
Error	Resolution
Not connected to Microsoft Graph	Install Graph SDK
Authentication failed	Retry sign-in
Insufficient permissions	Use Intune admin account

## 🔄 Refresh JSON List

Click:

Refresh JSON List
Purpose

The tool scans:

Config\SettingsCatalog

for .json files.

✅ Expected Outcome

Result
All JSON files appear in the policy table

## 🧪 Validate JSON

Click:

Validate JSON
Validation Checks
Validation	Description
File Exists	JSON file exists
JSON Readable	JSON can be parsed
Settings Array Exists	settings array exists
Settings Populated	Settings array is not empty

✅ Expected Outcome

firewall.json: Valid - JSON passed basic validation
asr.json: Valid - JSON passed basic validation

❌ Common Failures

Error	Resolution
Missing settings array	Re-export Settings Catalog JSON
JSON parsing failed	Repair malformed JSON

## 🛡️ WhatIf / Validation Mode

Purpose

Test deployments without creating policies.

Steps
Step	Action
1	Enable WhatIf / Validate only
2	Select policy
3	Click Deploy Selected

✅ Expected Outcome
MDE - Firewall: WhatIf - Validated JSON only

## 🚀 Deploying Policies
Steps
Step	Action
1	Disable WhatIf
2	Select policies
3	Click Deploy Selected

✅ Expected Outcome
MDE - Firewall: Success - Created configuration policy
Existing Policy Behavior
Status	Meaning
Success	Policy created
Skipped	Policy already exists
Failed	Graph deployment failure

## 👥 Assigning Policies
Steps
Step	Action
1	Enter Entra group name
2	Enable Assign after deploy
3	Deploy policy
Example Group
MDE Pilot Devices

✅ Expected Outcome
Assigned - Assigned to group: MDE Pilot Devices

❌ Common Failures
Error	Cause
Group not found	Incorrect group display name

## 📤 Export Existing Policies

Purpose

Export existing Intune Settings Catalog policies into reusable JSON.

Steps

Step	Action

1	Click Export Existing Policy
2	Enter exact policy name
3	Save into Config\SettingsCatalog
4	Refresh JSON List

✅ Expected Outcome

Result
Exported JSON appears automatically in UI

## 💾 Backup All Policies

Purpose

Create timestamped backups of deployed policies.

Steps
Step	Action
1	Initialize Graph
2	Click Backup All Policies

✅ Expected Output

Folder	Description
Backups\yyyy-MM-dd_HH-mm	Timestamped backup folder

Example
Backups\2026-05-05_21-45
Expected Contents
File	Description
backup-summary.txt	Backup summary
firewall.json	Exported firewall policy
asr.json	Exported ASR policy
edr.json	Exported EDR policy
windows-security-experience.json	Exported policy

## 📊 Generate HTML Reports

Purpose

Generate deployment evidence reports.

Steps

Step	Action

-1	Deploy or validate policies
-2	Click Generate Report

Report Includes

-Section	Description
-Deployment Results	Deployment status tracking
-Settings Inventory	Deployed setting visibility
-Zero Trust Checklist	Security alignment visibility
-Output Location
-Reports\deployment-report.html

## 📂 Open Config / Logs / Reports

-Button	Opens
-Open Config Folder	Config directory
-Open Logs Folder	Logs directory
-Open Reports Folder	Reports directory
-Important Files
-File	Purpose
-deployment.log	Deployment logging
-deployment-report.html	HTML report
-backup-summary.txt	Backup summary

## 🧹 Clear Results

Purpose

Clear deployment status table without removing logs or reports.

Action

Click:

Clear Results

✅ Expected Outcome

Result

Results table clears
Logs remain
Reports remain
Policies remain

## 🧪 Scenarios and Expected Outcomes

Scenario 1 — Initial Validation

Steps
Step	Action
1	Launch tool
2	Refresh JSON List
3	Validate JSON

## ✅ Expected Outcome

Result
All JSON files validate successfully

Scenario 2 — Safe Deployment Test
Steps
Step	Action
1	Enable WhatIf
2	Select Firewall
3	Deploy Selected

## ✅ Expected Outcome

MDE - Firewall: WhatIf - Validated JSON only
Scenario 3 — Production Deployment
Steps
Step	Action
1	Disable WhatIf
2	Select Firewall
3	Deploy Selected

✅ Expected Outcome
Success - Created configuration policy
Scenario 4 — Existing Policy
Steps
Step	Action
1	Deploy policy already existing

✅ Expected Outcome
Skipped - Policy already exists
Scenario 5 — Deploy and Assign
Steps
Step	Action
1	Enter group name
2	Enable Assign after deploy
3	Deploy policy

✅ Expected Outcome
Assigned - Assigned to group
Scenario 6 — Export Existing Policy
Steps
Step	Action
1	Export existing policy
2	Save JSON
3	Refresh JSON List

✅ Expected Outcome

Result

Exported JSON appears automatically

Scenario 7 — Backup Policies

Steps

Step	Action
-1	Initialize Graph
-2	Backup All Policies

✅ Expected Outcome

Result

Timestamped backup folder created

Scenario 8 — Generate Report

Steps

Step	Action
-1	Deploy or validate
-2	Generate Report

✅ Expected Outcome
Result
deployment-report.html generated

## 📝 Operational Notes
Policy Naming

Policies deploy using:

MDE -

Example:

-JSON Name	Intune Policy Name
-Firewall	MDE - Firewall
-Dynamic JSON Loading

Any .json placed into:

Config\SettingsCatalog

will automatically appear after:

-Refresh JSON List
-Antivirus Note
-Note	Details
-Supported	Settings Catalog AV policies
-Not Fully Supported	Full Endpoint Security Antivirus profile imports
-EDR Note

Avoid including:

device_vendor_msft_windowsadvancedthreatprotection_onboarding_fromconnector

This value is tenant-specific and may fail deployment.

## 🔁 Recommended Workflow

Standard Operational Flow
Backup → Validate → WhatIf → Deploy → Assign → Report
Recommended Steps
Step	Action

-1	Run tool
-2	Initialize Graph
-3	Refresh JSON List
-4	Validate JSON
-5	Backup All Policies
-6	Run WhatIf
-7	Deploy policies
8	Assign to pilot group
9	Generate report
10	Review logs and report
