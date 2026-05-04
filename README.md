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
  
