🛡️ Defender for Endpoint Deployment Tool

A lightweight, JSON-driven deployment tool for Microsoft Defender for Endpoint (MDE) policies using Microsoft Graph.

This project simplifies how Defender policies are deployed by enabling repeatable, consistent security baselines across environments.

🚀 Overview

Deploying Defender for Endpoint policies manually can be:

Time-consuming
Inconsistent across environments
Difficult to validate

This tool provides a simple deployment engine that:

Uses JSON-based configurations
Automates policy creation via Microsoft Graph
Enables repeatable security deployments
Integrates with testing to validate security controls
🔧 Features (Phase 1)
✅ Deploy Settings Catalog policies via Microsoft Graph
✅ JSON-driven configuration model
✅ Built-in validation before deployment
✅ Export existing policies from Intune
✅ Simple UI for execution and visibility
🎯 Supported Policies

The following Defender policy types are supported:

🔥 Firewall
🛡️ Attack Surface Reduction (ASR)
📡 Endpoint Detection & Response (EDR) (cleaned / supported settings only)
🪟 Windows Security Experience
🔄 AV Configuration Controls (non-Endpoint Security)
⚠️ Important: Antivirus (AV)

Antivirus policies are NOT deployed through this tool in Phase 1.

AV must be managed through:

Intune → Endpoint Security → Antivirus
Why?

Defender Antivirus uses a different backend and template system that is not fully compatible with Settings Catalog deployment via Graph.

🧠 How It Works
1. Create policy in Intune
2. Export JSON using the tool
3. Store JSON in the repo
4. Reuse for deployment
📁 Repository Structure
MDE-EndpointSecurityPolicyDeployment-Tool/
│
├─ MDE-Deployment-Tool.ps1
│
├─ Config/
│  └─ SettingsCatalog/
│     ├─ firewall.json
│     ├─ asr.json
│     ├─ edr.json
│     ├─ windows-security-experience.json
│     └─ avc-update-controls.json
│
├─ Logs/
└─ Reports/
▶️ Getting Started
1. Clone the repository
git clone https://github.com/YOUR_REPO_NAME.git
cd MDE-EndpointSecurityPolicyDeployment-Tool
2. Run the tool
.\MDE-Deployment-Tool.ps1
3. Initialize Microsoft Graph

Click:

Initialize Graph

Required permissions:

DeviceManagementConfiguration.ReadWrite.All
DeviceManagementManagedDevices.Read.All
Directory.Read.All
4. Validate JSON

Click:

Validate JSON

This ensures all policy files are ready for deployment.

5. Deploy policies

Select policies and click:

Deploy Selected

Optional:

WhatIf / Validate only
📤 Export Existing Policies

The tool includes an export feature to:

Retrieve existing Settings Catalog policies
Save them as reusable JSON
Store them in:
Config\SettingsCatalog\
🔁 Integration with Testing Framework

This tool is designed to work alongside:

👉 https://github.com/dferrell30/MDE-Test-Framework

Together, they enable:

Deploy → Test → Validate → Repeat

This ensures that Defender policies are not only deployed, but also verified in real-world scenarios.

🚧 Roadmap (Phase 2)

Planned improvements:

🔜 Automatic policy assignment
🔜 Endpoint Security (AV) integration
🔜 Deployment reporting
🔜 Policy drift detection
🔜 Enhanced validation
💡 Design Philosophy
Keep it simple
Keep it repeatable
Keep it transparent
⚠️ Disclaimer

This is an early iteration and is actively being improved.
Test thoroughly before using in production environments.

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
