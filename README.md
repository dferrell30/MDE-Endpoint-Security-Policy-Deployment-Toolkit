# 🛡️ Defender for Endpoint Deployment Tool

![Status](https://img.shields.io/badge/status-Phase%201-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A lightweight, JSON-driven deployment tool for Microsoft Defender for Endpoint (MDE) policies using Microsoft Graph.

This project simplifies how Defender policies are deployed by enabling **repeatable, consistent security baselines** across environments.

<img width="1084" height="881" alt="image" src="https://github.com/user-attachments/assets/6bd8f83f-083a-4b30-b26f-c6ee7029cab6" />

---

## 🚀 Overview

Deploying Defender for Endpoint policies manually can be:

- Time-consuming  
- Inconsistent across environments  
- Difficult to validate  

This tool provides a **simple deployment engine** that:

- Uses JSON-based configurations  
- Automates policy creation via Microsoft Graph  
- Enables repeatable security deployments  
- Supports Defender Antivirus baseline configuration via Settings Catalog  
- Integrates with testing to validate security controls  

---

## 🔧 Features (Phase 1)

- ✅ Deploy Settings Catalog policies via Microsoft Graph  
- ✅ JSON-driven configuration model  
- ✅ Built-in validation before deployment  
- ✅ Export existing policies from Intune  
- ✅ Simple UI for execution and visibility  

---

## 🎯 Supported Policies

- 🔥 Firewall  
- 🛡️ Attack Surface Reduction (ASR)  
- 📡 Endpoint Detection & Response (EDR) *(supported settings only)*  
- 🪟 Windows Security Experience  
- 🛡️ Defender Antivirus *(Settings Catalog / AV Configuration Controls)*  

---

## ⚠️ Known Limitations

This tool focuses on **Settings Catalog-based deployment via Microsoft Graph**.  
Some Defender capabilities require alternative deployment methods.

---

### 🔥 Firewall Policies

- Must be created and exported from:


- ❌ Endpoint Security Firewall profiles are not supported  
- ✅ Only Settings Catalog firewall configurations can be deployed  

---

### 🛡️ Defender Antivirus (AV)

- Supported via **Settings Catalog (AV Configuration Controls)**  

Limitations:

- ❌ Onboarding / connector-based settings  
- ❌ Tenant-bound or encrypted values  
- ❌ Some advanced AV configurations  

Recommended:


Use Endpoint Security for:
- Advanced configurations  
- Onboarding  
- Tenant-specific settings  

---

### 📡 Endpoint Detection & Response (EDR)

- Connector-based onboarding is **not supported**  

Do NOT include:


- Only supported, non-connector-based settings should be used  

---

### ⚙️ Settings Catalog Dependency

- All policies must originate from **Settings Catalog exports**  

Hand-built JSON may fail due to:

- Incorrect setting types (Simple vs Choice)  
- Missing template references  
- Invalid values for tenant-specific schemas  

---

### 🔐 Graph API Constraints

This tool uses:


Some Defender features use different APIs and are not included in Phase 1.

---

### 🧪 Validation Scope

Built-in validation checks:

- JSON structure  
- Presence of settings  

Does NOT validate:

- Tenant compatibility  
- Setting-level Graph constraints  
- Endpoint Security template conflicts  

---

### 🚧 Phase 1 Scope

This tool is designed for:

- Repeatable baseline deployment  
- Settings Catalog policy automation  

Not included yet:

- Automatic policy assignment  
- Endpoint Security policy deployment  
- Drift detection  

---

## 📁 Repository Structure

MDE-EndpointSecurityPolicyDeployment-Tool/
│
├─ MDE-Deployment-Tool.ps1
│
├─ Config/
│ └─ SettingsCatalog/
│ ├─ firewall.json
│ ├─ asr.json
│ ├─ edr.json
│ ├─ windows-security-experience.json
│ └─ avc-update-controls.json
│
├─ Logs/
└─ Reports/

---

## 🧠 How It Works

Create policy in Intune
Export JSON using the tool
Store JSON in the repo
Reuse for deployment

---

## 🔁 Integration with Testing Framework

This tool is designed to work alongside:

👉 https://github.com/dferrell30/MDE-Test-Framework :contentReference[oaicite:0]{index=0}

Together, they enable:


Deploy → Test → Validate → Repeat


---

## ⚠️ Disclaimer

This project is intended for **defensive security validation and educational use only**.

- Do not use in unauthorized environments  
- Do not use for offensive or malicious purposes  
- Always test in approved lab or enterprise environments  

Some actions may generate security telemetry and alerts.

---

## ⚖️ Professional Disclaimer

This project is an independent work developed in a personal capacity.

- It is not affiliated with or endorsed by Microsoft  
- No employer has reviewed or approved this work  
- No proprietary or confidential resources were used  

All opinions and content are solely my own.

---

## 🤝 Feedback

Feedback, ideas, and suggestions are welcome.

---

## 📣 Author

Built to simplify Defender for Endpoint deployment and validation workflows.

⚠️ Disclaimers This project is intended for defensive security validation and educational use.

Do not use this framework in unauthorized environments Do not use for offensive or malicious purposes Always perform testing in approved lab or enterprise environments Some tests generate telemetry that may trigger alerts

The author is not responsible for misuse of this tool or unintended impacts resulting from its execution.

This tool is provided for educational, testing, and security validation purposes only.

Use of this tool should be limited to:

Authorized environments Lab or approved enterprise systems The author assumes no liability or responsibility for:

Misuse of this tool Damage to systems Unauthorized or improper use By using this tool, you agree to use it in a lawful and responsible manner.

This project is not affiliated with or endorsed by Microsoft.

---

⚖️ Professional Disclaimer This project is an independent work developed in a personal capacity.

The views, opinions, code, and content expressed in this repository are solely my own and do not reflect the views, policies, or positions of any current or future employer, client, or affiliated organization.

No employer, past, present, or future, has reviewed, approved, endorsed, or is in any way associated with these works.

This project was developed outside the scope of any employment and without the use of proprietary, confidential, or restricted resources.

All code/language in this repository is provided under the terms of the included MIT License.
  
