
# 🛡️ Defender for Endpoint Deployment Tool

![Status](https://img.shields.io/badge/status-Phase%201-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A lightweight, JSON-driven deployment tool for Microsoft Defender for Endpoint (MDE) policies using Microsoft Graph.

This project simplifies how Defender policies are deployed by enabling **repeatable, consistent security baselines** across environments.

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

The following Defender policy types are supported:

- 🔥 Firewall  
- 🛡️ Attack Surface Reduction (ASR)  
- 📡 Endpoint Detection & Response (EDR) *(supported settings only)*  
- 🪟 Windows Security Experience  
- 🛡️ Defender Antivirus (Settings Catalog / AV Configuration Controls)

---

## 🛡️ Defender Antivirus (AV)

This tool supports deployment of Defender Antivirus settings via **Settings Catalog (AV Configuration Controls)**.

### ⚠️ Important Notes

- Only **supported Settings Catalog AV settings** should be used  
- Some AV settings (such as onboarding and certain advanced configurations) are **not compatible** with Graph deployment  
- Endpoint Security Antivirus profiles use a different backend and are **not currently targeted in Phase 1**

### Recommended Approach

- Use this tool for **baseline AV configuration**
- Use Intune Endpoint Security for:
  - Advanced AV configurations  
  - Onboarding and tenant-bound settings
 

## ⚠️ Known Limitations

This tool focuses on **Settings Catalog-based deployment via Microsoft Graph**.  
Some Defender capabilities behave differently or require alternative deployment methods.

---

### 🔥 Firewall Policies

- Firewall policies must be created and exported from:
  


🤝 Feedback

Feedback, ideas, and suggestions are welcome.

📣 Author

Built to simplify Defender for Endpoint deployment and validation workflows.

⚠️ Disclaimers This project is intended for defensive security validation and educational use.

Do not use this framework in unauthorized environments Do not use for offensive or malicious purposes Always perform testing in approved lab or enterprise environments Some tests generate telemetry that may trigger alerts

The author is not responsible for misuse of this tool or unintended impacts resulting from its execution.

This tool is provided for educational, testing, and security validation purposes only.

Use of this tool should be limited to:

Authorized environments Lab or approved enterprise systems The author assumes no liability or responsibility for:

Misuse of this tool Damage to systems Unauthorized or improper use By using this tool, you agree to use it in a lawful and responsible manner.

This project is not affiliated with or endorsed by Microsoft.

⚖️ Professional Disclaimer This project is an independent work developed in a personal capacity.

The views, opinions, code, and content expressed in this repository are solely my own and do not reflect the views, policies, or positions of any current or future employer, client, or affiliated organization.

No employer, past, present, or future, has reviewed, approved, endorsed, or is in any way associated with these works.

This project was developed outside the scope of any employment and without the use of proprietary, confidential, or restricted resources.

All code/language in this repository is provided under the terms of the included MIT License.
